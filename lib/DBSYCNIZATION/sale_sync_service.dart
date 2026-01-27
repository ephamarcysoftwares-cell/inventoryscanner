import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../DB/database_helper.dart';  // Adjust path as needed

class SaleSyncService {
  /// Fetch and sync unsynced sales (optionally filtered by date)
  static Future<void> syncUnsyncedSales({String? date}) async {
    print("[SYNC] Starting sales sync. Date filter: $date");

    // Check internet connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print("[SYNC] No internet connection. Aborting sync.");
      return;
    }

    // Fetch unsynced sales from local DB
    final sales = await DatabaseHelper.instance.fetchUnsyncedSales(date: date);
    print("[SYNC] Found ${sales.length} unsynced sale(s) to sync.");

    for (var sale in sales) {
      print("[SYNC] Syncing sale ID: ${sale['id']}");
      print("[SYNC] Sale data: ${jsonEncode(sale)}");

      try {
        // Send POST request to server API
        final response = await http.post(
          Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_sale.php'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode(sale),
        );

        print("[SYNC] Server response: ${response.statusCode} - ${response.body}");

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          if (responseData['success'] == true) {
            // Mark sale as synced locally
            await DatabaseHelper.instance.updateSaleSyncStatus(sale['id'], synced: 1);
            print("[SYNC] ✅ Sale ID ${sale['id']} synced successfully.");
          } else {
            print("[SYNC] ❌ Server responded but success==false for sale ID ${sale['id']}. Response: ${response.body}");
          }
        } else {
          print("[SYNC] ❌ Failed to sync sale ID ${sale['id']}. HTTP code: ${response.statusCode}");
        }
      } catch (e) {
        print("[SYNC] 🚫 Exception syncing sale ID ${sale['id']}: $e");
      }
    }

    print("[SYNC] Sales sync completed.");
  }
}
