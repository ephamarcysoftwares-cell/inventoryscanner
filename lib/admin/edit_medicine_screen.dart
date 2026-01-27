import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ Imebadilishwa hapa
import 'package:dropdown_search/dropdown_search.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class EditMedicineScreen extends StatefulWidget {
  final int id;
  final String name;
  final String company;
  final int total_quantity;
  final int remaining_quantity;
  final double buy;
  final double price;
  final String batchNumber;
  final String manufacturedDate;
  final String expiryDate;
  final String added_by;
  final double discount;
  final String unit;
  final String businessName;
  final Map<String, dynamic> user;
  final String? qr_code_url;

  const EditMedicineScreen({
    super.key,
    required this.id,
    required this.name,
    required this.company,
    required this.total_quantity,
    required this.remaining_quantity,
    required this.buy,
    required this.price,
    required this.batchNumber,
    required this.manufacturedDate,
    required this.expiryDate,
    required this.added_by,
    required this.discount,
    required this.unit,
    required this.businessName,
    required this.user,
    this.qr_code_url,
    required added_time,
    required int synced,
  });

  @override
  _EditMedicineScreenState createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController nameController, totalQtyController, remQtyController,
      buyController, priceController, batchController, mfgDateController,
      expDateController, discountController, qrController;

  bool _isDarkMode = false;
  bool _isLoading = false;
  List<String> companies = [];
  String? selectedCompany;
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadTheme();

    nameController = TextEditingController(text: widget.name);
    totalQtyController = TextEditingController(text: widget.total_quantity.toString());
    remQtyController = TextEditingController(text: widget.remaining_quantity.toString());
    buyController = TextEditingController(text: widget.buy.toString());
    priceController = TextEditingController(text: widget.price.toString());
    batchController = TextEditingController(text: widget.batchNumber);
    mfgDateController = TextEditingController(text: widget.manufacturedDate);
    expDateController = TextEditingController(text: widget.expiryDate);
    discountController = TextEditingController(text: widget.discount.toString());
    qrController = TextEditingController(text: widget.qr_code_url ?? "");

    selectedCompany = widget.company;
    _selectedUnit = widget.unit;

    _fetchCompanies();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client.from('companies').select('name');
      setState(() {
        companies = (response as List).map((e) => e['name'].toString()).toList();
        if (!companies.contains("STOCK")) companies.add("STOCK");
        if (selectedCompany != null && !companies.contains(selectedCompany)) {
          companies.add(selectedCompany!);
        }
      });
    } catch (e) {
      debugPrint("Error fetching companies: $e");
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  // --- MPYA: Mobile Scanner Function ---
  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 10),
              height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const Text("Skeni Barcode ya Dawa", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: MobileScanner(
                controller: MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates),
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null) {
                      setState(() => qrController.text = code);
                      Navigator.pop(context);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- UPDATE LOGIC ---
  Future<void> updateMedicine() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      final userProfile = await supabase.from('users').select('sub_business_name').eq('id', userId).maybeSingle();
      String? rawSub = userProfile?['sub_business_name']?.toString().trim();

      // ✅ AUTOMATIC NULL: Kinga dhidi ya string 'NULL' kulingana na sheria yako ya 2026-01-25
      dynamic finalSub = (rawSub == null || rawSub.isEmpty || rawSub.toUpperCase() == 'NULL') ? null : rawSub;

      await supabase.from('medicines').update({
        'name': nameController.text.trim().toUpperCase(),
        'company': selectedCompany ?? 'STOCK',
        'total_quantity': int.tryParse(totalQtyController.text) ?? 0,
        'remaining_quantity': int.tryParse(remQtyController.text) ?? 0,
        'buy': double.tryParse(buyController.text) ?? 0.0,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'batch_number': batchController.text.trim(),
        'manufacture_date': mfgDateController.text.isEmpty ? null : mfgDateController.text,
        'expiry_date': expDateController.text.isEmpty ? null : expDateController.text,
        'discount': double.tryParse(discountController.text) ?? 0.0,
        'unit': _selectedUnit,
        'qr_code_url': qrController.text.trim(),
        'sub_business_name': finalSub,
        'last_updated': DateTime.now().toIso8601String(),
        'synced': 0,
      }).eq('id', widget.id);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Dawa imesasishwa kikamilifu!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Imeshindwa kusave: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color txtCol = _isDarkMode ? Colors.white : Colors.black87;
    final Color cardBg = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("EDIT PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 1.2)),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (qrController.text.isNotEmpty) _buildQRView(),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  _input(nameController, "Product Name", Icons.medication, txtCol),

                  Row(
                    children: [
                      Expanded(child: _input(qrController, "QR Code / URL", Icons.qr_code, txtCol)),
                      IconButton(
                        onPressed: _openScanner, // ✅ Imetumika function ya mobile_scanner
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.green, size: 30),
                      ),
                    ],
                  ),

                  _drop("Company", selectedCompany, companies, (v) => setState(() => selectedCompany = v), txtCol),

                  Row(
                    children: [
                      Expanded(child: _input(totalQtyController, "Total Qty", Icons.inventory, txtCol, type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _input(remQtyController, "Rem Qty", Icons.shopping_cart, txtCol, type: TextInputType.number)),
                    ],
                  ),

                  Row(
                    children: [
                      Expanded(child: _input(buyController, "Buy Price", Icons.payments, txtCol, type: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _input(priceController, "Sell Price", Icons.sell, txtCol, type: TextInputType.number)),
                    ],
                  ),

                  _date(mfgDateController, "Manufacture Date", txtCol),
                  _date(expDateController, "Expiry Date", txtCol),
                  _unitDrop(txtCol),
                ],
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: updateMedicine,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF311B92), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildQRView() {
    return Column(
      children: [
        const Icon(Icons.qr_code_2, size: 80, color: Colors.deepPurple),
        Text("Current QR: ${qrController.text}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _input(TextEditingController c, String l, IconData i, Color col, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c, keyboardType: type, style: TextStyle(color: col),
        decoration: InputDecoration(
          labelText: l, prefixIcon: Icon(i, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _date(TextEditingController c, String l, Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: c, readOnly: true, onTap: () => _selectDate(c), style: TextStyle(color: col),
        decoration: InputDecoration(
          labelText: l, prefixIcon: const Icon(Icons.calendar_month, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _drop(String l, String? v, List<String> items, Function(String?) onChg, Color col) {
    String? safeValue = (v != null && items.contains(v)) ? v : (items.isNotEmpty ? items.first : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        items: items.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: col)))).toList(),
        onChanged: onChg,
        decoration: InputDecoration(labelText: l, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _unitDrop(Color col) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownSearch<String>(
        items: const ['Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle', 'Tablet', 'Capsule', 'Strip'],
        selectedItem: _selectedUnit,
        onChanged: (v) => setState(() => _selectedUnit = v),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(labelText: "Unit", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }
}