import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../DB/database_helper.dart';  // Import for database operations
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';  // Your database helper import
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
  final String added_time;
  final String unit;
  final String businessName;
  final int synced;

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
    required this.added_time,
    required this.unit,
    required this.businessName,
    required this.synced,
  });

  @override
  _EditMedicineScreenState createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  late TextEditingController nameController;
  late TextEditingController totalQuantityController;
  late TextEditingController quantityController;
  late TextEditingController buyController;
  late TextEditingController priceController;
  late TextEditingController batchNumberController;
  late TextEditingController manufacturedDateController;
  late TextEditingController expiryDateController;
  late TextEditingController addedByController;
  late TextEditingController discountController;
  late TextEditingController addedTimeController;
  late TextEditingController syncedController;
  bool _isDarkMode = false;
  // Companies loaded dynamically from DB
  List<String> companies = [];
  String? selectedCompany;

  // Business names loaded dynamically from DB
  List<String> businessNames = [];
  String? selectedBusinessName;

  // Selected Unit for dropdown
  String? _selectedUnit;
  String? businessName;
  @override
  void initState() {
    super.initState();
    _loadTheme();


    nameController = TextEditingController(text: widget.name);
    totalQuantityController = TextEditingController(text: widget.total_quantity.toString());
    quantityController = TextEditingController(text: widget.remaining_quantity.toString());
    buyController = TextEditingController(text: widget.buy.toString());
    priceController = TextEditingController(text: widget.price.toString());
    batchNumberController = TextEditingController(text: widget.batchNumber);
    manufacturedDateController = TextEditingController(text: widget.manufacturedDate);
    expiryDateController = TextEditingController(text: widget.expiryDate);
    addedByController = TextEditingController(text: widget.added_by);
    discountController = TextEditingController(text: widget.discount.toString());
    addedTimeController = TextEditingController(text: widget.added_time);
    syncedController = TextEditingController(text: widget.synced.toString());

    selectedCompany = widget.company;
    selectedBusinessName = widget.businessName;
    _selectedUnit = widget.unit;

    _fetchCompanies();
    _loadBusinessNames();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> _fetchCompanies() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    // 1. Get the user's business name
    final userDoc = await supabase
        .from('users')
        .select('business_name')
        .eq('id', userId)
        .maybeSingle();

    final String? myBusiness = userDoc?['business_name'];

    if (myBusiness != null) {
      // 2. ONLY fetch companies where business_name matches
      final response = await supabase
          .from('companies')
          .select('name')
          .eq('business_name', myBusiness) // <-- This is the key filter
          .order('name', ascending: true);

      if (response is List) {
        setState(() {
          companies = response.map((row) => row['name'].toString()).toList();
        });
      }
    }
  }
  Future<void> _loadBusinessNames() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet. Cannot load business info.");
        return;
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint("❌ No session user found.");
        return;
      }

      // 2. Fetch ONLY the business_name for this specific user ID
      // This is the most secure way to handle multi-tenant data.
      final response = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && response['business_name'] != null) {
        final String myBusiness = response['business_name'].toString().trim();

        // 3. Update UI
        if (mounted) {
          setState(() {
            // Wrap the single name in a list to satisfy your dropdown/list UI
            businessNames = [myBusiness];

            // Automatically select the user's business
            selectedBusinessName = myBusiness;
          });
          debugPrint("✅ Business restricted to: $myBusiness");
        }
      } else {
        debugPrint("⚠️ No business profile found in 'users' table for this ID.");
      }
    } catch (e) {
      debugPrint("⚠️ Supabase Profile Fetch Error: $e");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    totalQuantityController.dispose();
    quantityController.dispose();
    buyController.dispose();
    priceController.dispose();
    batchNumberController.dispose();
    manufacturedDateController.dispose();
    expiryDateController.dispose();
    addedByController.dispose();
    discountController.dispose();
    addedTimeController.dispose();
    syncedController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  bool _isExpiryDateValid(String expiryDate) {
    DateTime currentDate = DateTime.now();
    try {
      DateTime expiry = DateFormat("yyyy-MM-dd").parse(expiryDate);
      return expiry.isAfter(currentDate);
    } catch (e) {
      return false;
    }
  }

  Future<void> updateMedicine() async {
    try {
      final supabase = Supabase.instance.client;

      // 1. GET DATA "BEFORE"
      final beforeData = await supabase
          .from('medicines')
          .select()
          .eq('id', widget.id)
          .single();

      // 2. RESOLVE BUSINESS NAME
      // If your global 'businessName' is null, we take it from the medicine itself
      String currentBusiness = businessName ?? beforeData['business_name'] ?? 'Default Pharmacy';

      // 3. SAVE TO EDITED_MEDICINES (Audit Log)
      await supabase.from('edited_medicines').insert({
        'medicine_id': widget.id.toString(),
        'business_name': currentBusiness, // 👈 This ensures it is not empty
        'edited_by': addedByController.text.isEmpty ? 'Admin' : addedByController.text,

        // Before mapping
        'medicine_name_before': beforeData['name'],
        'company_before': beforeData['company'],
        'total_qty_before': beforeData['total_quantity'],
        'remaining_qty_before': beforeData['remaining_quantity'],
        'buy_price_before': beforeData['buy'],
        'selling_price_before': beforeData['price'],
        'batch_number_before': beforeData['batch_number'],
        'mfg_date_before': beforeData['manufacture_date'],
        'expiry_date_before': beforeData['expiry_date'],

        // After mapping (from Controllers)
        'medicine_name_after': nameController.text.trim(),
        'company_after': selectedCompany,
        'total_qty_after': int.tryParse(totalQuantityController.text) ?? 0,
        'remaining_qty_after': int.tryParse(quantityController.text) ?? 0,
        'buy_price_after': double.tryParse(buyController.text) ?? 0.0,
        'selling_price_after': double.tryParse(priceController.text) ?? 0.0,
        'batch_number_after': batchNumberController.text.trim(),
        'mfg_date_after': manufacturedDateController.text,
        'expiry_date_after': expiryDateController.text,
      });

      // 4. UPDATE THE MAIN MEDICINE TABLE
      await supabase.from('medicines').update({
        'name': nameController.text.trim(),
        'company': selectedCompany,
        'total_quantity': int.tryParse(totalQuantityController.text) ?? 0,
        'remaining_quantity': int.tryParse(quantityController.text) ?? 0,
        'buy': double.tryParse(buyController.text) ?? 0.0,
        'price': double.tryParse(priceController.text) ?? 0.0,
        'batch_number': batchNumberController.text.trim(),
        'manufacture_date': manufacturedDateController.text,
        'expiry_date': expiryDateController.text,
        'business_name': currentBusiness, // Keep business name consistent
      }).eq('id', widget.id);

      debugPrint("✅ Audit log saved with Business: $currentBusiness");
      Navigator.pop(context, true);

    } catch (e) {
      debugPrint("❌ Update Failed: $e");
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    // Theme State Logic
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    // Admin Dashboard Style Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "EDIT PRODUCT",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple, lightViolet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Instructions Card (Adaptive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: primaryPurple.withOpacity(isDark ? 0.4 : 0.2)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: primaryPurple),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Update the product details below and save changes.',
                        style: TextStyle(fontSize: 12, color: subTextCol),
                      ),
                    ),
                  ],
                ),
              ),

              // Form Fields Grouped in an Adaptive Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Ensure _buildTextField handles isDark inside its implementation
                    _buildTextField(nameController, 'Product Name', Icons.medication),

                    // Company Dropdown (Themed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Company',
                          labelStyle: TextStyle(color: subTextCol),
                          prefixIcon: const Icon(Icons.business, color: primaryPurple),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: cardColor, // Prevents white menu on dark background
                            value: selectedCompany,
                            style: TextStyle(color: textCol),
                            items: companies.map((company) {
                              return DropdownMenuItem<String>(
                                value: company,
                                child: Text(company, style: TextStyle(color: textCol)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedCompany = value);
                            },
                            hint: Text('Select Company', style: TextStyle(color: subTextCol)),
                          ),
                        ),
                      ),
                    ),

                    _buildTextField(totalQuantityController, 'Total Stocked Qty', Icons.format_list_numbered, inputType: TextInputType.number),
                    _buildTextField(quantityController, 'Remaining Qty', Icons.add_shopping_cart, inputType: TextInputType.number),

                    Row(
                      children: [
                        Expanded(child: _buildTextField(buyController, 'Buy Price', Icons.attach_money, inputType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTextField(priceController, 'Selling Price', Icons.monetization_on, inputType: TextInputType.number)),
                      ],
                    ),

                    _buildTextField(batchNumberController, 'Batch Number', Icons.confirmation_num),
                    _buildDateField(manufacturedDateController, 'Manufactured Date'),
                    _buildDateField(expiryDateController, 'Expiry Date'),
                    _buildTextField(discountController, 'Discount', Icons.discount, inputType: TextInputType.number),

                    _buildUnitDropdown(), // Ensure this uses cardColor and textCol inside

                    // Business Name Dropdown (Themed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Business Name',
                          labelStyle: TextStyle(color: subTextCol),
                          prefixIcon: const Icon(Icons.business_center, color: primaryPurple),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: cardColor,
                            value: selectedBusinessName,
                            style: TextStyle(color: textCol),
                            items: businessNames.map((business) {
                              return DropdownMenuItem<String>(
                                value: business,
                                child: Text(business, style: TextStyle(color: textCol)),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => selectedBusinessName = value);
                            },
                            hint: Text('Select Business Name', style: TextStyle(color: subTextCol)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: updateMedicine,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text(
                    'UPDATE PRODUCT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? primaryPurple : deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.green),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        readOnly: true,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(Icons.calendar_today, color: Colors.green),
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
        onTap: () => _selectDate(context, controller),
      ),
    );
  }

  Widget _buildUnitDropdown() {
    List<String> unitItems = [
      'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
      'Gram (g)', 'Milliliter (ml)', 'Meter (m)', 'Centimeter (cm)', 'Pack',
      'Carton', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet',
      'Capsule', 'Tray', 'Barrel', 'Can', 'Jar', 'Pouch', 'Unit', 'Bundle'
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        items: unitItems,
        selectedItem: _selectedUnit,
        onChanged: (String? newValue) {
          setState(() {
            _selectedUnit = newValue!;
          });
        },
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: 'Select Unit',
            border: OutlineInputBorder(),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              labelText: 'Search unit...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),
    );
  }


}
