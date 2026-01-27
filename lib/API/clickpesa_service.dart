import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class ClickPesaService {
  final String _clientId = "IDZdzneti4V2DNdsuFemUgxLcPmkxkyL";
  final String _apiKey = "SKrEvNLpJ6nRdPns5rwZJzE8SkqfTG0MZzW7kTd3kR";
  final String _waInstance = "27E9E9F88CC1";
  final String _waToken = "jOos7Fc3cE7gj2";

  Future<Map<String, dynamic>> initiateUssdPush({
    required String amount,
    required String phoneNumber,
    required String customerName,
    required String orderId,
  }) async {
    try {
      // 1. Get Token
      final tokenResp = await http.post(
        Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
        headers: {'api-key': _apiKey, 'client-id': _clientId},
      );
      if (tokenResp.statusCode != 200) return {"success": false, "message": "Auth Error"};

      String token = jsonDecode(tokenResp.body)['token'].toString().replaceFirst("Bearer ", "");

      // 2. Format Phone
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = "255${cleanPhone.substring(1)}";

      // 3. Request Payment
      final payResp = await http.post(
        Uri.parse("https://api.clickpesa.com/third-parties/payments/initiate-ussd-push-request"),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "amount": amount,
          "currency": "TZS",
          "orderReference": Random().nextInt(999999).toString(),
          "phoneNumber": cleanPhone,
          "checksum": "PLACEHOLDER_CHECKSUM"
        }),
      );

      bool success = payResp.statusCode == 200 || payResp.statusCode == 202;

      // 4. WhatsApp Notification (Optional)
      if (success) {
        await http.post(
          Uri.parse("https://wawp.net/wp-json/awp/v1/send"),
          body: {
            'instance_id': _waInstance,
            'access_token': _waToken,
            'chatId': cleanPhone,
            'message': "Order #$orderId received. Amount: TZS $amount. Thank you for shopping at 1 STOCK Arusha!",
          },
        );
      }

      return {"success": success, "message": success ? "Success" : "Failed to initiate push"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}