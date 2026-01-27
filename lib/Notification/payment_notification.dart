// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';
// import 'package:path/path.dart';
// import 'package:path_provider/path_provider.dart';
//
// import '../DB/database_helper.dart';
// import '../login.dart';
//
// class PaymentCheckScreen extends StatefulWidget {
//   const PaymentCheckScreen({super.key});
//
//   @override
//   State<PaymentCheckScreen> createState() => _PaymentCheckScreenState();
// }
//
// class _PaymentCheckScreenState extends State<PaymentCheckScreen> {
//   String status = "Checking payment...";
//   int? daysRemaining;
//
//   @override
//   void initState() {
//     super.initState();
//     initPaymentCheck();
//   }
//
//   Future<void> initPaymentCheck() async {
//     await createDummyPaymentFileIfNotExists(); // optional
//     await checkPayment();
//   }
//
//   Future<void> createDummyPaymentFileIfNotExists() async {
//     final dir = await getApplicationDocumentsDirectory();
//     final folder = Directory(join(dir.path, 'payzz'));
//
//     if (!await folder.exists()) {
//       await folder.create(recursive: true);
//     }
//
//     final filePath = join(folder.path, 'payment_974801fa-4211-4f44-be6f-dbfe5680f6c6.json');
//     final file = File(filePath);
//
//     if (!await file.exists()) {
//       await file.writeAsString(jsonEncode([
//         {"next_payment_date": "2025-05-10"}
//       ]));
//       print("Dummy payment file created at $filePath");
//     }
//   }
//
//   Future<void> checkPayment() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final filePath = join(directory.path, 'payzz/payment_974801fa-4211-4f44-be6f-dbfe5680f6c6.json');
//       final file = File(filePath);
//
//       if (!await file.exists()) {
//         throw Exception("Payment file not found at: $filePath");
//       }
//
//       final contents = await file.readAsString();
//       final jsonList = jsonDecode(contents);
//       final data = jsonList[0];
//       final nextPaymentDate = DateTime.parse(data['next_payment_date']);
//       final today = DateTime.now();
//       daysRemaining = nextPaymentDate.difference(today).inDays;
//
//       if (daysRemaining! < 0) {
//         setState(() => status = "Payment expired!");
//       } else {
//         setState(() => status = "Payment OK — $daysRemaining day(s) remaining");
//       }
//
//       // Wait and go to login
//       await Future.delayed(const Duration(seconds: 3));
//
//       // Use context directly from the build method
//       Navigator.pushAndRemoveUntil(
//         context, // Correct BuildContext used
//         MaterialPageRoute(builder: (context) => const LoginScreen()),
//             (Route<dynamic> route) => false, // Removes all previous routes
//       );
//
//     } catch (e) {
//       setState(() => status = "Error checking payment:\n$e");
//     }
//   }
//
//   Future<String?> getAdminEmail() async {
//     final db = await DatabaseHelper.instance.database;
//     final result = await db.query(
//       'users',
//       columns: ['email'],
//       where: 'role = ?',
//       whereArgs: ['admin'],
//     );
//
//     if (result.isNotEmpty) {
//       return result.first['email'] as String?;
//     }
//     return null;
//   }
//
//   Future<void> _sendEmailNotification(
//       String name,
//       String email,
//       String phone,
//       String location,
//       String address,
//       String whatsapp,
//       String lipaNumber, {
//         required String reason,
//       }) async {
//     String? adminEmail = await getAdminEmail();
//     if (adminEmail == null) {
//       print("No admin found to send email to.");
//       return;
//     }
//
//     final smtpServer = gmail('ephamarcysoftwares@gmail.com', 'tmir prqw hlxe rqdg');
//
//     final message = Message()
//       ..from = Address('ephamarcysoftwares@gmail.com', 'E-PHARMACY SOFTWARE')
//       ..recipients.add(adminEmail)
//       ..subject = 'Payment Notification'
//       ..text = '''
// Hi Admin,
//
// $name has a payment issue.
//
// Reason: $reason
//
// Details:
// Email: $email
// Phone: $phone
// Location: $location
// Address: $address
// WhatsApp: $whatsapp
// Lipa Number: $lipaNumber
//
// E-PHARMACY SYSTEM
// ''';
//
//     try {
//       await send(message, smtpServer);
//       print('Email sent to admin.');
//     } catch (e) {
//       print('Email failed: $e');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Center(
//         child: Text(
//           status,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//       ),
//     );
//   }
// }
