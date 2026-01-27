import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../DB/database_helper.dart';

class SyncService {
  static Timer? _syncTimer;

  static void startPeriodicSync() {
    print('Starting periodic medicine sync...');
    // Run immediately on start
    _syncMedicinesToServer();

    // Schedule every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _syncMedicinesToServer();
    });
  }

  static void stopPeriodicSync() {
    print('Stopping periodic medicine sync...');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> _syncMedicinesToServer() async {
    try {
      // Check internet connectivity before syncing
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('No internet connection. Sync skipped.');
        return;
      }

      final localMedicines = await DatabaseHelper.instance.fetchMedicines();

      print('Starting sync. Total local medicines: ${localMedicines.length}');

      for (var med in localMedicines) {
        final medName = med['name']?.toString() ?? '';
        print('Processing medicine: "$medName"');

        if (medName.isEmpty) {
          print('Skipping medicine with empty name.');
          continue;
        }

        bool exists = await _checkMedicineExistsOnServer(medName);
        print('Medicine "$medName" exists on server? $exists');

        if (!exists) {
          bool posted = await _postMedicineToServer(med);
          if (posted) {
            print('Posted medicine "$medName" to server.');

            // Mark local medicine as synced (implement this method in your DatabaseHelper)
            await DatabaseHelper.instance.updateMedicineSyncedFlag(med['id'], 1);
          } else {
            print('Failed to post medicine "$medName".');
          }
        } else {
          print('Medicine "$medName" already exists on server.');

          // Mark as synced anyway if already exists on server
          await DatabaseHelper.instance.updateMedicineSyncedFlag(med['id'], 1);
        }
      }
      print('Sync cycle completed.');
    } catch (e, stacktrace) {
      print('Error syncing medicines: $e');
      print(stacktrace);
    }
  }

  // Check if medicine exists by calling GET endpoint; expects JSON response {"exists": true/false}
  static Future<bool> _checkMedicineExistsOnServer(String name) async {
    final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_medicine.php?name=$name');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = response.body;
        print('Existence check response body: $data');

        final jsonData = jsonDecode(data);
        return jsonData['exists'] ?? false;
      } else {
        print('Check medicine exists failed. Status: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error checking medicine on server: $e');
    }
    return false;
  }

  // Post new medicine data to server
  static Future<bool> _postMedicineToServer(Map<String, dynamic> medicine) async {
    final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_medicine.php');

    try {
      print('Posting medicine data: ${jsonEncode(medicine)}');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(medicine),
      );

      print('POST response status: ${response.statusCode}');
      print('POST response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error posting medicine to server: $e');
      return false;
    }
  }
}
