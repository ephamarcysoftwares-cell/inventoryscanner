// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';
// import 'package:path/path.dart' as path;
// import 'package:sqflite/sqflite.dart';
// import 'package:twilio_flutter/twilio_flutter.dart';
// import '../DB/database_helper.dart';
// import '../phamacy/ReceiptScreen.dart';
//
// class OtherCartScreen extends StatefulWidget {
//   final Map<String, dynamic> user;
//   const OtherCartScreen({Key? key, required this.user}) : super(key: key);
//
//   @override
//   _OtherCartScreenState createState() => _OtherCartScreenState();
// }
//
// class _OtherCartScreenState extends State<OtherCartScreen> {
//   List<Map<String, dynamic>> _cartItems = [];
//   double grandTotal = 0.0;
//   String paymentMethod = "Cash";
//   TextEditingController nameController = TextEditingController();
//   TextEditingController phoneController = TextEditingController();
//   TextEditingController emailController = TextEditingController();
//   TextEditingController referenceController = TextEditingController();
//   String businessName = '';
//   String businessEmail = '';
//   String businessPhone = '';
//   String businessLocation = '';
//   String businessLogoPath = '';
//   String address = '';
//   String whatsapp = '';
//   String lipaNumber = '';
//
//   String selectedCountry = 'Tanzania'; // Default selected country
//   String countryCode = '+255'; // Default country code for Tanzania
//
//   List<Map<String, String>> countries = [
//     {'country': 'Tanzania', 'code': '+255'},
//     {'country': 'Kenya', 'code': '+254'},
//     {'country': 'Uganda', 'code': '+256'},
//     // Add more countries as needed
//   ];
//
//   TwilioFlutter? twilioFlutter;
//
//   @override
//   void initState() {
//     super.initState();
//     _fetchCartItems();
//     getBusinessInfo();
//     // Twilio setup
//     twilioFlutter = TwilioFlutter(
//       accountSid: 'your_twilio_account_sid', // Your Twilio Account SID
//       authToken: 'your_twilio_auth_token',  // Your Twilio Auth Token
//       twilioNumber: 'your_twilio_phone_number',  // Your Twilio phone number
//     );
//   }
//   void _clearCart() {
//     setState(() {
//       _cartItems.clear();
//     });
//   }
//
//   Future<void> _fetchCartItems() async {
//     final db = await DatabaseHelper.instance.database;
//     List<Map<String, dynamic>> items = await db.query('other_cart', where: 'user_id = ?', whereArgs: [widget.user['id']]);
//
//     double total = items.fold(0, (sum, item) => sum + (item['quantity'] * item['price']));
//
//     setState(() {
//       _cartItems = items;
//       grandTotal = total;
//     });
//   }
//   Future<void> _removeItemFromCart(int itemId) async {
//     final db = await DatabaseHelper.instance.database;
//
//     // Fetch item details BEFORE deletion
//     List<Map<String, dynamic>> itemDetails = await db.query('other_cart', where: 'id = ?', whereArgs: [itemId]);
//
//     if (itemDetails.isEmpty) return;
//
//     String medicineName = itemDetails.first['medicine_name'];
//     int quantity = (itemDetails.first['quantity'] as num).toInt();
//     double price = (itemDetails.first['price'] as num).toDouble();
//     int medicineId = (itemDetails.first['medicine_id'] as num).toInt();
//
//     // Fetch current remaining_quantity
//     List<Map<String, dynamic>> medicineDetails = await db.query('other_product', where: 'id = ?', whereArgs: [medicineId]);
//
//     if (medicineDetails.isNotEmpty) {
//       int remainingQuantity = medicineDetails.first['remaining_quantity'] ?? 0;
//
//       // Add back the quantity
//       int newRemainingQuantity = remainingQuantity + quantity;
//
//       // Update the medicine stock
//       await db.update(
//         'other_product',
//         {'remaining_quantity': newRemainingQuantity},
//         where: 'id = ?',
//         whereArgs: [medicineId],
//       );
//     }
//
//     // Now delete the item from local cart
//     await db.delete('other_cart', where: 'id = ?', whereArgs: [itemId]);
//
//     // Send request to remote PHP server to delete the item from remote cart
//     try {
//       final response = await http.post(
//         Uri.parse('http://ephamarcysoftware.co.tz/ephamarcy/delete_cart_item.php'),
//         body: {'id': itemId.toString()},
//       );
//
//       print('Server response code: ${response.statusCode}');
//       print('Server response body: ${response.body}');
//
//       final data = json.decode(response.body);
//
//       if (data['status'] != 'success') {
//         print('Remote deletion failed: ${data['message']}');
//       } else {
//         print('Item removed from remote server.');
//       }
//     } catch (e) {
//       print('Error communicating with remote server: $e');
//     }
//
//     // Refresh the cart items after removal
//     await _fetchCartItems();
//
//     // Send notification to admin
//     await _sendEmailNotification(itemId, medicineName, quantity, price);
//   }
//
//
//
//   // Function to get all admin emails
//   Future<List<String>> getAdminEmails() async {
//     final db = await DatabaseHelper.instance.database;
//     final result = await db.query(
//       'users',
//       columns: ['email'],
//       where: 'role = ?',
//       whereArgs: ['admin'],
//     );
//
//     return result.map((row) => row['email'].toString()).toList();
//   }
//
// // Function to send email notification to all admins
//   Future<void> _sendEmailNotification(int itemId, String medicineName, int quantity, double price) async {
//     final adminEmails = await getAdminEmails();
//
//     if (adminEmails.isEmpty) {
//       print("❌ No admin found to send email to.");
//       return;
//     }
//
//     final smtpServer = SmtpServer(
//       'mail.ephamarcysoftware.co.tz',
//       username: 'suport@ephamarcysoftware.co.tz',
//       password: 'Matundu@2050',
//       port: 465,
//       ssl: true,
//     );
//
//     final message = Message()
//       ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
//       ..recipients.addAll(adminEmails)
//       ..subject = '🛑 Bill Canceled - $medicineName'
//       ..html = '''
//     <html>
//     <head>
//       <style>
//         table {
//           border-collapse: collapse;
//           width: 100%;
//           max-width: 600px;
//         }
//         th, td {
//           padding: 8px;
//           text-align: left;
//           border: 1px solid #ddd;
//         }
//         th {
//           background-color: #f44336;
//           color: white;
//         }
//       </style>
//     </head>
//     <body>
//       <h2 style="color: #d32f2f;">Bill Cancellation Notification</h2>
//       <p>The following item has been <strong>removed</strong> from the pending bill:</p>
//       <table>
//         <tr>
//           <th>Field</th>
//           <th>Details</th>
//         </tr>
//         <tr>
//           <td>ID</td>
//           <td>$itemId</td>
//         </tr>
//         <tr>
//           <td>Name</td>
//           <td>$medicineName</td>
//         </tr>
//         <tr>
//           <td>Quantity</td>
//           <td>$quantity</td>
//         </tr>
//         <tr>
//           <td>Price</td>
//           <td>TSH ${price.toStringAsFixed(2)}</td>
//         </tr>
//       </table>
//       <p>This action was performed by <strong>${widget.user['full_name']}</strong>.</p>
//       <p>Regards,<br/>STOCK & INVENTORY SOFTWARE</p>
//     </body>
//     </html>
//     ''';
//
//     try {
//       final sendReport = await send(message, smtpServer);
//       print('✅ Email sent to all admins: $sendReport');
//     } catch (e) {
//       print('❌ Failed to send email: $e');
//     }
//   }
//
//
//   // Send SMS to customer using Twilio
//   Future<void> _sendSMS(String customerPhone, String saleDetails) async {
//     try {
//       final message = await twilioFlutter!.sendSMS(
//         toNumber: customerPhone,
//         messageBody: saleDetails,
//       );
//       print('SMS sent: ${message.toString()}');
//     } catch (e) {
//       print('Failed to send SMS: $e');
//     }
//   }
//   Future<void> getBusinessInfo() async {
//     try {
//       Database db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
//       List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
//
//       if (result.isNotEmpty) {
//         setState(() {
//           businessName = result[0]['business_name']?.toString() ?? '';
//           businessEmail = result[0]['email']?.toString() ?? '';
//           businessPhone = result[0]['phone']?.toString() ?? '';
//           businessLocation = result[0]['location']?.toString() ?? '';
//           businessLogoPath = result[0]['logo']?.toString() ?? '';
//           address = result[0]['address']?.toString() ?? '';
//           whatsapp = result[0]['whatsapp']?.toString() ?? '';
//           lipaNumber = result[0]['lipa_number']?.toString() ?? '';
//         });
//       }
//     } catch (e) {
//       print('Error loading business info: $e');
//     }
//   }
//   Future<void> _confirmSale() async {
//     setState(() {
//       _isLoading = true;
//     });
//
//     try {
//       final db = await DatabaseHelper.instance.database;
//
//       if (_cartItems.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Cart is empty!")),
//         );
//         return;
//       }
//
//       String customerName = nameController.text.trim();
//       String customerPhone = phoneController.text.trim();
//       String customerEmail = emailController.text.trim();
//
//       if (customerName.isEmpty || customerPhone.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("Enter customer details!")),
//         );
//         return;
//       }
//
//       // Clean phone: remove leading 0 and format with country code
//       String localPhone = customerPhone.replaceFirst(RegExp(r'^0'), '');
//       String fullPhoneNumber = '$countryCode$localPhone';
//
//       // Get user info
//       List<Map<String, dynamic>> userResult = await db.query(
//         'users',
//         columns: ['full_name', 'role', 'id'],
//         where: 'id = ?',
//         whereArgs: [widget.user['id']],
//       );
//
//       String confirmedBy = userResult.isNotEmpty ? userResult.first['full_name'] : 'Unknown';
//       String userRole = userResult.isNotEmpty ? userResult.first['role'] : 'Unknown';
//       int staffId = userResult.isNotEmpty ? userResult.first['id'] : -1;
//       int unit = 1;
//
//       String receiptNumber = "REC${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}";
//       String confirmedTime = DateFormat('yyyy-MM-dd HH:mm:ss')
//           .format(DateTime.now().toUtc().add(Duration(hours: 3)));
//       int totalQuantity = _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt());
//       List<String> medicineNames = _cartItems.map((item) => item['medicine_name'].toString()).toList();
//
//       // Data common to both tables/email
//       final saleData = {
//         'customer_name': customerName,
//         'customer_phone': fullPhoneNumber,
//         'customer_email': customerEmail,
//         'medicine_name': medicineNames.join(', '),
//         'remaining_quantity': totalQuantity,
//         'total_price': grandTotal,
//         'receipt_number': receiptNumber,
//         'payment_method': paymentMethod,
//         'confirmed_time': DateTime.tryParse(confirmedTime)?.toIso8601String() ?? confirmedTime,
//         'user_id': widget.user['id'],
//         'confirmed_by': confirmedBy,
//         'user_role': userRole,
//         'staff_id': staffId,
//         'unit': unit,
//         'business_name': businessName,
//       };
//
//       int? saleId;
//
//       if (paymentMethod == 'TO LEND(MKOPO)') {
//         // Insert to To_lend table only (no sales)
//         try {
//           saleId = await db.insert('To_lend', saleData);
//           print('✅ Inserted into To_lend with ID: $saleId');
//         } catch (e) {
//           print('❌ Error inserting To_lend: $e');
//         }
//
//         // Send To Lend alert email to customer
//         final smtpServer = SmtpServer(
//           'mail.ephamarcysoftware.co.tz',
//           username: 'suport@ephamarcysoftware.co.tz',
//           password: 'Matundu@2050',
//           port: 465,
//           ssl: true,
//         );
//
//         final htmlContent = '''
// <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background: #f9f9f9;">
//   <h1 style="text-align: center; color: #d35400;">⚠️ MKOPO(TO LEND) </h1>
//   <p style="font-size: 16px;">Dear <strong>$customerName</strong>,</p>
//   <p style="font-size: 14px; color: #555;">
//     You have chosen to purchase items on credit (To Lend). Please find the details below:
//   </p>
//
//   <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
//     <thead>
//       <tr style="background-color: #d35400; color: white;">
//         <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Field</th>
//         <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Details</th>
//       </tr>
//     </thead>
//     <tbody>
//       <tr style="background-color: #fbeee6;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Customer Name</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$customerName</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Phone</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$fullPhoneNumber</td>
//       </tr>
//       <tr style="background-color: #fbeee6;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Email</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$customerEmail</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Receipt Number</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$receiptNumber</td>
//       </tr>
//       <tr style="background-color: #fbeee6;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Confirmed By</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$confirmedBy</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Confirmed Time</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$confirmedTime</td>
//       </tr>
//     </tbody>
//   </table>
//
//   <h2 style="margin-top: 30px; color: #d35400;">Items on Credit</h2>
//   <table style="width: 100%; border-collapse: collapse;">
//     <thead>
//       <tr style="background-color: #d35400; color: white;">
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Medicine</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Quantity</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Unit Price (TSH)</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Total Price (TSH)</th>
//       </tr>
//     </thead>
//     <tbody>
//       ${_cartItems.map((item) => '''
//       <tr style="background-color: #fbeee6;">
//         <td style="padding: 10px; border: 1px solid #ddd;">${item['medicine_name']}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${item['quantity']}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${item['price'].toStringAsFixed(2)}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${(item['quantity'] * item['price']).toStringAsFixed(2)}</td>
//       </tr>
//       ''').join()}
//     </tbody>
//   </table>
//
//   <h3 style="text-align: right; margin-top: 20px;">
//     Total Quantity: <strong>$totalQuantity</strong><br>
//     Grand Total: <strong>TSH ${grandTotal.toStringAsFixed(2)}</strong>
//   </h3>
//
//   <p style="font-size: 14px; color: #555; margin-top: 30px;">
//     Please ensure timely payment as agreed. Contact us if you have any questions.
//   </p>
//
//   <p style="text-align: center; font-size: 12px; color: #999; margin-top: 40px;">
//     &copy; ${DateTime.now().year} E-PHAMARCY SOFTWARE. All rights reserved.
//   </p>
// </div>
// ''';
//
//         final message = Message()
//           ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
//           ..recipients.add(customerEmail)
//           ..subject = 'To Lend Alert - $receiptNumber'
//           ..html = htmlContent;
//
//         try {
//           final sendReport = await send(message, smtpServer);
//           print('To Lend alert email sent: ${sendReport.toString()}');
//         } catch (e) {
//           print('Failed to send To Lend alert email: $e');
//         }
//       } else {
//         // Insert into sales table for normal sales
//         try {
//           saleId = await db.insert('sales', saleData);
//           print('✅ Sale saved with ID: $saleId');
//         } catch (e) {
//           print('❌ Error saving sale: $e');
//         }
//
//         // Send sale data to live server
//         print('📦 Sending sale data to live server...');
//         try {
//           final response = await http.post(
//             Uri.parse('http://ephamarcysoftware.co.tz/ephamarcy/save_sale.php'),
//             headers: {'Content-Type': 'application/json'},
//             body: jsonEncode(saleData),
//           );
//
//           print('🌐 Server response status: ${response.statusCode}');
//           print('📨 Server response body: ${response.body}');
//
//           if (response.statusCode == 200 || response.statusCode == 201) {
//             print('✅ Sale saved on live server');
//           } else {
//             print('❌ Failed saving sale on live server');
//           }
//         } catch (e) {
//           print('🚨 Exception sending sale to server: $e');
//         }
//
//         // Insert sale items and update stock
//         await Future.wait(_cartItems.map((item) async {
//           try {
//             await db.insert('sale_items', {
//               'sale_id': saleId,
//               'medicine_id': item['medicine_id'],
//               'medicine_name': item['medicine_name'],
//               'remaining_quantity': item['remaining_quantity'],
//               'price': item['price'],
//               'unit': item['unit'],
//               'date_added': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
//               'added_by': widget.user['id'],
//               'business_name': businessName,
//             });
//
//             // Stock update code here if needed (commented out)
//             // int quantitySold = (item['quantity'] as num).toInt();
//             // int medicineId = item['medicine_id'];
//             // await db.rawUpdate("UPDATE medicines SET remaining_quantity = remaining_quantity - ? WHERE id = ?", [quantitySold, medicineId]);
//
//             // Update live server stock
//             var response = await http.post(
//               Uri.parse("http://ephamarcysoftware.co.tz/ephamarcy/update_remaining.php"),
//               body: {
//                 'medicine_id': item['medicine_id'].toString(),
//                 'remaining_quantity': item['quantity'].toString(),
//               },
//             );
//             if (response.statusCode == 200) {
//               print('✅ Server stock updated for medicine_id: ${item['medicine_id']}');
//             } else {
//               print('❌ Failed to update server stock for medicine_id: ${item['medicine_id']}');
//             }
//           } catch (e) {
//             print('❗ Error processing sale item ${item['medicine_name']}: $e');
//           }
//         }));
//       }
//
//       // Clear cart after processing
//       await db.delete('cart', where: 'user_id = ?', whereArgs: [widget.user['id']]);
//       print('✅ Cart cleared for user');
//
//       // Compose SMS message
//       String saleDetailsSms = '''
// Sale Details:
// Customer: $customerName
// Phone: $fullPhoneNumber
// Email: $customerEmail
// Items: ${medicineNames.join(', ')}
// Quantity: $totalQuantity
// Total Price: TSH ${grandTotal.toStringAsFixed(2)}
// Payment: $paymentMethod
// Receipt#: $receiptNumber
// Confirmed By: $confirmedBy
// Time: $confirmedTime
// ''';
//
//       await _sendSMS(fullPhoneNumber, saleDetailsSms);
//
//       // Compose beautiful sale confirmation email for regular sales
//       if (paymentMethod != 'TO LEND(MKOPO)') {
//         final smtpServer = SmtpServer(
//           'mail.ephamarcysoftware.co.tz',
//           username: 'suport@ephamarcysoftware.co.tz',
//           password: 'Matundu@2050',
//           port: 465,
//           ssl: true,
//         );
//
//         final htmlContent = '''
// <div style="font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; max-width: 600px; margin: auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px; background: #f9f9f9;">
//   <h1 style="text-align: center; color: #2E86C1;">🧾 Sale Receipt</h1>
//   <p style="font-size: 16px;">Dear <strong>$customerName</strong>,</p>
//   <p style="font-size: 14px; color: #555;">
//     Thank you for shopping with <strong>$businessName</strong>. Below are your sale details:
//   </p>
//
//   <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
//     <thead>
//       <tr style="background-color: #2E86C1; color: white;">
//         <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Field</th>
//         <th style="padding: 10px; text-align: left; border: 1px solid #ddd;">Details</th>
//       </tr>
//     </thead>
//     <tbody>
//       <tr style="background-color: #e8f4fc;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Customer Name</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$customerName</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Phone</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$fullPhoneNumber</td>
//       </tr>
//       <tr style="background-color: #e8f4fc;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Email</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$customerEmail</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Receipt Number</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$receiptNumber</td>
//       </tr>
//       <tr style="background-color: #e8f4fc;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Payment Method</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$paymentMethod</td>
//       </tr>
//       <tr>
//         <td style="padding: 10px; border: 1px solid #ddd;">Confirmed By</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$confirmedBy</td>
//       </tr>
//       <tr style="background-color: #e8f4fc;">
//         <td style="padding: 10px; border: 1px solid #ddd;">Confirmed Time</td>
//         <td style="padding: 10px; border: 1px solid #ddd;">$confirmedTime</td>
//       </tr>
//     </tbody>
//   </table>
//
//   <h2 style="margin-top: 30px; color: #2E86C1;">Purchased Items</h2>
//   <table style="width: 100%; border-collapse: collapse;">
//     <thead>
//       <tr style="background-color: #2E86C1; color: white;">
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: left;">Medicine</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Quantity</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Unit Price (TSH)</th>
//         <th style="padding: 10px; border: 1px solid #ddd; text-align: right;">Total Price (TSH)</th>
//       </tr>
//     </thead>
//     <tbody>
//       ${_cartItems.map((item) => '''
//       <tr style="background-color: #e8f4fc;">
//         <td style="padding: 10px; border: 1px solid #ddd;">${item['medicine_name']}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${item['quantity']}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${item['price'].toStringAsFixed(2)}</td>
//         <td style="padding: 10px; border: 1px solid #ddd; text-align: right;">${(item['quantity'] * item['price']).toStringAsFixed(2)}</td>
//       </tr>
//       ''').join()}
//     </tbody>
//   </table>
//
//   <h3 style="text-align: right; margin-top: 20px;">
//     Total Quantity: <strong>$totalQuantity</strong><br>
//     Grand Total: <strong>TSH ${grandTotal.toStringAsFixed(2)}</strong>
//   </h3>
//
//   <p style="font-size: 14px; color: #555; margin-top: 30px;">
//     If you have any questions, feel free to contact us.<br>
//     Thank you for choosing <strong>$businessName</strong>!
//   </p>
//
//   <p style="text-align: center; font-size: 12px; color: #999; margin-top: 40px;">
//     &copy; ${DateTime.now().year} E-PHAMARCY SOFTWARE. All rights reserved.
//   </p>
// </div>
// ''';
//
//         final message = Message()
//           ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
//           ..recipients.add(customerEmail)
//           ..subject = 'Sale Receipt - $receiptNumber'
//           ..html = htmlContent;
//
//         try {
//           final sendReport = await send(message, smtpServer);
//           print('Sale confirmation email sent: ${sendReport.toString()}');
//         } catch (e) {
//           print('Failed to send sale email: $e');
//         }
//       }
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Sale processed successfully!')),
//       );
//
//       _clearCart();
//     } catch (e) {
//       print('❌ Error confirming sale: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error processing sale: $e')),
//       );
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }
//
//
//
//   void _showLoadingDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) {
//         return AlertDialog(
//           content: Row(
//             children: [
//               CircularProgressIndicator(),
//               SizedBox(width: 20),
//               Text("Please wait..."),
//             ],
//           ),
//         );
//       },
//     );
//   }
//   bool _isLoading = false;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('🧾 other product Pending Bill'),
//         backgroundColor: Colors.greenAccent,
//         centerTitle: true,
//       ),
//       body: Column(
//         children: [
//           // Customer details form
//           Expanded(
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(16.0),
//               child: Card(
//                 elevation: 5,
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     children: [
//                       _buildTextField(nameController, 'Customer Name'),
//                       const SizedBox(height: 12),
//                       _buildTextField(phoneController, 'Phone Number', keyboardType: TextInputType.phone),
//                       const SizedBox(height: 12),
//                       _buildTextField(emailController, 'Email Address', keyboardType: TextInputType.emailAddress),
//                       const SizedBox(height: 12),
//                       DropdownButtonFormField<String>(
//                         value: selectedCountry,
//                         onChanged: (value) {
//                           setState(() {
//                             selectedCountry = value!;
//                             countryCode = countries.firstWhere(
//                                     (element) => element['country'] == value)['code']!;
//                           });
//                         },
//                         items: countries.map((country) => DropdownMenuItem(
//                           value: country['country'],
//                           child: Text(country['country']!),
//                         )).toList(),
//                         decoration: _inputDecoration('Country'),
//                       ),
//                       const SizedBox(height: 12),
//                       DropdownButtonFormField<String>(
//                         value: paymentMethod,
//                         onChanged: (newValue) {
//                           setState(() {
//                             paymentMethod = newValue!;
//                           });
//                         },
//                         items: ['Cash','TO LEND(MKOPO)', 'Mobile', 'Lipa Number'].map((method) {
//                           return DropdownMenuItem(
//                             value: method,
//                             child: Text(method),
//                           );
//                         }).toList(),
//                         decoration: _inputDecoration('Payment Method'),
//                       ),
//                       if (paymentMethod == 'Lipa Number') ...[
//                         const SizedBox(height: 12),
//                         _buildTextField(
//                           referenceController,
//                           'Reference Number',
//                           keyboardType: TextInputType.number,
//                           maxLength: 20,
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//
//           // Cart Items
//           Container(
//             height: 200,
//             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             child: Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//               child: ListView.builder(
//                 padding: const EdgeInsets.all(8),
//                 itemCount: _cartItems.length,
//                 itemBuilder: (context, index) {
//                   final item = _cartItems[index];
//                   return Card(
//                     margin: const EdgeInsets.symmetric(vertical: 4),
//                     elevation: 2,
//                     child: ListTile(
//                       title: Text(
//                         'Product Name: ${item['medicine_name']}',
//                         style: TextStyle(
//                           color: Colors.black,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 20,
//                           letterSpacing: 1.0,
//                           shadows: [
//                             Shadow(
//                               blurRadius: 8.0,
//                               color: Colors.black.withOpacity(0.3),
//                               offset: Offset(2.0, 2.0),
//                             ),
//                           ],
//                         ),
//                       ),
//                       subtitle: Text(
//                         'Quantity: ${item['quantity']} | Price: TSH ${NumberFormat('#,##0.00', 'en_US').format(item['price'])}',
//                         style: TextStyle(
//                           color: Colors.blueAccent,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 16,
//                           letterSpacing: 1.2,
//                           shadows: [
//                             Shadow(
//                               blurRadius: 10.0,
//                               color: Colors.black.withOpacity(0.3),
//                               offset: Offset(2.0, 2.0),
//                             ),
//                           ],
//                         ),
//                       ),
//                       trailing: IconButton(
//                         icon: const Icon(Icons.delete, color: Colors.red),
//                         onPressed: () => _removeItemFromCart(item['id']),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ),
//
//           // Confirm button
//           Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.check_circle_outline),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 ),
//                 onPressed: _isLoading ? null : () async {
//                   setState(() { _isLoading = true; });
//
//                   // Call your existing method to process & save the sale
//                   await _confirmSale();
//
//                   // Then always go to ReceiptScreen
//                   final confirmedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now().toUtc().add(Duration(hours: 3)));
//                   final receiptNumber = "REC${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}";
//                   final customerName = nameController.text.trim();
//                   final customerPhone = phoneController.text.trim();
//                   final customerEmail = emailController.text.trim();
//
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => ReceiptScreen(
//                         confirmedBy: widget.user['full_name'] ?? 'Unknown',
//                         confirmedTime: confirmedTime,
//                         customerName: customerName,
//                         customerPhone: customerPhone,
//                         customerEmail: customerEmail,
//                         paymentMethod: paymentMethod,
//                         receiptNumber: receiptNumber,
//                         medicineNames: _cartItems.map((item) => '${item['medicine_name']} x ${item['quantity']}').toList(),
//                         medicineQuantities: _cartItems.map((item) => item['quantity'] as int).toList(),
//                         medicinePrices: _cartItems.map((item) => item['price'] as double).toList(),
//                         medicineUnits: _cartItems.map((item) => item['unit'] as String).toList(),
//                         totalPrice: grandTotal,
//                         remaining_quantity: _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt()),
//                       ),
//                     ),
//                   );
//
//                   setState(() { _isLoading = false; });
//                 },
//                 label: _isLoading
//                     ? const CircularProgressIndicator(
//                   valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
//                 )
//                     : Text(
//                   'Confirm Sale  •  TSH ${NumberFormat('#,##0.00', 'en_US').format(grandTotal)}',
//                   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
// // Reusable field
//   Widget _buildTextField(TextEditingController controller, String label,
//       {TextInputType keyboardType = TextInputType.text, int? maxLength}) {
//     return TextField(
//       controller: controller,
//       keyboardType: keyboardType,
//       maxLength: maxLength,
//       decoration: _inputDecoration(label),
//     );
//   }
//
// // Standard input decoration
//   InputDecoration _inputDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//     );
//   }
//
//
//
// }
