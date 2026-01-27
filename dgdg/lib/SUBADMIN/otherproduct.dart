import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import '../DB/sync_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../sales_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Adjust the import as necessaryDB
// Assuming you are using an email service for sending emails

class OtherProduct extends StatefulWidget {
  final Map<String, dynamic> user;

  OtherProduct({required this.user, required String staffId, required userName});

  @override
  _OtherProductState createState() => _OtherProductState();
}

class _OtherProductState extends State<OtherProduct> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _buyController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _unitController = TextEditingController(); // Unit controller

  // New date controllers
  final TextEditingController _manufactureDateController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  DateTime? _selectedManufactureDate;
  DateTime? _selectedExpiryDate;

  String? _selectedCompany;
  String? _selectedUnit = 'Per Item'; // Default to 'Per Item'
  bool _isLoading = false;
  List<String> companies = [];
  // Business Info Variables
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = ''; // This was already here
  String businessWhatsapp = '';   // Added this
  String businessLipaNumber = ''; // Added this
  bool _isDarkMode = false;
  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCompanies();     // already present
    getBusinessInfo();     // fetch business info
  }
  void _resetForm() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _buyController.clear();
    _batchNumberController.clear();
    _discountController.clear();
    _manufactureDateController.clear();
    _expiryDateController.clear();

    setState(() {
      _selectedCompany = null;
      _selectedUnit = 'Per Item';
      _isLoading = false;
    });
  }

  Future<void> _fetchCompanies() async {
    List<String> combinedCompanies = [];

    try {
      // 1. Fetch from Local SQLite (Always do this first)
      final db = await DatabaseHelper.instance.database;
      final localResult = await db.query('companies', columns: ['name']);
      List<String> localList = localResult.map((c) => c['name'] as String).toList();
      combinedCompanies.addAll(localList);

      // 2. Check Internet Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {

        // 3. Fetch from Supabase
        try {
          final supabase = Supabase.instance.client;
          final onlineResponse = await supabase
              .from('companies')
              .select('name');

          if (onlineResponse != null) {
            List<String> onlineList = (onlineResponse as List)
                .map((c) => c['name'].toString())
                .toList();
            combinedCompanies.addAll(onlineList);
          }
        } catch (supabaseError) {
          debugPrint("Supabase fetch failed: $supabaseError");
          // We don't show an error to user because we have local data as backup
        }
      }

      // 4. Remove duplicates and update State
      setState(() {
        // Set removes duplicates, then we convert back to List
        companies = combinedCompanies.toSet().toList();
        // Optional: Sort alphabetically
        companies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });

    } catch (e) {
      debugPrint("Error in _fetchCompanies: $e");
    }
  }

  Future<void> _selectDate(BuildContext context, bool isManufactureDate) async {
    final DateTime initialDate = DateTime.now();
    final DateTime firstDate = DateTime(2000);
    final DateTime lastDate = DateTime(2100);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isManufactureDate ? (_selectedManufactureDate ?? initialDate) : (_selectedExpiryDate ?? initialDate),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isManufactureDate) {
          _selectedManufactureDate = picked;
          _manufactureDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        } else {
          _selectedExpiryDate = picked;
          _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> _addMedicine() async {
    setState(() => _isLoading = true);

    // 1. Collect and Parse Values
    String name = _nameController.text.trim();
    String company = _selectedCompany ?? '';
    int totalQty = int.tryParse(_quantityController.text.trim()) ?? 0;
    double buy = double.tryParse(_buyController.text.trim()) ?? 0.0;
    double price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    double discount = double.tryParse(_discountController.text.trim()) ?? 0.0;
    String batch = _batchNumberController.text.trim();
    String unit = _selectedUnit ?? 'Per Item';
    String mfgDate = _manufactureDateController.text.trim();
    String expDate = _expiryDateController.text.trim();
    String currentDT = DateTime.now().toIso8601String();
    String addedBy = widget.user['full_name'] ?? 'Admin';

    // 2. Connectivity Check
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot add product.'), backgroundColor: Colors.orange)
      );
      setState(() => _isLoading = false);
      return;
    }

    // 3. Validation
    if (name.isEmpty || totalQty <= 0 || mfgDate.isEmpty || expDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      // 4. Resolve Business Name (Ensuring it is NOT empty)
      // Try to get it from your global variable first, then the helper function
      String? resolvedBusiness = businessName;
      if (resolvedBusiness == null || resolvedBusiness.isEmpty) {
        resolvedBusiness = await getBusinessName(widget.user['id'].toString());
      }
      // Final fallback to prevent null database errors
      resolvedBusiness ??= "Unknown Business";

      // 5. SUPABASE INSERT (Main Table)
      await supabase.from('other_product').insert({
        'name': name,
        'company': company,
        'manufacture_date': mfgDate,
        'expiry_date': expDate,
        'total_quantity': totalQty,
        'remaining_quantity': totalQty, // Supabase numeric handles int/double
        'buy_price': buy,
        'selling_price': price,
        'batch_number': batch,
        'added_by': addedBy,
        'discount': discount,
        'unit': unit,
        'business_name': resolvedBusiness,
        'date_added': currentDT,
      });

      // 6. SUPABASE INSERT (Logs Table)
      await supabase.from('other_product_logs').insert({
        'name': name,
        'company': company,
        'total_quantity': totalQty,
        'remaining_quantity': totalQty,
        'buy_price': buy,
        'selling_price': price,
        'batch_number': batch,
        'manufacture_date': mfgDate,
        'expiry_date': expDate,
        'added_by': addedBy,
        'discount': discount,
        'unit': unit,
        'business_name': resolvedBusiness,
        'date_added': currentDT,
        'action': 'Successfully added'
      });

      debugPrint("✅ Product added to Supabase for: $resolvedBusiness");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product Added Successfully!'), backgroundColor: Colors.teal)
        );
        _resetForm();
      }

    } on PostgrestException catch (e) {
      debugPrint("❌ Supabase Error: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Database Error: ${e.message}'), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      debugPrint("❌ Fatal Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Get all admin emails from database
  Future<List<String>> getAllAdminEmails() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet connection. Cannot fetch admin emails.");
        return [];
      }

      // 2. Fetch from Supabase
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('users')
          .select('email')
          .eq('role', 'admin');

      if (response is List) {
        // 3. Extract, Clean, and Remove Duplicates
        final List<String> emailList = response
            .map((item) => item['email']?.toString().trim().toLowerCase() ?? '')
            .where((email) => email.isNotEmpty && email != 'null')
            .toSet() // Removes duplicates automatically
            .toList();

        debugPrint("✅ Successfully fetched ${emailList.length} admin emails from Supabase.");
        return emailList;
      }

      return [];
    } catch (e) {
      debugPrint("❌ Error fetching admin emails from Supabase: $e");
      return [];
    }
  }

  // Send email notification to all admins
  Future<void> _sendEmailNotification(
      String name,
      String company,
      int quantity,
      double price,
      double buy,
      String batchNumber,
      String addedBy,
      double discount,
      String unit,
      String manufactureDate,
      String expiryDate,
      ) async {
    try {
      List<String> adminEmails = await getAllAdminEmails();

      if (adminEmails.isEmpty) {
        print("❌ No admins found to send email to.");
        return;
      }

      print("✅ Admin emails found: $adminEmails");

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>New Product Added</title>
  <style>
    body {
      font-family: Arial, sans-serif;
      background-color: #f4f6f8;
      margin: 0;
      padding: 20px;
      color: #333;
    }
    .container {
      background-color: #ffffff;
      padding: 30px;
      border-radius: 10px;
      box-shadow: 0 4px 15px rgba(0,0,0,0.1);
      max-width: 600px;
      margin: auto;
    }
    h2 {
      color: #007bff;
      text-align: center;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-top: 20px;
    }
    td {
      padding: 12px 15px;
      border: 1px solid #ddd;
    }
    td.label {
      background-color: #f0f4ff;
      font-weight: bold;
      width: 40%;
      color: #0056b3;
    }
    .footer {
      margin-top: 30px;
      font-size: 0.9em;
      text-align: center;
      color: #999;
    }
  </style>
</head>
<body>
  <div class="container">
    <h2>🆕 New Product Added</h2>
    <p>A new product has been added to the inventory system. Here are the details:</p>
    <table>
      <tr>
        <td class="label">Name</td>
        <td>$name</td>
      </tr>
      <tr>
        <td class="label">Company</td>
        <td>$company</td>
      </tr>
      <tr>
        <td class="label">Quantity</td>
        <td>$quantity</td>
      </tr>
      <tr>
        <td class="label">Buy Price</td>
        <td>THS ${buy.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td class="label">Selling Price</td>
        <td>THS ${price.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td class="label">Batch Number</td>
        <td>$batchNumber</td>
      </tr>
      <tr>
        <td class="label">Manufacture Date</td>
        <td>$manufactureDate</td>
      </tr>
      <tr>
        <td class="label">Expiry Date</td>
        <td>$expiryDate</td>
      </tr>
      <tr>
        <td class="label">Unit</td>
        <td>$unit</td>
      </tr>
      <tr>
        <td class="label">Discount</td>
        <td>${discount.toStringAsFixed(2)}%</td>
      </tr>
      <tr>
        <td class="label">Added By</td>
        <td>$addedBy</td>
      </tr>
    </table>
    <p>Thank you.<br/>- <strong>Stock & Inventory Software</strong></p>
    <div class="footer">
      &copy; ${DateTime.now().year} E-PHAMARCY SOFTWARE. All rights reserved.
    </div>
  </div>
</body>
</html>
''';

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE')
        ..recipients.addAll(adminEmails)
        ..subject = '🆕 New Product Added: $name'
        ..text = 'New product "$name" has been added.' // fallback text
        ..html = htmlContent;

      final sendReport = await send(message, smtpServer);
      print("✅ Email sent: ${sendReport.toString()}");
    } catch (e) {
      print("❌ Failed to send email: $e");
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch business info from Supabase.");
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch from Supabase
      // We use .limit(1) to avoid 406 errors if multiple rows exist
      final onlineData = await supabase
          .from('businesses')
          .select()
          .limit(1)
          .maybeSingle();

      if (onlineData != null) {
        // 3. Update the UI state directly
        if (mounted) {
          _updateBusinessState(onlineData);
        }
        debugPrint("✅ Business info loaded directly from Supabase");
      } else {
        debugPrint("⚠️ No business info found in Supabase.");
      }

    } catch (e) {
      debugPrint('❌ Supabase Business Info Error: $e');
    }
  }

// Ensure your state update logic handles the Supabase Map keys correctly
  void _updateBusinessState(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      // Column names on the left must match your Supabase 'public.businesses' schema
      businessName = data['business_name']?.toString() ?? 'Default Pharmacy';
      businessEmail = data['email']?.toString() ?? '';
      businessPhone = data['phone']?.toString() ?? '';
      businessLocation = data['location']?.toString() ?? '';

      // Mapping 'logo' column to 'businessLogoPath' variable
      businessLogoPath = data['logo']?.toString() ?? '';

      // Mapping new fields
      businessWhatsapp = data['whatsapp']?.toString() ?? '';
      businessLipaNumber = data['lipa_number']?.toString() ?? '';
    });
  }

// Helper method to keep code clean




  @override
  Widget build(BuildContext context) {
    // Theme State Logic
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.grey[700]!;

    // Admin Dashboard Color Palette
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "ADD PRODUCT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 2),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Business Info Card ---
            if (businessName.isNotEmpty) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : primaryPurple.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (businessLogoPath.isNotEmpty)
                        Container(
                          width: 70, height: 70,
                          margin: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: primaryPurple.withOpacity(0.2), width: 2),
                            image: DecorationImage(
                              image: FileImage(File(businessLogoPath)),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            businessName,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? lightViolet : deepPurple),
                          ),
                          const SizedBox(height: 4),
                          Text("Email: $businessEmail", style: TextStyle(fontSize: 13, color: subTextCol)),
                          Text("Phone: $businessPhone", style: TextStyle(fontSize: 13, color: subTextCol)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // --- Welcome Text ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Welcome, ${widget.user['full_name']}",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textCol)),
                  Text("Email: ${widget.user['email']}",
                      style: TextStyle(fontSize: 15, color: subTextCol)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- Main Form Card ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  _buildStyledInput(_nameController, "Name", Icons.inventory_2_outlined, isDark),
                  const SizedBox(height: 12),

                  // Company Dropdown
                  DropdownSearch<String>(
                    items: companies,
                    selectedItem: _selectedCompany,
                    onChanged: (value) => setState(() => _selectedCompany = value),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      // textCol is already defined as: isDark ? Colors.white : Colors.black87
                      baseStyle: TextStyle(color: textCol, fontSize: 14),
                      dropdownSearchDecoration: _inputDecoration("Company", Icons.business, isDark),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      // Fix: This styles the actual list items in the menu
                      itemBuilder: (context, item, isSelected) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          item,
                          style: TextStyle(color: textCol, fontSize: 14),
                        ),
                      ),
                      containerBuilder: (context, child) => Container(
                        decoration: BoxDecoration(
                          color: cardColor, // Matches the dark card background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: child,
                      ),
                      searchFieldProps: TextFieldProps(
                        style: TextStyle(color: textCol),
                        decoration: _inputDecoration("Search Company", Icons.search, isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildStyledInput(_quantityController, "Total Quantity", Icons.numbers, isDark, isNumeric: true),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _buildStyledInput(_buyController, "Buy Price", Icons.account_balance_wallet, isDark, isNumeric: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStyledInput(_priceController, "Selling Price", Icons.sell, isDark, isNumeric: true)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildStyledInput(_batchNumberController, "Batch Number", Icons.qr_code, isDark),
                  const SizedBox(height: 12),

                  _buildDatePicker(_manufactureDateController, "Manufacture Date", true, isDark),
                  const SizedBox(height: 12),
                  _buildDatePicker(_expiryDateController, "Expiry Date", false, isDark),
                  const SizedBox(height: 12),

                  _buildStyledInput(_discountController, "Discount (%)", Icons.percent, isDark, isNumeric: true),
                  const SizedBox(height: 12),

                  // Unit Dropdown
                  DropdownSearch<String>(
                    items: const [
                      'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
                      'Pack', 'Piece (pc)', 'Set', 'Roll', 'Sachet', 'Strip', 'Tablet', 'Capsule'
                    ],
                    selectedItem: _selectedUnit,
                    onChanged: (value) => setState(() => _selectedUnit = value),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      baseStyle: TextStyle(color: textCol, fontSize: 14),
                      dropdownSearchDecoration: _inputDecoration("Unit", Icons.ad_units, isDark),
                    ),
                    popupProps: PopupProps.menu(
                      showSearchBox: false, // Set to true if you want to search through units
                      // Fix: This ensures the text inside the dropdown list is visible
                      itemBuilder: (context, item, isSelected) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          item,
                          style: TextStyle(
                            color: textCol, // Uses white in Dark Mode, black in Light Mode
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Fix: This ensures the dropdown menu background matches the card color
                      containerBuilder: (context, child) => Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Submit Button (Green remains consistent but shadow adjusts)
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                : Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF1B5E20)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(isDark ? 0.15 : 0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _addMedicine,
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text("ADD PRODUCT",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

// --- UPDATED HELPER METHODS FOR DARK MODE ---



  Widget _buildDatePicker(TextEditingController controller, String label, bool isMfg, bool isDark) {
    return TextFormField(
      controller: controller,
      readOnly: true, // Prevents manual typing
      onTap: () => _selectDate(context, isMfg),
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: _inputDecoration(label, Icons.calendar_today, isDark),
    );
  }

// --- Helper UI Methods to maintain Admin Style ---

  InputDecoration _inputDecoration(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      // Fix: Label color changes based on theme
      labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.blueGrey,
          fontSize: 14
      ),
      // Fix: Icon color stays vibrant in Dark Mode
      prefixIcon: Icon(
          icon,
          color: isDark ? const Color(0xFF9575CD) : const Color(0xFF673AB7),
          size: 20
      ),
      filled: true,
      // Fix: Dynamic background color
      fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1))
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF9575CD), width: 1.5)
      ),
    );
  }

  Widget _buildStyledInput(TextEditingController controller, String label, IconData icon, bool isDark, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      // Ensure the text color adapts to the theme
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      // Fixed: Added the 3rd argument 'isDark'
      decoration: _inputDecoration(label, icon, isDark),
    );
  }

 

  // Helper to get business name from local DB by userId
  Future<String?> getBusinessName(String userId) async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch business name.");
        return null;
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch from Supabase
      // We use .select('business_name') to save bandwidth
      // We use .limit(1) to prevent "multiple rows" errors
      final data = await supabase
          .from('businesses')
          .select('business_name')
          .eq('id', userId) // Using 'id' based on your saved schema
          .limit(1)
          .maybeSingle();

      if (data != null && data['business_name'] != null) {
        String onlineName = data['business_name'].toString();
        debugPrint("✅ Business Name fetched from Supabase: $onlineName");

        // Update global variable if it exists in your class
        if (mounted) {
          setState(() => businessName = onlineName);
        }

        return onlineName;
      } else {
        debugPrint("⚠️ No business found for ID: $userId");
      }

    } catch (e) {
      debugPrint('❌ Supabase Business Name Error: $e');
    }

    return null;
  }
}
