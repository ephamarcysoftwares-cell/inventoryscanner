import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

import '../DB/database_helper.dart';

class UserSyncService {
  static Timer? _syncTimer;

  static void startPeriodicSync() {
    print('Starting periodic user sync every 5 minutes...');
    // Run immediately on start
    syncAllUsersToServer();

    // Schedule every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      syncAllUsersToServer();
    });
  }

  static void stopPeriodicSync() {
    print('Stopping periodic user sync...');
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  static Future<void> syncAllUsersToServer() async {
    try {
      // Check internet connectivity
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        print('[SYNC DEBUG] No internet connection. Sync skipped.');
        return;
      }

      final localUsers = await DatabaseHelper.instance.getAllUsers();
      print('[SYNC DEBUG] Starting sync. Total local users to sync: ${localUsers.length}');

      for (var user in localUsers) {
        print('[SYNC DEBUG] Syncing user id: ${user['id']}');

        final success = await _postUserToServer(user);
        if (success) {
          print('[SYNC DEBUG] User id ${user['id']} synced successfully.');
        } else {
          print('[SYNC DEBUG] Failed to sync user id ${user['id']}.');
        }
      }

      print('[SYNC DEBUG] User sync cycle completed.');
    } catch (e, stacktrace) {
      print('[SYNC ERROR] Error syncing users: $e');
      print(stacktrace);
    }
  }

  static Future<bool> _postUserToServer(Map<String, dynamic> user) async {
    final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/sync_user.php');

    try {
      final jsonBody = jsonEncode(user);
      print('[SYNC DEBUG] Posting user data: $jsonBody');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      );

      print('[SYNC DEBUG] POST response status: ${response.statusCode}');
      print('[SYNC DEBUG] POST response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('[SYNC ERROR] Server returned error status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('[SYNC ERROR] Exception while posting user data: $e');
      return false;
    }
  }
}
