import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Import for DropdownSearch
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'edit_medicine_screen.dart';

class ViewMedicineScreen extends StatefulWidget {
  const ViewMedicineScreen({super.key});

  @override
  _ViewMedicineScreenState createState() => _ViewMedicineScreenState();
}

class _ViewMedicineScreenState extends State<ViewMedicineScreen> {
  late Future<List<Map<String, dynamic>>> medicines;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  // Business info
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  bool _isDarkMode = false;
  // State for DropdownSearch
  List<String> uniqueCompanies = [];
  String _selectedCompany = ''; // Will hold the selected company in the dialog

  @override
  void initState() {
    super.initState();
    _loadTheme();
    medicines = Future.value([]);
    initializeData();
  }
  Future<void> initializeData() async {
    // 1. Trigger the medicine stream/future immediately
    setState(() {
      medicines = fetchMedicines(searchQuery: searchQuery);
    });

    // 2. Run background metadata fetches in parallel
    try {
      await Future.wait([
        getBusinessInfo(),
        fetchUniqueCompanies(),
      ]);
    } catch (e) {
      debugPrint('Initialization error: $e');
    }
  }
  Future<List<String>> getAllAdminEmails() async {
    Set<String> emailSet = {};
    final supabase = Supabase.instance.client;

    // Ensure we have a logged-in user
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) return [];

      // 2. Fetch business name for the logged-in user
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', currentUser.id)
          .maybeSingle();

      String? myBusiness = userProfile?['business_name'];

      if (myBusiness != null) {
        // 3. Fetch admin emails from the VIEW for THIS business
        final response = await supabase
            .from('business_admins')
            .select('email')
            .eq('business_name', myBusiness);

        if (response is List) {
          for (var row in response) {
            final String? email = row['email'];
            if (email != null && email.isNotEmpty) {
              emailSet.add(email.trim().toLowerCase());
            }
          }
          debugPrint("✅ Found ${emailSet.length} Admin emails for: $myBusiness");
        }
      }
    } catch (e) {
      debugPrint('❌ Error in getAllAdminEmails: $e');
    }

    return emailSet.toList();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
