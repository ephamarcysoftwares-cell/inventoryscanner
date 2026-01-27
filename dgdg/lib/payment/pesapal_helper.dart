import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';


class PesapalHelper {
  static const String consumerKey = "XNVCGHeOqfKVcPxISIY9ECHG338=";
  static const String consumerSecret = "aOp1+QllzGP2Y2GZqM9lxq9ekC1AbrrY";
  static const String pesapalUrl = "https://pay.pesapal.com/v3/api";

  static Future<String?> getAccessToken() async {
    final response = await http.post(
      Uri.parse("$pesapalUrl/Auth/RequestToken"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "consumer_key": consumerKey,
        "consumer_secret": consumerSecret,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)["token"];
    }
    return null;
  }

  static Future<String?> initiatePayment({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required double amount,
    required String currency,
    required String callbackUrl,
  }) async {
    String? token = await getAccessToken();
    if (token == null) return null;

    final response = await http.post(
      Uri.parse("$pesapalUrl/Transactions/SubmitOrderRequest"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "id": "Order-${DateTime.now().millisecondsSinceEpoch}",
        "amount": amount.toString(),
        "currency": currency,
        "description": "Purchase Description",
        "callback_url": callbackUrl,
        "notification_id": "YOUR_NOTIFICATION_ID",
        "billing_address": {
          "email_address": email,
          "phone_number": phoneNumber,
          "first_name": firstName,
          "last_name": lastName
        }
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["redirect_url"];
    }
    return null;
  }
}
