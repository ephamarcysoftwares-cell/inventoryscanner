import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../../FOTTER/CurvedRainbowBar.dart';

class OtherServicesScreenAdd extends StatefulWidget {
  final Map<String, dynamic> user;

  OtherServicesScreenAdd({required this.user});

  @override
  _OtherServicesScreenAddState createState() => _OtherServicesScreenAddState();
}

class _OtherServicesScreenAddState extends State<OtherServicesScreenAdd> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _scanController = TextEditingController(); // Kwa ajili ya manual barcode kama ipo

  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  DateTime? _expiryDate;
  String? _selectedUnit = 'Pcs';
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _isNonExpired = true;
  bool _isCheckingBarcode = false;

  int? _currentUserBusinessId;
  String business_name = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getBusinessInfo();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _quantityController.dispose();
    _buyController.dispose();
    _priceController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase.from('users').select('business_id, business_name').eq('id', user.id).maybeSingle();

      if (userProfile != null && mounted) {
        setState(() {
          _currentUserBusinessId = userProfile['business_id'];
          business_name = userProfile['business_name'] ?? '1 STOCK';
        });
      }
    } catch (e) { debugPrint('❌ Error: $e'); }
  }

  // --- LOGIC: VERIFY DUPLICATE QR ---
  void _onScanChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) _checkDuplicateQR(value.trim());
    });
  }

  Future<void> _checkDuplicateQR(String code) async {
    if (_currentUserBusinessId == null) return;
    setState(() => _isCheckingBarcode = true);
    try {
      final response = await Supabase.instance.client
          .from('services')
          .select('name')
          .eq('qr_code_url', code)
          .eq('business_id', _currentUserBusinessId!)
          .maybeSingle();

      if (response != null && mounted) {
        _showDuplicateWarning(response['name'], code);
      }
    } catch (e) { debugPrint("Error checking QR: $e"); }
    finally { if (mounted) setState(() => _isCheckingBarcode = false); }
  }

  void _showDuplicateWarning(String prodName, String code) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("KODI IPO TAYARI", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text("QR '$code' inatumiwa na '$prodName'. Badilisha au futa."),
        actions: [TextButton(onPressed: () { _scanController.clear(); Navigator.pop(ctx); }, child: const Text("REKEBISHA"))],
      ),
    );
  }

  // --- LOGIC: SAVE PROCESS ---
  Future<void> _confirmAndSave() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackbar('Jaza Jina na Bei!', Colors.orange);
      return;
    }
    _executeSave();
  }

  Future<void> _executeSave() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Ikiwa scanController ni tupu, tengeneza QR mpya
      String qrDataValue = _scanController.text.trim().isEmpty
          ? "SRV-${DateTime.now().millisecondsSinceEpoch}"
          : _scanController.text.trim();

      int finalQty = int.tryParse(_quantityController.text) ?? 1;
      String formattedExp = _isNonExpired ? "2099-12-31" :
      (_expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : "2099-12-31");

      await supabase.from('services').insert({
        'name': _nameController.text.trim().toUpperCase(),
        'total_quantity': finalQty,
        'remaining_quantity': finalQty,
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'expiry_date': formattedExp,
        'added_by': widget.user['full_name'] ?? 'Admin',
        'unit': _selectedUnit,
        'business_id': _currentUserBusinessId,
        'business_name': business_name,
        'qr_code_url': qrDataValue,
      });

      if (mounted) {
        _showSnackbar("IMESAJILIWA!", Colors.green);
        _showQRResult(qrDataValue, _nameController.text.toUpperCase());
        _resetForm();
      }
    } catch (e) {
      _showSnackbar('❌ Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI: QR DIALOG (NO RENDERING ERROR) ---
  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 300, // Fixed width kuzuia Intrinsic dimensions error
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("QR CODE TAYARI", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    children: [
                      Text(name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160, width: 160,
                        child: QrImageView(data: code, version: QrVersions.auto),
                      ),
                      const SizedBox(height: 5),
                      Text(business_name, style: const TextStyle(fontSize: 8, color: Colors.black54)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text("MUELEKEZO:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11)),
              const Text("Pakua na uprint sticker hii ubandike kwenye bidhaa/huduma kwa ajili ya mauzo.",
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 10)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await _screenshotController.capture();
                  if (image != null) {
                    await FileSaver.instance.saveFile(name: "QR_${name.replaceAll(' ', '_')}", bytes: image, ext: "png");
                    _showSnackbar("✅ Imepakuliwa!", Colors.blue);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("Download QR", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Funga"))
            ],
          ),
        ),
      ),
    );
  }

  void _resetForm() {
    _nameController.clear(); _quantityController.clear(); _priceController.clear();
    _buyController.clear(); _scanController.clear();
    setState(() { _expiryDate = null; });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    const primaryColor = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("HUDUMA & BIDHAA MPYA", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryColor, Color(0xFF673AB7)]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barcode Scanner Field
            TextField(
              controller: _scanController,
              onChanged: _onScanChanged,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Scan / Ingiza Barcode (Hiyari)",
                prefixIcon: const Icon(Icons.qr_code_scanner, color: primaryColor),
                suffixIcon: _isCheckingBarcode ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                filled: true, fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            _buildModeToggle(),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]
              ),
              child: Column(
                children: [
                  _buildTextField(_nameController, "Jina la Huduma/Bidhaa", Icons.edit, isDark),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_quantityController, "Idadi (Stock)", Icons.inventory, isDark, keyboard: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildUnitDropdown(isDark)),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_buyController, "Bei ya Mtaji", Icons.account_balance_wallet, isDark, keyboard: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_priceController, "Bei ya Kuuza", Icons.payments, isDark, keyboard: TextInputType.number)),
                    ],
                  ),
                  if (!_isNonExpired) ...[
                    const SizedBox(height: 10),
                    _buildExpiryPicker(isDark),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 30),
    );
  }

  // --- WIDGET HELPERS ---
  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _isNonExpired ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _isNonExpired ? Colors.green : Colors.orange),
      ),
      child: SwitchListTile(
        title: Text(_isNonExpired ? "HUDUMA (Haina Expiry)" : "BIDHAA (Ina Stock/Expiry)",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isNonExpired ? Colors.green[800] : Colors.orange[800])),
        value: _isNonExpired,
        onChanged: (v) => setState(() {
          _isNonExpired = v;
          _selectedUnit = v ? "Service" : "Pcs";
        }),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool isDark, {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller, keyboardType: keyboard,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
            labelText: label, prefixIcon: Icon(icon, size: 20, color: Colors.deepPurple),
            filled: true, fillColor: isDark ? const Color(0xFF2D3748) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
        ),
      ),
    );
  }

  Widget _buildUnitDropdown(bool isDark) {
    return DropdownSearch<String>(
      items: const ["Pcs", "Service", "Box", "Litre", "KG", "Rim", "Set"],
      selectedItem: _selectedUnit,
      onChanged: (v) => setState(() => _selectedUnit = v),
      dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
              labelText: "Unit", filled: true,
              fillColor: isDark ? const Color(0xFF2D3748) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          )
      ),
    );
  }

  Widget _buildExpiryPicker(bool isDark) {
    return ListTile(
      tileColor: Colors.red.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(_expiryDate == null ? "Gusa kuchagua Expiry" : "Expiry: ${DateFormat('dd-MM-yyyy').format(_expiryDate!)}",
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
      trailing: const Icon(Icons.calendar_month, color: Colors.red),
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2100));
        if (picked != null) setState(() => _expiryDate = picked);
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmAndSave,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("HIFADHI & QR CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}