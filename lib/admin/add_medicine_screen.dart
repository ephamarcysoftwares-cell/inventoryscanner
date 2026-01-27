import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';

import '../../FOTTER/CurvedRainbowBar.dart';

/// **************************************************************************
/// SCREEN: AddMedicineScreen
/// PROJECT: 1 STOCK ONLINE STORE - ARUSHA
/// DESCRIPTION: Inaruhusu kuongeza bidhaa, kuskani barcode,
///              na kuhakiki kama bidhaa tayari ipo ili kuzuia duplicate.
/// **************************************************************************

class AddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  AddMedicineScreen({required this.user});

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  // --------------------------------------------------------------------------
  // CONTROLLERS & KEYS
  // --------------------------------------------------------------------------
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _scanController = TextEditingController();

  final ScreenshotController _screenshotController = ScreenshotController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // --------------------------------------------------------------------------
  // STATE VARIABLES
  // --------------------------------------------------------------------------
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  String? _selectedCompany;
  String? _selectedUnit = 'Pcs';

  bool _isLoading = false;
  bool _isCheckingBarcode = false;
  bool _isDarkMode = false;
  bool _isNonExpired = false;

  List<String> companies = [];
  Timer? _debounce;

  // Business Information (Fetched from database)
  String business_name = '1 STOCK';
  String sub_business_name = 'Main Branch';
  int? business_id;

  // --------------------------------------------------------------------------
  // INITIALIZATION
  // --------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadThemeSettings();
    _fetchCompanyList();
    _getDetailedBusinessInfo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _quantityController.dispose();
    _buyController.dispose();
    _priceController.dispose();
    _batchNumberController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // THEME & BUSINESS LOGIC
  // --------------------------------------------------------------------------
  Future<void> _loadThemeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isDarkMode = prefs.getBool('darkMode') ?? false;
      });
    }
  }

  Future<void> _getDetailedBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', widget.user['id'])
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          business_name = response['business_name']?.toString() ?? 'ONLINE STORE';
          sub_business_name = response['sub_business_name']?.toString() ?? ' ';
          business_id = int.tryParse(response['business_id'].toString());
        });
      }
    } catch (e) {
      debugPrint('Error Fetching Business Info: $e');
    }
  }

  Future<void> _fetchCompanyList() async {
    try {
      final response = await Supabase.instance.client
          .from('companies')
          .select('name')
          .order('name');

      if (mounted) {
        setState(() {
          companies = List<String>.from(response.map((e) => e['name']));
        });
      }
    } catch (e) {
      debugPrint("Company fetch error: $e");
    }
  }

  // --------------------------------------------------------------------------
  // AUTOMATIC SCANNER LOGIC (DEBOUNCE)
  // --------------------------------------------------------------------------
  void _handleBarcodeScan(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Inasubiri milliseconds 600 scanner imalize kuandika
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) {
        _verifyBarcodeUniqueness(value.trim());
      }
    });
  }

  /// Inakagua kama barcode ipo. Inatumia List badala ya maybeSingle
  /// ili kuzuia error ya "Multiple rows returned" (Postgrest 406).
  Future<void> _verifyBarcodeUniqueness(String code) async {
    if (business_id == null) return;

    setState(() => _isCheckingBarcode = true);

    try {
      final supabase = Supabase.instance.client;
      final List<dynamic> response = await supabase
          .from('medicines')
          .select('name')
          .eq('qr_code_url', code)
          .eq('business_id', business_id!);

      if (response.isNotEmpty && mounted) {
        // Ikiwa ipo, chukua jina la kwanza lililopatikana
        String existingProductName = response[0]['name'];
        _showDuplicateFoundDialog(existingProductName, code);
      }
    } catch (e) {
      debugPrint("Verification Error: $e");
    } finally {
      if (mounted) setState(() => _isCheckingBarcode = false);
    }
  }

  void _showDuplicateFoundDialog(String productName, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text("BIDHAA IPO TAYARI", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Barcode unayojaribu kusajili tayari inatumika na bidhaa nyingine katika mfumo wako."),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Kodi: $code", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("Inamilikiwa na: ${productName.toUpperCase()}",
                      style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              _scanController.clear();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SAWA, NITABADILISHA", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // DATABASE SAVE OPERATION
  // --------------------------------------------------------------------------
  Future<void> _validateAndConfirm() async {
    if (_nameController.text.isEmpty) {
      _showCustomSnackbar("Tafadhali ingiza jina la bidhaa!", Colors.orange);
      return;
    }
    if (_priceController.text.isEmpty) {
      _showCustomSnackbar("Tafadhali weka bei ya kuuza!", Colors.orange);
      return;
    }
    if (!_isNonExpired && _expiryDate == null) {
      _showCustomSnackbar("Tafadhali chagua tarehe ya expiry!", Colors.orange);
      return;
    }

    _showConfirmationBottomSheet();
  }

  void _showConfirmationBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("HAKIKI TAARIFA ZA MWISHO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            ListTile(title: const Text("Bidhaa"), trailing: Text(_nameController.text.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))),
            ListTile(title: const Text("Bei ya Kuuza"), trailing: Text("TZS ${_priceController.text}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
            ListTile(title: const Text("Barcode"), trailing: Text(_scanController.text.isEmpty ? "Itazalishwa" : _scanController.text)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _saveToDatabase();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("NIMEHAKIKI - HIFADHI SASA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
  Future<void> _saveToDatabase() async {
    setState(() => _isLoading = true);

    // 1. Kutengeneza data ya Debug
    debugPrint("🚀 ANZA: Mchakato wa kuhifadhi umeanza...");

    try {
      final supabase = Supabase.instance.client;

      // --- LOGIC YA AUTOMATIC NULL ---
      // Hii inahakikisha kama tawi ni neno 'NULL' au tupu, database inapokea NULL halisi
      dynamic finalSubBusiness = (sub_business_name == null ||
          sub_business_name.toString().trim().isEmpty ||
          sub_business_name.toString().toUpperCase() == 'NULL')
          ? null
          : sub_business_name.toString().trim();

      String finalQRCode = _scanController.text.trim().isEmpty
          ? "QR-${DateTime.now().millisecondsSinceEpoch}"
          : _scanController.text.trim();

      String productName = _nameController.text.trim().toUpperCase();

      // 2. Map ya Data inayokwenda Supabase
      final Map<String, dynamic> dataToInsert = {
        'name': productName,
        'company': _isNonExpired ? 'STOCK' : (_selectedCompany ?? 'N/A'),
        'total_quantity': int.tryParse(_quantityController.text) ?? 0,
        'remaining_quantity': int.tryParse(_quantityController.text) ?? 0,
        'business_id': int.tryParse(business_id.toString()),
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'discount': 0,
        'batch_number': _isNonExpired ? 'SERVICE' : _batchNumberController.text.trim(),
        'manufacture_date': _manufactureDate != null ? DateFormat('yyyy-MM-dd').format(_manufactureDate!) : null,
        'expiry_date': _isNonExpired ? "2099-12-31" : (_expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : null),
        'added_by': widget.user['full_name'] ?? 'Admin',
        'unit': _selectedUnit,
        'business_name': business_name,
        'sub_business_name': finalSubBusiness, // ✅ Inatumia NULL halisi hapa
        'added_time': DateTime.now().toIso8601String(),
        'qr_code_url': finalQRCode,
        'synced': false,
      };

      debugPrint("📦 DATA INAYOTUMWA: $dataToInsert");

      // 3. Kufanya insertion kule Supabase
      // Trigger yako ya 'trg_auto_clean_sub_business' itasafisha zaidi kama kuna kosa limebaki
      final response = await supabase.from('medicines').insert(dataToInsert).select();

      debugPrint("✅ MAFANIKIO: Data imehifadhiwa Supabase: $response");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "IMESAJILIWA: $productName imewekwa tayari!",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[800],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _clearAllFields(); // Hakikisha function hii ipo kusafisha form
      }
    } catch (e) {
      debugPrint("❌ HITILAFU (Database Error): $e");
      _showCustomSnackbar("Kuna Hitilafu: $e", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("🏁 MWISHO: Mchakato umekamilika.");
      }
    }
  }
  // --------------------------------------------------------------------------
  // SUCCESS & RESULT VIEW
  // --------------------------------------------------------------------------
  void _showSuccessAnimation(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Tumetumia SingleChildScrollView ndani ya AlertDialog kuzuia overflow
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 10),
              const Text("IMESAJILIWA TAYARI!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),

              // REKEBISHO KUU: SizedBox yenye Fixed Width/Height
              SizedBox(
                width: 250, // Lazima iwe na size maalumu
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 10),
                        // REKEBISHO: QrImageView pia iwe na size yake
                        QrImageView(
                          data: code,
                          size: 150.0,
                          version: QrVersions.auto,
                          gapless: false,
                        ),
                        const SizedBox(height: 5),
                        Text(business_name,
                            style: const TextStyle(color: Colors.black54, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Capture na Save
                    final img = await _screenshotController.capture();
                    if (img != null) {
                      await FileSaver.instance.saveFile(
                          name: "QR_${name.replaceAll(' ', '_')}",
                          bytes: img,
                          ext: "png"
                      );
                      _showCustomSnackbar("✅ QR Imehifadhiwa!", Colors.green);
                    }
                  },
                  icon: const Icon(Icons.download, size: 18, color: Colors.white),
                  label: const Text("PAKUA QR", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                ),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("FUNGA DIRISHA", style: TextStyle(color: Colors.red))
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearAllFields() {
    _nameController.clear();
    _quantityController.clear();
    _buyController.clear();
    _priceController.clear();
    _batchNumberController.clear();
    _scanController.clear();
    setState(() {
      _manufactureDate = null;
      _expiryDate = null;
    });
  }

  void _showCustomSnackbar(String message, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        )
    );
  }

  // --------------------------------------------------------------------------
  // UI BUILDING BLOCKS
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
            "SAJILI BIDHAA MPYA",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white
            )
        ),
        centerTitle: true,
        // Changed from dark gray to a professional Blue
        backgroundColor: Colors.blue[800],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // Ensures back button & icons are white
        actions: [
          IconButton(
            icon: Icon(
              _isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Column(
          children: [
            _buildHeaderToggle(isDark),
            const SizedBox(height: 20),

            // GATEWAY YA SCANNER
            _buildScannerInputArea(isDark),
            const SizedBox(height: 20),

            // FOMU KUU
            _buildMainInventoryForm(isDark),

            const SizedBox(height: 40),

            // KITUFE CHA HIFADHI
            _isLoading
                ? const CircularProgressIndicator(color: Colors.blue)
                : _buildSubmitButton(),

            const SizedBox(height: 100), // Nafasi ya chini
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 45),
    );
  }

  Widget _buildHeaderToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isNonExpired ? Colors.orange.withOpacity(0.15) : Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _isNonExpired ? Colors.orange : Colors.blue, width: 1.5),
      ),
      child: SwitchListTile(
        title: Text(_isNonExpired ? "MODI: HUDUMA / STATIONARY" : "MODI: BIDHAA /KAMA DAWA",
            style: TextStyle(fontWeight: FontWeight.bold, color: _isNonExpired ? Colors.orange[900] : Colors.blue[900], fontSize: 13)),
        subtitle: const Text("Washa kama bidhaa haina tarehe ya mwisho (Expiry)", style: TextStyle(fontSize: 10)),
        secondary: Icon(_isNonExpired ? Icons.miscellaneous_services : Icons.medication, color: _isNonExpired ? Colors.orange : Colors.blue),
        value: _isNonExpired,
        onChanged: (v) => setState(() => _isNonExpired = v),
        activeColor: Colors.orange,
      ),
    );
  }

  Widget _buildScannerInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.qr_code_scanner, color: Colors.blue, size: 20),
              const SizedBox(width: 10),
              const Text("HATUA YA 1: SKENI BARCODE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)),
              const Spacer(),
              if (_isCheckingBarcode)
                const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _scanController,
            autofocus: true,
            onChanged: _handleBarcodeScan,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Skeni bidhaa hapa...",
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.blue.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: _scanController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _scanController.clear()))
                  : null,
            ),
          ),
          if (_scanController.text.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text("* Ikiwa huna barcode, mfumo utazalisha QR Code yenyewe.", style: TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildMainInventoryForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("HATUA YA 2: MAELEZO YA BIDHAA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 15),

          _customTextField(_nameController, "Jina la Bidhaa / Dawa", Icons.edit_note, isDark),

          if (!_isNonExpired) _buildCompanySelector(isDark),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _customTextField(_quantityController, "Idadi (Stock)", Icons.inventory_2, isDark, type: TextInputType.number)),
              const SizedBox(width: 15),
              Expanded(child: _customTextField(_priceController, "Bei ya Kuuza", Icons.payments, isDark, type: TextInputType.number)),
            ],
          ),

          if (!_isNonExpired) ...[
            _customTextField(_buyController, "Bei ya Kununua", Icons.shopping_cart_checkout, isDark, type: TextInputType.number),
            _customTextField(_batchNumberController, "Batch Number", Icons.numbers, isDark),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildDatePicker("MFG Date", _manufactureDate, (d) => setState(() => _manufactureDate = d), isDark)),
                const SizedBox(width: 10),
                Expanded(child: _buildDatePicker("EXP Date", _expiryDate, (d) => setState(() => _expiryDate = d), isDark, isExpiry: true)),
              ],
            ),
          ],

          const SizedBox(height: 20),
          _buildUnitSelector(isDark),
        ],
      ),
    );
  }

  Widget _customTextField(TextEditingController controller, String label, IconData icon, bool isDark, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.blueGrey),
          labelStyle: const TextStyle(fontSize: 13),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildCompanySelector(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownSearch<String>(
        items: companies,
        onChanged: (v) => setState(() => _selectedCompany = v),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: "Chagua Kampuni / Kiwanda",
            prefixIcon: const Icon(Icons.business, size: 20),
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(decoration: InputDecoration(hintText: "Tafuta kampuni...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        ),
      ),
    );
  }

  Widget _buildUnitSelector(bool isDark) {
    return DropdownSearch<String>(
      items: const ["Pcs", "Box", "Litre", "KG", "Service", "Strip", "Bottle"],
      selectedItem: _selectedUnit,
      onChanged: (v) => setState(() => _selectedUnit = v),
      dropdownDecoratorProps: DropDownDecoratorProps(
        dropdownSearchDecoration: InputDecoration(
          labelText: "Unit / Kipimo",
          prefixIcon: const Icon(Icons.scale, size: 20),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onPicked, bool isDark, {bool isExpiry = false}) {
    return GestureDetector(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(data: isDark ? ThemeData.dark() : ThemeData.light(), child: child!),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: isExpiry && date == null ? Colors.red.withOpacity(0.5) : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: isExpiry ? Colors.red : Colors.grey),
            const SizedBox(width: 8),
            Text(
              date == null ? label : DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(fontSize: 11, fontWeight: date != null ? FontWeight.bold : FontWeight.normal, color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: (business_id == null || _isCheckingBarcode) ? null : _validateAndConfirm,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: const Text("HIFADHI KWENYE MFUMO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
      ),
    );
  }
}

/// **************************************************************************
/// END OF CODE
/// **************************************************************************