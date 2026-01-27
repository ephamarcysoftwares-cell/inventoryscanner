import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class SubAddMedicineScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  SubAddMedicineScreen({required this.user});

  @override
  _SubAddMedicineScreenState createState() => _SubAddMedicineScreenState();
}

class _SubAddMedicineScreenState extends State<SubAddMedicineScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();

  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  String? _selectedCompany;
  String? _selectedUnit = 'Pcs';
  bool _isLoading = false;
  bool _isBusinessInfoLoaded = false;
  List<String> companies = [];
  bool _isDarkMode = false;

  // Variables za kusave kwenye medicines table
  String business_name = '';
  String sub_business_name = '';
  int? business_id;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();
    _initializeData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _initializeData() async {
    await getBusinessInfo();
    if (mounted) {
      setState(() {
        _isBusinessInfoLoaded = true;
      });
    }
  }

  // REKEBISHO KUBWA: Tumeondoa neno 'location' na tunatumia table ya businesses
  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.user['id'];

      if (userId == null) return;

      // REKEBISHO: Tumia column zilizopo tu kwenye schema yako ya Users
      final userProfile = await supabase
          .from('users')
          .select('business_name, sub_business_name, business_id')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile != null && mounted) {
        setState(() {
          business_name = userProfile['business_name']?.toString() ?? '';
          sub_business_name = userProfile['sub_business_name']?.toString() ?? 'Main Branch';
          // Hakikisha business_id inasomwa kama int (BigInt kwenye DB)
          business_id = userProfile['business_id'] != null
              ? int.tryParse(userProfile['business_id'].toString())
              : null;
        });
        debugPrint("✅ Data Imepakiwa: $business_name | Tawi: $sub_business_name | ID: $business_id");
      }
    } catch (e) {
      // Hapa ndipo kosa la 'location does not exist' lilikuwa linatokea
      debugPrint('❌ Error Fetching Business Info: $e');
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await Supabase.instance.client
          .from('companies')
          .select('name')
          .order('name', ascending: true);
      if (response is List) {
        setState(() {
          companies = response.map((c) => c['name'].toString()).toSet().toList();
        });
      }
    } catch (e) {
      debugPrint("⚠️ Companies fetch error: $e");
    }
  }

  Future<void> _addMedicine() async {
    // 1. Zuia kama taarifa za biashara hazijapakiwa (Kuepuka NULL)
    if (business_id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Inapakua taarifa... subiri kidogo."),
        backgroundColor: Colors.orange,
      ));
      await getBusinessInfo();
      return;
    }

    if (_nameController.text.isEmpty || _selectedCompany == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Jaza Jina, Kampuni na Expiry!'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String formattedExpDate = DateFormat('yyyy-MM-dd').format(_expiryDate!);
      String? formattedMfgDate = _manufactureDate != null ? DateFormat('yyyy-MM-dd').format(_manufactureDate!) : null;

      // --- SEHEMU YA 1: SAVE MEDICINE ---
      final medicineData = {
        'name': _nameController.text.trim(),
        'company': _selectedCompany,
        'total_quantity': int.tryParse(_quantityController.text) ?? 0,
        'remaining_quantity': int.tryParse(_quantityController.text) ?? 0,
        'buy': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'batch_number': _batchNumberController.text.trim(),
        'manufacture_date': formattedMfgDate,
        'expiry_date': formattedExpDate,
        'added_by': widget.user['full_name'] ?? 'Admin',
        'discount': double.tryParse(_discountController.text) ?? 0.0,
        'unit': _selectedUnit,
        'business_name': business_name,
        'business_id': business_id,
        'sub_business_name': sub_business_name,
        'added_time': DateTime.now().toIso8601String(),
        'synced': true,
      };

      await supabase.from('medicines').insert(medicineData);

      // --- SEHEMU YA 2: SAVE MEDICAL LOG ---
      // Hii itarekodi kila tukio la kuongeza dawa
      await supabase.from('medical_logs').insert({
        'medicine_name': _nameController.text.trim(),
        'action': 'Added to Stock',
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'added_by': widget.user['full_name'],
        'business_id': business_id,
        'sub_business_name': sub_business_name,
        'log_date': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Imefanikiwa! Log imerekodiwa tawi la $sub_business_name'),
          backgroundColor: Colors.green,
        ));
        _resetFormFields();
      }
    } catch (e) {
      debugPrint("❌ Kosa: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kosa la Database: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetFormFields() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _buyController.clear();
    _batchNumberController.clear();
    _discountController.clear();
    setState(() { _manufactureDate = null; _expiryDate = null; });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const Color primaryPurple = Color(0xFF673AB7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("INGIZA MZIGO MPYA-LEO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF311B92), primaryPurple]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryPurple.withOpacity(0.3))
              ),
              child: Column(
                children: [
                  Text(business_name.isEmpty ? "Inapakua..." : business_name, style: const TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
                  Text("TAWI: $sub_business_name", style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[600])),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                children: [
                  _buildTextField(controller: _nameController, label: "Jina la Bidhaa", isDark: isDark),
                  _buildCompanyDropdown(isDark: isDark),
                  _buildTextField(controller: _quantityController, label: "Idadi (Quantity)", keyboardType: TextInputType.number, isDark: isDark),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(controller: _buyController, label: "Bei ya Kununua", keyboardType: TextInputType.number, isDark: isDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(controller: _priceController, label: "Bei ya Kuuzia", keyboardType: TextInputType.number, isDark: isDark)),
                    ],
                  ),
                  _buildTextField(controller: _batchNumberController, label: "Batch Number", isDark: isDark),
                  _buildUnitDropdown(isDark: isDark),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: _dateBtn("MFG Date", _manufactureDate, () => _selectDate(context, true), isDark)),
                      const SizedBox(width: 10),
                      Expanded(child: _dateBtn("EXP Date", _expiryDate, () => _selectDate(context, false), isDark, isExpiry: true)),
                    ],
                  ),
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
                onPressed: _addMedicine,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: const Text("HIFADHI KWENYE TAWLI", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- WIDGET HELPERS ---
  Widget _dateBtn(String label, DateTime? date, VoidCallback onTap, bool isDark, {bool isExpiry = false}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(side: BorderSide(color: isExpiry ? Colors.red.withOpacity(0.5) : Colors.grey.withOpacity(0.3))),
      child: Text(date == null ? label : DateFormat('yyyy-MM-dd').format(date), style: TextStyle(fontSize: 11, color: isExpiry ? Colors.red : (isDark ? Colors.white : Colors.black87))),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, TextInputType? keyboardType, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownSearch<String>(
        items: companies,
        selectedItem: _selectedCompany,
        onChanged: (v) => setState(() => _selectedCompany = v),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: "Chagua Kampuni",
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _buildUnitDropdown({required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownSearch<String>(
        items: ['Pcs', 'Box', 'Strip', 'Tablet', 'Bottle', 'KG', 'Litre'],
        selectedItem: _selectedUnit,
        onChanged: (v) => setState(() => _selectedUnit = v),
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: "Unit",
            filled: true,
            fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isMfg) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() { if (isMfg) _manufactureDate = picked; else _expiryDate = picked; });
  }
}