import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart'; // ✅ Imetumika mobile_scanner
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditOtherProductScreen extends StatefulWidget {
  final int id;
  final String name;
  final String company;
  final int total_quantity;
  final int remaining_quantity;
  final double buy_price;
  final double selling_price;
  final String batch_number;
  final String manufacture_date;
  final String expiry_date;
  final String added_by;
  final double discount;
  final String date_added;
  final String unit;
  final String businessName;
  final int synced;
  final String? qr_code_url;
  final Map<String, dynamic> user; // ✅ Kwa ajili ya Audit na Sub-business

  const EditOtherProductScreen({
    Key? key,
    required this.id,
    required this.name,
    required this.company,
    required this.total_quantity,
    required this.remaining_quantity,
    required this.buy_price,
    required this.selling_price,
    required this.batch_number,
    required this.manufacture_date,
    required this.expiry_date,
    required this.added_by,
    required this.discount,
    required this.date_added,
    required this.unit,
    required this.businessName,
    required this.synced,
    required this.user,
    this.qr_code_url,
  }) : super(key: key);

  @override
  _EditOtherProductScreenState createState() => _EditOtherProductScreenState();
}

class _EditOtherProductScreenState extends State<EditOtherProductScreen> {
  late TextEditingController nameController, totalQuantityController, quantityController,
      buyController, priceController, batchNumberController, manufacturedDateController,
      expiryDateController, discountController, qrCodeController;

  bool _isLoading = false;
  List<String> companies = [];
  String? selectedCompany;
  bool _isDarkMode = false;
  String? _selectedUnit;

  @override
  void initState() {
    super.initState();
    _loadTheme();

    nameController = TextEditingController(text: widget.name);
    totalQuantityController = TextEditingController(text: widget.total_quantity.toString());
    quantityController = TextEditingController(text: widget.remaining_quantity.toString());
    buyController = TextEditingController(text: widget.buy_price.toString());
    priceController = TextEditingController(text: widget.selling_price.toString());
    batchNumberController = TextEditingController(text: widget.batch_number);
    manufacturedDateController = TextEditingController(text: widget.manufacture_date);
    expiryDateController = TextEditingController(text: widget.expiry_date);
    discountController = TextEditingController(text: widget.discount.toString());
    qrCodeController = TextEditingController(text: widget.qr_code_url ?? "");

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
      debugPrint("Error companies: $e");
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

  // --- MPYA: Scanner Function ---
  void _openMobileScanner() {
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
            const Text("Panga Barcode kwenye Fremu", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null) {
                      setState(() => qrCodeController.text = code);
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

  // UPDATE LOGIC
  Future<void> updateProduct() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // 1. Logic ya Sub-Business Name (Kinga dhidi ya string 'NULL')
      final userProfile = await supabase.from('users').select('sub_business_name').eq('id', userId).maybeSingle();
      String? rawSub = userProfile?['sub_business_name']?.toString().trim();
      dynamic finalSub = (rawSub == null || rawSub.isEmpty || rawSub.toUpperCase() == 'NULL') ? null : rawSub;

      // 2. Audit Log
      await supabase.from('edited_medicines').insert({
        'medicine_id': widget.id.toString(),
        'business_name': widget.businessName,
        'edited_by': widget.user['full_name'] ?? 'Admin',
        'medicine_name_before': widget.name,
        'medicine_name_after': nameController.text.trim().toUpperCase(),
      });

      // 3. Update 'other_product' table
      await supabase.from('other_product').update({
        'name': nameController.text.trim().toUpperCase(),
        'company': selectedCompany ?? 'STOCK',
        'total_quantity': double.tryParse(totalQuantityController.text) ?? 0,
        'remaining_quantity': double.tryParse(quantityController.text) ?? 0,
        'buy_price': double.tryParse(buyController.text) ?? 0.0,
        'selling_price': double.tryParse(priceController.text) ?? 0.0,
        'batch_number': batchNumberController.text.trim(),
        'manufacture_date': manufacturedDateController.text.isEmpty ? null : manufacturedDateController.text,
        'expiry_date': expiryDateController.text.isEmpty ? null : expiryDateController.text,
        'discount': double.tryParse(discountController.text) ?? 0.0,
        'unit': _selectedUnit,
        'qr_code_url': qrCodeController.text.trim(),
        'sub_business_name': finalSub, // Kinga ya NULL imetekelezwa
        'last_updated': DateTime.now().toIso8601String(),
      }).eq('id', widget.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Product Updated!'), backgroundColor: Colors.teal));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("EDIT OTHER PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 1.2)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (qrCodeController.text.isNotEmpty) _buildQRPreview(textCol),

            _buildEditCard(cardColor, [
              _buildTextField(nameController, 'Product Name', Icons.inventory_2, textCol),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(child: _buildTextField(qrCodeController, 'QR / Barcode', Icons.qr_code, textCol)),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _openMobileScanner, // Imetumia function mpya
                      icon: const Icon(Icons.camera_alt, color: Colors.blue, size: 30),
                    )
                  ],
                ),
              ),

              _buildDropdown("Company", selectedCompany, companies, (val) => setState(() => selectedCompany = val), isDark, textCol),

              Row(
                children: [
                  Expanded(child: _buildTextField(totalQuantityController, 'Total Qty', Icons.add_box, textCol, inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(quantityController, 'Rem. Qty', Icons.storage, textCol, inputType: TextInputType.number)),
                ],
              ),

              Row(
                children: [
                  Expanded(child: _buildTextField(buyController, 'Buy Price', Icons.account_balance_wallet, textCol, inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(priceController, 'Sell Price', Icons.payments, textCol, inputType: TextInputType.number)),
                ],
              ),

              _buildDateField(manufacturedDateController, "Manufacture Date", textCol),
              _buildDateField(expiryDateController, "Expiry Date", textCol),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: DropdownSearch<String>(
                  items: const ['Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle', 'Pack', 'Sachet', 'Strip'],
                  selectedItem: _selectedUnit,
                  onChanged: (v) => setState(() => _selectedUnit = v),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Unit", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : updateProduct,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF311B92), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('UPDATE PRODUCT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildQRPreview(Color textCol) {
    return Column(children: [
      const Icon(Icons.qr_code_2, size: 60, color: Colors.deepPurple),
      Text("Current QR: ${qrCodeController.text}", style: TextStyle(fontSize: 12, color: textCol.withOpacity(0.6))),
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildEditCard(Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color textCol, {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        style: TextStyle(color: textCol),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, Color textCol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(controller),
        style: TextStyle(color: textCol),
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, bool isDark, Color textCol) {
    List<String> safeItems = List.from(items);
    if (value != null && !safeItems.contains(value)) safeItems.add(value);
    if (!safeItems.contains("STOCK")) safeItems.add("STOCK");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        value: (value == null || !safeItems.contains(value)) ? "STOCK" : value,
        items: safeItems.toSet().map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: textCol)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.business, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }
}