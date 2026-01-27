// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'package:printing/printing.dart';
// import 'package:open_filex/open_filex.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';
//
// import '../CHATBOAT/chatboat.dart';
//
//
// class ReceiptScreen extends StatefulWidget {
//   final String confirmedBy;
//   final String confirmedTime;
//   final String customerName;
//   final String customerPhone;
//   final String customerEmail;
//   final String paymentMethod;
//   final String receiptNumber;
//   final List<String> medicineNames;
//   final List<int> medicineQuantities;
//   final List<double> medicinePrices;
//   final List<String> medicineUnits; // ✅ Add this line
//   final double totalPrice;
//   final int remaining_quantity;
//
//   ReceiptScreen({
//     required this.confirmedBy,
//     required this.confirmedTime,
//     required this.customerName,
//     required this.customerPhone,
//     required this.customerEmail,
//     required this.paymentMethod,
//     required this.receiptNumber,
//     required this.medicineNames,
//     required this.medicineQuantities,
//     required this.medicinePrices,
//     required this.medicineUnits, // ✅ Add this line
//     required this.totalPrice,
//     required this.remaining_quantity,
//   });
//
//   @override
//   _ReceiptScreenState createState() => _ReceiptScreenState();
// }
//
//
// class _ReceiptScreenState extends State<ReceiptScreen> {
//   String businessName = '';
//   String businessEmail = '';
//   String businessPhone = '';
//   String businessLocation = '';
//   String businessLogoPath = '';
//
//   @override
//   void initState() {
//     super.initState();
//     getBusinessInfo();
//   }
//
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
//         });
//       }
//     } catch (e) {
//       print('Error loading business info: $e');
//     }
//   }
//
//   Future<void> _sendEmailWithAttachment(String method) async {
//     final pdf = _generateReceiptPdf();
//     final directory = await getTemporaryDirectory();
//     final filePath = '${directory.path}/receipt.pdf';
//     final file = File(filePath);
//     await file.create(recursive: true);
//     await file.writeAsBytes(await pdf.save());
//
//     if (method == "email") {
//       await _sendEmailWithPdf(filePath);
//     } else {
//       await OpenFilex.open(filePath);
//     }
//   }
//
//   Future<void> _sendEmailWithPdf(String filePath) async {
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
//       ..recipients.add(widget.customerEmail)
//       ..subject = 'Receipt from STOCK&INVENTORY SOFTWARE'
//       ..text = 'Dear ${widget.customerName},\n\nHere is your receipt.\n\nBest regards,\nSTOCK&INVENTORY SOFTWARE'
//       ..attachments.add(FileAttachment(File(filePath)));
//
//     try {
//       final sendReport = await send(message, smtpServer);
//       print('Message sent: ' + sendReport.toString());
//     } catch (e) {
//       print('Error sending email: $e');
//     }
//   }
//
//   pw.Document _generateReceiptPdf() {
//     final pdf = pw.Document();
//     final logoDir = Directory("C:\\Users\\Public\\epharmacy\\bussiness_logo");
//     pw.MemoryImage? logoImage;
//
//     try {
//       if (logoDir.existsSync()) {
//         final logoFile = logoDir
//             .listSync()
//             .whereType<File>()
//             .firstWhere(
//               (file) => file.path.toLowerCase().endsWith('.png') || file.path.toLowerCase().endsWith('.jpg') || file.path.toLowerCase().endsWith('.jpeg'),
//           orElse: () => File(""),
//         );
//
//         if (logoFile.path.isNotEmpty && logoFile.existsSync()) {
//           logoImage = pw.MemoryImage(logoFile.readAsBytesSync());
//         }
//       }
//     } catch (e) {
//       print("Error loading logo: $e");
//     }
//
//     pdf.addPage(
//       pw.Page(
//         build: (pw.Context context) {
//           return pw.Container(
//             padding: pw.EdgeInsets.all(20),
//             decoration: pw.BoxDecoration(
//               border: pw.Border.all(width: 2, color: PdfColor.fromHex('#000000')),
//               borderRadius: pw.BorderRadius.circular(10),
//             ),
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Center(
//                   child: pw.Text(
//                     " ==============================",
//                     style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
//                   ),
//                 ),
//                 pw.SizedBox(height: 10),
//                 if (logoImage != null)
//                   pw.Center(child: pw.Image(logoImage, width: 100, height: 100)),
//                 pw.SizedBox(height: 10),
//                 pw.Center(
//                   child: pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.center,
//                     children: [
//                       pw.Text(businessName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
//                       pw.Text("Email: $businessEmail"),
//                       pw.Text("Phone: $businessPhone"),
//                       pw.Text("Location: $businessLocation"),
//                     ],
//                   ),
//                 ),
//                 pw.SizedBox(height: 20),
//                 pw.Table.fromTextArray(
//                   context: context,
//                   data: [
//                     ["Receipt Number:", widget.receiptNumber],
//                     ["Customer:", widget.customerName],
//                     ["Phone:", widget.customerPhone],
//                     ...List.generate(widget.medicineNames.length, (index) {
//                       double totalPrice = widget.medicineQuantities[index] * widget.medicinePrices[index];
//                       return [
//                         "Product: ${widget.medicineNames[index]}  ${widget.medicineUnits[index]}",
//                         "Sub Total: TSH ${NumberFormat('#,##0.00', 'en_US').format(widget.medicineQuantities[index] * widget.medicinePrices[index])}"
//
//                       ];
//                     }),
//                     ["Payment Method:", widget.paymentMethod],
//                     ["Staff Name:", widget.confirmedBy],
//                     ["Time Saved:", widget.confirmedTime],
//                     ["Total Price:", "TSH ${NumberFormat('#,##0.00', 'en_US').format(widget.totalPrice)}"]
//
//                   ],
//
//                 ),
//
//
//                 pw.SizedBox(height: 20),
//                 pw.Center(
//                   child: pw.BarcodeWidget(
//                     barcode: pw.Barcode.code128(),
//                     data: widget.receiptNumber,
//                     width: 200,
//                     height: 50,
//                   ),
//                 ),
//                 pw.Center(
//                   child: pw.Text(
//                     "Thank you for shopping with us",
//                     style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//
//
//     return pdf;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Automatically send the email after generating the PDF
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await _sendEmailWithAttachment("email");
//     });
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Receipt Details", style: TextStyle(fontWeight: FontWeight.bold)),
//         backgroundColor: Colors.greenAccent,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header Text
//               Text("📜 Receipt Details", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
//               SizedBox(height: 10),
//
//               // Data Table for Items
//               DataTable(
//                 columns: [
//                   DataColumn(label: Text("No", style: TextStyle(fontWeight: FontWeight.bold))),
//                   DataColumn(label: Text("Product", style: TextStyle(fontWeight: FontWeight.bold))),
//                   DataColumn(label: Text("Qty", style: TextStyle(fontWeight: FontWeight.bold))),
//                   DataColumn(label: Text("Unit", style: TextStyle(fontWeight: FontWeight.bold))),
//                   DataColumn(label: Text("Total Price", style: TextStyle(fontWeight: FontWeight.bold))),
//                 ],
//                 rows: List.generate(widget.medicineNames.length, (index) {
//                   // Calculate the total price for each medicine
//                   double totalPrice = widget.medicineQuantities[index] * widget.medicinePrices[index];
//                   return DataRow(cells: [
//                     DataCell(Text((index + 1).toString())),  // No
//                     DataCell(Text(widget.medicineNames[index])),  // Medicine
//                     DataCell(Text(widget.medicineQuantities[index].toString())),
//                     DataCell(Text(widget.medicineUnits[index])),  // Unit
//                     DataCell(Text("TSH ${NumberFormat('#,##0.00', 'en_US').format(totalPrice)}"))
//
//                   ]);
//                 })..addAll([
//                   // Additional rows with receipt data at the bottom
//                   DataRow(cells: [
//                     DataCell(Text("🧾 Receipt Number", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.receiptNumber)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                   DataRow(cells: [
//                     DataCell(Text("👤 Customer", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.customerName)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                   DataRow(cells: [
//                     DataCell(Text("📞 Phone", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.customerPhone)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                   DataRow(cells: [
//                     DataCell(Text("💳 Payment Method", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.paymentMethod)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                   DataRow(cells: [
//                     DataCell(Text("👨‍⚕️ Staff", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.confirmedBy)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                   DataRow(cells: [
//                     DataCell(Text("⏰ Time", style: TextStyle(fontWeight: FontWeight.bold))),
//                     DataCell(Text(widget.confirmedTime)),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                     DataCell(Text("")),
//                   ]),
//                 ]),
//               ),
//
//               SizedBox(height: 20),
//
//               // Thank You Message and Action Buttons
//               Center(
//                 child: Column(
//                   children: [
//                     // Thank you message with some padding
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 16.0), // Adds vertical padding
//                       child: Text(
//                         "View or print!",
//                         style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
//                         textAlign: TextAlign.center, // Center the text
//                       ),
//                     ),
//                     SizedBox(height: 20),  // Adds space between the message and the buttons
//
//                     // Row to align the buttons on the left and right
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribute space between the buttons
//                       children: [
//                         Padding(
//                           padding: const EdgeInsets.only(left: 10.0), // Padding for left button
//                           child: ElevatedButton(
//                             onPressed: () async {
//                               final pdf = _generateReceiptPdf();
//                               await Printing.sharePdf(
//                                 bytes: await pdf.save(),
//                                 filename: 'receipt_${DateTime.now().toIso8601String().replaceAll(":", "-")}.pdf',
//                               );
//                             },
//                             child: Row(
//                               children: [
//                                 Icon(Icons.picture_as_pdf, color: Colors.white),
//                                 SizedBox(width: 8),
//                                 Text("📄 View in PDF"),
//                               ],
//                             ),
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.blue, // Background color
//                               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                             ),
//                           ),
//                         ),
//                         Padding(
//                           padding: const EdgeInsets.only(right: 10.0), // Padding for right button
//                           child: ElevatedButton(
//                             onPressed: () async {
//                               final pdf = _generateReceiptPdf();
//                               await Printing.layoutPdf(
//                                 onLayout: (PdfPageFormat format) async => pdf.save(),
//                               );
//                             },
//                             child: Row(
//                               children: [
//                                 Icon(Icons.print, color: Colors.white),
//                                 SizedBox(width: 8),
//                                 Text("🖨️ Print"),
//                               ],
//                             ),
//
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: Colors.green, // Background color
//                               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                             ),
//
//
//                           ),
//
//                         ),
//                       ],
//                     ),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.end,
//                       children: [
//                         FloatingActionButton(
//                           mini: true,
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => ChatbotScreen(
//                                   ollamaApiUrl: 'http://localhost:11434/v1/chat/completions',
//                                 ),
//                               ),
//                             );
//                           },
//                           tooltip: 'Open Chatbot Assistance',
//                           child: Icon(
//                             Icons.chat_bubble_outline,
//                             size: 32, // Increase the icon size (default is 24)
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//
//               ),
//             ],
//
//           ),
//         ),
//       ),
//     );
//   }
//
// }
