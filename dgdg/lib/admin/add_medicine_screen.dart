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

import '../../FOTTER/CurvedRainbowBar.dart';

class AddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  AddMedicineScreen({required this.user});

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();

  // Screenshot Controller kwa ajili ya kupakua picha
  final ScreenshotController _screenshotController = ScreenshotController();

  // State Variables
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  String? _selectedCompany;
  String? _selectedUnit = 'Pcs';
  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _isNonExpired = false;
  List<String> companies = [];

  // Business Data
  String business_name = '';
  String sub_business_name = '';
  int? business_id;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    _getBusinessInfo();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', widget.user['id'])
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          business_name = response['business_name']?.toString() ?? '';
          sub_business_name = response['sub_business_name']?.toString() ?? 'Main Branch';
          business_id = int.tryParse(response['business_id'].toString());
        });
      }
    } catch (e) {
      debugPrint('❌ Error Fetching Business Info: $e');
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client.from('companies').select('name').order('name');
      setState(() => companies = List<String>.from(response.map((e) => e['name'])));
    } catch (e) {
      debugPrint("⚠️ Companies fetch error: $e");
    }
  }

  // --- LOGIC YA KUPAKUA ---
  // Future<void> _downloadQR(String name) async {
  //   try {
  //     final Uint8List? image = await _screenshotController.capture();
  //
  //     if (image != null) {
  //       String fileName = "${name.replaceAll(' ', '_')}_QR";
  //       await FileSaver.instance.saveFile(
  //         name: fileName,
  //         bytes: image,
  //         ext: "png",
  //         mimeType: MimeType.png,
  //       );
  //       _showSnackbar("✅ QR Code imepakuliwa!", Colors.green);
  //     }
  //   } catch (e) {
  //     _showSnackbar("❌ Kushindwa kupakua: $e", Colors.red);
  //   }
  // }

  // --- 1. DIALOG YA HAKIKI ---
  Future<void> _confirmAndSave() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      _showSnackbar('Tafadhali jaza Jina na Bei!', Colors.red);
      return;
    }
    if (!_isNonExpired && _expiryDate == null) {
      _showSnackbar('Tafadhali chagua Tarehe ya Expire!', Colors.red);
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
            Text("Bidhaa: ${_nameController.text.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Bei: TZS ${_priceController.text}"),
            Text("Modi: ${_isNonExpired ? 'HUDUMA' : 'BIDHAA'}"),
            const SizedBox(height: 10),
            const Text("QR Code itatengenezwa na kuhifadhiwa."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeSave();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("HIFADHI & QR"),
          ),
        ],
      ),
    );
  }

  // --- 2. LOGIC YA KUHIFADHI ---
  Future<void> _executeSave() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      String formattedExp = _isNonExpired ? "2099-12-31" : DateFormat('yyyy-MM-dd').format(_expiryDate!);
      String? formattedMfg = _manufactureDate != null ? DateFormat('yyyy-MM-dd').format(_manufactureDate!) : null;
      String currentTime = DateTime.now().toIso8601String();

      // Data ya QR
      String qrDataValue = "QR-${DateTime.now().millisecondsSinceEpoch}";

      await supabase.from('medicines').insert({
        'name': _nameController.text.trim().toUpperCase(),
        'company': _isNonExpired ? 'STOCK' : (_selectedCompany ?? 'N/A'),
        'total_quantity': int.tryParse(_quantityController.text) ?? 1,
        'remaining_quantity': int.tryParse(_quantityController.text) ?? 1,
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _isNonExpired ? 'SERVICE' : _batchNumberController.text.trim(),
        'manufacture_date': formattedMfg,
        'expiry_date': formattedExp,
        'added_by': widget.user['full_name'] ?? 'Admin',
        'unit': _selectedUnit,
        'business_name': business_name,
        'business_id': business_id,
        'sub_business_name': sub_business_name,
        'added_time': currentTime,
        'qr_code_url': qrDataValue, // <--- Tunatumia hii pekee
      });

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

  // --- 3. DIALOG YA QR CODE (KWA COMPUTER) ---
