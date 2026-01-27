import 'dart:convert';
import 'package:http/http.dart' as http;

// Function to verify email using AbstractAPI
Future<bool> isEmailReal(String email) async {
  final apiKey = '03094af5d6104e678258f68ba9ed9bf4';
  final url = Uri.parse(
      'https://emailvalidation.abstractapi.com/v1/?api_key=$apiKey&email=$email');

  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // AbstractAPI returns a "deliverability" field: DELIVERABLE / UNDELIVERABLE / UNKNOWN
      String deliverability = data['deliverability'] ?? 'UNKNOWN';
      print('Email: $email -> Deliverability: $deliverability');

      return deliverability == 'DELIVERABLE';
    } else {
      print('Failed to verify email: ${response.statusCode}');
      return false;
    }
  } catch (e) {
    print('Error verifying email: $e');
    return false;
  }
}
