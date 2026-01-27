// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';
//
// import '../API/payment_conmfemetion.dart';
// import '../DB/database_helper.dart';
//
//
// Future<void> checkPaymentsAndSendEmails() async {
//   try {
//     final transactionMaps = await DatabaseHelper.instance.getAllTransactions();
//
//     if (transactionMaps.isEmpty) {
//       print("No payments found.");
//       return;
//     }
//
//     List<PaymentTransaction> transactions = transactionMaps
//         .map((map) => PaymentTransaction.fromJson(map))
//         .toList();
//
//     for (final tx in transactions) {
//       if (tx.status == 'Completed' && tx.customerEmailSent == 0) {
//         try {
//           await sendCustomerPaymentReceivedEmail(
//             customerEmail: tx.customerEmail ?? '',
//             fullName: tx.fullName ?? '',
//             amount: tx.amount,
//             paymentDate: tx.paymentDate ?? '',
//             nextPaymentDate: tx.nextPaymentDate,
//           );
//
//           await DatabaseHelper.instance.markCustomerEmailSent(tx.id);
//           print("Email sent for payment id: ${tx.id}");
//         } catch (e) {
//           print("Failed to send email for payment id ${tx.id}: $e");
//         }
//       }
//     }
//   } catch (e) {
//     print("Error during payment check: $e");
//   }
// }
//
// Future<void> sendCustomerPaymentReceivedEmail({
//   required String customerEmail,
//   required String fullName,
//   required double amount,
//   required String paymentDate,
//   String? nextPaymentDate,
// }) async {
//   final smtpServer = SmtpServer(
//     'mail.ephamarcysoftware.co.tz',
//     username: 'suport@ephamarcysoftware.co.tz',
//     password: 'Matundu@2050',
//     port: 465,
//     ssl: true,
//   );
//
//   final message = Message()
//     ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
//     ..recipients.add(customerEmail)
//     ..subject = '✅ Thank you so much, your payment has been received!'
//     ..html = '''
//       <p>Dear <strong>$fullName</strong>,</p>
//       <p>We have received your payment of <strong>\$$amount</strong> on <strong>$paymentDate</strong>.</p>
//       ${nextPaymentDate != null ? "<p>Your next payment is due on <strong>$nextPaymentDate</strong>.</p>" : ""}
//       <p>Thank you for your support!</p>
//     ''';
//
//   await send(message, smtpServer);
// }
