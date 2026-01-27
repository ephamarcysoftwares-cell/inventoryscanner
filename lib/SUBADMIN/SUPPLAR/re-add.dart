import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:sqflite/sqflite.dart';

import '../../DB/database_helper.dart';
import '../../FOTTER/CurvedRainbowBar.dart';

class ReaddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? initialData;

  ReaddMedicineScreen({required this.user, this.initialData});

  @override
  _ReaddMedicineScreenState createState() => _ReaddMedicineScreenState();
}

class _ReaddMedicineScreenState extends State<ReaddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyController = TextEditingController();
  final _priceController = TextEditingController();
  final _batchNumberController = TextEditingController();
  final _discountController = TextEditingController();

  final List<String> _units = [
    'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
    'Gram (g)', 'Milliliter (ml)', 'Meter (m)', 'Centimeter (cm)', 'Pack',
    'Carton', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet',
    'Capsule', 'Tray', 'Barrel', 'Can', 'Jar', 'Pouch', 'Unit', 'Bundle'
  ];
  String _selectedUnit = 'Per Item';

  DateTime? _manufactureDate;
  DateTime? _expiryDate;

  List<String> _companies = [];
  String? _selectedCompany;

  List<String> _businessNames = [];
  String? _selectedBusinessName;
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _fetchBusinessNames();
    getBusinessInfo();

    if (widget.initialData != null) {
      final data = widget.initialData!;
      _nameController.text = data['name'] ?? '';
      _quantityController.text = data['total_quantity']?.toString() ?? '';
      _buyController.text = data['buy']?.toString() ?? '';
      _priceController.text = data['price']?.toString() ?? '';
      _batchNumberController.text = data['batchNumber'] ?? '';
      _discountController.text = data['discount']?.toString() ?? '';
      _selectedUnit = data['unit'] ?? 'Per Item';
      _selectedCompany = data['company'];
      _selectedBusinessName = data['businessName'];

      if (data['manufacture_date'] != null) {
        _manufactureDate = DateTime.tryParse(data['manufacture_date']);
      }
      if (data['expiry_date'] != null) {
        _expiryDate = DateTime.tryParse(data['expiry_date']);
      }
    }
  }

  Future<void> _fetchCompanies() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('companies', columns: ['name']);
    if (result.isNotEmpty) {
      setState(() {
        _companies = result.map((c) => c['name'] as String).toList();
      });
    }
  }

  Future<void> _fetchBusinessNames() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('businesses', columns: ['business_name']);
    if (result.isNotEmpty) {
      setState(() {
        _businessNames = result.map((b) => b['business_name'] as String).toList();
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isManufacture) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isManufacture ? (_manufactureDate ?? DateTime.now()) : (_expiryDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isManufacture) {
          _manufactureDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _saveMedicine() async {
    try {
      print('Attempting to save medicine...');
      if (_formKey.currentState!.validate()) {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now();

        print('Validation passed');

        final medicines = {
          'name': _nameController.text,
          'company': _selectedCompany ?? '',
          'total_quantity': int.tryParse(_quantityController.text) ?? 0,
          'remaining_quantity': int.tryParse(_quantityController.text) ?? 0,
          'buy': double.tryParse(_buyController.text) ?? 0.0,
          'price': double.tryParse(_priceController.text) ?? 0.0,
          'batchNumber': _batchNumberController.text,
          'manufacture_date': _manufactureDate?.toIso8601String() ?? '',
          'expiry_date': _expiryDate?.toIso8601String() ?? '',
          'added_by': widget.user['full_name'],
          'discount': double.tryParse(_discountController.text) ?? 0.0,
          'added_time': now.toIso8601String(),
          'unit': _selectedUnit,
          'businessName': _selectedBusinessName ?? '',
          'synced': 0,
        };

        final medical_logs = {
          'medicine_name': _nameController.text,
          'company': _selectedCompany ?? '',
          'total_quantity': int.tryParse(_quantityController.text) ?? 0,
          'remaining_quantity': int.tryParse(_quantityController.text) ?? 0,
          'buy_price': double.tryParse(_buyController.text) ?? 0.0,
          'selling_price': double.tryParse(_priceController.text) ?? 0.0,
          'batch_number': _batchNumberController.text,
          'manufacture_date': _manufactureDate?.toIso8601String() ?? '',
          'expiry_date': _expiryDate?.toIso8601String() ?? '',
          'added_by': widget.user['full_name'],
          'discount': (double.tryParse(_discountController.text) ?? 0.0).toString(),
          'unit': _selectedUnit,
          'business_name': _selectedBusinessName ?? '',
          'date_added': now.toIso8601String(),
          'action': widget.initialData != null ? 'Updated' : 'Successfully added',
        };

        if (widget.initialData != null && widget.initialData!['id'] != null) {
          final id = widget.initialData!['id'] as int;

          print('Updating existing medicine with id $id');

          // Fetch old record for backup
          final oldRecord = await db.query(
            'medicines',
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );

          if (oldRecord.isNotEmpty) {
            final old = oldRecord.first;

            final deletedMedicine = {
              'name': old['name'],
              'company': old['company'],
              'total_quantity': old['total_quantity'],
              'remaining_quantity': old['remaining_quantity'],
              'buy': old['buy'],
              'price': old['price'],
              'batchNumber': old['batchNumber'],
              'manufacture_date': old['manufacture_date'],
              'expiry_date': old['expiry_date'],
              'added_by': old['added_by'],
              'discount': old['discount'],
              'date_added': old['added_time'] ?? now.toIso8601String(),
              'unit': old['unit'],
              'business_name': old['businessName'] ?? '',  // <--- Add fallback here
              'deleted_date': now.toIso8601String(),
            };


            print('Backing up old record to deleted_medicines');
            await db.insert('deleted_medicines', deletedMedicine);
          }

          print('Updating medicine record...');
          await DatabaseHelper.instance.ReupdateMedicine(id, medicines);
          print('Insert medical_logs...');
          await db.insert('medical_logs', medical_logs);

          print('Sending update email notification...');
          await _sendEmailNotification(
            _nameController.text,
            _selectedCompany ?? '',
            int.tryParse(_quantityController.text) ?? 0,
            double.tryParse(_priceController.text) ?? 0.0,
            double.tryParse(_buyController.text) ?? 0.0,
            _batchNumberController.text,
            widget.user['full_name'],
            double.tryParse(_discountController.text) ?? 0.0,
            _selectedUnit,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product updated successfully')),
          );
        } else {
          print('Inserting new medicine...');
          await DatabaseHelper.instance.insertMedicine(medicines);
          print('Insert medical_logs...');
          await db.insert('medical_logs', medical_logs);

          print('Sending new product email notification...');
          await _sendEmailNotification(
            _nameController.text,
            _selectedCompany ?? '',
            int.tryParse(_quantityController.text) ?? 0,
            double.tryParse(_priceController.text) ?? 0.0,
            double.tryParse(_buyController.text) ?? 0.0,
            _batchNumberController.text,
            widget.user['email'],
            double.tryParse(_discountController.text) ?? 0.0,
            _selectedUnit,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Product added successfully')),
          );
        }

        setState(() {
          _isLoading = true;
        });
        await Future.delayed(Duration(seconds: 1));
        Navigator.pop(context);
      } else {
        print('Validation failed, not saving');
      }
    } catch (e, stack) {
      print('Exception in _saveMedicine: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving product: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<List<String>> getAllAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    List<String> emails = [];
    for (var row in result) {
      final email = row['email']?.toString();
      if (email != null && email.isNotEmpty) {
        emails.add(email);
      }
    }
    return emails;
  }

  Future<void> _sendEmailNotification(
      String name,
      String company,
      int quantity,
      double price,
      double buy,
      String batchNumber,
      String addedBy,
      double discount,
      String unit,
      ) async {
    try {
      List<String> adminEmails = await getAllAdminEmails();

      if (adminEmails.isEmpty) {
        print("❌ No admins found to send email to.");
        return;
      }

      print("✅ Admin emails found: $adminEmails");

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>New Product Added</title>
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
      padding: 30px;
      border-radius: 10px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
      max-width: 600px;
      margin: auto;
    }
    h2 {
      color: #007bff;
      text-align: center;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 20px;
    }
    td {
      padding: 12px 15px;
      border: 1px solid #ddd;
    }
    td.label {
      background-color: #f0f4ff;
      font-weight: bold;
      width: 40%;
      color: #0056b3;
    }
    .footer {
      margin-top: 30px;
      font-size: 0.9em;
      text-align: center;
      color: #999;
    }
  </style>
</head>
<body>
  <div class="container">
    <h2>🆕 New Product Added</h2>
    <p>A new product has been added to the inventory system. Here are the details:</p>
    <table>
      <tr>
        <td class="label">Name</td>
        <td>$name</td>
      </tr>
      <tr>
        <td class="label">Company</td>
        <td>$company</td>
      </tr>
      <tr>
        <td class="label">Quantity</td>
        <td>$quantity</td>
      </tr>
      <tr>
        <td class="label">Buy Price</td>
        <td>THS ${buy.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td class="label">Selling Price</td>
        <td>THS ${price.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td class="label">Batch Number</td>
        <td>$batchNumber</td>
      </tr>
      <tr>
        <td class="label">Unit</td>
        <td>$unit</td>
      </tr>
      <tr>
        <td class="label">Discount</td>
        <td>${discount.toStringAsFixed(2)}%</td>
      </tr>
      <tr>
        <td class="label">Added By</td>
        <td>$addedBy</td>
      </tr>
    </table>
    <p>Thank you.<br/>- <strong>Stock & Inventory Software</strong></p>
    <div class="footer">
      &copy; ${DateTime.now().year} E-PHAMARCY SOFTWARE. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
        ..recipients.addAll(adminEmails)
        ..subject = '🆕 New Product Added: $name'
        ..text = 'New product "$name" has been added.'
        ..html = htmlContent;

      final sendReport = await send(message, smtpServer);
      print("✅ Email sent: ${sendReport.toString()}");
    } catch (e) {
      print("❌ Failed to send email: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialData != null
              ? 'STOCK & INVENTORY SOFTWARE - Enter Product'
              : 'Re Stock',
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Medicine Name'),
                validator: (val) => val!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _buyController,
                decoration: InputDecoration(labelText: 'Buy Price'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Selling Price'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _batchNumberController,
                decoration: InputDecoration(labelText: 'Batch Number'),
              ),
              TextFormField(
                controller: _discountController,
                decoration: InputDecoration(labelText: 'Discount (%)'),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 10),
              DropdownSearch<String>(
                items: _units,
                selectedItem: _selectedUnit,
                onChanged: (val) => setState(() => _selectedUnit = val.toString()),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Unit',
                    border: OutlineInputBorder(),
                  ),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: 'Search unit...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'Please select a unit' : null,
              ),
              SizedBox(height: 10),
              DropdownSearch<String>(
                items: _companies,
                selectedItem: _selectedCompany,
                onChanged: (val) => setState(() => _selectedCompany = val),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Company',
                    border: OutlineInputBorder(),
                  ),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: 'Search company...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                validator: (val) =>
                val == null || val.isEmpty ? 'Please select a company' : null,
              ),
              SizedBox(height: 10),
              DropdownSearch<String>(
                items: _businessNames,
                selectedItem: _selectedBusinessName,
                onChanged: (val) => setState(() => _selectedBusinessName = val),
                dropdownDecoratorProps: const DropDownDecoratorProps(
                  dropdownSearchDecoration: InputDecoration(
                    labelText: 'Select Business Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                popupProps: PopupProps.menu(
                  showSearchBox: true,
                  searchFieldProps: TextFieldProps(
                    decoration: InputDecoration(
                      labelText: 'Search business...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please select a business name'
                    : null,
              ),
              SizedBox(height: 10),
              ListTile(
                title: Text(_manufactureDate == null
                    ? 'Select Manufacture Date'
                    : 'Manufacture Date: ${DateFormat('yyyy-MM-dd').format(_manufactureDate!)}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true),
              ),
              ListTile(
                title: Text(_expiryDate == null
                    ? 'Select Expiry Date'
                    : 'Expiry Date: ${DateFormat('yyyy-MM-dd').format(_expiryDate!)}'),
                trailing: Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, false),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                  setState(() {
                    _isLoading = true;
                  });
                  await _saveMedicine();
                  setState(() {
                    _isLoading = false;
                  });
                },
                child: _isLoading
                    ? CircularProgressIndicator(
                  color: Colors.yellow,
                )
                    : Text(widget.initialData != null ? 'Update Product' : 'Add Product'),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
