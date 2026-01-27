import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class AddNonExpiredProduct extends StatefulWidget {
  final Map<String, dynamic> user;

  AddNonExpiredProduct({required this.user});

  @override
  _AddNonExpiredProductState createState() => _AddNonExpiredProductState();
}

class _AddNonExpiredProductState extends State<AddNonExpiredProduct> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _partNumberController = TextEditingController();
  final TextEditingController _itemCodeController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  String? _selectedCompany;
  String? _selectedUnit = 'Piece (pc)';
  bool _isLoading = false;
  List<String> companies = [];
  bool _isDarkMode = false;
  bool _isCheckingCode = false;

  String businessName = '';
  String subBusinessName = '';
  int? businessId;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    _fetchAndSetBusinessInfo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _quantityController.dispose();
    _buyController.dispose();
    _priceController.dispose();
    _partNumberController.dispose();
    _itemCodeController.dispose();
    _discountController.dispose();
    super.dispose();
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
      debugPrint("❌ Error: $e");
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client.from('companies').select('name').order('name');
      if (response is List) {
        setState(() => companies = response.map((c) => c['name'].toString()).toList());
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
  }

  // --- LOGIC: VERIFY DUPLICATE CODE ---
  void _onCodeChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) _checkDuplicateCode(value.trim());
    });
  }

  Future<void> _checkDuplicateCode(String code) async {
    if (businessId == null) return;
    setState(() => _isCheckingCode = true);
    try {
      final response = await Supabase.instance.client
          .from('medicines')
          .select('name')
          .eq('item_code', code)
          .eq('business_id', businessId!)
          .maybeSingle();

      if (response != null && mounted) {
        _showDuplicateWarning(response['name'], code);
      }
    } catch (e) { debugPrint("Error: $e"); }
    finally { if (mounted) setState(() => _isCheckingCode = false); }
  }

  void _showDuplicateWarning(String prodName, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("ITEM CODE IPO TAYARI", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("Kodi '$code' tayari inatumiwa na bidhaa: '$prodName'"),
        actions: [TextButton(onPressed: () { _itemCodeController.clear(); Navigator.pop(ctx); }, child: const Text("BADILISHA"))],
      ),
    );
  }

  // --- LOGIC: SAVE PROCESS ---
  Future<void> _addSparePart() async {
    if (businessId == null) {
      _showSnackBar('Inapakia taarifa za tawi...', Colors.orange);
      return;
    }

    if (_nameController.text.isEmpty || _itemCodeController.text.isEmpty || _quantityController.text.isEmpty) {
      _showSnackBar('Jaza Jina, Item Code na Idadi!', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String itemCode = _itemCodeController.text.trim();
      String qrDataValue = "QR-$itemCode-${DateTime.now().millisecondsSinceEpoch}";
      int totalQuantity = int.tryParse(_quantityController.text.trim()) ?? 0;

      await supabase.from('medicines').insert({
        'name': _nameController.text.trim().toUpperCase(),
        'company': _selectedCompany ?? 'GENERAL',
        'total_quantity': totalQuantity,
        'remaining_quantity': totalQuantity,
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _partNumberController.text.trim().isEmpty ? 'N/A' : _partNumberController.text.trim(),
        'item_code': itemCode,
        'unit': _selectedUnit,
        'discount': double.tryParse(_discountController.text) ?? 0.0,
        'added_by': widget.user['full_name'] ?? 'Admin',
        'business_name': businessName,
        'business_id': businessId,
        'sub_business_name': subBusinessName,
        'added_time': DateTime.now().toIso8601String(),
        'qr_code_url': qrDataValue,
        'expiry_date': '2099-12-31', // Kwa kuwa ni Non-Expired
      });

      if (mounted) {
        _showSnackBar("IMEHIFADHIWA!", Colors.green);
        _showQRResult(qrDataValue, _nameController.text.toUpperCase());
        _resetFormFields();
      }
    } catch (e) {
      _showSnackBar('Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI: QR DIALOG (FIXED RENDERING) ---
  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 300, // Fixed Width
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("QR CODE TAYARI", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  width: 220,
                  color: Colors.white,
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 150, width: 150,
                        child: QrImageView(data: code, version: QrVersions.auto),
                      ),
                      const SizedBox(height: 5),
                      Text(subBusinessName, style: const TextStyle(fontSize: 8, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("MUELEKEZO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
              const Text("Pakua kisha iprint sticker hii uibandike kwenye kifaa kwa ajili ya mauzo ya haraka.",
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await _screenshotController.capture();
                  if (image != null) {
                    await FileSaver.instance.saveFile(name: "QR_${name.replaceAll(' ', '_')}", bytes: image, ext: "png");
                    _showSnackBar("✅ Imepakuliwa!", Colors.blue);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("PAKUA KWA PRINTING", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Funga & Endelea"))
            ],
          ),
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    const Color primaryPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(businessName.isEmpty ? "PAKIA TAARIFA..." : "TAWI: ${subBusinessName.toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        centerTitle: true,
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
                  _buildTextField(
                      controller: _itemCodeController,
                      label: "Item Code / Barcode",
                      isDark: isDark, icon: Icons.qr_code,
                      onChanged: _onCodeChanged,
                      suffix: _isCheckingCode ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null
                  ),
                  _buildTextField(controller: _partNumberController, label: "Part Number", isDark: isDark, icon: Icons.settings),
                  _buildTextField(controller: _nameController, label: "Jina la Kifaa", isDark: isDark, icon: Icons.build),
                  _buildDropdown(isDark: isDark),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: _quantityController, label: "Idadi", keyboardType: TextInputType.number, isDark: isDark, icon: Icons.inventory)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildUnitDropdown(isDark: isDark)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: _buyController, label: "Bei Kununua", keyboardType: TextInputType.number, isDark: isDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(controller: _priceController, label: "Bei Kuuza", keyboardType: TextInputType.number, isDark: isDark)),
                    ],
                  ),
                  _buildTextField(controller: _discountController, label: "Punguzo (Discount %)", keyboardType: TextInputType.number, isDark: isDark, icon: Icons.percent),
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
                child: const Text("HIFADHI & QR CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 35),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType? keyboardType, required bool isDark, IconData? icon, Function(String)? onChanged, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller, keyboardType: keyboardType, onChanged: onChanged,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple, size: 20) : null,
          suffixIcon: suffix,
          labelText: label, filled: true,
          fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
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
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownSearch<String>(
        items: const ['Piece (pc)', 'Set', 'Box', 'Pair', 'KG', 'Litre'],
        selectedItem: _selectedUnit,
        onChanged: (val) => setState(() => _selectedUnit = val),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(labelText: "Unit", filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
      ),
    );
  }
}