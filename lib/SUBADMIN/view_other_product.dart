import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:sqflite/sqflite.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'Edit_other_product.dart';

class ViewOtherProductScreen extends StatefulWidget {
  const ViewOtherProductScreen({super.key, required Map<String, dynamic> user});

  @override
  _ViewOtherProductScreenState createState() => _ViewOtherProductScreenState();
}

class _ViewOtherProductScreenState extends State<ViewOtherProductScreen> {
  late Future<List<Map<String, dynamic>>> products;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String businessName = "";
  String businessEmail = "";
  String businessPhone = "";
  String businessLocation = "";
  String businessLogoPath = "";
  String address = "";
  String whatsapp = "";
  String lipaNumber = "";
  bool _isDarkMode = false;
  List<String> uniqueCompanies = [];
  String _selectedCompany = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    loadProducts();
    initializeData();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> initializeData() async {
    await getBusinessInfo();
    await fetchUniqueCompanies();
    loadProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchUniqueCompanies() async {
    try {
      // 1. Check Internet Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch companies from Supabase.");
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch company names from Supabase
      // We select only the 'company' column to save data
      final response = await supabase
          .from('other_product')
          .select('company');

      if (response is List) {
        // 3. Process data: Filter nulls, trim, remove duplicates with toSet()
        final List<String> fetchedCompanies = response
            .map((item) => item['company']?.toString().trim() ?? '')
            .where((name) => name.isNotEmpty && name.toLowerCase() != 'null')
            .toSet() // Automatically removes duplicates
            .toList();

        // 4. Sort alphabetically
        fetchedCompanies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        // 5. Update UI
        if (mounted) {
          setState(() {
            uniqueCompanies = fetchedCompanies;
          });
          debugPrint("✅ Unique companies fetched from Supabase: ${uniqueCompanies.length}");
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching unique companies from Supabase: $e');
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch business info.");
        return;
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint("⚠️ No active session found.");
        return;
      }

      // 2. Fetch User Profile to get their Business Name
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null || userProfile['business_name'] == null) {
        debugPrint("⚠️ Current user has no business assigned.");
        return;
      }

      String userBusiness = userProfile['business_name'];
      debugPrint("🔍 Fetching details for business: $userBusiness");

      // 3. Fetch specific business details
      final businessData = await supabase
          .from('businesses')
          .select()
          .eq('business_name', userBusiness)
          .maybeSingle();

      if (businessData != null) {
        // 4. Update UI State
        if (mounted) {
          _applyDataToState(businessData);
        }
        debugPrint("✅ Business info loaded for: $userBusiness");
      } else {
        debugPrint("⚠️ Business details not found for '$userBusiness'.");
      }

    } catch (e) {
      debugPrint('❌ Supabase Business Info Error: $e');
    }
  }


// Helper method to update variables and refresh UI
  void _applyDataToState(Map<String, dynamic> data) {
    setState(() {
      businessName = data['business_name']?.toString() ?? '';
      businessEmail = data['email']?.toString() ?? '';
      businessPhone = data['phone']?.toString() ?? '';
      businessLocation = data['location']?.toString() ?? '';
      businessLogoPath = data['logo']?.toString() ?? ''; // Maps to 'logo' in DB
      address = data['address']?.toString() ?? '';
      whatsapp = data['whatsapp']?.toString() ?? '';
      lipaNumber = data['lipa_number']?.toString() ?? ''; // Maps to 'lipa_number'
    });
  }

  void loadProducts() {
    setState(() {
      products = fetchProducts(searchQuery: searchQuery);
    });
    fetchUniqueCompanies();
  }

  bool isExpired(String? expiryDateStr) {
    if (expiryDateStr == null || expiryDateStr.isEmpty) return false;
    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      final today = DateTime.now();
      return expiryDate.isBefore(today);
    } catch (e) {
      return false;
    }
  }
  Future<void> sendAdminNotification({
    required String name,
    required String company,
    required int quantity,
    required double price,
    required double buy,
    required String batchNumber,
    required String addedBy,
    required double discount,
    required String unit,
  }) async {
    print('🟡 [DEBUG] sendAdminNotification called');
    try {
      final emails = await getAllAdminEmails();
      print('📧 [DEBUG] Retrieved admin emails: $emails');

      if (emails.isEmpty) {
        print('⚠️ [DEBUG] No admin emails found');
        return;
      }

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );
      print('🔐 [DEBUG] SMTP server configured');

      final htmlContent = '''
<html>
<body>
<h2>🆕 New Product Added</h2>
<table border="1" cellpadding="5">
<tr><td>Name</td><td>$name</td></tr>
<tr><td>Company</td><td>$company</td></tr>
<tr><td>Quantity</td><td>$quantity</td></tr>
<tr><td>Buy Price</td><td>$buy</td></tr>
<tr><td>Selling Price</td><td>$price</td></tr>
<tr><td>Batch</td><td>$batchNumber</td></tr>
<tr><td>Unit</td><td>$unit</td></tr>
<tr><td>Discount</td><td>$discount%</td></tr>
<tr><td>Added By</td><td>$addedBy</td></tr>
</table>
</body>
</html>
''';

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK & INVENTORY SOFTWARE')
        ..recipients.addAll(emails)
        ..subject = '🆕 New Product Added: $name'
        ..html = htmlContent;

      print('📨 [DEBUG] Sending email...');
      final sendReport = await send(message, smtpServer);
      print('✅ [DEBUG] Email sent: $sendReport');
    } catch (e) {
      print('❌ [DEBUG] Failed to send admin email: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts({String searchQuery = ''}) async {
    final query = searchQuery.trim();

    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 Offline: Cannot fetch products.");
        return [];
      }

      final supabase = Supabase.instance.client;

      // 2. Build Supabase Query
      var supabaseQuery = supabase.from('other_product').select();

      // 3. Apply Search Filter (Cloud-side)
      if (query.isNotEmpty) {
        // .ilike is case-insensitive search
        supabaseQuery = supabaseQuery.or(
            'name.ilike.%$query%,'
                'company.ilike.%$query%,'
                'batch_number.ilike.%$query%,'
                'added_by.ilike.%$query%,'
                'unit.ilike.%$query%'
        );
      }

      // 4. Fetch and Sort
      final response = await supabaseQuery.order('name', ascending: true);
      final List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);

