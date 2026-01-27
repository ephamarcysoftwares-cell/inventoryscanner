// // import 'package:flutter_secure_storage/flutter_secure_storage.dart';
//
// class PesapalConfig {
//   static final _storage = FlutterSecureStorage();
//
//   static Future<void> saveKeys(String key, String secret) async {
//     await _storage.write(key: 'pesapal_consumer_key', value: key);
//     await _storage.write(key: 'pesapal_consumer_secret', value: secret);
//   }
//
//   static Future<Map<String, String>> getKeys() async {
//     String? key = await _storage.read(key: 'pesapal_consumer_key');
//     String? secret = await _storage.read(key: 'pesapal_consumer_secret');
//
//     if (key == null || secret == null) {
//       throw Exception("Pesapal API keys are not set.");
//     }
//
//     return {
//       'consumer_key': key,
//       'consumer_secret': secret,
//     };
//   }
// }
//
// class FlutterSecureStorage {
// }
