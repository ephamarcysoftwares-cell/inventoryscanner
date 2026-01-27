import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../DB/database_helper.dart';


class EditMedicineStore extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? medicine; // for editing

  const EditMedicineStore({
    super.key,
    required this.user,
    this.medicine,
    // removed medicineId param because it wasn't used
  });

  @override
  State<EditMedicineStore> createState() => _EditMedicineStoreState();
}

class _EditMedicineStoreState extends State<EditMedicineStore> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();

  DateTime? _manufactureDate;
  DateTime? _expiryDate;

  List<String> _businessNames = [];
  String? _selectedBusinessName;

  List<String> _companyNames = [];
  String? _selectedCompany;

  // Define units here - no duplicates
  final List<String> units = [
    'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
    'Gram (g)', 'Milliliter (ml)', 'Meter (m)', 'Centimeter (cm)', 'Pack',
    'Carton', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet',
    'Capsule', 'Tray', 'Barrel', 'Can', 'Jar', 'Pouch', 'Unit', 'Bundle'
  ];

  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadBusinessNames();
    _loadCompanyNames();
    _setInitialValuesIfEditing();
  }

  void _setInitialValuesIfEditing() {
    final med = widget.medicine;
    if (med != null) {
      _nameController.text = med['name'] ?? '';
      _quantityController.text = med['quantity']?.toString() ?? '';
      _priceController.text = med['price']?.toString() ?? '';
      _buyController.text = med['buy_price']?.toString() ?? '';
      _batchNumberController.text = med['batchNumber'] ?? '';
      _selectedBusinessName = med['businessName'];
      _selectedCompany = med['company'];
      _manufactureDate = med['manufactureDate'] != null && med['manufactureDate'].toString().isNotEmpty
          ? DateTime.tryParse(med['manufactureDate'])
          : null;
      _expiryDate = med['expiryDate'] != null && med['expiryDate'].toString().isNotEmpty
          ? DateTime.tryParse(med['expiryDate'])
          : null;

      // Ensure selected unit is in the list, else set null
      _selectedUnit = units.contains(med['unit']) ? med['unit'] : null;
    }
  }

  Future<void> _loadBusinessNames() async {
    List<String> names = await DatabaseHelper.instance.getBusinessNames();
    setState(() {
      _businessNames = names;
      _selectedBusinessName ??= names.isNotEmpty ? names.first : null;
    });
  }

  Future<void> _loadCompanyNames() async {
    List<String> names = await DatabaseHelper.instance.getCompanies();
    setState(() {
      _companyNames = names;
      _selectedCompany ??= names.isNotEmpty ? names.first : null;
    });
  }

  Future<void> _selectDate(BuildContext context, bool isManufactureDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isManufactureDate) {
          _manufactureDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  Future<void> _saveMedicine() async {
    if (_formKey.currentState!.validate() &&
        _manufactureDate != null &&
        _expiryDate != null) {
      String name = _nameController.text;
      String company = _selectedCompany ?? '';
      int quantity = int.parse(_quantityController.text);
      double price = double.parse(_priceController.text);
      double buy_price = double.parse(_buyController.text);
      String batchNumber = _batchNumberController.text;
      String unit = _selectedUnit ?? '';
      String addedBy = widget.user['full_name'];
      String businessName = _selectedBusinessName ?? '';
      String added_time = DateTime.now().toIso8601String();

      if (widget.medicine != null) {
        await DatabaseHelper.instance.updateMedicineInStore(
          id: widget.medicine!['id'],
          name: name,
          company: company,
          quantity: quantity,
          buy_price: buy_price,
          price: price,
          unit: unit,
          batchNumber: batchNumber,
          manufactureDate: DateFormat('yyyy-MM-dd').format(_manufactureDate!),
          expiryDate: DateFormat('yyyy-MM-dd').format(_expiryDate!),
          businessName: businessName,
          updatedAt: added_time,
          updatedBy: '', // fill as needed
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product updated successfully')),
        );
      } else {
        await DatabaseHelper.instance.addMedicineToStore(
          name: name,
          company: company,
          quantity: quantity,
          buy_price: buy_price,
          price: price,
          unit: unit,
          batchNumber: batchNumber,
          manufactureDate: DateFormat('yyyy-MM-dd').format(_manufactureDate!),
          expiryDate: DateFormat('yyyy-MM-dd').format(_expiryDate!),
          addedBy: addedBy,
          businessName: businessName,
          createdAt: added_time,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully')),
        );

        _formKey.currentState!.reset();
        _nameController.clear();
        _quantityController.clear();
        _priceController.clear();
        _buyController.clear();
        _batchNumberController.clear();

        setState(() {
          _manufactureDate = null;
          _expiryDate = null;
          _selectedUnit = null;
        });
      }
    } else {
      if (_manufactureDate == null || _expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select manufacture and expiry dates')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F6FF),
      appBar: AppBar(
        title: Text(widget.medicine != null ? 'Edit Product' : 'Add Product to Store NOW'),
        elevation: 4,
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Name TextField
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Product Name'),
                validator: (value) => value == null || value.isEmpty ? 'Please enter Product name' : null,
              ),

              const SizedBox(height: 12),

              // Company Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCompany,
                decoration: const InputDecoration(labelText: 'Company'),
                items: _companyNames
                    .map((company) => DropdownMenuItem(
                  value: company,
                  child: Text(company),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCompany = val),
                validator: (value) => value == null ? 'Please select a company' : null,
              ),

              const SizedBox(height: 12),

              // Business Name Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBusinessName,
                decoration: const InputDecoration(labelText: 'Business Name'),
                items: _businessNames
                    .map((business) => DropdownMenuItem(
                  value: business,
                  child: Text(business),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBusinessName = val),
                validator: (value) => value == null ? 'Please select a business' : null,
              ),

              const SizedBox(height: 12),

              // Quantity TextField
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter quantity';
                  if (int.tryParse(value) == null) return 'Enter valid number';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Buy Price TextField
              TextFormField(
                controller: _buyController,
                decoration: const InputDecoration(labelText: 'Buy Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter buy price';
                  if (double.tryParse(value) == null) return 'Enter valid price';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Selling Price TextField
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Selling Price'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter selling price';
                  if (double.tryParse(value) == null) return 'Enter valid price';
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Unit Dropdown
              DropdownButtonFormField<String>(
                value: _selectedUnit,
                decoration: const InputDecoration(labelText: 'Unit'),
                items: units
                    .map((unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(unit),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedUnit = val),
                validator: (value) => value == null || value.isEmpty ? 'Please select a unit' : null,
              ),

              const SizedBox(height: 12),

              // Batch Number TextField
              TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch Number'),
              ),

              const SizedBox(height: 12),

              // Manufacture Date picker
              Row(
                children: [
                  const Text('Manufacture Date:'),
                  const SizedBox(width: 10),
                  Text(_manufactureDate == null
                      ? 'Not selected'
                      : DateFormat('yyyy-MM-dd').format(_manufactureDate!)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _selectDate(context, true),
                    child: const Text('Select'),
                  )
                ],
              ),

              const SizedBox(height: 12),

              // Expiry Date picker
              Row(
                children: [
                  const Text('Expiry Date:'),
                  const SizedBox(width: 10),
                  Text(_expiryDate == null
                      ? 'Not selected'
                      : DateFormat('yyyy-MM-dd').format(_expiryDate!)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _selectDate(context, false),
                    child: const Text('Select'),
                  )
                ],
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saveMedicine,
                child: Text(widget.medicine != null ? 'Update Product' : 'Add Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
