import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../DB/database_helper.dart';
import '../../DB/sync_helper.dart';
import '../user_helper.dart';


class SyncService {
  static Timer? _timer;

  static void startPeriodicSync() {
    debugPrint('[SyncService] Starting periodic sync...');

    // Run immediately first time
    _sync();

    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      debugPrint('[SyncService] Timer triggered sync at ${DateTime.now()}');
      _sync();
    });
  }

  static Future<void> _sync() async {
    debugPrint('[SyncService] Sync started at ${DateTime.now()}');

    try {
      String addedBy = await UserHelper.getAddedBy();
      debugPrint('[SyncService] Retrieved addedBy: $addedBy');

      String? lastSync = await SyncHelper.getLastSyncTime();
      lastSync ??= '1970-01-01T00:00:00Z';
      debugPrint('[SyncService] Last sync time: $lastSync');

      final response = await http.get(Uri.parse(
        'https://ephamarcysoftware.co.tz/ephamarcy/get_updated_medicines.php?added_by=$addedBy&last_sync=$lastSync',
      ));
      debugPrint('[SyncService] Server response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List data = json.decode(response.body);
        debugPrint('[SyncService] Received ${data.length} items from server');

        for (var item in data) {
          debugPrint('[SyncService] Adding medicine ${item['name']} to local DB');
          await DatabaseHelper.instance.addMedicine(
            item['name'],
            item['company'],
            int.parse(item['total_quantity']),
            double.parse(item['remaining_quantity'].toString()),
            double.parse(item['buy'].toString()),
            item['price'].toString(),
            item['batchNumber'],
            item['manufacture_date'],
            item['expiry_date'],
            item['added_by'],
            item['discount'].toString(),
            item['updated_at'],
            item['unit'],
            item['businessName'],
          );
        }

        debugPrint('[SyncService] Finished adding medicines. Saving sync time...');
        await SyncHelper.saveLastSyncTime(DateTime.now().toIso8601String());
        debugPrint('[SyncService] Sync time saved.');
      } else {
        debugPrint('[SyncService] Failed to sync from server: ${response.statusCode}');
      }
    } catch (e, stacktrace) {
      debugPrint('[SyncService] Error during sync: $e');
      debugPrint(stacktrace.toString());
    }

    debugPrint('[SyncService] Sync finished at ${DateTime.now()}');
  }
}
