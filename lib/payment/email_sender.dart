import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

Future<void> sendEmailReceipt(String email, String customerName, double amount) async {
  String username = "your_email@gmail.com";
  String password = "your_email_password";

  final smtpServer = gmail(username, password);

  final message = Message()
    ..from = Address(username, 'e-Pharmacy')
    ..recipients.add(email)
    ..subject = "Payment Receipt - e-Pharmacy"
    ..text = "Hello $customerName,\n\nThank you for your payment of TZS $amount via Pesapal.\n\nBest regards,\ne-Pharmacy Team";

  try {
    await send(message, smtpServer);
    print("Email sent successfully");
  } catch (e) {
    print("Failed to send email: $e");
  }
}
