import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  static const String pesapalConsumerKey = "aOp1+QllzGP2Y2GZqM9lxq9ekC1AbrrY";
  static const String pesapalConsumerSecret = "XNVCGHeOqfKVcPxISIY9ECHG338=";
  static const String pesapalUrl = "https://cybqa.pesapal.com"; // Sandbox URL

  /// Generate PesaPal Payment URL
  static Future<String?> createPesaPalPayment(double amount, String currency, String email) async {
    try {
      // 1️⃣ Get Authentication Token
      final authResponse = await http.post(
        Uri.parse("$pesapalUrl/pesapalv3/api/Auth/RequestToken"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "consumer_key": pesapalConsumerKey,
          "consumer_secret": pesapalConsumerSecret,
        }),
      );

      if (authResponse.statusCode == 200) {
        String accessToken = jsonDecode(authResponse.body)["token"];

        // 2️⃣ Create Payment Order
        final paymentResponse = await http.post(
          Uri.parse("$pesapalUrl/pesapalv3/api/Transactions/SubmitOrderRequest"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Content-Type": "application/json"
          },
          body: jsonEncode({
            "amount": amount.toString(),
            "currency": currency,
            "description": "E-Pharmacy Payment Subscription",
            "callback_url": "epharmacy://payment-success",
            "notification_id": "964ff1f5-d41c-42cf-82b9-dc073922c07e", // Your IPN ID
            "customer": {"email": email}
          }),
        );

        if (paymentResponse.statusCode == 200) {
          return jsonDecode(paymentResponse.body)["redirect_url"];
        }
      }
      return null;
    } catch (e) {
      print("PesaPal Error: $e");
      return null;
    }
  }
}
