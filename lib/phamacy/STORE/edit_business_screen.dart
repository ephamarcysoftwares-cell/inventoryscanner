import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../DB/database_helper.dart';


class EditBusinessScreen extends StatefulWidget {
  final Map<String, dynamic> business;
  const EditBusinessScreen({super.key, required this.business});

  @override
  State<EditBusinessScreen> createState() => _EditBusinessScreenState();
}

class _EditBusinessScreenState extends State<EditBusinessScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController locationController;
  late TextEditingController addressController;
  late TextEditingController whatsappController;
  late TextEditingController lipaNumberController;

  String? _logoPath;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.business['business_name']);
    emailController = TextEditingController(text: widget.business['email']);
    phoneController = TextEditingController(text: widget.business['phone']);
    locationController = TextEditingController(text: widget.business['location']);
    addressController = TextEditingController(text: widget.business['address']);
    whatsappController = TextEditingController(text: widget.business['whatsapp']);
    lipaNumberController = TextEditingController(text: widget.business['lipa_number']);
    _logoPath = widget.business['logo'];
  }

  Future<void> _pickLogo() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _logoPath = pickedFile.path;
      });
    }
  }

  Future<void> _updateBusiness() async {
    final updatedData = {
      'business_name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'location': locationController.text.trim(),
      'address': addressController.text.trim(),
      'whatsapp': whatsappController.text.trim(),
      'lipa_number': lipaNumberController.text.trim(),
      'logo': _logoPath,
    };

    await DatabaseHelper.instance.updateBusiness(widget.business['id'], updatedData);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E-PHAMARCY SOFTWARE'),
        backgroundColor: Colors.greenAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Logo display
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: _logoPath != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_logoPath!), width: 100, height: 100, fit: BoxFit.cover),
                )
                    : Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add_a_photo, color: Colors.grey),
                ),
              ),
            ),
            SizedBox(height: 20),

            TextField(controller: nameController, decoration: InputDecoration(labelText: 'Business Name')),
            TextField(controller: emailController, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: phoneController, decoration: InputDecoration(labelText: 'Phone')),
            TextField(controller: locationController, decoration: InputDecoration(labelText: 'Location')),
            TextField(controller: addressController, decoration: InputDecoration(labelText: 'Address')),
            TextField(controller: whatsappController, decoration: InputDecoration(labelText: 'WhatsApp')),
            TextField(controller: lipaNumberController, decoration: InputDecoration(labelText: 'Lipa Number')),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateBusiness,
              child: Text('Update Business'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
            ),
          ],
        ),
      ),
    );
  }
}
