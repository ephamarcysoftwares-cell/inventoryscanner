import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dropdown_search/dropdown_search.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/rendering.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

void main() {
  runApp(MaterialApp(home: QrcodeGenerator()));
}

class Product {
  final String productName;
  final String kg;
  final String businessName;
  final String businessEmail;
  final String businessPhone;
  final String businessLocation;
  final String businessLogoPath;
  final String address;
  final String whatsapp;
  final String lipaNumber;

  Product({
    required this.productName,
    required this.kg,
    required this.businessName,
    required this.businessEmail,
    required this.businessPhone,
    required this.businessLocation,
    required this.businessLogoPath,
    required this.address,
    required this.whatsapp,
    required this.lipaNumber,
  });

  String toBarcodeData() {
    return 'Product Details\n'
        'Product Name: $productName\n'
        'Business Name: $businessName\n'
        'Business Email: $businessEmail\n'
        'Business Phone: $businessPhone\n'
        'Business Location: $businessLocation\n'
        'Address: $address\n'
        'WhatsApp: $whatsapp\n'
        'Lipa Number: $lipaNumber\n'
        'Weight : $kg';
  }
}

class QrcodeGenerator extends StatefulWidget {
  @override
  _QrcodeGeneratorState createState() => _QrcodeGeneratorState();
}

class _QrcodeGeneratorState extends State<QrcodeGenerator> {
  final _productNameController = TextEditingController();
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _userInfoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String _barcodeData = "";
  Product? _product;
  bool _isBarcode = false;
  bool _isUserInfo = false;
  String? _selectedUnit;

  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';

  final GlobalKey _barcodeKey = GlobalKey();

