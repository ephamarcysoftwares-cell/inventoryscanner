// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//
// class PesapalSecureStorage {
//   static final _storage = FlutterSecureStorage();
//
//   static Future<void> savePesapalKeys(
//       String key, String secret, String notificationId) async {
//     await _storage.write(key: 'pesapal_consumer_key', value: key);
//     await _storage.write(key: 'pesapal_consumer_secret', value: secret);
//     await _storage.write(key: 'pesapal_notification_id', value: notificationId);
//   }
//
//   static Future<Map<String, String>> getPesapalKeys() async {
//     String? key = await _storage.read(key: 'pesapal_consumer_key');
//     String? secret = await _storage.read(key: 'pesapal_consumer_secret');
//     String? notificationId = await _storage.read(key: 'pesapal_notification_id');
//
//     if (key == null || secret == null || notificationId == null) {
//       throw Exception("Pesapal API keys are missing.");
//     }
//
//     return {
//       'consumer_key': key,
//       'consumer_secret': secret,
//       'notification_id': notificationId,
//     };
//   }
// }
