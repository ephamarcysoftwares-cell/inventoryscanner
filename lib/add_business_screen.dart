import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:sqflite/sqflite.dart';
import 'package:stock_and_inventory_software/sales_report_service.dart';
import 'DB/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class AddBusinessScreen extends StatefulWidget {
  const AddBusinessScreen({super.key});

  @override
  State<AddBusinessScreen> createState() => _AddBusinessScreenState();
}

class _AddBusinessScreenState extends State<AddBusinessScreen> {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessEmailController = TextEditingController();
  final TextEditingController businessPhoneController = TextEditingController();
  final TextEditingController businessLocationController = TextEditingController();
  final TextEditingController businessAddressController = TextEditingController(); // New address controller
  final TextEditingController businessWhatsappController = TextEditingController(); // New WhatsApp controller
  final TextEditingController businessLipaNumberController = TextEditingController();

  String? _selectedBusinessName;
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';
  // New Lipa number controller

  bool isSaving = false;
  String message = '';
  File? _logo; // Variable to store the logo image

  // Save the business information to the database
  Future<void> getBusinessInfo() async {
    try {
      // 1️⃣ Load from local SQLite first
      Database db = await openDatabase(
          'C:\\Users\\Public\\epharmacy\\epharmacy.db');
      List<Map<String, dynamic>> localResult =
      await db.rawQuery('SELECT * FROM businesses');

      if (localResult.isNotEmpty) {
        setState(() {
          businessName = localResult[0]['business_name']?.toString() ?? '';
          businessEmail = localResult[0]['email']?.toString() ?? '';
          businessPhone = localResult[0]['phone']?.toString() ?? '';
          businessLocation = localResult[0]['location']?.toString() ?? '';
          businessLogoPath = localResult[0]['logo']?.toString() ?? '';
          address = localResult[0]['address']?.toString() ?? '';
          whatsapp = localResult[0]['whatsapp']?.toString() ?? '';
          lipaNumber = localResult[0]['lipa_number']?.toString() ?? '';
        });
      }

      // 2️⃣ Check internet connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        // 3️⃣ Fetch from Supabase
        final supabase = Supabase.instance.client;
        final supabaseResult = await supabase
            .from('businesses')
            .select()
            .order('id', ascending: true)
            .limit(1)
            .maybeSingle();

        if (supabaseResult != null) {
          setState(() {
            businessName = supabaseResult['business_name']?.toString() ?? businessName;
            businessEmail = supabaseResult['email']?.toString() ?? businessEmail;
            businessPhone = supabaseResult['phone']?.toString() ?? businessPhone;
            businessLocation = supabaseResult['location']?.toString() ?? businessLocation;
            businessLogoPath = supabaseResult['logo']?.toString() ?? businessLogoPath;
            address = supabaseResult['address']?.toString() ?? address;
            whatsapp = supabaseResult['whatsapp']?.toString() ?? whatsapp;
            lipaNumber = supabaseResult['lipa_number']?.toString() ?? lipaNumber;
          });
        }
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }


  Future<void> saveBusiness() async {
    String name = businessNameController.text.trim();
    String email = businessEmailController.text.trim();
    String phone = businessPhoneController.text.trim();
    String location = businessLocationController.text.trim();
    String address = businessAddressController.text.trim();
    String whatsapp = businessWhatsappController.text.trim();
    String lipaNumber = businessLipaNumberController.text.trim();

    if ([name, email, phone, location, address, whatsapp, lipaNumber]
        .any((field) => field.isEmpty)) {
      setState(() {
        message = "All fields are required!";
      });
      return;
    }

    setState(() {
      isSaving = true;
      message = '';
    });

    // Optional: Fetch existing business info if needed
    await getBusinessInfo();

    // Check for duplicates locally
    bool nameExists =
    await DatabaseHelper.instance.isBusinessFieldExists('business_name', name);
    bool emailExists =
    await DatabaseHelper.instance.isBusinessFieldExists('email', email);
    bool phoneExists =
    await DatabaseHelper.instance.isBusinessFieldExists('phone', phone);

    if (nameExists || emailExists || phoneExists) {
      String duplicateFields = [
        if (nameExists) 'Business Name',
        if (emailExists) 'Email',
        if (phoneExists) 'Phone',
      ].join(', ');

      setState(() {
        message = "$duplicateFields already exists!";
        isSaving = false;
      });
      return;
    }

    // Save the logo file if it exists
    String? logoPath;
    if (_logo != null) {
      logoPath = await _saveLogoToFile(_logo!);
    }

    final Map<String, dynamic> businessData = {
      'business_name': name,
      'email': email,
      'phone': phone,
      'location': location,
      'address': address,
      'whatsapp': whatsapp,
      'lipa_number': lipaNumber,
      'logo': logoPath,
    };

    // 1️⃣ Insert locally
    final int localResult =
    await DatabaseHelper.instance.insertBusiness('businesses', businessData);

    if (localResult <= 0) {
      setState(() {
        message = "Failed to add business locally. Try again.";
        isSaving = false;
      });
      return;
    }

    // Clear controllers after successful local insert
    businessNameController.clear();
    businessEmailController.clear();
    businessPhoneController.clear();
    businessLocationController.clear();
    businessAddressController.clear();
    businessWhatsappController.clear();
    businessLipaNumberController.clear();

    setState(() {
      message = "Business added locally!";
    });

    // 2️⃣ Insert on Supabase
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('businesses').insert({
        'business_name': name,
        'email': email,
        'phone': phone,
        'location': location,
        'address': address,
        'whatsapp': whatsapp,
        'lipa_number': lipaNumber,
        'logo': logoPath,
      }).select().maybeSingle();

      setState(() {
        message = "Business added successfully on Supabase!";
      });
    } catch (e) {
      print("Supabase insert failed: $e");
      setState(() {
        message =
        "Business saved locally but failed to sync with Supabase: $e";
      });
    }

    // 3️⃣ Optional: Send email notification
    await _sendEmailNotification(name, email, phone, location, address, whatsapp, lipaNumber);

    setState(() {
      isSaving = false;
    });
  }