  List<String> unitItems = [
    'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
    'Gram (g)', 'Milliliter (ml)', 'Meter (m)', 'Centimeter (cm)', 'Pack',
    'Carton', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet',
    'Capsule', 'Tray', 'Barrel', 'Can', 'Jar', 'Pouch', 'Unit', 'Bundle'
  ];

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
  }

  Future<void> getBusinessInfo() async {
    try {
      Database db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name']?.toString() ?? '';
          businessEmail = result[0]['email']?.toString() ?? '';
          businessPhone = result[0]['phone']?.toString() ?? '';
          businessLocation = result[0]['location']?.toString() ?? '';
          businessLogoPath = result[0]['logo']?.toString() ?? '';
          address = result[0]['address']?.toString() ?? '';
          whatsapp = result[0]['whatsapp']?.toString() ?? '';
          lipaNumber = result[0]['lipa_number']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }

  String _userInfoData() {
    return 'User Info\n${_userInfoController.text}';
  }

  Future<void> _createProduct() async {
    if (_isUserInfo) {
      setState(() {
        _barcodeData = _userInfoData();
      });

      final db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
      final localData = {
        'product_name': 'User Info',
        'kg': '',
        'business_name': _userInfoData(),
        'business_email': '',
        'business_phone': '',
        'business_location': '',
        'business_logo_path': '',
        'address': '',
        'whatsapp': '',
        'lipa_number': '',
        'created_at': DateTime.now().toIso8601String(),
      };
      await db.insert('products', localData, conflictAlgorithm: ConflictAlgorithm.replace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("User info saved to products table.")),
      );

      await http.post(
        Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_qrcode.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(localData),
      );
    } else {
      final product = Product(
        productName: _productNameController.text,
        kg: _kgController.text,
        businessName: businessName,
        businessEmail: businessEmail,
        businessPhone: businessPhone,
        businessLocation: businessLocation,
        businessLogoPath: businessLogoPath,
        address: address,
        whatsapp: whatsapp,
        lipaNumber: lipaNumber,
      );

      setState(() {
        _product = product;
        _barcodeData = product.toBarcodeData();
      });

      await saveProductToDatabase(context, product);
    }
  }

  Future<void> saveProductToDatabase(BuildContext context, Product product) async {
    try {
      Database db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');

      final localData = {
        'product_name': product.productName,
        'kg': product.kg,
        'business_name': product.businessName,
        'business_email': product.businessEmail,
        'business_phone': product.businessPhone,
        'business_location': product.businessLocation,
        'business_logo_path': product.businessLogoPath,
        'address': product.address,
        'whatsapp': product.whatsapp,
        'lipa_number': product.lipaNumber,
        'created_at': DateTime.now().toIso8601String(),
      };

      await db.insert('products', localData, conflictAlgorithm: ConflictAlgorithm.replace);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Product saved to database.")),
      );

      await http.post(
        Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/save_qrcode.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(localData),
      );
    } catch (e) {
      print('Error saving product: $e');
    }
  }

  Future<String> _generatePdf(String data, String title) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(data),
            pw.SizedBox(height: 20),
            pw.BarcodeWidget(
              data: data,
              barcode: _isBarcode ? pw.Barcode.code128() : pw.Barcode.qrCode(),
              drawText: false,
            ),
          ],
        ),
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/barcode_or_qrcode.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  Future<void> _sendEmailWithAttachments(String pdfPath, String? pngPath) async {
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    // Use manual email if provided, otherwise admin email
    String? recipientEmail = _emailController.text.isNotEmpty
        ? _emailController.text
        : (await getAdminEmail() as String?);

    if (recipientEmail == null || recipientEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No email provided.")),
      );
      return;
    }

    final message = Message()
      ..from = Address(
        'suport@ephamarcysoftware.co.tz',
        businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE',
      )
      ..recipients.add(recipientEmail)
      ..subject = 'Details, Barcode & QR Code'
      ..text = 'Attached are your info, PDF, and barcode/QR code image.'
      ..attachments.add(FileAttachment(File(pdfPath)));

    // Attach PNG if available
    if (pngPath != null && pngPath.isNotEmpty) {
      message.attachments.add(FileAttachment(File(pngPath)));
    }

    try {
      await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Email sent successfully!")),
      );
    } catch (e) {
      print('Error sending email: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending email")),
      );
    }
  }


  Future<Object?> getAdminEmail() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
    if (result.isNotEmpty) return result.first['email'];
    return null;
  }

  Future<void> _generateAndSendPdf() async {
    String data = _isUserInfo ? _userInfoData() : _product!.toBarcodeData();
    String title = _isUserInfo ? "Details" : "Product Details";

    // Generate PDF
    String pdfPath = await _generatePdf(data, title);

    // Generate PNG in temp directory
    RenderRepaintBoundary boundary =
    _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final tempDir = await getTemporaryDirectory();
    final pngFile = File('${tempDir.path}/barcode_or_qrcode.png');
    await pngFile.writeAsBytes(pngBytes);

    // Send email with both attachments
    await _sendEmailWithAttachments(pdfPath, pngFile.path);
  }

  Future<void> _saveBarcodeAsPng() async {
    try {
      RenderRepaintBoundary boundary =
      _barcodeKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final directory = await FilePicker.platform.getDirectoryPath();
      if (directory != null) {
        final file = File('$directory/barcode_or_qrcode.png');
        await file.writeAsBytes(pngBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image saved as PNG at ${file.path}")),
        );
      }
    } catch (e) {
      print('Error saving PNG: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving PNG: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "bar code Generator",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Use My Info'),
                Switch(
                  value: _isUserInfo,
                  onChanged: (value) {
                    setState(() {
                      _isUserInfo = value;
                    });
                  },
                ),
              ],
            ),
            if (_isUserInfo)
              TextField(
                controller: _userInfoController,
                decoration: InputDecoration(
                  labelText: 'Enter your info (list or whatever)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
                maxLines: null,
              )
            else ...[
              TextField(controller: _productNameController, decoration: InputDecoration(labelText: 'Product Name')),
              TextField(controller: _kgController, decoration: InputDecoration(labelText: 'Weight (kg)')),
              SizedBox(height: 16),
              DropdownSearch<String>(
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(labelText: "Search Unit", prefixIcon: Icon(Icons.search)),
                  ),
                ),
                items: unitItems,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(labelText: 'Select Unit'),
                ),
                selectedItem: _selectedUnit,
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedUnit = newValue!;
                  });
                },
              ),
            ],
            SizedBox(height: 20),
            Row(
              children: [
                Text('Generate Barcode'),
                Switch(
                  value: _isBarcode,
                  onChanged: (value) {
                    setState(() {
                      _isBarcode = value;
                    });
                  },
                ),
                Text('Generate QR Code'),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _createProduct, child: Text('Generate')),
            SizedBox(height: 20),
            if (_barcodeData.isNotEmpty || _product != null)
              Column(
                children: [
                  RepaintBoundary(
                    key: _barcodeKey,
                    child: BarcodeWidget(
                      barcode: _isBarcode ? Barcode.code128() : Barcode.qrCode(),
                      data: _isUserInfo ? _userInfoData() : _product!.toBarcodeData(),
                      width: 200,
                      height: 200,
                    ),
                  ),
                  SizedBox(height: 20),

                  // NEW: Email input
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Enter email to send PDF/PNG (optional)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 10),

                  ElevatedButton(onPressed: _generateAndSendPdf, child: Text('Generate & Send PDF/PNG')),
                  SizedBox(height: 20),
                  ElevatedButton(onPressed: _saveBarcodeAsPng, child: Text('Download Barcode/QR Code as PNG')),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
