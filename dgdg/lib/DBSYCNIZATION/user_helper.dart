import 'package:shared_preferences/shared_preferences.dart';

class UserHelper {
  static Future<void> saveAddedBy(String addedBy) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('added_by', addedBy);
  }

  static Future<String> getAddedBy() async {
    final prefs = await SharedPreferences.getInstance();
    // Provide a default user or handle as needed
    return prefs.getString('added_by') ?? 'defaultUser';
  }
}
