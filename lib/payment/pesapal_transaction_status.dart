// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../payment/pesapal_secure_storage.dart';
//
// class PesapalTransactionStatus {
//   static Future<String> checkTransactionStatus(String transactionId) async {
//     Map<String, String> keys = await PesapalSecureStorage.getPesapalKeys();
//     String consumerKey = keys['consumer_key']!;
//     String consumerSecret = keys['consumer_secret']!;
//
//     String url = "https://www.pesapal.com/api/transactions/$transactionId/status";
//
//     final response = await http.get(Uri.parse(url), headers: {
//       "Authorization": "Basic ${base64Encode(utf8.encode('$consumerKey:$consumerSecret'))}",
//       "Accept": "application/json",
//     });
//
//     if (response.statusCode == 200) {
//       var data = jsonDecode(response.body);
//       return data["status"];
//     } else {
//       throw Exception("Failed to fetch transaction status");
//     }
//   }
// }