  // Fetch admin email from the database
  // Fetch all admin emails from the database
  Future<List<String>> getAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    return result.map((row) => row['email'].toString()).toList();
  }

// Send email notification to all admins
  Future<void> _sendEmailNotification(
      String name,
      String email,
      String phone,
      String location,
      String address,
      String whatsapp,
      String lipaNumber,
      ) async {
    List<String> adminEmails = await getAdminEmails(); // ✅ await the result

    if (adminEmails.isEmpty) {
      print("❌ No admin found to send email to.");
      return;
    }

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = Message()
      ..from = Address(
          'suport@ephamarcysoftware.co.tz',
          businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
      ..recipients.addAll(adminEmails) // ✅ now using actual list of emails
      ..subject = '📢 New Business Added: $name'
      ..html = '''
<!DOCTYPE html>
<html>
<head>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #f4f6f8;
      margin: 0;
      padding: 20px;
      color: #333;
    }
    .container {
      background-color: #ffffff;
      max-width: 600px;
      margin: auto;
      border-radius: 10px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
      padding: 25px 30px;
    }
    h2 {
      color: #00796b;
      margin-bottom: 20px;
      text-align: center;
      font-weight: 700;
    }
    p.intro {
      font-size: 16px;
      margin-bottom: 25px;
      text-align: center;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 30px;
    }
    th, td {
      text-align: left;
      padding: 12px 15px;
      border-bottom: 1px solid #e0e0e0;
      font-size: 15px;
    }
    th {
      background-color: #00796b;
      color: white;
      font-weight: 600;
    }
    tr:hover {
      background-color: #e0f2f1;
    }
    .footer {
      text-align: center;
      font-size: 13px;
      color: #999;
      border-top: 1px solid #e0e0e0;
      padding-top: 12px;
    }
    
  body {
    font-family: Arial, sans-serif;
    background-color: #f4f6f8;
    margin: 0;
    padding: 20px;
    color: #333;
  }
  .container {
    background-color: #ffffff;
    max-width: 600px;
    margin: auto;
    border-radius: 10px;
    box-shadow: 0 4px 15px rgba(0,0,0,0.1);
    padding: 25px 30px;
  }
  h2 {
    color: #00796b;
    margin-bottom: 20px;
    text-align: center;
    font-weight: 700;
  }
  p.intro {
    font-size: 16px;
    margin-bottom: 25px;
    text-align: center;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    margin-bottom: 30px;
    border: 2px solid #00796b;
  }
  th, td {
    text-align: left;
    padding: 12px 15px;
    border: 1px solid #00796b;
    font-size: 15px;
  }
  th {
    background-color: #00796b;
    color: white;
    font-weight: 600;
  }
  .footer {
    text-align: center;
    font-size: 13px;
    color: #999;
    border-top: 1px solid #e0e0e0;
    padding-top: 12px;
  }
 

  </style>
</head>
<body>
  <div class="container">
    <h2>New Business Added</h2>
    <p class="intro">Hello Admin,<br>A new business has been added to the system with the following details:</p>
    <table >
      <tr>
        <th>Field</th>
        <th>Details</th>
      </tr>
      <tr>
        <td>Business Name</td>
        <td>$name</td>
      </tr>
      <tr>
        <td>Email</td>
        <td>$email</td>
      </tr>
      <tr>
        <td>Phone</td>
        <td>$phone</td>
      </tr>
      <tr>
        <td>Location</td>
        <td>$location</td>
      </tr>
      <tr>
        <td>Address</td>
        <td>$address</td>
      </tr>
      <tr>
        <td>WhatsApp</td>
        <td>$whatsapp</td>
      </tr>
      <tr>
        <td>Lipa Number</td>
        <td>$lipaNumber</td>
      </tr>
    </table>
    <p>Regards,<br><strong>STOCK & INVENTORY SOFTWARE</strong></p>
    <div class="footer">
      <small>This is an automated message, please do not reply.</small>
    </div>
  </div>
</body>
</html>
''';

    try {
      await send(message, smtpServer);
      print('Email sent to admin');
    } catch (e) {
      print('Failed to send email: $e');
    }
  }


  // Save the logo to the specified directory in C:\Users\Public\epharmacy\bussiness_logo
  Future<String?> _saveLogoToFile(File logo) async {
    try {
      final String folderPath = r'C:\Users\Public\epharmacy\bussiness_logo';
      final Directory directory = Directory(folderPath);

      // Check and create folder if not exists
      if (!await directory.exists()) {
        print('Directory does not exist. Creating...');
        await directory.create(recursive: true);
        print('Directory created: $folderPath');
      }

      final String fileName = 'business_logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final String fullPath = '$folderPath\\$fileName';

      // Save the file
      final savedFile = await logo.copy(fullPath);
      print('Logo saved at: ${savedFile.path}');
      return savedFile.path;

    } catch (e) {
      print('Failed to save logo: $e');
      return null;
    }
  }

  // Pick a logo image from the gallery
  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _logo = File(pickedFile.path);
      });
    }
  }

  // Widget for displaying and selecting the logo
  Widget _buildLogoSection() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickLogo, // Trigger image picking on tap
          child: _logo == null
              ? CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.add_a_photo, size: 40, color: Colors.green[700]),
          )
              : CircleAvatar(
            radius: 50,
            backgroundImage: FileImage(_logo!),
          ),
        ),
        SizedBox(height: 10),
        Text(
          _logo == null ? "Tap to upload logo" : "Logo uploaded",
          style: TextStyle(color: Colors.green[700], fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Add Business",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildLogoSection(), // Logo section
              SizedBox(height: 10),
              TextField(
                controller: businessNameController,
                decoration: _inputDecoration('Business Name'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessEmailController,
                decoration: _inputDecoration('Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessPhoneController,
                decoration: _inputDecoration('Phone'),
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessLocationController,
                decoration: _inputDecoration('Location'),
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessAddressController,
                decoration: _inputDecoration('Address'), // New field
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessWhatsappController,
                decoration: _inputDecoration('WhatsApp'), // New field
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 10),
              TextField(
                controller: businessLipaNumberController,
                decoration: _inputDecoration('Lipa Number'), // New field
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSaving ? null : saveBusiness,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green[700],
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 10,
                ),
                child: isSaving
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Save Business', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 20),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(
                    color: message.contains('success') ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Input decoration for text fields
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      labelStyle: TextStyle(color: Colors.green[700]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