// Function to send the product restock notification email
  Future<void> sendAdminNotification({
    required String name,
    required String company,
    required int quantity,
    required double price,
    required double buy,
    required String batch_number,
    required String addedBy,
    required double discount,
    required String unit,
    // 🔹 ADD THIS LINE BELOW
    required String businessName,
  }) async {
    try {
      final emails = await getAllAdminEmails();
      if (emails.isEmpty) return;

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final message = Message()
      // 🔹 USE THE PARAMETER HERE FOR THE SENDER NAME
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.addAll(emails)
        ..subject = '🆕 Stock Updated: $name ($businessName)'
        ..html = '''
        <h3>🆕 Product Stock Updated</h3>
        <p><b>Business:</b> $businessName</p>
        <p><b>Product:</b> $name</p>
        <p><b>Quantity Added:</b> $quantity $unit</p>
        <p><b>Updated By:</b> $addedBy</p>
      ''';

      await send(message, smtpServer);
      debugPrint("✅ Notification sent for $businessName");
    } catch (e) {
      debugPrint('❌ Email failed: $e');
    }
  }
  // ================== Fetch Unique Company Names ==================
  Future<void> fetchUniqueCompanies() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) return;

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Get the user's business name
      final userDoc = await supabase.from('users').select('business_name').eq('id', userId).maybeSingle();
      final String? myBusiness = userDoc?['business_name'];

      if (myBusiness == null) return;

      // 2. Fetch companies ONLY for this business
      final response = await supabase
          .from('medicines')
          .select('company')
          .eq('business_name', myBusiness) // <-- STRICT FILTER
          .not('company', 'is', null);

      if (response is List) {
        final Set<String> companySet = response
            .map((item) => item['company']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty)
            .toSet();

        final List<String> sortedList = companySet.toList();
        sortedList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        if (mounted) {
          setState(() {
            uniqueCompanies = sortedList;
          });
          debugPrint("✅ Companies restricted to $myBusiness: ${uniqueCompanies.length}");
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching unique companies: $e');
    }
  }



  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) return;

      final data = await supabase
          .from('users')
          .select('business_name')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && data['business_name'] != null) {
        setState(() {
          businessName = data['business_name'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching business name: $e');
    }
  }

// Helper method to refresh the UI variables
  void _updateBusinessUI(Map<String, dynamic> data) {
    setState(() {
      businessName = data['business_name']?.toString() ?? '';
      businessEmail = data['email']?.toString() ?? '';
      businessPhone = data['phone']?.toString() ?? '';
      businessLocation = data['location']?.toString() ?? '';
      businessLogoPath = data['logo']?.toString() ?? '';
    });
  }

  void loadMedicines() {
    setState(() {
      medicines = fetchMedicines(searchQuery: searchQuery);
    });
    fetchUniqueCompanies(); // Also refresh company list
  }

  Future<List<Map<String, dynamic>>> fetchMedicines({String searchQuery = ''}) async {
    List<Map<String, dynamic>> rawResults = [];
    final query = searchQuery.trim();

    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet connection.");
        return [];
      }

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        debugPrint("❌ No active session.");
        return [];
      }

      // 2. Fetch User's Business Name first
      final userDoc = await supabase
          .from('users')
          .select('business_name')
          .eq('id', userId)
          .maybeSingle();

      final userBusiness = userDoc?['business_name'];

      if (userBusiness == null) {
        debugPrint("⚠️ User has no business assigned.");
        return [];
      }

      // 3. Fetch Medicines filtered by that Business Name
      var supabaseQuery = supabase
          .from('medicines')
          .select()
          .eq('business_name', userBusiness); // Filter applied here

      if (query.isNotEmpty) {
        // Search logic restricted to the user's business
        supabaseQuery = supabaseQuery.or(
            'name.ilike.%$query%,'
                'company.ilike.%$query%,'
                'batch_number.ilike.%$query%'
        );
      }

      final response = await supabaseQuery.order('name', ascending: true);

      if (response is List) {
        rawResults = List<Map<String, dynamic>>.from(response);
      }

      // 4. Transform Data
      return rawResults.map((medicine) {
        final mutable = Map<String, dynamic>.from(medicine);

        int remainingQty = _parseToInt(mutable['remaining_quantity']);
        int totalQty = _parseToInt(mutable['total_quantity']);

        mutable['remaining_quantity'] = remainingQty < 0 ? 0 : remainingQty;
        mutable['total_quantity'] = totalQty;
        mutable['sold_quantity'] = (totalQty - remainingQty) < 0 ? 0 : (totalQty - remainingQty);

        // Expiry Logic
        final expiryStr = mutable['expiry_date']?.toString();
        bool isExpired = false;
        if (expiryStr != null && expiryStr.isNotEmpty) {
          try {
            DateTime expiryDate = DateTime.parse(expiryStr);
            DateTime now = DateTime.now();
            isExpired = expiryDate.isBefore(DateTime(now.year, now.month, now.day));
          } catch (_) {}
        }

        // Status tagging
        if (isExpired) {
          mutable['status'] = 'Expired';
          mutable['isExpiredLabel'] = 'EXPIRED';
        } else if (remainingQty < 1) {
          mutable['status'] = 'Out of Stock';
        } else {
          mutable['status'] = 'Available';
        }

        return mutable;
      }).toList();

    } catch (e) {
      debugPrint('❌ Fatal Error in fetchMedicines: $e');
      return [];
    }
  }

