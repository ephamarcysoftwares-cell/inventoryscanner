import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import 'PaymentTransaction.dart';

// Model
class PaymentTransaction {
  final int id;
  final String? status;
  final String? paymentDate;
  final String? nextPaymentDate;
  final double amount;
  final int synced; // 0=not emailed yet, 1=emailed
  final String? firstName;
  final String? lastName;

  PaymentTransaction({
    required this.id,
    this.status,
    this.paymentDate,
    this.nextPaymentDate,
    required this.amount,
    required this.synced,
    this.firstName,
    this.lastName,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as int,
      status: json['status'] as String?,
      paymentDate: json['payment_date'] as String?,
      nextPaymentDate: json['next_payment_date'] as String?,
      amount: (json['amount'] as num).toDouble(),
      synced: json['synced'] as int? ?? 0,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
    );
  }
}

// Background task: check for new payments and notify admins
Future<void> backgroundPaymentCheck() async {
  try {
    final transactionMaps = await DatabaseHelper.instance.getAllTransactions();

    if (transactionMaps.isEmpty) {
      print("No payments found.");
      return;
    }

    List<PaymentTransaction> transactions = transactionMaps
        .map((map) => PaymentTransaction.fromJson(map))
        .toList();

    for (final tx in transactions) {
      if (tx.status == 'Completed' && tx.synced == 0) {
        try {
          final fullName = "${tx.firstName ?? ''} ${tx.lastName ?? ''}".trim();
          final adminEmails = await DatabaseHelper.instance.getAllUserEmails();

          if (adminEmails.isEmpty) {
            print('No admin emails found.');
            continue;
          }

          await sendAdminPaymentNotificationEmail(
            adminEmails: adminEmails,
            fullName: fullName.isNotEmpty ? fullName : 'Customer',
            amount: tx.amount,
            paymentDate: tx.paymentDate ?? '',
            nextPaymentDate: tx.nextPaymentDate,
          );

          await DatabaseHelper.instance.markCustomerEmailSent(tx.id);
          print("Email sent for payment id: ${tx.id}");
        } catch (e) {
          print("Failed to send email for payment id ${tx.id}: $e");
        }
      }
    }
  } catch (e) {
    print("Error during background payment check: $e");
  }
}
Future<void> sendAdminPaymentNotificationEmail({
  required List<String> adminEmails,
  required String fullName,
  required double amount,
  required String paymentDate,
  String? nextPaymentDate,
}) async {
  if (adminEmails.isEmpty) {
    print('❗ Email NOT sent: adminEmails list is empty.');
    return;
  }

  final smtpServer = SmtpServer(
    'mail.ephamarcysoftware.co.tz',
    username: 'suport@ephamarcysoftware.co.tz',
    password: 'Matundu@2050',
    port: 465,
    ssl: true,
  );

  final plainTextContent = '''
Dear $fullName,

We are happy to inform you that your payment of TSH ${amount.toStringAsFixed(2)} has been received on $paymentDate.

${(nextPaymentDate != null && nextPaymentDate.isNotEmpty) ? 'Your next payment is scheduled on $nextPaymentDate.' : ''}

Thank you for trusting STOCK&INVENTORY SOFTWARE!

Warm regards,
STOCK&INVENTORY SOFTWARE Team
support@ephamarcysoftware.co.tz
+255 742 448 965
Arusha - Nairobi Road, Near Makao Mapya
''';

  final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8" />
<title>Payment Confirmation</title>
</head>
<body style="margin:0; padding:0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: linear-gradient(135deg, #6a11cb, #2575fc); color:#fff; text-align: center;">
  <div style="max-width: 600px; margin: auto; padding: 40px 30px;">
    <h1 style="font-size: 38px; margin-bottom: 20px;">🎉 Thank You So Much!</h1>

    <p style="font-size: 18px; line-height: 1.7;">Dear Valued Customer,</p>

    <p style="font-size: 20px; font-weight: bold; margin: 15px 0;">
      <span style="color: #ffeb3b;">$fullName</span>
    </p>

    <p style="font-size: 18px; line-height: 1.7; margin-top: 10px;">
      We are thrilled to confirm your payment of <strong>TSH ${amount.toStringAsFixed(2)}</strong> was successfully received on $paymentDate!
    </p>

    ${nextPaymentDate != null && nextPaymentDate.isNotEmpty ? '''
    <p style="font-size: 18px; line-height: 1.7; margin-top: 10px;">
      Your next payment is scheduled on <strong>$nextPaymentDate</strong>.
    </p>
    ''' : ''}

    <p style="font-size: 18px; margin-top: 20px;">
      Thank you for trusting our software to manage and grow your business.
    </p>

    <div style="margin: 40px 0;">
      <a href="#" style="display: inline-block; background: #fff; color: #2575fc; text-decoration: none; padding: 14px 30px; border-radius: 35px; font-weight: bold; font-size: 18px; box-shadow: 0 5px 10px rgba(0,0,0,0.2);">
        🌟 Explore Your Account & Features
      </a>
    </div>

    <p style="margin-top: 50px; font-size: 14px; opacity: 0.85; text-align: left;">
      Warm regards,<br />
      <strong>STOCK&amp;INVENTORY SOFTWARE Team</strong><br />
      📧 <a href="mailto:support@ephamarcysoftware.co.tz" style="color:#ffeb3b; text-decoration:none;">support@ephamarcysoftware.co.tz</a><br />
      📞 +255 742 448 965<br />
      📍 Arusha - Nairobi Road, Near Makao Mapya
    </p>
  </div>
</body>
</html>
''';

  final message = Message()
    ..from = Address('support@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
    ..recipients.addAll(adminEmails)
    ..subject = '✅ Payment received from $fullName'
    ..text = plainTextContent
    ..html = htmlContent;

  try {
    print('⏳ Sending email...');
    final sendReport = await send(message, smtpServer);
    print('✅ Email sent successfully! Report: $sendReport');
  } on MailerException catch (e) {
    print('❌ MailerException: ${e.message}');
    for (var problem in e.problems) {
      print(' - Problem: ${problem.code}: ${problem.msg}');
    }
  } catch (e) {
    print('❌ General error sending email: $e');
  }
}
