import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import '../DB/sync_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddNonExpiredProduct extends StatefulWidget {
  final Map<String, dynamic> user;

  AddNonExpiredProduct({required this.user});

  @override
  _AddNonExpiredProductState createState() => _AddNonExpiredProductState();
}

class _AddNonExpiredProductState extends State<AddNonExpiredProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _partNumberController = TextEditingController();
  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  String? _selectedCompany;
  String? _selectedUnit = 'Piece (pc)';
  bool _isLoading = false;
  List<String> companies = [];
  bool _isDarkMode = false;
  String businessName = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    _fetchAndSetBusinessName();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _fetchAndSetBusinessName() async {
    try {
      final userId = widget.user['id'].toString();
      final response = await Supabase.instance.client
          .from('users')
          .select('business_name')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          businessName = response['business_name'] ?? 'STOCK & INVENTORY';
        });
      }
    } catch (e) {
      if (mounted) setState(() => businessName = "STOCK & INVENTORY");
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client
          .from('companies')
          .select('name')
          .order('name', ascending: true);

      if (response is List) {
        setState(() {
          companies = response.map((c) => c['name'].toString()).toList();
        });
      }
    } catch (e) {
      debugPrint("Supabase Fetch Error: $e");
    }
  }

  Future<void> _addSparePart() async {
    setState(() => _isLoading = true);

    String name = _nameController.text.trim();
    String company = _selectedCompany ?? 'N/A';
    int totalQuantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    double buy = double.tryParse(_buyController.text.trim()) ?? 0.0;
    double price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    String partNumber = _partNumberController.text.trim();
    String itemCode = _itemCodeController.text.trim();
    String addedBy = widget.user['full_name'] ?? 'Unknown';
    double discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    String unit = _selectedUnit ?? 'Piece (pc)';

    if (name.isEmpty || partNumber.isEmpty || itemCode.isEmpty || totalQuantity <= 0) {
      _showSnackBar('Jaza Jina, Part Number, Item Code na Idadi!', Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      String currentDateTime = DateTime.now().toIso8601String();

      /// INSERT MAIN TABLE
      await supabase.from('medicines').insert({
        'name': name,
        'company': company,
        'total_quantity': totalQuantity,
        'remaining_quantity': totalQuantity,
        'buy': buy,
        'price': price,
        'batch_number': partNumber,
        'item_code': itemCode,
        'unit': unit,
        'discount': discount,
        'added_by': addedBy,
        'business_name': businessName,
        'added_time': currentDateTime,
      });

      /// INSERT LOG TABLE
      await supabase.from('medical_logs').insert({
        'medicine_name': name,
        'company': company,
        'total_quantity': totalQuantity,          // ✅ INT
        'remaining_quantity': totalQuantity.toDouble(), // ✅ NUMERIC
        'buy_price': buy,                         // ✅ NUMERIC
        'selling_price': price,                  // ✅ NUMERIC
        'batch_number': partNumber,
        'item_code': itemCode,
        'unit': unit,
        'discount': discount,
        'added_by': addedBy,
        'business_name': businessName,
        'action': 'Added Spare: $partNumber',
        'date_added': currentDateTime,
        'synced': true,
      });

      _showSnackBar('Data imehifadhiwa!', Colors.green);
      _resetFormFields();
    } catch (e) {
      _showSnackBar('Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  void _resetFormFields() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _buyController.clear();
    _partNumberController.clear();
    _itemCodeController.clear();
    _discountController.clear();
    setState(() => _selectedCompany = null);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          businessName.isEmpty ? "BRANCH: PAKIA..." : "BRANCH: ${businessName.toUpperCase()}",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)]),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildTextField(controller: _itemCodeController, label: "Item Code (Kodi)", isDark: isDark, icon: Icons.qr_code),
                  _buildTextField(controller: _partNumberController, label: "Part Number", isDark: isDark, icon: Icons.settings_input_component),
                  _buildTextField(controller: _nameController, label: "Jina la kifaa (Item Name)", isDark: isDark, icon: Icons.build),

                  _buildDropdown(isDark: isDark),

                  _buildTextField(controller: _quantityController, label: "Idadi (Quantity)", keyboardType: TextInputType.number, isDark: isDark, icon: Icons.inventory),

                  // MSTARI WA BEI - Expanded inazuia kosa la Overflow
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: _buyController, label: "Bei Kununua", keyboardType: TextInputType.number, isDark: isDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(controller: _priceController, label: "Bei Kuuza", keyboardType: TextInputType.number, isDark: isDark)),
                    ],
                  ),

                  _buildTextField(controller: _discountController, label: "Punguzo (Discount %)", keyboardType: TextInputType.number, isDark: isDark, icon: Icons.percent),

                  _buildUnitDropdown(isDark: isDark),
                ],
              ),
            ),
            const SizedBox(height: 25),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _addSparePart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("HIFADHI DATA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType? keyboardType, required bool isDark, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.white70 : Colors.blueGrey, size: 20) : null,
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontSize: 13),
          filled: true,
          fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        items: companies, // Hapa inakubali List moja kwa moja
        selectedItem: _selectedCompany,
        onChanged: (val) => setState(() => _selectedCompany = val),
        dropdownDecoratorProps: DropDownDecoratorProps( // Hapa tunatumia dropdownDecoratorProps
          baseStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
          dropdownSearchDecoration: InputDecoration(
            labelText: "Brand / Kampuni",
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontSize: 13),
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        items: const ['Piece (pc)', 'Set', 'Box', 'Pair', 'KG', 'Litre'],
        selectedItem: _selectedUnit,
        onChanged: (val) => setState(() => _selectedUnit = val),
        dropdownDecoratorProps: DropDownDecoratorProps(
          baseStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
          dropdownSearchDecoration: InputDecoration(
            labelText: "Unit (Kipimo)",
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.blueGrey, fontSize: 13),
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        ),
      ),
    );
  }
}