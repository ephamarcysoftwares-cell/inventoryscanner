import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class finalAddMedicineStore extends StatefulWidget {
  final Map<String, dynamic> user;

  const finalAddMedicineStore({super.key, required this.user});

  @override
  State<finalAddMedicineStore> createState() => _finalAddMedicineStoreState();
}

class _finalAddMedicineStoreState extends State<finalAddMedicineStore> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final List<String> _units = [
    'Pcs',
    'Box',
    'Strip',
    'Bottle',
    'Tablet',
    'Capsule'
  ];

  // State
  DateTime? _manufactureDate;
  DateTime? _expiryDate;
  List<String> _companyNames = []; // Initialize empty
  String? _selectedCompany;
  String? _selectedBusinessName;
  String? _selectedUnit;
  bool _isLoading = false;
  int? _businessId;
  String? _subBusinessName;
  bool _isNonExpired = false;
  @override
  void initState() {
    super.initState();
    // Start the chain: Get Business -> then Get Companies
    _loadMyBusinessContext();
  }

  // --- 1. LOAD BUSINESS CONTEXT ---
  Future<void> _loadMyBusinessContext() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Hakikisha unavuta column zote unazohitaji
      final response = await supabase
          .from('users')
          .select('business_name, business_id, sub_business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          // Hakikisha hapa unatumia majina ya column kama yalivyo kule Supabase
          _selectedBusinessName = response['business_name'];
          _businessId = response['business_id'];
          _subBusinessName = response['sub_business_name'];
        });

        print(
            "✅ [DEBUG] Context Loaded: BizName=$_selectedBusinessName, BizID=$_businessId");

        if (_selectedBusinessName != null) {
          await _fetchCompanies(_selectedBusinessName!);
        }
      } else {
        print("⚠️ [DEBUG] No user context found in Supabase");
      }
    } catch (e) {
      print("❌ [DEBUG] Context Error: $e");
    }
  }

  // --- 2. FETCH COMPANIES (Filtered by Business) ---
  Future<void> _fetchCompanies(String myBusiness) async {
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // DEBUG: Check if we are actually reaching this point
      print("🚀 STEP 1: Starting fetch for: '$myBusiness'");

      final response = await supabase
          .from('companies')
          .select('name')
          .eq('business_name', myBusiness.trim()); // Case sensitive!

      print("🚀 STEP 2: Supabase responded. Data: $response");

      if (response != null && response is List) {
        if (response.isEmpty) {
          print(
              "⚠️ STEP 3: Query returned 0 rows. Check table 'companies' for business '$myBusiness'");
        }

        setState(() {
          _companyNames = response
              .map((row) => row['name'].toString())
              .toList();

          if (_companyNames.isNotEmpty) {
            _selectedCompany = _companyNames.first;
          }
        });

        print("✅ STEP 4: State updated with ${_companyNames.length} items.");
      }
    } catch (e) {
      print("❌ STEP 5: CRITICAL ERROR: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 3. ADD TO SUPABASE ---
  Future<void> _addMedicine() async {
    print("🚀 [DEBUG] _addMedicine function called");

    if (_selectedBusinessName == null || _businessId == null) {
      print("❌ [DEBUG] Save failed: BizName or BizID is NULL");
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Error: Business profile or ID not loaded"))
      );
      return;
    }

    if (_formKey.currentState!.validate() && _manufactureDate != null &&
        _expiryDate != null) {
      setState(() => _isLoading = true);

      try {
        final supabase = Supabase.instance.client;
        final String now = DateTime.now().toIso8601String();

        print(
            "💾 [DEBUG] Inserting into store: $_selectedBusinessName, ID: $_businessId");

        // HATUA A: STORE
        await supabase.from('store').insert({
          'name': _nameController.text.trim(),
          'company': _selectedCompany,
          'quantity': int.parse(_quantityController.text),
          'buy_price': double.parse(_buyController.text),
          'price': double.parse(_priceController.text),
          'unit': _selectedUnit,
          'batch_number': _batchNumberController.text.trim(),
          'manufacture_date': DateFormat('yyyy-MM-dd').format(
              _manufactureDate!),
          'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
          'added_by': widget.user['full_name'],
          'business_name': _selectedBusinessName,
          'business_id': _businessId,
          'sub_business_name': _subBusinessName, // Ongeza hii pia
          'user_id': supabase.auth.currentUser!.id,
          'added_time': now,
        });

        // HATUA B: LOGS
        await supabase.from('migration_logs').insert({
          'medicine_name': _nameController.text.trim(),
          'quantity_migrated': int.parse(_quantityController.text),
          'status': 'NEW STORE ENTRY',
          'business_name': _selectedBusinessName,
          'business_id': _businessId,
          'sub_business_name': _subBusinessName, // Muhimu kwa ripoti
          'added_by': widget.user['full_name'],
          'manufacture_date': DateFormat('yyyy-MM-dd').format(
              _manufactureDate!),
          'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
          'batch_number': _batchNumberController.text.trim(),
          'company': _selectedCompany,
          'price': double.parse(_priceController.text),
          'buy': double.parse(_buyController.text),
          'unit': _selectedUnit,
          'migration_date': now,
        });

        print("✅ [DEBUG] Successfully saved and logged!");
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Product Saved & Logged Successfully! ✅'))
        );
        _resetForm();
      } catch (e) {
        print("❌ [DEBUG] Database Error: $e");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save: $e'),
                backgroundColor: Colors.red)
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      print("⚠️ [DEBUG] Form validation failed or dates missing");
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _buyController.clear();
    _batchNumberController.clear();
    setState(() {
      _manufactureDate = null;
      _expiryDate = null;
    });
  }

  // --- UI HELPERS ---
  Future<void> _selectDate(BuildContext context, bool isManufactureDate) async {
    final DateTime? picked = await showDatePicker(context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101));
    if (picked != null) setState(() {
      isManufactureDate ? _manufactureDate = picked : _expiryDate = picked;
    });
  }

  Widget _buildFormCard({required Widget child}) => Expanded(child: Card(
      elevation: 4,
      margin: const EdgeInsets.all(6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12.0), child: child)));


  // Hakikisha hii ipo juu kwenye State class

  @override
  Widget build(BuildContext context) {
    // Tunatumia rangi zako za awali za Indigo Style
    final Color primaryIndigo = Colors.indigo.shade700;
    final Color lightBg = const Color(0xFFF2F6FF);

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_selectedBusinessName ?? "Loading Store...",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (_subBusinessName != null)
              Text("Branch: $_subBusinessName",
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // --- ROW 1: JINA NA KAMPUNI ---
              Row(children: [
                _buildFormCard(child: TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name', prefixIcon: Icon(Icons.medication_outlined)),
                  validator: (v) => v!.isEmpty ? 'Enter name' : null,
                )),
                _buildFormCard(child: DropdownSearch<String>(
                  items: _companyNames,
                  selectedItem: _selectedCompany,
                  onChanged: (v) => setState(() => _selectedCompany = v),
                  dropdownDecoratorProps: const DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(labelText: "Company", border: UnderlineInputBorder()),
                  ),
                )),
              ]),

              // --- SEHEMU YA NON-EXPIRED (STYLE YA KADI YA INDIGO) ---
              Card(
                elevation: 0,
                color: primaryIndigo.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: primaryIndigo.withOpacity(0.1))),
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: SwitchListTile(
                  title: const Text("Bidhaa Haiozi (Non-Expired)?",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo)),
                  subtitle: const Text("Washa kama ni Kitabu, Chombo, au Huduma", style: TextStyle(fontSize: 11)),
                  value: _isNonExpired,
                  activeColor: primaryIndigo,
                  onChanged: (bool value) {
                    setState(() {
                      _isNonExpired = value;
                      if (_isNonExpired) {
                        _manufactureDate = DateTime.now();
                        _expiryDate = DateTime(2099, 12, 31);
                      } else {
                        _manufactureDate = null;
                        _expiryDate = null;
                      }
                    });
                  },
                ),
              ),

              // --- ROW 2: QUANTITY & UNIT ---
              Row(children: [
                _buildFormCard(child: TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity', prefixIcon: Icon(Icons.numbers)),
                  validator: (v) => v!.isEmpty ? 'Qty?' : null,
                )),
                _buildFormCard(child: DropdownButtonFormField<String>(
                  value: _selectedUnit,
                  items: ['Pcs', 'Box', 'Strip', 'Bottle', 'Tablet', 'Capsule', 'Kg', 'Litre']
                      .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (v) => setState(() => _selectedUnit = v),
                  decoration: const InputDecoration(labelText: "Unit"),
                  validator: (v) => v == null ? 'Select Unit' : null,
                )),
              ]),

              // --- ROW 3: BEI ZA KUNUNUA NA KUUZA ---
              Row(children: [
                _buildFormCard(child: TextFormField(
                  controller: _buyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Buy Price', prefixIcon: Icon(Icons.download_rounded)),
                  validator: (v) => v!.isEmpty ? 'Price?' : null,
                )),
                _buildFormCard(child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sell Price', prefixIcon: Icon(Icons.sell_outlined)),
                  validator: (v) => v!.isEmpty ? 'Price?' : null,
                )),
              ]),

              // --- BATCH NUMBER ---
              _buildFormCard(child: TextFormField(
                controller: _batchNumberController,
                decoration: const InputDecoration(labelText: 'Batch Number', prefixIcon: Icon(Icons.qr_code_scanner)),
              )),

              // --- ROW 4: DATES (Zinaonekana tu kama _isNonExpired ni FALSE) ---
              if (!_isNonExpired)
                Row(children: [
                  _buildFormCard(child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Mfg Date", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(_manufactureDate == null ? "Chagua" : DateFormat('dd-MM-yyyy').format(_manufactureDate!),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )),
                  _buildFormCard(child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Exp Date", style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                        const SizedBox(height: 4),
                        Text(_expiryDate == null ? "Chagua" : DateFormat('dd-MM-yyyy').format(_expiryDate!),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13)),
                      ],
                    ),
                  )),
                ]),

              const SizedBox(height: 30),

              // --- SAVE BUTTON (INDIGO STYLE) ---
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryIndigo,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: (_isLoading || _selectedBusinessName == null) ? null : _addMedicine,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('HIFADHI KWENYE STORE',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}