import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../DB/database_helper.dart';

class MedicalLogSyncService {
  static Timer? _syncTimer;

  static void startPeriodicSync() {
    print('Starting periodic medical logs sync...');
    // Run immediately on start
    _syncLogsToServer();

    // Schedule every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _syncLogsToServer();
    });
  }

  static void stopPeriodicSync() {
    print('Stopping periodic medical logs sync...');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _syncLogsToServer() async {
    try {
      // Check internet connectivity before syncing
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection. Sync skipped.');
        return;
      }

      final localLogs = await DatabaseHelper.instance.getAllMedicalLogs();

      print('Starting sync. Total local medical logs: ${localLogs.length}');

      for (var log in localLogs) {
        final logId = log['id'];
        print('Processing medical log id: $logId');

        // Check if log exists on server
        bool exists = await _checkLogExistsOnServer(logId);
        print('Medical log id $logId exists on server? $exists');

        if (!exists) {
          bool posted = await _postLogToServer(log);
          if (posted) {
            print('Posted medical log id $logId to server.');

            // Mark local log as synced (implement in DatabaseHelper)
            await DatabaseHelper.instance.updateMedicalLogSyncedFlag(logId, 1);
          } else {
            print('Failed to post medical log id $logId.');
          }
        } else {
          print('Medical log id $logId already exists on server.');

          // Mark as synced anyway if already on server
          await DatabaseHelper.instance.updateMedicalLogSyncedFlag(logId, 1);
        }
      }
      print('Medical logs sync cycle completed.');
    } catch (e, stacktrace) {
      print('Error syncing medical logs: $e');
      print(stacktrace);
    }
  }

  static Future<bool> _checkLogExistsOnServer(dynamic id) async {
    final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_log.php?id=$id');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.body;
        print('Existence check response body: $data');

        final jsonData = jsonDecode(data);
        return jsonData['exists'] ?? false;
      } else {
        print('Check medical log exists failed. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error checking medical log on server: $e');
    }
    return false;
  }

  static Future<bool> _postLogToServer(Map<String, dynamic> log) async {
    final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_log.php');

    try {
      print('Posting medical log data: ${jsonEncode(log)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(log),
      );

      print('POST response status: ${response.statusCode}');
      print('POST response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error posting medical log to server: $e');
      return false;
    }
  }
}
