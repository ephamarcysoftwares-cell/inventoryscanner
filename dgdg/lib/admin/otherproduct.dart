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
import '../DB/database_helper.dart';
import '../DB/sync_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtherProduct extends StatefulWidget {
  final Map<String, dynamic> user;

  OtherProduct({required this.user, required String staffId, required userName});

  @override
  _OtherProductState createState() => _OtherProductState();
}

class _OtherProductState extends State<OtherProduct> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _manufactureDateController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  // Controller ya picha
  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  String? _selectedCompany;
  String? _selectedUnit = 'Piece (pc)';
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _isNonExpired = false;
  List<String> companies = [];

  // Business Info
  String businessName = '';
  String subBusinessName = '';
  int? businessId;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    getBusinessInfo();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', widget.user['id'])
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
      debugPrint('❌ Error loading business info: $e');
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client.from('companies').select('name').order('name');
      setState(() => companies = (response as List).map((c) => c['name'].toString()).toList());
    } catch (e) {
      debugPrint("Fetch failed: $e");
    }
  }

  // --- LOGIC YA KUHIFADHI ---
  Future<void> _addMedicine() async {
    if (businessId == null) {
      _showSnackBar('Subiri, tunapakia taarifa za biashara...', Colors.orange);
      return;
    }

    String name = _nameController.text.trim();
    if (name.isEmpty || _quantityController.text.isEmpty) {
      _showSnackBar('Jaza Jina na Idadi!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String currentDT = DateTime.now().toIso8601String();
      String qrDataValue = "QR-${DateTime.now().millisecondsSinceEpoch}";

      // 1. Insert into other_product
      await supabase.from('other_product').insert({
        'name': name.toUpperCase(),
        'company': _selectedCompany ?? 'STOCK',
        'manufacture_date': _isNonExpired ? "2020-01-01" : _manufactureDateController.text,
        'expiry_date': _isNonExpired ? "2099-12-31" : _expiryDateController.text,
        'total_quantity': double.tryParse(_quantityController.text) ?? 0,
        'remaining_quantity': double.tryParse(_quantityController.text) ?? 0,
        'buy_price': double.tryParse(_buyController.text) ?? 0.0,
        'selling_price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _isNonExpired ? 'STATIONARY' : _batchNumberController.text.trim(),
        'added_by': widget.user['full_name'] ?? 'Admin',
        'unit': _selectedUnit,
        'business_id': businessId,
        'sub_business_name': subBusinessName,
        'date_added': currentDT,
        'qr_code_url': qrDataValue, // Column yako mpya
      });

      if (mounted) {
        _showQRResult(qrDataValue, name.toUpperCase());
        _resetForm();
      }
    } catch (e) {
      _showSnackBar('Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- DIALOG YA QR NA DOWNLOAD ---
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

  void _resetForm() {
    _nameController.clear(); _quantityController.clear(); _priceController.clear();
    _buyController.clear(); _batchNumberController.clear();
    _discountController.clear(); _manufactureDateController.clear(); _expiryDateController.clear();
    setState(() => _selectedCompany = null);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const Color primaryPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("TAWI: ${subBusinessName.toUpperCase()}",
            style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [primaryPurple, Color(0xFF673AB7)]),
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildInput(_nameController, "Jina la Bidhaa", Icons.shopping_bag, isDark),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(color: primaryPurple.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: SwitchListTile(
                      title: const Text("Haina Tarehe ya Expire?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Stationary, Vitabu, Vifaa n.k", style: TextStyle(fontSize: 11)),
                      value: _isNonExpired,
                      activeColor: primaryPurple,
                      onChanged: (v) => setState(() => _isNonExpired = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInput(_quantityController, "Idadi", Icons.numbers, isDark, isNumeric: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInput(_buyController, "Bei ya Kununua", Icons.wallet, isDark, isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildInput(_priceController, "Bei ya Kuuza", Icons.sell, isDark, isNumeric: true)),
                    ],
                  ),
                  if (!_isNonExpired) ...[
                    const SizedBox(height: 12),
                    _buildDatePicker(_manufactureDateController, "Manufacture Date", isDark),
                    const SizedBox(height: 12),
                    _buildDatePicker(_expiryDateController, "Expiry Date", isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator(color: primaryPurple)
                : SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: _addMedicine,
                  child: const Text("HIFADHI & TENGENEZA QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon, bool isDark, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icon, color: Colors.deepPurple, size: 20),
        filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildDatePicker(TextEditingController controller, String label, bool isDark) {
    return TextFormField(
      controller: controller, readOnly: true,
      onTap: () async {
        final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (picked != null) setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
      },
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label, prefixIcon: const Icon(Icons.calendar_today, color: Colors.deepPurple, size: 20),
        filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}