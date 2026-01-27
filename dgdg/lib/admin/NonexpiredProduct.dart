import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/database_helper.dart';
import '../DB/sync_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

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

  final ScreenshotController _screenshotController = ScreenshotController();

  String? _selectedCompany;
  String? _selectedUnit = 'Piece (pc)';
  bool _isLoading = false;
  List<String> companies = [];
  bool _isDarkMode = false;

  String businessName = '';
  String subBusinessName = '';
  int? businessId;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    _fetchAndSetBusinessInfo();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _fetchAndSetBusinessInfo() async {
    try {
      final userId = widget.user['id'].toString();
      final response = await Supabase.instance.client
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          businessName = response['business_name'] ?? 'STOCK & INVENTORY';
          subBusinessName = response['sub_business_name'] ?? 'Main Branch';
          businessId = response['business_id'] != null
              ? int.tryParse(response['business_id'].toString())
              : null;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching business info: $e");
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client.from('companies').select('name').order('name');
      if (response is List) {
        setState(() => companies = response.map((c) => c['name'].toString()).toList());
      }
    } catch (e) {
      debugPrint("Supabase Fetch Error: $e");
    }
  }

  Future<void> _addSparePart() async {
    if (businessId == null) {
      _showSnackBar('Inapakia taarifa za tawi... subiri.', Colors.orange);
      return;
    }

    String name = _nameController.text.trim();
    String itemCode = _itemCodeController.text.trim();
    int totalQuantity = int.tryParse(_quantityController.text.trim()) ?? 0;

    if (name.isEmpty || itemCode.isEmpty || totalQuantity <= 0) {
      _showSnackBar('Jaza Jina, Item Code na Idadi!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String currentDateTime = DateTime.now().toIso8601String();
      // Tunatumia Item Code kama QR au tunatengeneza mpya
      String qrDataValue = "QR-$itemCode-${DateTime.now().millisecondsSinceEpoch}";

      await supabase.from('medicines').insert({
        'name': name.toUpperCase(),
        'company': _selectedCompany ?? 'N/A',
        'total_quantity': totalQuantity,
        'remaining_quantity': totalQuantity,
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _partNumberController.text.trim(),
        'item_code': itemCode,
        'unit': _selectedUnit,
        'discount': double.tryParse(_discountController.text) ?? 0.0,
        'added_by': widget.user['full_name'] ?? 'Unknown',
        'business_name': businessName,
        'business_id': businessId,
        'sub_business_name': subBusinessName,
        'added_time': currentDateTime,
        'qr_code_url': qrDataValue, // Column yako mpya
      });

      if (mounted) {
        _showQRResult(qrDataValue, name.toUpperCase());
        _resetFormFields();
      }
    } catch (e) {
      _showSnackBar('Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("QR CODE TAYARI", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                      const SizedBox(height: 10),
                      QrImageView(data: code, version: QrVersions.auto, size: 200.0),
                      const SizedBox(height: 8),
                      Text(subBusinessName, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Divider(),
              const Text("MUELEKEZO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
              const Text("Pakua picha hii kisha iprint. Bandika sticker hii kwenye bidhaa ili uweze kuiskeni Bidhaa bila kuingia kwenye mfumo wakati wa mauzo", textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await _screenshotController.capture();
                  if (image != null) {
                    await FileSaver.instance.saveFile(
                      name: "QR_${name.replaceAll(' ', '_')}",
                      bytes: image, ext: "png", mimeType: MimeType.png,
                    );
                    _showSnackBar("✅ QR Imepakuliwa!", Colors.green);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("PAKUA KWA AJILI YA KUPRINT", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20)),
              ),
            ],
          ),
        ),
        actions: [
          Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Funga & Endelea")))
        ],
      ),
    );
  }

  void _resetFormFields() {
    _nameController.clear(); _quantityController.clear(); _priceController.clear();
    _buyController.clear(); _partNumberController.clear(); _itemCodeController.clear();
    _discountController.clear();
    setState(() => _selectedCompany = null);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    const Color primaryPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(businessName.isEmpty ? "PAKIA TAARIFA..." : "TAWI: ${subBusinessName.toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryPurple, Color(0xFF673AB7)]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                ? const CircularProgressIndicator(color: primaryPurple)
                : SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _addSparePart,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("HIFADHI & TENGENEZA QR", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- HELPERS ---
  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType? keyboardType, required bool isDark, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple, size: 20) : null,
          labelText: label, filled: true,
          fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        items: companies, selectedItem: _selectedCompany,
        onChanged: (val) => setState(() => _selectedCompany = val),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(labelText: "Brand / Kampuni", filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
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
          dropdownSearchDecoration: InputDecoration(labelText: "Unit (Kipimo)", filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
      ),
    );
  }
}