// Helper to handle mixed types from SQLite (Real) and Supabase (Int/Numeric)
  int _parseToInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  Future<Map<String, dynamic>> fetchMedicineDetails(String id) async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet connection. Cannot fetch medicine details.");
        return {};
      }

      // 2. Fetch directly from Supabase
      final supabase = Supabase.instance.client;

      // Note: We use String id because Supabase IDs are usually UUIDs
      final response = await supabase
          .from('medicines')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        debugPrint("✅ Details loaded from Supabase");
        return Map<String, dynamic>.from(response);
      } else {
        debugPrint("⚠️ No medicine found with ID: $id");
        return {};
      }

    } catch (e) {
      debugPrint('❌ Error in fetchMedicineDetails (Supabase): $e');
      return {};
    }
  }

  Future<void> deleteMedicine(dynamic id) async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No internet connection.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final supabase = Supabase.instance.client;

      // Use .eq('id', id) - Supabase client handles the int/string
      // conversion internally if the variable type matches the DB.
      await supabase
          .from('medicines')
          .delete()
          .eq('id', id);

      debugPrint("✅ Medicine ID $id deleted from Supabase");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Product deleted successfully.'),
          backgroundColor: Colors.redAccent,
        ));
        loadMedicines(); // Refresh the list
      }
    } catch (e) {
      debugPrint("❌ Delete Error: $e");
    }
  }

  Future<void> saveToDeletedTable(Map<String, dynamic> medicine) async {
    final String now = DateTime.now().toIso8601String();

    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet. Could not save to deleted logs in Supabase.");
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Prepare and Insert directly to Supabase
      // Note: 'businessName' should be your global variable or passed via 'medicine'
      await supabase.from('deleted_medicines').insert({
        'name': medicine['name'] ?? 'Unknown',
        'company': medicine['company'] ?? 'Unknown',
        'total_quantity': _parseToInt(medicine['total_quantity']),
        'remaining_quantity': _parseToInt(medicine['remaining_quantity']),
        'buy': _parseToDouble(medicine['buy']),
        'price': _parseToDouble(medicine['price']),
        'batch_number': (medicine['batch_number'] ?? medicine['batchNumber'] ?? '').toString(),
        'manufacture_date': medicine['manufacture_date'] ?? '',
        'expiry_date': medicine['expiry_date'] ?? '',
        'added_by': medicine['added_by']?.toString() ?? 'Admin',
        'discount': _parseToDouble(medicine['discount']),
        'date_added': medicine['date_added'] ?? now,
        'unit': medicine['unit'] ?? 'Per Item',
        'business_name': businessName, // Your global variable
        'deleted_date': now,
      });

      debugPrint("✅ Deleted record saved directly to Supabase logs");

    } catch (e) {
      debugPrint("❌ Fatal Error in saveToDeletedTable (Supabase): $e");
    }
  }


  double _parseToDouble(dynamic value) => double.tryParse(value.toString()) ?? 0.0;

  Future<void> addOrReAddMedicineWithUpdates(
      Map<String, dynamic> medicine,
      int quantityToAdd,
      String batchNumber,
      String newCompany,
      String newMfgDate,
      String newExpDate,
      ) async {
    final now = DateTime.now().toIso8601String();
    final supabase = Supabase.instance.client;
    final String medicineId = medicine['id'].toString();

    // FIX: Get business_name from medicine record if variable is null
    String bName = businessName ?? medicine['business_name'] ?? 'Unknown Business';

    String actionType = "";

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) return;

    try {
      int remainingQty = _parseToInt(medicine['remaining_quantity']);
      int totalQty = _parseToInt(medicine['total_quantity']);
      int finalTotal;
      int finalRemaining;

      if (remainingQty < 1) {
        actionType = "Stock Re-added (Restocked)";
        finalTotal = quantityToAdd;
        finalRemaining = quantityToAdd;
      } else {
        actionType = "Stock Updated (Added +$quantityToAdd)";
        finalTotal = totalQty + quantityToAdd;
        finalRemaining = remainingQty + quantityToAdd;
      }

      // 1. UPDATE MEDICINES TABLE
      await supabase.from('medicines').update({
        'company': newCompany,
        'total_quantity': finalTotal,
        'remaining_quantity': finalRemaining,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate,
        'expiry_date': newExpDate,
        'added_time': now,
        'business_name': bName,
      }).eq('id', medicineId);

      // 2. SAVE TO MEDICAL_LOGS TABLE
      await supabase.from('medical_logs').insert({
        'medicine_name': medicine['name'],
        'company': newCompany,
        'total_quantity': quantityToAdd,
        'remaining_quantity': finalRemaining,
        'buy_price': _parseToDouble(medicine['buy']),
        'selling_price': _parseToDouble(medicine['price']),
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate,
        'expiry_date': newExpDate,
        'added_by': medicine['added_by'] ?? 'Admin',
        'discount': _parseToDouble(medicine['discount']),
        'unit': medicine['unit'],
        'business_name': bName,
        'date_added': now,
        'action': actionType,
        'synced': true,
      });

      debugPrint("✅ Saved for Business: $bName");

      // 🚀 3. SEND EMAIL NOTIFICATION (Strictly to this Business Admins)
      await sendAdminNotification(
        name: medicine['name'] ?? 'Unknown',
        company: newCompany,
        quantity: quantityToAdd,
        price: _parseToDouble(medicine['price']),
        buy: _parseToDouble(medicine['buy']),
        batch_number: batchNumber,
        addedBy: medicine['added_by'] ?? 'Admin',
        discount: _parseToDouble(medicine['discount']),
        unit: medicine['unit'] ?? 'Items',
        // Pass the business name to be used as the Sender Display Name
        businessName: bName,
      );

      loadMedicines();

    } catch (e) {
      debugPrint("❌ Supabase update/log/email error: $e");
    }
  }
  // ================== Build UI ==================
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
          "VIEW NORMAL PRODUCT",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 1.2),
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
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Branch Header Card (Adaptive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 10
                  )
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: primaryPurple),
                  const SizedBox(width: 10),
                  Text('BRANCH: $businessName',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? lightViolet : deepPurple,
                          fontSize: 16
                      )),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Search Field (Adaptive)
            TextField(
              controller: searchController,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: subTextCol),
                prefixIcon: const Icon(Icons.search, color: primaryPurple),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: isDark ? Colors.white10 : primaryPurple.withOpacity(0.1)),
                ),
              ),
              onChanged: (v) {
                setState(() {
                  searchQuery = v;
                  medicines = fetchMedicines(searchQuery: v);
                });
              },
            ),
            const SizedBox(height: 15),

            // ===== Table Header (Fixed deepPurple for contrast) =====
            Container(
              decoration: const BoxDecoration(
                color: deepPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Rem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(
                      flex: 2,
                      child: Text('Action',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          textAlign: TextAlign.center
                      )
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: medicines,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryPurple));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No product found.', style: TextStyle(color: subTextCol)));
                  }
                  final medList = snapshot.data!;
                  return ListView.builder(
                    itemCount: medList.length,
                    itemBuilder: (context, index) {
                      final med = medList[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? cardColor : (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9F8FF)),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Row(
                            children: [
                              Expanded(flex: 3, child: Text(med['name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textCol))),
                              Expanded(flex: 1, child: Text('${med['total_quantity'] ?? 0}', style: TextStyle(fontSize: 11, color: textCol))),
                              Expanded(flex: 1, child: Text('${med['remaining_quantity'] ?? 0}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (med['remaining_quantity'] ?? 0) < 5 ? Colors.red : Colors.green))),
                              Expanded(flex: 2, child: Text('${med['price'] ?? 0}', style: TextStyle(fontSize: 11, color: isDark ? lightViolet : deepPurple))),
                              Expanded(flex: 2, child: Text(med['expiry_date'] ?? '', style: TextStyle(fontSize: 10, color: subTextCol))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ADD STOCK
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                                onPressed: () async {
                                  _selectedCompany = med['company']?.toString() ?? '';
                                  if (_selectedCompany.isEmpty) _selectedCompany = uniqueCompanies.firstOrNull ?? '';
                                  final qtyController = TextEditingController();
                                  final batchController = TextEditingController(text: med['batch_number']?.toString() ?? '');
                                  final mfgDateController = TextEditingController(text: med['manufacture_date']?.toString() ?? '');
                                  final expDateController = TextEditingController(text: med['expiry_date']?.toString() ?? '');
                                  final formKey = GlobalKey<FormState>();

                                  final result = await showDialog<Map<String, String>?>(
                                    context: context,
                                    builder: (context) => StatefulBuilder(
                                      builder: (context, setStateInDialog) {
                                        return AlertDialog(
                                          backgroundColor: cardColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: Text('Add Stock: ${med['name']}', style: TextStyle(color: isDark ? lightViolet : deepPurple, fontSize: 18)),
                                          content: Form(
                                            key: formKey,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  DropdownSearch<String>(
                                                    items: uniqueCompanies,
                                                    selectedItem: _selectedCompany,
                                                    onChanged: (newValue) => setStateInDialog(() => _selectedCompany = newValue!),
                                                    dropdownBuilder: (context, selectedItem) => Text(selectedItem ?? "", style: TextStyle(color: textCol)),
                                                    dropdownDecoratorProps: DropDownDecoratorProps(
                                                      dropdownSearchDecoration: InputDecoration(
                                                        labelText: 'Company',
                                                        labelStyle: TextStyle(color: subTextCol),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey), borderRadius: BorderRadius.circular(12)),
                                                      ),
                                                    ),
                                                    popupProps: PopupProps.menu(
                                                      showSearchBox: true,
                                                      menuProps: MenuProps(backgroundColor: cardColor),
                                                      itemBuilder: (context, item, isSelected) => ListTile(title: Text(item, style: TextStyle(color: textCol))),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextFormField(
                                                    controller: qtyController,
                                                    style: TextStyle(color: textCol),
                                                    keyboardType: TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: "Quantity",
                                                      labelStyle: TextStyle(color: subTextCol),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey), borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    validator: (val) => (val == null || int.tryParse(val) == null) ? 'Invalid qty' : null,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _buildNormalDatePicker(context, mfgDateController, "Mfg Date"),
                                                  const SizedBox(height: 12),
                                                  _buildNormalDatePicker(context, expDateController, "Exp Date"),
                                                ],
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: subTextCol))),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
                                              onPressed: () {
                                                if (formKey.currentState!.validate()) {
                                                  Navigator.pop(context, {
                                                    'quantity': qtyController.text,
                                                    'batch_number': batchController.text,
                                                    'company': _selectedCompany,
                                                    'manufacture_date': mfgDateController.text,
                                                    'expiry_date': expDateController.text,
                                                  });
                                                }
                                              },
                                              child: const Text('Add', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );
                                  if (result != null) {
                                    await addOrReAddMedicineWithUpdates(med, int.parse(result['quantity']!), result['batch_number']!, result['company']!, result['manufacture_date']!, result['expiry_date']!);
                                  }
                                },
                              ),
                              // EDIT
                              IconButton(
                                icon: const Icon(Icons.edit_note, color: Colors.green, size: 20),
                                onPressed: () {
                                  final rawSynced = med['synced'];
                                  int safeSynced = (rawSynced is bool) ? (rawSynced ? 1 : 0) : (rawSynced ?? 0);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditMedicineScreen(
                                        // ... parameters ...
                                        id: med['id'],
                                        name: med['name']?.toString() ?? '',
                                        company: med['company']?.toString() ?? '',
                                        total_quantity: med['total_quantity'] ?? 0,
                                        remaining_quantity: med['remaining_quantity'] ?? 0,
                                        buy: (med['buy'] ?? 0).toDouble(),
                                        price: (med['price'] ?? 0).toDouble(),
                                        batchNumber: med['batch_number']?.toString() ?? '',
                                        manufacturedDate: med['manufacture_date']?.toString() ?? '',
                                        expiryDate: med['expiry_date']?.toString() ?? '',
                                        added_by: med['added_by']?.toString() ?? '',
                                        discount: (med['discount'] ?? 0).toDouble(),
                                        added_time: med['added_time']?.toString() ?? '',
                                        unit: med['unit'] ?? '',
                                        businessName: med['business_name']?.toString() ?? '',
                                        synced: safeSynced,
                                      ),
                                    ),
                                  ).then((_) => loadMedicines());
                                },
                              ),
                              // DELETE
                              // Inside your ListView.builder trailing actions:
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () {
                                  // Show confirmation dialog
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text("Delete Product"),
                                      content: const Text("Are you sure you want to delete this?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            // FIX IS HERE: .toString()
                                            await deleteMedicine(med['id'].toString());
                                            await saveToDeletedTable(med);
                                          },
                                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryPurple,
        onPressed: () async {
          final list = await medicines;
          if (list.isNotEmpty) { /* generatePdf(list); */ }
        },
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
    );
  }

// Helper for Date Pickers to avoid repetition and errors
  Widget _buildNormalDatePicker(BuildContext context, TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) {
          controller.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      },
    );
  }
}