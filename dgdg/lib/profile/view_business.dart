import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../DB/database_helper.dart';

class BusinessScreen extends StatefulWidget {
  final int businessId; // The ID of the business to view and update
  const BusinessScreen({super.key, required this.businessId});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessEmailController = TextEditingController();
  final TextEditingController businessPhoneController = TextEditingController();
  final TextEditingController businessLocationController = TextEditingController();

  bool isSaving = false;
  String message = '';
  File? _logo; // Variable to store the logo image
  String? currentLogoPath; // Store the current logo path for updating

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }

  // Load the existing business data into the form
  Future<void> _loadBusinessData() async {
    final businessData = await DatabaseHelper.instance.getBusinessById(widget.businessId);

    if (businessData != null) {
      setState(() {
        businessNameController.text = businessData['business_name'];
        businessEmailController.text = businessData['email'];
        businessPhoneController.text = businessData['phone'];
        businessLocationController.text = businessData['location'];
        currentLogoPath = businessData['logo']; // Set the current logo path

        if (currentLogoPath != null) {
          _logo = File(currentLogoPath!); // Load the existing logo if available
        }
      });
    }
  }

  // Save the updated business data
  Future<void> updateBusiness() async {
    String name = businessNameController.text.trim();
    String email = businessEmailController.text.trim();
    String phone = businessPhoneController.text.trim();
    String location = businessLocationController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || location.isEmpty) {
      setState(() {
        message = "All fields are required!";
      });
      return;
    }

    setState(() {
      isSaving = true;
      message = '';
    });

    // Check if business name, email, or phone already exists
    bool nameExists = await DatabaseHelper.instance.isBusinessFieldExists('business_name', name);
    bool emailExists = await DatabaseHelper.instance.isBusinessFieldExists('email', email);
    bool phoneExists = await DatabaseHelper.instance.isBusinessFieldExists('phone', phone);

    if (nameExists || emailExists || phoneExists) {
      String duplicateFields = '';
      if (nameExists) duplicateFields += 'Business Name, ';
      if (emailExists) duplicateFields += 'Email, ';
      if (phoneExists) duplicateFields += 'Phone, ';
      duplicateFields = duplicateFields.substring(0, duplicateFields.length - 2);

      setState(() {
        message = "$duplicateFields already exists!";
        isSaving = false;
      });
      return;
    }

    // Save the logo file if it exists (update if changed)
    String? logoPath;
    if (_logo != null) {
      logoPath = await _saveLogoToFile(_logo!);
    } else {
      logoPath = currentLogoPath; // Keep the current logo if not changed
    }

    // Prepare the updated business data for insertion
    final Map<String, dynamic> updatedBusinessData = {
      'business_name': name,
      'email': email,
      'phone': phone,
      'location': location,
      'logo': logoPath, // Store the logo path in the database
    };

    final result = await DatabaseHelper.instance.updateBusiness(widget.businessId, updatedBusinessData);

    if (result > 0) {
      setState(() {
        message = "Business updated successfully!";
        businessNameController.clear();
        businessEmailController.clear();
        businessPhoneController.clear();
        businessLocationController.clear();
      });
    } else {
      setState(() {
        message = "Failed to update business. Try again.";
      });
    }

    setState(() {
      isSaving = false;
    });
  }

  // Fetch admin email from the database
  Future<Object?> getAdminEmail() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    if (result.isNotEmpty) {
      return result.first['email'];
    }
    return null;
  }

  // Send email notification to the admin
  Future<void> _sendEmailNotification(String name, String email, String phone, String location) async {
    String? adminEmail = (await getAdminEmail()) as String?;

    if (adminEmail == null) {
      print("No admin found to send email to.");
      return;
    }

    final smtpServer = gmail('mlyukakenedy@gmail.com', 'amgk pwcz jnyq imha');
    final message = Message()
      ..from = Address('mlyukakenedy@gmail.com', 'e-Pharmacy')
      ..recipients.add(adminEmail)
      ..subject = 'Business Updated: $name'
      ..text = '''
        Hello Admin,

        A business has been updated:

        Business Name: $name
        Email: $email
        Phone: $phone
        Location: $location

        Regards,
        e-Pharmacy System
      ''';

    try {
      await send(message, smtpServer);
      print('Email sent to admin');
    } catch (e) {
      print('Failed to send email: $e');
    }
  }

  // Save the logo to the local file system
  Future<String?> _saveLogoToFile(File logo) async {
    final directory = await getApplicationDocumentsDirectory();
    final logoPath = '${directory.path}/business_logo_${DateTime.now().millisecondsSinceEpoch}.png';
    final logoFile = await logo.copy(logoPath);
    return logoFile.path; // Return the saved file path
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
          child: _logo == null && currentLogoPath == null
              ? CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            child: Icon(Icons.add_a_photo, size: 40, color: Colors.green[700]),
          )
              : CircleAvatar(
            radius: 50,
            backgroundImage: _logo != null
                ? FileImage(_logo!)
                : currentLogoPath != null
                ? FileImage(File(currentLogoPath!))
                : null,
          ),
        ),
        SizedBox(height: 10),
        Text(
          _logo == null && currentLogoPath == null ? "Tap to upload logo" : "Logo uploaded",
          style: TextStyle(color: Colors.green[700], fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Business'),
        backgroundColor: Colors.greenAccent,
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
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSaving ? null : updateBusiness,
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
                    : Text('Update Business', style: TextStyle(fontSize: 18)),
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
