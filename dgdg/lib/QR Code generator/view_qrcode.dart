// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:barcode_widget/barcode_widget.dart'; // Import the barcode widget package
// import 'package:mailer/mailer.dart';
// import 'package:mailer/smtp_server.dart';
// import 'package:mailer/smtp_server/gmail.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:flutter/services.dart' show rootBundle;
// import 'dart:typed_data';
//
// import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart'; // Import barcode scanner package
// import 'package:intl/intl.dart'; // For date formatting
//
// void main() {
//   runApp(MaterialApp(home: ProductListPage()));
// }
//
// class Product {
//   final String productName;
//   final String kg;
//   final String businessName;
//   final String businessEmail;
//   final String businessPhone;
//   final String businessLocation;
//   final String businessLogoPath;
//   final String address;
//   final String whatsapp;
//   final String lipaNumber;
//   final String createdAt;
//
//   Product({
//     required this.productName,
//     required this.kg,
//     required this.businessName,
//     required this.businessEmail,
//     required this.businessPhone,
//     required this.businessLocation,
//     required this.businessLogoPath,
//     required this.address,
//     required this.whatsapp,
//     required this.lipaNumber,
//     required this.createdAt,
//   });
//
//   factory Product.fromMap(Map<String, dynamic> map) {
//     return Product(
//       productName: map['product_name'],
//       kg: map['kg'],
//       businessName: map['business_name'],
//       businessEmail: map['business_email'],
//       businessPhone: map['business_phone'],
//       businessLocation: map['business_location'],
//       businessLogoPath: map['business_logo_path'],
//       address: map['address'],
//       whatsapp: map['whatsapp'],
//       lipaNumber: map['lipa_number'],
//       createdAt: map['created_at'],
//     );
//   }
// }
//
// class ProductListPage extends StatefulWidget {
//   @override
//   _ProductListPageState createState() => _ProductListPageState();
// }
//
// class _ProductListPageState extends State<ProductListPage> {
//   List<Product> _savedProducts = [];
//   List<Product> _filteredProducts = [];
//   bool _isBarcode = false; // Default to QR code
//   TextEditingController _searchController = TextEditingController();
//   TextEditingController _emailController = TextEditingController(); // Controller for email
//
//   DateTime? _startDate;
//   DateTime? _endDate;
//   String? _startDateFormatted;
//   String? _endDateFormatted;
//   String? _selectedBusinessName;
//   String businessName = '';
//   String businessEmail = '';
//   String businessPhone = '';
//   String businessLocation = '';
//   String businessLogoPath = '';
//   String address = '';
//   String whatsapp = '';
//   String lipaNumber = '';
//   @override
//   void initState() {
//     super.initState();
//     _loadSavedProducts();
//     _searchController.addListener(_filterProducts);
//     getBusinessInfo();
//   }
//
//   Future<void> _loadSavedProducts() async {
//     final dbPath = await getDatabasesPath();
//     Database db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
//     final List<Map<String, dynamic>> productRows = await db.query('products');
//
//     setState(() {
//       _savedProducts = List.generate(productRows.length, (index) {
//         return Product.fromMap(productRows[index]);
//       });
//       _filteredProducts = _savedProducts;
//     });
//   }
//
//   // Filter products based on search query and date range
//   void _filterProducts() {
//     String query = _searchController.text.toLowerCase();
//     setState(() {
//       _filteredProducts = _savedProducts
//           .where((product) {
//         bool matchesSearch = product.productName.toLowerCase().contains(query) ||
//             product.businessName.toLowerCase().contains(query) ||
//             product.kg.contains(query);
//
//         if (_startDate != null && _endDate != null) {
//           DateTime createdAt = DateTime.parse(product.createdAt);
//           return matchesSearch &&
//               createdAt.isAfter(_startDate!) &&
//               createdAt.isBefore(_endDate!);
//         }
//         return matchesSearch;
//       })
//           .toList();
//     });
//   }
//
//   // Method to scan the barcode or QR code
//   Future<void> _scanCode() async {
//     String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
//         '#ff6666', 'Cancel', true, ScanMode.BARCODE); // QR mode can also be used
//
//     if (barcodeScanRes != '-1') {
//       // Once the barcode is scanned, retrieve the product based on the scanned result
//       _showProductDetails(barcodeScanRes);
//     }
//   }
//
//   // Method to show the product details in a dialog
//   void _showProductDetails(String productName) {
//     // Find the product by its name or another unique identifier
//     Product? product = _savedProducts.firstWhere(
//           (product) => product.productName == productName,
//       orElse: () => Product(
//         productName: 'Not found',
//         kg: 'N/A',
//         businessName: 'N/A',
//         businessEmail: 'N/A',
//         businessPhone: 'N/A',
//         businessLocation: 'N/A',
//         businessLogoPath: '',
//         address: 'N/A',
//         whatsapp: 'N/A',
//         lipaNumber: 'N/A',
//         createdAt: 'N/A',
//       ),
//     );
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: Text('Product Details'),
//           content: SingleChildScrollView(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Product Name: ${product.productName}'),
//                 Text('Weight: ${product.kg}'),
//                 Text('Business Name: ${product.businessName}'),
//                 Text('Business Email: ${product.businessEmail}'),
//                 Text('Business Phone: ${product.businessPhone}'),
//                 Text('Business Location: ${product.businessLocation}'),
//                 Text('Address: ${product.address}'),
//                 Text('WhatsApp: ${product.whatsapp}'),
//                 Text('Lipa Number: ${product.lipaNumber}'),
//                 Text('Created At: ${product.createdAt}'),
//                 SizedBox(height: 10),
//                 // Display the barcode/QR code based on _isBarcode value
//                 _generateBarcodeImage(product),
//                 SizedBox(height: 20),
//                 // Email input field
//                 TextField(
//                   controller: _emailController,
//                   decoration: InputDecoration(
//                     labelText: 'Enter Email Address to Send',
//                     border: OutlineInputBorder(),
//                   ),
//                 ),
//                 SizedBox(height: 20),
//                 ElevatedButton(
//                   onPressed: () {
//                     // Send email when the button is pressed
//                     _sendEmailWithPdf(product, _emailController.text);
//                   },
//                   child: Text('Send via Email'),
//                 ),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: Text('Close'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   Future<String> _generateProductPdf(Product product) async {
//     final pdf = pw.Document();
//
//     final barcodeData = '''
// Product Name: ${product.productName}
// Weight: ${product.kg}
// Business Name: ${product.businessName}
// Business Email: ${product.businessEmail}
// Business Phone: ${product.businessPhone}
// Business Location: ${product.businessLocation}
// Address: ${product.address}
// WhatsApp: ${product.whatsapp}
// Lipa Number: ${product.lipaNumber}
// ''';
//
//     pdf.addPage(
//       pw.Page(
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text('Product Details',
//                   style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//               pw.SizedBox(height: 10),
//               pw.Text(barcodeData.trim()),
//               pw.SizedBox(height: 20),
//               pw.Container(
//                 height: 100,
//                 width: 200,
//                 child: pw.BarcodeWidget(
//                   data: barcodeData.trim(),
//                   barcode: _isBarcode ? pw.Barcode.code128() : pw.Barcode.qrCode(),
//                   drawText: false,
//                 ),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//
//     final output = await getTemporaryDirectory();
//     final file = File("${output.path}/product_${product.productName}.pdf");
//     await file.writeAsBytes(await pdf.save());
//
//     return file.path;
//   }
//
//   // Generate barcode or QR code widget
//   Widget _generateBarcodeImage(Product product) {
//     // Collect all product details into a string
//     String productDetails = '''
//       Product Name: ${product.productName}
//       Weight: ${product.kg}
//       Business Name: ${product.businessName}
//       Business Email: ${product.businessEmail}
//       Business Phone: ${product.businessPhone}
//       Business Location: ${product.businessLocation}
//       Address: ${product.address}
//       WhatsApp: ${product.whatsapp}
//       Lipa Number: ${product.lipaNumber}
//     ''';
//
//     return BarcodeWidget(
//       barcode: _isBarcode ? Barcode.code128() : Barcode.qrCode(), // Toggle between Barcode and QR code
//       data: productDetails.trim(), // Using all details in the barcode/QR code data
//       width: 200,
//       height: 200,
//     );
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
//   // Send email with PDF (for now it's just sending a simple email without PDF attachment)
//   Future<void> _sendEmailWithPdf(Product product, String recipientEmail) async {
//     final smtpServer = SmtpServer(
//       'mail.ephamarcysoftware.co.tz',
//       username: 'suport@ephamarcysoftware.co.tz',
//       password: 'Matundu@2050',
//       port: 465,
//       ssl: true,
//     );
//
//     try {
//       final pdfPath = await _generateProductPdf(product);
//
//       final message = Message()
//         ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
//         ..recipients.add(recipientEmail.isEmpty ? await getAdminEmail() ?? '' : recipientEmail)
//         ..subject = 'Product Details & Barcode/QR Code PDF'
//         ..text = 'Attached is your product info with the barcode/QR code.'
//         ..attachments.add(FileAttachment(File(pdfPath)));
//
//       final sendReport = await send(message, smtpServer);
//       print('Message sent: ' + sendReport.toString());
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Email sent successfully!")));
//     } catch (e) {
//       print('Error sending email: $e');
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Error sending email")));
//     }
//   }
//
//
//   // Get admin email from database
//   Future<String?> getAdminEmail() async {
//     final dbPath = await getDatabasesPath();
//     final db = await openDatabase('$dbPath/epharmacy.db');
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
//   @override
//   void dispose() {
//     _searchController.dispose();
//     _emailController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           "Product List",
//           style: TextStyle(color: Colors.white), // ✅ correct place
//         ),
//         centerTitle: true,
//         backgroundColor: Colors.teal,
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
//         ),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             // Date Picker Row
//             Row(
//               children: [
//                 Text('Start Date: ${_startDateFormatted ?? 'Select'}'),
//                 IconButton(
//                   icon: Icon(Icons.calendar_today),
//                   onPressed: _selectStartDate,
//                 ),
//                 Text('End Date: ${_endDateFormatted ?? 'Select'}'),
//                 IconButton(
//                   icon: Icon(Icons.calendar_today),
//                   onPressed: _selectEndDate,
//                 ),
//               ],
//             ),
//             SizedBox(height: 20),
//             // Search bar
//             TextField(
//               controller: _searchController,
//               decoration: InputDecoration(
//                 labelText: 'Search Products',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.search),
//               ),
//             ),
//             SizedBox(height: 20),
//             // Barcode / QR Code Toggle
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text('Barcode'),
//                 Switch(
//                   value: _isBarcode,
//                   onChanged: (bool value) {
//                     setState(() {
//                       _isBarcode = value;
//                     });
//                   },
//                 ),
//                 Text('QR Code'),
//               ],
//             ),
//             SizedBox(height: 20),
//             // Scan Button
//             ElevatedButton(
//               onPressed: _scanCode,
//               child: Text('Scan Barcode/QR Code'),
//             ),
//             SizedBox(height: 20),
//             // Display the filtered products list in a ListView
//             Expanded(
//               child: _filteredProducts.isNotEmpty
//                   ? ListView.builder(
//                 itemCount: _filteredProducts.length,
//                 itemBuilder: (context, index) {
//                   final product = _filteredProducts[index];
//                   return Card(
//                     margin: EdgeInsets.symmetric(vertical: 8),
//                     child: ListTile(
//                       contentPadding: EdgeInsets.all(10),
//                       title: Text(product.productName),
//                       subtitle: Text('Business Name: ${product.businessName}'),
//                       trailing: IconButton(
//                         icon: Icon(Icons.info),
//                         onPressed: () {
//                           _showProductDetails(product.productName);
//                         },
//                       ),
//                     ),
//                   );
//                 },
//               )
//                   : Center(child: Text('No products found matching your search.')),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // Select Start Date using DatePicker
//   Future<void> _selectStartDate() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _startDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _startDate) {
//       setState(() {
//         _startDate = picked;
//         _startDateFormatted = DateFormat('yyyy-MM-dd').format(picked);
//         _filterProducts(); // Filter products based on the selected date range
//       });
//     }
//   }
//
//   // Select End Date using DatePicker
//   Future<void> _selectEndDate() async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _endDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime.now(),
//     );
//     if (picked != null && picked != _endDate) {
//       setState(() {
//         _endDate = picked;
//         _endDateFormatted = DateFormat('yyyy-MM-dd').format(picked);
//         _filterProducts(); // Filter products based on the selected date range
//       });
//     }
//   }
// }
