import 'dart:io';
import 'dart:typed_data'; // Kwa ajili ya picha
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Hakikisha ipo
import 'package:screenshot/screenshot.dart'; // Hakikisha ipo
import 'package:file_saver/file_saver.dart'; // Hakikisha ipo
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // Controller ya QR
  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  DateTime? _expiryDate;
  String? _selectedUnit = 'Pcs';
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _isNonExpired = true;

  int? _currentUserBusinessId;
  String business_name = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getBusinessInfo();
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
          business_name = userProfile['business_name'] ?? '';
        });
      }
    } catch (e) { debugPrint('❌ Error: $e'); }
  }

  // --- 1. DIALOG YA HAKIKI ---
  Future<void> _confirmAndSave() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackbar('Jaza Jina na Bei!', Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("HAKIKI TAARIFA"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Aina: ${_isNonExpired ? 'HUDUMA TUPU' : 'BIDHAA/MZIGO'}"),
            Text("Jina: ${_nameController.text.toUpperCase()}"),
            Text("Bei: TZS ${_priceController.text}"),
            const SizedBox(height: 10),
            const Text("QR Code itatengenezwa kwa ajili ya bidhaa hii.", style: TextStyle(fontSize: 11, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _executeSave(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("HIFADHI & QR"),
          ),
        ],
      ),
    );
  }

  // --- 2. EXECUTE SAVE ---
  Future<void> _executeSave() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      String qrDataValue = "SRV-${DateTime.now().millisecondsSinceEpoch}";

      int finalQty = (_selectedUnit == 'Service' || _isNonExpired)
          ? (int.tryParse(_quantityController.text) ?? 0)
          : (int.tryParse(_quantityController.text) ?? 1);

      String formattedExp = _isNonExpired ? "2099-12-31" :
      (_expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : "2099-12-31");

      final data = {
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
        'added_time': DateTime.now().toIso8601String(),
        'qr_code_url': qrDataValue, // Ongeza hii kwenye table yako ya services
      };

      await supabase.from('services').insert(data);

      if (mounted) {
        _showQRResult(qrDataValue, _nameController.text.toUpperCase());
        _resetForm();
      }
    } catch (e) {
      _showSnackbar('❌ Hitilafu: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. DIALOG YA QR NA DOWNLOAD ---
  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("QR TAYARI", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sehemu itakayopigwa picha (Sticker)
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                      const SizedBox(height: 10),
                      QrImageView(data: code, version: QrVersions.auto, size: 180.0),
                      const SizedBox(height: 5),
                      Text(business_name, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),
              const Divider(), // MSTARI WA KUTENGANISHA

              // --- MAELEZO ULIYOYAOMBA ---
              const Text(
                  "MUELEKEZO:",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12)
              ),
              const SizedBox(height: 5),
              const Text(
                  "Pakua picha hii kisha iprint. Bandika sticker hii kwenye bidhaa ili uweze kuiskeni Bidhaa bila kuingia kwenye mfumo wakati wa mauzo",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black87)
              ),
              // ---------------------------

              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final image = await _screenshotController.capture();
                  if (image != null) {
                    await FileSaver.instance.saveFile(
                      name: "QR_${name.replaceAll(' ', '_')}",
                      bytes: image,
                      ext: "png",
                      mimeType: MimeType.png,
                    );
                    _showSnackbar("✅ QR Imepakuliwa!", Colors.green);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("Download QR kwa Printing", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Center(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Funga", style: TextStyle(fontWeight: FontWeight.bold))
              )
          )
        ],
      ),
    );
  }

  void _resetForm() {
    _nameController.clear(); _quantityController.clear(); _priceController.clear(); _buyController.clear();
    setState(() { _expiryDate = null; });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("INGIZA HUDUMA / BIDHAA", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildModeToggle(),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E293B) : Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                children: [
                  _buildTextField(_nameController, "Jina la Huduma/Bidhaa", Icons.edit, isDark),
                  _buildTextField(_quantityController, "Idadi (Stock)", Icons.numbers, isDark, keyboard: TextInputType.number),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_buyController, "Bei ya Mtaji", Icons.shopping_cart, isDark, keyboard: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_priceController, "Bei ya Kuuza", Icons.payments, isDark, keyboard: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildUnitDropdown(isDark),
                  if (!_isNonExpired) ...[
                    const SizedBox(height: 15),
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

  // --- HELPERS ---
  Widget _buildExpiryPicker(bool isDark) {
    return ListTile(
      tileColor: Colors.red.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(_expiryDate == null ? "Chagua Tarehe ya Expiry" : "Expiry: ${DateFormat('dd-MM-yyyy').format(_expiryDate!)}", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
      trailing: const Icon(Icons.calendar_today, color: Colors.red),
      onTap: () async {
        DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 365)), firstDate: DateTime.now(), lastDate: DateTime(2100));
        if (picked != null) setState(() => _expiryDate = picked);
      },
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _isNonExpired ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _isNonExpired ? Colors.green : Colors.orange),
      ),
      child: SwitchListTile(
        title: Text(_isNonExpired ? "HUDUMA TUPU (Haina Expiry/Stock)" : "BIDHAA DUKANI (Ina Stock/Expiry)",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isNonExpired ? Colors.green[800] : Colors.orange[800])),
        value: _isNonExpired,
        onChanged: (v) => setState(() {
          _isNonExpired = v;
          if (v) _selectedUnit = "Service"; else _selectedUnit = "Pcs";
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
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20, color: Colors.deepPurple), filled: true, fillColor: isDark ? const Color(0xFF2D3748) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
      ),
    );
  }

  Widget _buildUnitDropdown(bool isDark) {
    return DropdownSearch<String>(
      items: const ["Pcs", "Service", "Box", "Litre", "KG", "Rim"],
      selectedItem: _selectedUnit,
      onChanged: (v) => setState(() => _selectedUnit = v),
      dropdownDecoratorProps: DropDownDecoratorProps(dropdownSearchDecoration: InputDecoration(labelText: "Unit", filled: true, fillColor: isDark ? const Color(0xFF2D3748) : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity, height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmAndSave,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("HIFADHI & QR CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}