// 1. Hakikisha hii controller ipo nje ya function (juu ya class yako)


  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("QR CODE TAYARI", textAlign: TextAlign.center),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eneo hili ndilo linapigwa picha kwa ajili ya kudownload
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white, // Inahakikisha picha inayopakuliwa ina background nyeupe
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      QrImageView(
                        data: code, // Hii sasa inatoka kwenye qr_code_url
                        version: QrVersions.auto,
                        size: 180.0,
                        gapless: false,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        business_name,
                        style: const TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // MAELEZO KWA MTUMIAJI
              const Divider(),
              const Text(
                "MAELEKEZO:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Pakua picha hii kisha iprint. Bandika sticker hii kwenye bidhaa ili uweze kuiskeni Bidhaa bila kuingia kwenye mfumo wakati wa mauzo.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.black87),
                ),
              ),
              Text(
                "QR URL: $code",
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
              ),

              const SizedBox(height: 20),

              // --- KITUFE CHA KUDOWNLOAD (COMPUTER VERSION) ---
              ElevatedButton.icon(
                onPressed: () async {
                  final Uint8List? image = await _screenshotController.capture();
                  if (image != null) {
                    // Inasave file kwenye folda ya Downloads ya Computer
                     (
                      name: "QR_${name.replaceAll(' ', '_')}",
                      bytes: image,
                      ext: "png",

                    );
                    _showSnackbar("✅ Picha ya QR imehifadhiwa!", Colors.green);
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text("PAKUA KWA AJILI YA KUPRINT", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Funga Dirisha", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  void _resetForm() {
    _nameController.clear(); _quantityController.clear(); _priceController.clear();
    _buyController.clear(); _batchNumberController.clear();
    setState(() { _manufactureDate = null; _expiryDate = null; });
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
        title: const Text(
          "INGIZA BIDHAA & QR",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white, // Inafanya maandishi yawe meupe
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF311B92),
        iconTheme: const IconThemeData(color: Colors.white), // Inafanya kishale cha kurudi kiwe cheupe
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
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
                  _buildTextField(_nameController, "Jina la Bidhaa", Icons.edit, isDark),
                  if (!_isNonExpired) _buildCompanyDropdown(isDark),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_quantityController, "Idadi", Icons.add_box, isDark, keyboard: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_priceController, "Bei ya Kuuza", Icons.sell, isDark, keyboard: TextInputType.number)),
                    ],
                  ),
                  if (!_isNonExpired) ...[
                    _buildTextField(_buyController, "Bei ya Kununua", Icons.account_balance_wallet, isDark, keyboard: TextInputType.number),
                    _buildTextField(_batchNumberController, "Batch Number", Icons.qr_code_2, isDark),
                    Row(
                      children: [
                        Expanded(child: _dateBtn("MFG Date", _manufactureDate, (d) => setState(() => _manufactureDate = d), isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _dateBtn("EXP Date", _expiryDate, (d) => setState(() => _expiryDate = d), isDark, isExp: true)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildUnitDropdown(isDark),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: business_id == null ? null : _confirmAndSave,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("HIFADHI & QR CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
          color: _isNonExpired ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _isNonExpired ? Colors.orange : Colors.blue)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_isNonExpired ? "MODI: HUDUMA / STATIONARY" : "MODI: DAWA / BIDHAA",
              style: TextStyle(fontWeight: FontWeight.bold, color: _isNonExpired ? Colors.orange[800] : Colors.blue[800])),
          Switch(value: _isNonExpired, onChanged: (v) => setState(() => _isNonExpired = v), activeColor: Colors.orange),
        ],
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
            labelText: label, prefixIcon: Icon(icon, size: 20),
            filled: true, fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: DropdownSearch<String>(
          items: companies,
          onChanged: (v) => setState(() => _selectedCompany = v),
          dropdownDecoratorProps: DropDownDecoratorProps(
              dropdownSearchDecoration: InputDecoration(
                  labelText: "Kampuni", filled: true,
                  fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              )
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: DropdownSearch<String>(
        items: const ["Pcs", "Box", "Litre", "KG", "Service"],
        selectedItem: _selectedUnit,
        onChanged: (v) => setState(() => _selectedUnit = v),
        dropdownDecoratorProps: DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
                labelText: "Unit", filled: true,
                fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
            )
        ),
      ),
    );
  }

  Widget _dateBtn(String label, DateTime? date, Function(DateTime) onPicked, bool isDark, {bool isExp = false}) {
    return OutlinedButton(
      onPressed: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (p != null) onPicked(p);
      },
      style: OutlinedButton.styleFrom(side: BorderSide(color: isExp ? Colors.red : Colors.grey)),
      child: Text(date == null ? label : DateFormat('dd/MM/yy').format(date),
          style: TextStyle(fontSize: 12, color: isExp ? Colors.red : (isDark ? Colors.white : Colors.black))),
    );
  }
}