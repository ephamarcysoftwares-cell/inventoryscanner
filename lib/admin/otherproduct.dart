import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class OtherProduct extends StatefulWidget {
  final Map<String, dynamic> user;
  final String staffId;
  final String? userName;

  OtherProduct({required this.user, required this.staffId, this.userName});

  @override
  _OtherProductState createState() => _OtherProductState();
}

class _OtherProductState extends State<OtherProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _scanController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _isLoading = false;
  bool _isDarkMode = false;
  bool _isNonExpired = true;
  bool _isCheckingBarcode = false;

  String businessName = '1 STOCK';
  String subBusinessName = 'ONLINE STORE';
  int? businessId;
  Timer? _debounce;
  DateTime? _manufactureDate;
  DateTime? _expiryDate;

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
    _batchNumberController.dispose();
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
      final response = await supabase
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', widget.user['id'])
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          businessName = response['business_name'] ?? '1 STOCK';
          subBusinessName = response['sub_business_name'] ?? 'ARUSHA';
          businessId = int.tryParse(response['business_id'].toString());
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _onScanChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value.trim().isNotEmpty) {
        _checkDuplicateBarcode(value.trim());
      }
    });
  }

  Future<void> _checkDuplicateBarcode(String code) async {
    if (businessId == null) return;
    setState(() => _isCheckingBarcode = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('other_product')
          .select('name')
          .eq('qr_code_url', code)
          .eq('business_id', businessId!);

      if (response.isNotEmpty && mounted) {
        _showDuplicateWarning(response[0]['name'], code);
      }
    } catch (e) {
      debugPrint("Error checking duplicate: $e");
    } finally {
      if (mounted) setState(() => _isCheckingBarcode = false);
    }
  }

  void _showDuplicateWarning(String productName, String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 10),
            Text("BARCODE IPO TAYARI", style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text("Barcode '$code' tayari inatumiwa na bidhaa: '${productName.toUpperCase()}'"),
        actions: [
          TextButton(
            onPressed: () { _scanController.clear(); Navigator.pop(ctx); },
            child: const Text("BADILISHA BARCODE", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _validateAndConfirm() {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty || _quantityController.text.isEmpty) {
      _showSnackBar("Tafadhali jaza Jina, Idadi na Bei!", Colors.orange, Icons.warning);
      return;
    }
    _saveToDatabase();
  }

  Future<void> _saveToDatabase() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // Ikiwa barcode ni tupu, tengeneza QR ya kipekee kulingana na muda
      String qrCode = _scanController.text.trim().isEmpty
          ? "STOCK-${DateTime.now().millisecondsSinceEpoch}"
          : _scanController.text.trim();

      await supabase.from('other_product').insert({
        'name': _nameController.text.trim().toUpperCase(),
        'company': _isNonExpired ? 'GENERAL STOCK' : 'N/A',
        'total_quantity': double.tryParse(_quantityController.text) ?? 0.0,
        'remaining_quantity': double.tryParse(_quantityController.text) ?? 0.0,
        'buy_price': double.tryParse(_buyController.text) ?? 0.0,
        'selling_price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _isNonExpired ? 'STOCK' : _batchNumberController.text.trim(),
        'manufacture_date': _isNonExpired ? null : (_manufactureDate != null ? DateFormat('yyyy-MM-dd').format(_manufactureDate!) : null),
        'expiry_date': _isNonExpired ? "2099-12-31" : (_expiryDate != null ? DateFormat('yyyy-MM-dd').format(_expiryDate!) : "2099-12-31"),
        'business_id': businessId,
        'business_name': businessName,
        'sub_business_name': subBusinessName,
        'qr_code_url': qrCode,
        'added_by': widget.userName ?? 'Admin',
        'date_added': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackBar("BIDHAA IMEHIFADHIWA!", Colors.green, Icons.check_circle);
        _showQRResult(qrCode, _nameController.text.toUpperCase());
        _resetForm();
      }
    } catch (e) {
      if (mounted) _showSnackBar("Kosa la Kuhifadhi: $e", Colors.red, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showQRResult(String code, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("QR CODE IMETENGENEZWA", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: 220,
                color: Colors.white,
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 150, width: 150,
                      child: QrImageView(
                        data: code,
                        version: QrVersions.auto,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(subBusinessName, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    Text(code, style: const TextStyle(fontSize: 8, color: Colors.black38)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final img = await _screenshotController.capture();
                    if (img != null) {
                      await FileSaver.instance.saveFile(name: "QR_$name", bytes: img, ext: "png");
                      _showSnackBar("Picha ya QR imehifadhiwa!", Colors.blue, Icons.image);
                    }
                  },
                  icon: const Icon(Icons.download, color: Colors.white, size: 16),
                  label: const Text("PAKUA", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800]),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FUNGA")),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        // Tumia 'shape' badala ya 'borderRadius'
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _resetForm() {
    _nameController.clear(); _priceController.clear(); _scanController.clear();
    _quantityController.clear(); _buyController.clear(); _batchNumberController.clear();
    setState(() { _expiryDate = null; _manufactureDate = null; });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    const Color primaryPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        title: Column(
          children: [
            const Text("ONGEZA BIDHAA MPYA", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            Text(subBusinessName.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [primaryPurple, Color(0xFF673AB7)]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Barcode Section (Inapokea USB Scanner pia)
            TextField(
              controller: _scanController,
              onChanged: _onScanChanged,
              autofocus: true, // Focus hapa kwa ajili ya USB scanner
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                labelText: "Skeni Barcode hapa (USB au Camera)",
                hintText: "Weka cursor hapa kisha skeni...",
                prefixIcon: const Icon(Icons.qr_code_scanner, color: primaryPurple),
                suffixIcon: _isCheckingBarcode ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                filled: true, fillColor: isDark ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Form Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _inputField(_nameController, "Jina la Bidhaa (Mvinyo, Soda, n.k)", Icons.inventory_2, isDark),
                  const SizedBox(height: 15),

                  SwitchListTile(
                    title: const Text("Bidhaa haina tarehe ya mwisho (Expiry)?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Kwa bidhaa kama Soda, Maji, au Vifaa", style: TextStyle(fontSize: 11)),
                    value: _isNonExpired,
                    activeColor: primaryPurple,
                    onChanged: (v) => setState(() => _isNonExpired = v),
                  ),

                  const Divider(),

                  Row(
                    children: [
                      Expanded(child: _inputField(_quantityController, "Idadi (Stock)", Icons.add_shopping_cart, isDark, type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _inputField(_priceController, "Bei ya Kuuza", Icons.sell, isDark, type: TextInputType.number)),
                    ],
                  ),

                  if (!_isNonExpired) ...[
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _inputField(_buyController, "Bei ya Kununua", Icons.account_balance_wallet, isDark, type: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _inputField(_batchNumberController, "Batch No.", Icons.numbers, isDark)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: _datePicker("Tengenezwa (MFG)", _manufactureDate, (d) => setState(() => _manufactureDate = d), isDark)),
                        const SizedBox(width: 10),
                        Expanded(child: _datePicker("Itaisha (EXP)", _expiryDate, (d) => setState(() => _expiryDate = d), isDark)),
                      ],
                    ),
                  ]
                ],
              ),
            ),

            const SizedBox(height: 30),

            _isLoading
                ? const CircularProgressIndicator(color: primaryPurple)
                : SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _validateAndConfirm,
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                label: const Text("HIFADHI BIDHAA SASA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 45),
    );
  }

  Widget _inputField(TextEditingController ctrl, String lbl, IconData icon, bool isDark, {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: type,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: lbl, prefixIcon: Icon(icon, size: 20, color: Colors.green),
        filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, Function(DateTime) onPicked, bool isDark) {
    return InkWell(
      onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
        if (p != null) onPicked(p);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 18, color: Colors.orange),
            const SizedBox(width: 8),
            Text(date == null ? label : DateFormat('dd/MM/yyyy').format(date!), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}