      // 5. Data Transformation (Calculating Status & Stock)
      return rawData.map((product) {
        final mutable = Map<String, dynamic>.from(product);

        // Remaining Quantity Calculation
        final double qtyRaw = double.tryParse(mutable['remaining_quantity']?.toString() ?? '0') ?? 0.0;
        final int qty = qtyRaw < 0 ? 0 : qtyRaw.toInt();

        mutable['remaining_quantity'] = qty;
        mutable['status'] = qty < 1 ? 'OUT OF STOCK' : 'Available';

        // Sold Quantity Calculation
        final int totalQty = int.tryParse(mutable['total_quantity']?.toString() ?? '0') ?? 0;
        mutable['sold_quantity'] = (totalQty - qty) < 0 ? 0 : (totalQty - qty);

        // Expiry Check (Assumes your isExpired helper is accessible)
        mutable['expired'] = isExpired(mutable['expiry_date']?.toString()) ? 'EXPIRED' : '';

        return mutable;
      }).toList();

    } catch (e) {
      debugPrint('❌ Supabase Fetch Error: $e');
      return [];
    }
  }

  Future<void> deleteProduct(dynamic supabaseId) async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final supabase = Supabase.instance.client;

      // 2. Online Delete (Supabase)
      // We filter by ID and business_name to satisfy the RLS policy you created
      await supabase
          .from('other_product')
          .delete()
          .eq('id', supabaseId)
          .eq('business_name', businessName); // Using your global businessName variable

      debugPrint("✅ Deleted from Supabase for $businessName");

      // 3. UI Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product deleted from $businessName cloud!'),
            backgroundColor: Colors.redAccent,
          ),
        );

        // 4. Refresh your UI list
        loadProducts();
      }

    } catch (e) {
      debugPrint("❌ Error in Supabase delete: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error deleting product from cloud'),
              backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  Future<List<String>> getAllAdminEmails() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("❌ No internet connection. Cannot fetch admin emails.");
        return [];
      }

      final supabase = Supabase.instance.client;

      // 2. Fetch from Supabase
      // We select only the 'email' column to keep the payload small
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

        debugPrint("✅ Fetched ${emailList.length} admin emails from Supabase.");
        return emailList;
      }

      return [];
    } catch (e) {
      debugPrint("❌ Error fetching admin emails from Supabase: $e");
      return [];
    }
  }



  // UPDATED: Now accepts newCompany, newMfgDate, and newExpDate
  Future<void> addOrReAddProduct(
      Map<String, dynamic> product,
      int quantityToAdd,
      String batchNumber,
      String newCompany,
      String newMfgDate,
      String newExpDate,
      ) async {
    final now = DateTime.now().toIso8601String();
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      // 1. Fetch Verified Identity (Strict Mode)
      final userRes = await supabase
          .from('users')
          .select('business_name, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final String myBusiness = userRes?['business_name'] ?? 'Unknown';
      final String myName = userRes?['full_name'] ?? 'Unknown';

      int remainingQty = int.tryParse(product['remaining_quantity']?.toString() ?? '0') ?? 0;
      int totalQty = int.tryParse(product['total_quantity']?.toString() ?? '0') ?? 0;
      String productName = product['name'] ?? '';
      int productId = product['id'];

      if (remainingQty < 1) {
        // --- CASE 1: RE-ADD ---
        // We delete and re-insert to reset the 'serial' behavior or clear old metadata
        await supabase.from('other_product')
            .delete()
            .eq('id', productId)
            .eq('business_name', myBusiness); // Strict Lock

        await supabase.from('other_product').insert({
          'name': productName,
          'company': newCompany,
          'total_quantity': quantityToAdd,
          'remaining_quantity': quantityToAdd,
          'buy_price': product['buy_price'] ?? 0,
          'selling_price': product['selling_price'] ?? 0,
          'batch_number': batchNumber,
          'manufacture_date': newMfgDate,
          'expiry_date': newExpDate,
          'added_by': myName,
          'discount': product['discount'] ?? 0,
          'unit': product['unit'] ?? '',
          'business_name': myBusiness,
          'date_added': now,
        });
      } else {
        // --- CASE 2: ADD MORE UNITS (UPDATE) ---
        await supabase.from('other_product')
            .update({
          'total_quantity': totalQty + quantityToAdd,
          'remaining_quantity': remainingQty + quantityToAdd,
          'batch_number': batchNumber,
          'company': newCompany,
          'manufacture_date': newMfgDate,
          'expiry_date': newExpDate,
          'last_updated': now, // Keep track of the update
        })
            .eq('id', productId)
            .eq('business_name', myBusiness); // Strict Lock
      }

      // --- STEP 3: LOGGING (FIXED FOR PGRST204) ---
      // Change 'product_name' to 'name' to match your schema
      await supabase.from('other_product_logs').insert({
        'name': productName, // FIX: Matches your table schema
        'company': newCompany,
        'total_quantity': remainingQty < 1 ? quantityToAdd : totalQty + quantityToAdd,
        'remaining_quantity': remainingQty < 1 ? quantityToAdd : remainingQty + quantityToAdd,
        'buy_price': product['buy_price'] ?? 0,
        'selling_price': product['selling_price'] ?? 0,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate,
        'expiry_date': newExpDate,
        'added_by': myName,
        'discount': product['discount'] ?? 0,
        'unit': product['unit'] ?? '',
        'business_name': myBusiness,
        'date_added': now,
        'action': remainingQty < 1 ? 'Re-added product' : 'Added more units',
      });

      // 4. Notifications & UI Refresh
      sendAdminNotification(
        name: productName,
        company: newCompany,
        quantity: quantityToAdd,
        price: product['selling_price']?.toDouble() ?? 0,
        buy: product['buy_price']?.toDouble() ?? 0,
        batchNumber: batchNumber,
        addedBy: myName,
        discount: product['discount']?.toDouble() ?? 0,
        unit: product['unit'] ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$productName updated with $quantityToAdd units'), backgroundColor: Colors.teal),
        );
        loadProducts();
      }

    } catch (e) {
      debugPrint("❌ Fatal Error in addOrReAddProduct: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update product on Cloud'), backgroundColor: Colors.red),
        );
      }
    }
  }
  // ================== PDF Export ==================
  Future<Uint8List> generatePdf(
      List<Map<String, dynamic>> productsList, {
        bool returnBytes = false,
      }) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('user') ?? '.........................';
    final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pw.ImageProvider? logoImage;
    if (businessLogoPath.isNotEmpty) {
      final file = File(businessLogoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          // Business Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName.isNotEmpty ? businessName : 'STOCK & INVENTORY SOFTWARE',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  if (businessLocation.isNotEmpty)
                    pw.Text('Location: $businessLocation', style: const pw.TextStyle(fontSize: 10)),
                  if (businessPhone.isNotEmpty)
                    pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10)),
                  if (businessEmail.isNotEmpty)
                    pw.Text('Email: $businessEmail', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Generated by $user on $timestamp', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (logoImage != null)
                pw.Container(height: 50, width: 50, child: pw.Image(logoImage)),
            ],
          ),

          pw.SizedBox(height: 15),
          pw.Text(
            'OTHER PRODUCT STOCK LIST',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          // Table
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
            ),
            data: [
              [
                'Name', 'Batch', 'Company', 'Buy', 'Price', 'Total Qty',
                'Sold Qty', 'Remaining', 'Status', 'Expired', 'Unit',
                'Mfg', 'Expiry', 'Staff', 'Added'
              ],
              ...productsList.map((m) => [
                m['name']?.toString() ?? '',
                m['batch_number']?.toString() ?? '',
                m['company']?.toString() ?? '',
                'TSH ${NumberFormat('#,##0.00').format(double.tryParse(m['buy_price']?.toString() ?? '0') ?? 0)}',
                'TSH ${NumberFormat('#,##0.00').format(double.tryParse(m['selling_price']?.toString() ?? '0') ?? 0)}',
                m['total_quantity']?.toString() ?? '0',
                m['sold_quantity']?.toString() ?? '0',
                m['remaining_quantity']?.toString() ?? '0',
                m['status']?.toString() ?? '',
                m['expired']?.toString() ?? '',
                m['unit']?.toString() ?? '',
                m['manufacture_date']?.toString() ?? '',
                m['expiry_date']?.toString() ?? '',
                m['added_by']?.toString() ?? '',
                m['date_added']?.toString() ?? '',
              ])
            ],
          ),
        ],
      ),
    );

    if (returnBytes) {
      return pdf.save();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Other_Products_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.readAsBytes();
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
          "OTHER PRODUCT WINDOWS",
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
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10)
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, color: primaryPurple),
                  const SizedBox(width: 10),
                  Text('BRANCH: $businessName',
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? lightViolet : deepPurple, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Modern Search Field (Adaptive)
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
                  products = fetchProducts(searchQuery: v);
                });
              },
            ),
            const SizedBox(height: 15),

            // ===== Table Header (Purple Style) =====
            Container(
              decoration: const BoxDecoration(
                color: deepPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Product Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Rem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(
                      flex: 2,
                      child: Text(
                        'Action',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        textAlign: TextAlign.center,
                      )
                  ),
                ],
              ),
            ),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: products,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryPurple));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No products found.', style: TextStyle(color: subTextCol)));
                  }

                  final productList = snapshot.data!;
                  return ListView.builder(
                    itemCount: productList.length,
                    itemBuilder: (context, index) {
                      final p = productList[index];
                      final expiredText = p['expired'] ?? '';

                      return Container(
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? cardColor : (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9F8FF)),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Row(
                            children: [
                              Expanded(flex: 3, child: Text(p['name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textCol))),
                              Expanded(flex: 1, child: Text('${p['total_quantity'] ?? 0}', style: TextStyle(fontSize: 11, color: textCol))),
                              Expanded(flex: 1, child: Text('${p['remaining_quantity'] ?? 0}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (p['remaining_quantity'] ?? 0) < 5 ? Colors.red : Colors.green))),
                              Expanded(flex: 2, child: Text('${p['selling_price'] ?? 0}', style: TextStyle(fontSize: 11, color: isDark ? lightViolet : deepPurple))),
                              Expanded(flex: 2, child: Text(p['expiry_date'] ?? '',
                                  style: TextStyle(fontSize: 10, color: expiredText == 'EXPIRED' ? Colors.red : subTextCol))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 20),
                                onPressed: () async {
                                  _selectedCompany = p['company']?.toString() ?? '';
                                  if (_selectedCompany.isEmpty) _selectedCompany = uniqueCompanies.firstOrNull ?? '';

                                  final qtyController = TextEditingController();
                                  final batchController = TextEditingController(text: p['batch_number'] ?? '');
                                  final mfgDateController = TextEditingController(text: p['manufacture_date'] ?? '');
                                  final expDateController = TextEditingController(text: p['expiry_date'] ?? '');
                                  final formKey = GlobalKey<FormState>();

                                  final result = await showDialog<Map<String, String>?>(
                                    context: context,
                                    builder: (context) => StatefulBuilder(
                                      builder: (context, setStateInDialog) {
                                        return AlertDialog(
                                          backgroundColor: cardColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                          title: Text('Add Stock: ${p['name']}', style: TextStyle(color: isDark ? lightViolet : deepPurple, fontSize: 18)),
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
                                                        labelText: "Company",
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
                                                  TextFormField(
                                                    controller: batchController,
                                                    style: TextStyle(color: textCol),
                                                    decoration: InputDecoration(
                                                      labelText: "Batch No",
                                                      labelStyle: TextStyle(color: subTextCol),
                                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey), borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  _buildDatePickerField(context, mfgDateController, "Mfg Date"),
                                                  const SizedBox(height: 12),
                                                  _buildDatePickerField(context, expDateController, "Exp Date"),
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
                                                    'batchNumber': batchController.text,
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
                                    await addOrReAddProduct(p, int.parse(result['quantity']!), result['batchNumber']!, result['company']!, result['manufacture_date']!, result['expiry_date']!);
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_note, color: Colors.green, size: 20),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EditOtherProductScreen(
                                        id: p['id'],
                                        name: p['name'] ?? '',
                                        company: p['company'] ?? '',
                                        total_quantity: p['total_quantity'] ?? 0,
                                        remaining_quantity: p['remaining_quantity'] ?? 0,
                                        buy_price: (p['buy_price'] ?? 0).toDouble(),
                                        selling_price: (p['selling_price'] ?? 0).toDouble(),
                                        batch_number: p['batch_number'] ?? '',
                                        manufacture_date: p['manufacture_date'] ?? '',
                                        expiry_date: p['expiry_date'] ?? '',
                                        added_by: p['added_by'] ?? '',
                                        discount: (p['discount'] ?? 0).toDouble(),
                                        date_added: p['date_added'] ?? '',
                                        unit: p['unit'] ?? '',
                                        businessName: p['business_name'] ?? '',
                                        synced: p['synced'] ?? 0,
                                      ),
                                    ),
                                  ).then((_) => loadProducts());
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: cardColor,
                                      title: Text('Delete', style: TextStyle(color: textCol)),
                                      content: Text('Are you sure?', style: TextStyle(color: subTextCol)),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) await deleteProduct(p['id']);
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
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text("PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        onPressed: () async {
          final list = await products;
          if (list.isEmpty) return;
          String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
          if (selectedDirectory == null) return;
          final filePath = "$selectedDirectory/Products_${DateTime.now().millisecondsSinceEpoch}.pdf";
          final pdfFile = File(filePath);
          await pdfFile.writeAsBytes(await generatePdf(list));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: $filePath')));
        },
      ),
    );
  }

// Helper method to keep build method clean and prevent errors
  Widget _buildDatePickerField(BuildContext context, TextEditingController controller, String label) {
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