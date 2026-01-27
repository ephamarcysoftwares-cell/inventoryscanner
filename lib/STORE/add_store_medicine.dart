import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as business_name;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class AddMedicineStore extends StatefulWidget {
  final Map<String, dynamic> user;

  const AddMedicineStore({super.key, required this.user});

  @override
  State<AddMedicineStore> createState() => _AddMedicineStoreState();
}

class _AddMedicineStoreState extends State<AddMedicineStore> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();

  DateTime? _manufactureDate;
  DateTime? _expiryDate;

  // Data Lists
  List<String> _businessNames = [];
  String? _selectedBusinessName;
  List<String> _companyNames = [];
  String? _selectedCompany;
  String? _selectedUnit;
  bool _isDarkMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }

  /// 🛠️ Step 1: Initialize Business and then Companies
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);

    // First, find out which business this user belongs to
    await _loadUserBusiness();

    // Only if a business was found, load the associated companies
    if (_selectedBusinessName != null) {
      await _fetchCompanies();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadUserBusiness() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['business_name'] != null) {
        setState(() {
          _selectedBusinessName = response['business_name'].toString();
          _businessNames = [_selectedBusinessName!];
        });
        // 🔥 Crucial: Fetch companies IMMEDIATELY after we get the name
        await _fetchCompanies();
      } else {
        debugPrint("❌ No business assigned to this user in 'users' table.");
      }
    } catch (e) {
      debugPrint("⚠️ Business Load Error: $e");
    }
  }

  Future<void> _fetchCompanies() async {
    if (_selectedBusinessName == null) return;

    try {
      debugPrint("🔍 Searching for companies with business: '$_selectedBusinessName'");

      final response = await supabase
          .from('companies')
          .select('name')
          .eq('business_name', _selectedBusinessName!) // Matches exactly
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      setState(() {
        _companyNames = data.map((item) => item['name'].toString()).toList();
        if (_companyNames.isNotEmpty) {
          _selectedCompany = _companyNames.first;
        }
      });

      debugPrint("✅ Found ${_companyNames.length} companies.");
    } catch (e) {
      debugPrint("⚠️ Company Fetch Error: $e");
    }
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  // Future<void> _fetchCompanies() async {
  //   try {
  //     // Filter companies where the business_name matches the user's business
  //     final response = await supabase
  //         .from('companies')
  //         .select('name')
  //         .eq('business_name', _selectedBusinessName!)
  //         .order('name', ascending: true);
  //
  //     final List<dynamic> data = response as List<dynamic>;
  //     setState(() {
  //       _companyNames = data.map((item) => item['name'].toString()).toList();
  //       if (_companyNames.isNotEmpty) {
  //         _selectedCompany = _companyNames.first;
  //       }
  //     });
  //     debugPrint("🏭 Loaded ${_companyNames.length} companies for $_selectedBusinessName");
  //   } catch (e) {
  //     debugPrint("⚠️ Company Fetch Error: $e");
  //   }
  // }

  /// ☁️ Step 2: Save directly to Supabase
  Future<void> _addMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    if (_manufactureDate == null || _expiryDate == null) {
      _showSnackBar("Please select MFG and EXP dates", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception("User session not found");

      // Mapping data to your public.store schema
      final Map<String, dynamic> medicineData = {
        'name': _nameController.text.trim(),
        'company': _selectedCompany,
        'quantity': int.tryParse(_quantityController.text) ?? 0,
        'buy_price': double.tryParse(_buyController.text) ?? 0.0,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'unit': _selectedUnit,
        'batch_number': _batchNumberController.text.trim(),
        'manufacture_date': DateFormat('yyyy-MM-dd').format(_manufactureDate!),
        'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate!),
        'added_by': widget.user['full_name'], // Passed from login/previous screen
        'business_name': _selectedBusinessName,
        'user_id': user.id, // Auth UUID
      };

      await supabase.from('store').insert(medicineData);

      _showSnackBar("✅ Product saved to Cloud Store successfully!");
      _clearForm();
    } catch (e) {
      debugPrint("❌ Supabase Insert Error: $e");
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _buyController.clear();
    _batchNumberController.clear();
    setState(() {
      _manufactureDate = null;
      _expiryDate = null;
      _selectedUnit = null;
    });
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isManufactureDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isManufactureDate) _manufactureDate = picked;
        else _expiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Theme State Logic ---
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.blueGrey;

    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ADD PRODUCT TO STORE",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              "BRANCH: ${_businessNames}", // Using your saved business name variable
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: _isLoading && _companyNames.isEmpty
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Section: Basic Info ---
              _buildSectionTitle("Basic Information", isDark),
              _buildFormCard(
                cardColor: cardColor,
                child: TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: textCol),
                  decoration: _inputDecoration("Product Name", Icons.inventory_2, isDark),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
              ),
              _buildFormCard(
                cardColor: cardColor,
                child: DropdownSearch<String>(
                  items: _companyNames,
                  selectedItem: _selectedCompany,
                  onChanged: (val) => setState(() => _selectedCompany = val),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    baseStyle: TextStyle(color: textCol),
                    dropdownSearchDecoration: _inputDecoration("Company / Manufacturer", Icons.business, isDark),
                  ),
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    containerBuilder: (context, child) => Container(color: cardColor, child: child),
                    itemBuilder: (context, item, isSelected) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(item, style: TextStyle(color: textCol)),
                    ),
                    searchFieldProps: TextFieldProps(
                      style: TextStyle(color: textCol),
                      decoration: _inputDecoration("Search company...", Icons.search, isDark),
                    ),
                  ),
                ),
              ),

              // --- Section: Inventory & Units ---
              _buildSectionTitle("Inventory & Pricing", isDark),
              Row(
                children: [
                  Expanded(
                    child: _buildFormCard(
                      cardColor: cardColor,
                      child: TextFormField(
                        controller: _quantityController,
                        style: TextStyle(color: textCol),
                        decoration: _inputDecoration("Qty", Icons.numbers, isDark),
                        keyboardType: TextInputType.number,
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFormCard(
                      cardColor: cardColor,
                      child: DropdownSearch<String>(
                        items: const ['Dozen', 'Box', 'Bottle', 'Strip', 'Tablet', 'Capsule', 'Sachet', 'KG', 'Liter', 'Pics', 'Unit'],
                        selectedItem: _selectedUnit,
                        onChanged: (val) => setState(() => _selectedUnit = val),
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          baseStyle: TextStyle(color: textCol),
                          dropdownSearchDecoration: _inputDecoration("Unit", Icons.straighten, isDark),
                        ),
                        popupProps: PopupProps.menu(
                          containerBuilder: (context, child) => Container(color: cardColor, child: child),
                          itemBuilder: (context, item, isSelected) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(item, style: TextStyle(color: textCol)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // --- Price Row ---
              Row(
                children: [
                  Expanded(
                    child: _buildFormCard(
                      cardColor: cardColor,
                      child: TextFormField(
                        controller: _buyController,
                        style: TextStyle(color: textCol),
                        decoration: _inputDecoration("Buy Price", Icons.download_rounded, isDark),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildFormCard(
                      cardColor: cardColor,
                      child: TextFormField(
                        controller: _priceController,
                        style: TextStyle(color: textCol),
                        decoration: _inputDecoration("Sell Price", Icons.upload_rounded, isDark),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ),
                ],
              ),

              // --- Section: Dates & Logistics ---
              _buildSectionTitle("Dates & Batch", isDark),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTile("MFG Date", _manufactureDate, () => _selectDate(context, true), isDark, cardColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateTile("EXP Date", _expiryDate, () => _selectDate(context, false), isDark, cardColor),
                  ),
                ],
              ),
              _buildFormCard(
                cardColor: cardColor,
                child: TextFormField(
                  controller: _batchNumberController,
                  style: TextStyle(color: textCol),
                  decoration: _inputDecoration("Batch Number", Icons.qr_code_scanner, isDark),
                  validator: (val) => val!.isEmpty ? 'Required' : null,
                ),
              ),
              _buildFormCard(
                cardColor: cardColor,
                child: DropdownButtonFormField<String>(
                  dropdownColor: cardColor, // Ensures the legacy dropdown background is dark
                  value: _selectedBusinessName,
                  items: _businessNames
                      .map((name) => DropdownMenuItem(
                      value: name, child: Text(name, style: TextStyle(fontSize: 13, color: textCol))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBusinessName = val),
                  decoration: _inputDecoration("Assign to Business", Icons.storefront, isDark),
                ),
              ),

              const SizedBox(height: 30),

              // --- Submit Button ---
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF43A047) : primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 4,
                    shadowColor: isDark ? Colors.black45 : primaryPurple.withOpacity(0.4),
                  ),
                  onPressed: _isLoading ? null : _addMedicine,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, color: Colors.white),
                      SizedBox(width: 10),
                      Text("ADD TO STORE",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- UI Helper Methods ---

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: isDark ? const Color(0xFF9575CD) : const Color(0xFF673AB7), size: 20),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(fontSize: 14, color: isDark ? Colors.white60 : Colors.blueGrey),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 20, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white38 : Colors.blueGrey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildFormCard({required Widget child, required Color cardColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap, bool isDark, Color cardColor) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16, color: isDark ? const Color(0xFF9575CD) : const Color(0xFF673AB7)),
                const SizedBox(width: 8),
                Text(
                  date == null ? "Select" : DateFormat('dd/MM/yyyy').format(date),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildSectionTitle(String title) {
  //   return Padding(
  //     padding: const EdgeInsets.only(left: 4, top: 20, bottom: 10),
  //     child: Text(
  //       title.toUpperCase(),
  //       style: const TextStyle(
  //         fontSize: 12,
  //         fontWeight: FontWeight.bold,
  //         color: Colors.blueGrey,
  //         letterSpacing: 1.1,
  //       ),
  //     ),
  //   );
  // }
  //
  // Widget _buildFormCard({required Widget child}) {
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 15),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(12),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.04),
  //           blurRadius: 8,
  //           offset: const Offset(0, 4),
  //         ),
  //       ],
  //     ),
  //     child: child,
  //   );
  // }
  //
  // Widget _buildDateTile(String label, DateTime? date, VoidCallback onTap) {
  //   return InkWell(
  //     onTap: onTap,
  //     child: Container(
  //       margin: const EdgeInsets.only(bottom: 15),
  //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(color: Colors.transparent),
  //         boxShadow: [
  //           BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
  //         ],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  //           const SizedBox(height: 4),
  //           Row(
  //             children: [
  //               const Icon(Icons.calendar_month, size: 16, color: Color(0xFF673AB7)),
  //               const SizedBox(width: 8),
  //               Text(
  //                 date == null ? "Select" : DateFormat('dd/MM/yyyy').format(date),
  //                 style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
  //               ),
  //             ],
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildRow(List<Widget> children) => Row(children: children);



  Widget _buildDateCard(String label, DateTime? date, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.all(5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(date == null ? 'Select' : DateFormat('yyyy-MM-dd').format(date), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}