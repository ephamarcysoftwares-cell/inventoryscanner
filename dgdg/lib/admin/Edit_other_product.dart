import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  }) : super(key: key);

  @override
  _EditOtherProductScreenState createState() => _EditOtherProductScreenState();
}

class _EditOtherProductScreenState extends State<EditOtherProductScreen> {
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
  String business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';
  bool _isLoading = false;
  List<String> companies = [];
  String? selectedCompany;
  bool _isDarkMode = false;
  List<String> businessNames = [];
  String? selectedBusinessName;

  String? _selectedUnit;
  late ScrollController _scrollController;

  final List<String> unitItems = [
    'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
    'Gram (g)', 'Milliliter (ml)', 'Meter (m)', 'Centimeter (cm)', 'Pack',
    'Carton', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet',
    'Capsule', 'Tray', 'Barrel', 'Can', 'Jar', 'Pouch', 'Unit', 'Bundle'
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _scrollController = ScrollController();

    nameController = TextEditingController(text: widget.name);
    totalQuantityController = TextEditingController(text: widget.total_quantity.toString());
    quantityController = TextEditingController(text: widget.remaining_quantity.toString());
    buyController = TextEditingController(text: widget.buy_price.toString());
    priceController = TextEditingController(text: widget.selling_price.toString());
    batchNumberController = TextEditingController(text: widget.batch_number);
    manufacturedDateController = TextEditingController(text: widget.manufacture_date);
    expiryDateController = TextEditingController(text: widget.expiry_date);
    addedByController = TextEditingController(text: widget.added_by);
    discountController = TextEditingController(text: widget.discount.toString());
    addedTimeController = TextEditingController(text: widget.date_added);
    syncedController = TextEditingController(text: widget.synced.toString());

    selectedCompany = widget.company;
    _selectedUnit = unitItems.contains(widget.unit) ? widget.unit : null;

    _fetchCompanies();
    _loadBusinessNames();
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch companies from Supabase.");
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch company names from Supabase 'medicines' table
      // Using .select('company') ensures we only download the specific column data
      final response = await supabase
          .from('medicines')
          .select('company');

      if (response is List) {
        // 3. Process data: Remove nulls, trim spaces, and ensure uniqueness
        final List<String> fetchedCompanies = response
            .map((item) => item['company']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty && name.toLowerCase() != 'null')
            .toSet() // Automatically handles the "Unique" requirement
            .toList();

        // 4. Sort alphabetically (A-Z)
        fetchedCompanies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        // 5. Update UI
        if (mounted) {
          setState(() {
            companies = fetchedCompanies;

            // Maintain selection: if the previously selected company is still in the list, keep it.
            // Otherwise, reset it to null or the first item.
            if (selectedCompany != null && !companies.contains(selectedCompany)) {
              selectedCompany = null;
            }
          });
          debugPrint("✅ Unique companies loaded from Supabase: ${companies.length}");
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching companies from Supabase: $e');
    }
  }

  Future<void> _loadBusinessNames() async {
    try {
      // 1. Check Internet Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch business names from Supabase.");
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch business names from Supabase
      // We only select the specific column to keep the response small and fast
      final response = await supabase
          .from('businesses')
          .select('business_name');

      if (response is List) {
        // 3. Process data: Remove nulls, trim spaces, and ensure uniqueness
        final List<String> fetchedNames = response
            .map((item) => item['business_name']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty && name.toLowerCase() != 'null')
            .toSet() // Automatically removes duplicates
            .toList();

        // 4. Sort alphabetically
        fetchedNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        // 5. Update UI State
        if (mounted) {
          setState(() {
            businessNames = fetchedNames;

            // Maintain selection logic:
            // Priority 1: Use the name passed from the widget if it exists in the new list
            if (widget.businessName != null && businessNames.contains(widget.businessName)) {
              selectedBusinessName = widget.businessName;
            }
            // Priority 2: Keep the current selection if it's still valid
            else if (selectedBusinessName != null && businessNames.contains(selectedBusinessName)) {
              // Stay as is
            }
            // Priority 3: Fallback to the first item or null
            else {
              selectedBusinessName = businessNames.isNotEmpty ? businessNames.first : null;
            }
          });
          debugPrint("✅ Business names loaded from Supabase: ${businessNames.length}");
        }
      }
    } catch (e) {
      debugPrint('❌ Supabase Business Fetch Error: $e');
    }
  }

  bool _isExpiryDateValid(String date) {
    try {
      return DateTime.parse(date).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  // 1. Fetch Business Info from Supabase
  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;

      // Fetching from your public.businesses schema
      final data = await supabase
          .from('businesses')
          .select()
          .limit(1) // Usually, a shop only has 1 business profile
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          // Map the columns from your SQL schema to your Flutter variables
          business_name = data['business_name']?.toString() ?? '';
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
          businessWhatsapp = data['whatsapp']?.toString() ?? '';
          businessLipaNumber = data['lipa_number']?.toString() ?? '';
        });
        debugPrint("✅ Business Profile Synced: $business_name");
      } else {
        debugPrint("⚠️ No business profile found in the businesses table.");
      }
    } catch (e) {
      debugPrint('❌ Supabase Fetch Error: $e');
    }
  }

  // 2. Perform the Update and Audit Log
  Future<void> updateProduct() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw "Kafanya Login upya (Session Expired)";

      // 1. Fetch Verified Identity & Business Context (Strict Mode)
      final userRes = await supabase
          .from('users')
          .select('business_name, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final String myBusiness = userRes?['business_name'] ?? selectedBusinessName ?? '';
      final String myName = userRes?['full_name'] ?? addedByController.text;

      // 2. Fetch "Before" state for the audit log
      // Security: Filter by both ID and Business Name
      final beforeData = await supabase
          .from('other_product')
          .select()
          .eq('id', widget.id)
          .eq('business_name', myBusiness)
          .single();

      // 3. Step A: Insert Audit Log into 'edited_product_logs'
      // FIX: We use .round() to ensure integers like 3368.0 become 3368
      await supabase.from('edited_product_logs').insert({
        'product_id': widget.id,
        'business_name': myBusiness,
        'edited_by': myName,
        'product_beforename': beforeData['name'],
        'product_aftername': nameController.text.trim(),

        'qty_before': (double.tryParse(beforeData['remaining_quantity'].toString()) ?? 0.0).round(),
        'qty_after': (double.tryParse(quantityController.text) ?? 0.0).round(),

        'price_before': double.tryParse(beforeData['selling_price'].toString()) ?? 0.0,
        'price_after': double.tryParse(priceController.text) ?? 0.0,

        'batch_before': beforeData['batch_number'],
        'batch_after': batchNumberController.text.trim(),
        'expiry_before': beforeData['expiry_date'],
        'expiry_after': expiryDateController.text.trim(),
      });

      // 4. Step B: Update the main 'other_product' table
      // Matches your SQL schema columns exactly
      await supabase.from('other_product').update({
        'name': nameController.text.trim(),
        'company': selectedCompany,
        'total_quantity': (double.tryParse(totalQuantityController.text) ?? 0.0).round(),
        'remaining_quantity': (double.tryParse(quantityController.text) ?? 0.0).round(),
        'buy_price': double.tryParse(buyController.text) ?? 0.0,
        'selling_price': double.tryParse(priceController.text) ?? 0.0,
        'batch_number': batchNumberController.text.trim(),
        'manufacture_date': manufacturedDateController.text,
        'expiry_date': expiryDateController.text,
        'discount': double.tryParse(discountController.text) ?? 0.0,
        'unit': _selectedUnit,
        'business_name': myBusiness,
        'last_updated': DateTime.now().toIso8601String(),
      })
          .eq('id', widget.id)
          .eq('business_name', myBusiness); // Strict Lock for Tenant Isolation

      // 5. Success UI Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Bidhaa imesasishwa kikamilifu!'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // Return 'true' to refresh the list screen
      }

    } catch (e) {
      debugPrint("❌ Update Product Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hitilafu: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          border: const OutlineInputBorder(),
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
          prefixIcon: const Icon(Icons.calendar_today, color: Colors.green),
          border: const OutlineInputBorder(),
        ),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (picked != null) {
            controller.text = picked.toIso8601String().split('T')[0];
          }
        },
      ),
    );
  }

  Widget _buildUnitDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownSearch<String>(
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              labelText: "Search Unit",
              prefixIcon: const Icon(Icons.search, color: Colors.green),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            labelText: "Select Unit",
            border: OutlineInputBorder(),
          ),
        ),
        items: unitItems,
        selectedItem: _selectedUnit,
        onChanged: (value) => setState(() => _selectedUnit = value),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Company',
          prefixIcon: const Icon(Icons.business, color: Colors.green),
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedCompany,
            items: companies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => selectedCompany = val),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Business Name',
          prefixIcon: const Icon(Icons.business_center, color: Colors.green),
          border: const OutlineInputBorder(),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedBusinessName,
            items: businessNames.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (val) => setState(() => selectedBusinessName = val),
          ),
        ),
      ),
    );
  }


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
          "EDIT OTHER PRODUCT",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
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
      body: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(10),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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
                        'Modify the details below and click update to save changes.',
                        style: TextStyle(fontSize: 12, color: subTextCol),
                      ),
                    ),
                  ],
                ),
              ),

              // Form Fields - Ensure _buildEditCard uses cardColor internally
              _buildEditCard([
                _buildTextField(nameController, 'Product Name', Icons.inventory_2),
                const SizedBox(height: 12),
                _buildCompanyDropdown(), // Helper must use textCol/cardColor
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField(totalQuantityController, 'Total Qty', Icons.format_list_numbered, inputType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(quantityController, 'Rem. Qty', Icons.storage, inputType: TextInputType.number)),
                  ],
                ),
              ]),

              const SizedBox(height: 15),

              _buildEditCard([
                Row(
                  children: [
                    Expanded(child: _buildTextField(buyController, 'Buy Price', Icons.account_balance_wallet, inputType: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildTextField(priceController, 'Sell Price', Icons.payments, inputType: TextInputType.number)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(batchNumberController, 'Batch Number', Icons.qr_code_scanner),
              ]),

              const SizedBox(height: 15),

              _buildEditCard([
                _buildDateField(manufacturedDateController, 'Manufacture Date'),
                const SizedBox(height: 12),
                _buildDateField(expiryDateController, 'Expiry Date'),
                const SizedBox(height: 12),
                _buildTextField(discountController, 'Discount (%)', Icons.percent, inputType: TextInputType.number),
              ]),

              const SizedBox(height: 15),

              _buildEditCard([
                _buildUnitDropdown(), // Helper must use textCol/cardColor
                const SizedBox(height: 12),
                _buildBusinessDropdown(), // Helper must use textCol/cardColor
              ]),

              const SizedBox(height: 30),

              // Update Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: updateProduct,
                  icon: const Icon(Icons.save_as, color: Colors.white),
                  label: const Text(
                    'UPDATE PRODUCT DETAILS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? primaryPurple : deepPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

// Helper widget to wrap form groups in a clean white card
  Widget _buildEditCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
