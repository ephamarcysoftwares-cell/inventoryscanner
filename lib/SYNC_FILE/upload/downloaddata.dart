// File: lib/services/sync_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  final Database _database;
  final _lock = Lock();

  SyncService(this._database);

  /// Executes a full two-way synchronization: upload local changes, then download server changes.
  Future<void> performFullSync() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      print("No internet connection. Sync aborted.");
      return;
    }

    print("Starting full two-way synchronization...");
    await _lock.synchronized(() async {
      await uploadAndSyncToServer();
      await downloadAndSyncFromServer();
    });
    print("Two-way synchronization completed.");
  }

  /// Uploads all unsynced local data to the server.
  Future<void> uploadAndSyncToServer() async {
    print("Starting local data upload...");
    await _syncTable(
        'users',
        'https://ephamarcysoftware.co.tz/ephamarcy/sync_users.php',
        'local' // Indicates this is a local-to-server sync
    );
    await _syncTable(
        'medicines',
        'https://ephamarcysoftware.co.tz/ephamarcy/sync_medicines.php',
        'local'
    );
    // Add other tables to upload here
    print("Local data upload completed.");
  }

  /// Downloads all data from the server and updates the local database.
  Future<void> downloadAndSyncFromServer() async {
    print("Starting local database download...");
    await _syncTable(
        'users',
        'https://ephamarcysoftware.co.tz/ephamarcy/get_users.php',
        'server' // Indicates this is a server-to-local sync
    );
    await _syncTable(
        'medicines',
        'https://ephamarcysoftware.co.tz/ephamarcy/get_medicines.php',
        'server'
    );
    // Add other tables to download here
    print("Local database download completed.");
  }

  /// A generalized method to handle both upload and download sync for a single table.
  Future<void> _syncTable(String tableName, String apiUrl, String direction) async {
    if (direction == 'local') {
      // ----------------- UPLOAD LOGIC -----------------
      try {
        final unsyncedRecords = await _database.query(tableName, where: 'synced = ?', whereArgs: [0]);
        if (unsyncedRecords.isEmpty) {
          print('No unsynced records in $tableName to upload.');
          return;
        }

        print('Found ${unsyncedRecords.length} unsynced records in $tableName. Uploading...');

        for (var record in unsyncedRecords) {
          final localId = record['id'];
          try {
            final response = await http.post(
              Uri.parse(apiUrl),
              body: json.encode(record),
              headers: {'Content-Type': 'application/json'},
            );

            if (response.statusCode == 200) {
              final serverResponse = json.decode(response.body);
              if (serverResponse['status'] == 'success') {
                await _database.update(
                  tableName,
                  {'synced': 1},
                  where: 'id = ?',
                  whereArgs: [localId],
                );
                print('Record $localId in $tableName uploaded successfully.');
              } else {
                print('Server failed to upload record $localId: ${serverResponse['message']}');
              }
            } else {
              print('HTTP Error ${response.statusCode} uploading record $localId.');
            }
          } catch (e) {
            print('Network error uploading record $localId in $tableName: $e');
          }
        }
      } catch (e) {
        print('Error querying local database for $tableName: $e');
      }
    } else if (direction == 'server') {
      // ----------------- DOWNLOAD LOGIC -----------------
      try {
        final response = await http.get(Uri.parse(apiUrl));

        if (response.statusCode == 200) {
          final List<dynamic> serverRecords = json.decode(response.body);
          if (serverRecords.isEmpty) {
            print('No records to download for $tableName.');
            return;
          }

          final batch = _database.batch();
          for (var record in serverRecords) {
            // Use INSERT with ConflictAlgorithm.replace to prevent duplicates
            batch.insert(
              tableName,
              record,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          print('Successfully downloaded and synced ${serverRecords.length} records for $tableName.');
        } else {
          print('HTTP Error ${response.statusCode} downloading data for $tableName.');
        }
      } catch (e) {
        print('Error downloading data for $tableName: $e');
      }
    }
  }
}