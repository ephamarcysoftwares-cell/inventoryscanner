import 'package:shared_preferences/shared_preferences.dart';

class SyncHelper {
  static Future<void> saveLastSyncTime(String time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', time);
  }

  static Future<String?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_sync');
  }
}
