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
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:file_saver/file_saver.dart';
class AViewOtherProductScreen extends StatefulWidget {
  const AViewOtherProductScreen({super.key, required Map<String, dynamic> user});

  @override
  _AViewOtherProductScreenState createState() => _AViewOtherProductScreenState();
}

class _AViewOtherProductScreenState extends State<AViewOtherProductScreen> {
  late Future<List<Map<String, dynamic>>> products;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String businessName = "";
  String userRole = '';
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
  final ScreenshotController _screenshotController = ScreenshotController();
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

// Kwenye State ongeza:


  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Tunatumia select kisha tunachukua ya kwanza ili kuepuka error 406
      final List<dynamic> response = await supabase
          .from('users')
          .select('business_name, sub_business_name, role')
          .eq('id', userId)
          .limit(1);

      if (response.isNotEmpty) {
        final data = response.first;
        setState(() {
          userRole = (data['role'] ?? '').toString().toLowerCase();
          String mainBiz = data['business_name'] ?? '';
          String? subBiz = data['sub_business_name'];

          if (subBiz != null && subBiz.isNotEmpty) {
            businessName = subBiz.toUpperCase();
          } else {
            businessName = mainBiz.toUpperCase();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Business Info Error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts({String searchQuery = ''}) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // 1. Pata Profile ya mtumiaji bila kutumia .single() inayoweza kuleta error
      final List<dynamic> userCheck = await supabase
          .from('users')
          .select('business_id, sub_business_name, role')
          .eq('id', userId);

      if (userCheck.isEmpty) return [];
      final user = userCheck.first;

      final myBusinessId = user['business_id'];
      if (myBusinessId == null) return [];

      // 2. Anza kuvuta bidhaa zinazohusu Business ID hii TU
      var query = supabase
          .from('other_product')
          .select()
          .eq('business_id', myBusinessId);

      // 3. Logic ya Branch/Sub-business
      if (user['role'].toString().toLowerCase() != 'storekeeper') {
        if (user['sub_business_name'] != null && user['sub_business_name'].toString().isNotEmpty) {
          query = query.eq('sub_business_name', user['sub_business_name']);
        } else {
          // Main Branch
          query = query.or('sub_business_name.is.null,sub_business_name.eq."",sub_business_name.eq."Main Branch"');
        }
      }

      // 4. Search Filter
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim();
        query = query.or('name.ilike.%$q%,company.ilike.%$q%,batch_number.ilike.%$q%');
      }

      final response = await query.order('name', ascending: true);
      final results = List<Map<String, dynamic>>.from(response);

      // 5. AUTO QR LOGIC (Background)
      _autoGenerateMissingQRCodes(results);

      return results;
    } catch (e) {
      debugPrint('❌ Fetch Products Error: $e');
      return [];
    }
  }
  Future<void> _autoGenerateMissingQRCodes(List<Map<String, dynamic>> list) async {
    final supabase = Supabase.instance.client;

    // Chuja zile ambazo hazina qr_code_url
    final missingQR = list.where((m) =>
    m['qr_code_url'] == null || m['qr_code_url'].toString().trim().isEmpty
    ).toList();

    if (missingQR.isEmpty) return;

    debugPrint('🛠️ Fixing ${missingQR.length} missing QR codes...');

    for (var prod in missingQR) {
      try {
        // Tengeneza data ya QR (Tumia item_code au Product ID)
        final String qrData = (prod['item_code'] != null && prod['item_code'].toString().isNotEmpty)
            ? prod['item_code'].toString()
            : "OTH-${prod['id']}";

        // Update Supabase
        await supabase
            .from('other_product')
            .update({'qr_code_url': qrData})
            .eq('id', prod['id']);

        debugPrint("✅ Fixed QR for: ${prod['name']}");
      } catch (e) {
        debugPrint("❌ Auto-fix failed for ${prod['name']}: $e");
      }
    }

    // Refresh screen mara moja baada ya updates zote
    if (mounted) {
      setState(() {
        products = fetchProducts(searchQuery: searchController.text);
      });
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

  void _showQRCodeDialog(Map<String, dynamic> product) {
    String qrData = (product['qr_code_url'] != null && product['qr_code_url'].toString().isNotEmpty)
        ? product['qr_code_url']
        : "OTH-${product['id']}";
    String productName = product['name'] ?? "Product";

    showDialog(
      context: context,
      barrierDismissible: true, // Inaruhusu kufunga ukibonyeza pembeni
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        // Tunatumia ConstrainedBox kuzuia "No Size" Error kwenye Windows
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sehemu ya Picha ya QR
              Screenshot(
                controller: _screenshotController,
                child: Container(
                  width: 250, // Lazima iwe na size thabiti
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        productName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 15),
                      // QR Image ndani ya SizedBox
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 180.0,
                          gapless: false,
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size(30, 30),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        businessName,
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              // Buttons za Chini
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("CLOSE", style: TextStyle(color: _isDarkMode ? Colors.white70 : Colors.black54)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF311B92),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () async {
                      try {
                        final image = await _screenshotController.capture();
                        if (image != null) {
                          await FileSaver.instance.saveFile(
                            name: "QR_${productName.replaceAll(' ', '_')}",
                            bytes: image,
                            ext: "png",
                            mimeType: MimeType.png,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("✅ QR Imehifadhiwa!"), backgroundColor: Colors.green),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint("Save Error: $e");
                      }
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text("SAVE PNG"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  // ================== Build UI ==================
// --- LOGIC YA KUFUTA BIDHAA ---
  void _handleDeleteProductLogic(BuildContext context, Map<String, dynamic> p, Color cardColor, Color textCol, Color subTextCol) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Delete Product', style: TextStyle(color: textCol)),
        content: Text('Are you sure you want to delete ${p['name']}?', style: TextStyle(color: subTextCol)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('other_product').delete().eq('id', p['id']);
        setState(() {
          products = fetchProducts(searchQuery: searchQuery);
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product deleted successfully")));
      } catch (e) {
        debugPrint("Error deleting: $e");
      }
    }
  }

  // --- LOGIC YA KUFANYA EDIT ---
  void _handleEditProductLogic(BuildContext context, Map<String, dynamic> p) {
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
          businessName: businessName, // Inatoka kwenye variable yako ya juu
          synced: p['synced'] ?? 0,
        ),
      ),
    ).then((_) {
      setState(() {
        products = fetchProducts(searchQuery: searchQuery);
      });
    });
  }
  void _handleAddStockLogic(BuildContext context, Map<String, dynamic> p, Color cardColor, bool isDark, Color lightViolet, Color deepPurple, Color textCol, Color subTextCol, Color primaryPurple) async {
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
                      dropdownDecoratorProps: DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          labelText: "Company",
                          labelStyle: TextStyle(color: subTextCol),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyController,
                      style: TextStyle(color: textCol),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: "Quantity", labelStyle: TextStyle(color: subTextCol), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (val) => (val == null || int.tryParse(val) == null) ? 'Invalid qty' : null,
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
      loadProducts(); // Refresh list
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
            // Branch Header Card
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

            // Search Field
            TextField(
              controller: searchController,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: subTextCol),
                prefixIcon: const Icon(Icons.search, color: primaryPurple),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
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

            // ===== Table Header =====
            Container(
              decoration: const BoxDecoration(
                color: deepPurple,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Product Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 1, child: Text('Rem', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Expiry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('QR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),

            // ===== Table Body =====
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
                      final bool hasQR = p['qr_code_url'] != null && p['qr_code_url'].toString().isNotEmpty;

                      return Container(
                        decoration: BoxDecoration(
                          color: index % 2 == 0 ? cardColor : (isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF9F8FF)),
                          border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(p['name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textCol))),
                              Expanded(flex: 1, child: Text('${p['total_quantity'] ?? 0}', style: TextStyle(fontSize: 11, color: textCol), textAlign: TextAlign.center)),
                              Expanded(flex: 1, child: Text('${p['remaining_quantity'] ?? 0}',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: (p['remaining_quantity'] ?? 0) < 5 ? Colors.red : Colors.green), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('${p['selling_price'] ?? 0}', style: TextStyle(fontSize: 11, color: isDark ? lightViolet : deepPurple))),
                              Expanded(flex: 2, child: Text(p['expiry_date'] ?? '',
                                  style: TextStyle(fontSize: 10, color: p['expired'] == 'EXPIRED' ? Colors.red : subTextCol))),

                              // 🔥 FIXED QR COLUMN 🔥
                              Expanded(
                                flex: 1,
                                child: SizedBox( // Laziisha Size kwa ajili ya hit-test
                                  height: 35,
                                  child: Center(
                                    child: hasQR
                                        ? IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.qr_code_2, color: Colors.green, size: 20),
                                      onPressed: () => _showQRCodeDialog(p),
                                    )
                                        : const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
                                  ),
                                ),
                              ),

                              // 🔥 FIXED ACTION BUTTONS 🔥
                              Expanded(
                                flex: 2,
                                child: SizedBox( // Laziisha Size kwa ajili ya hit-test
                                  height: 35,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min, // Inazuia Row kuchukua nafasi isiyo na mwisho
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30),
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent, size: 18),
                                        onPressed: () => _handleAddStockLogic(context, p, cardColor, isDark, lightViolet, deepPurple, textCol, subTextCol, primaryPurple),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30),
                                        icon: const Icon(Icons.edit_note, color: Colors.green, size: 18),
                                        onPressed: () => _handleEditProductLogic(context, p),
                                      ),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 30),
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () => _handleDeleteProductLogic(context, p, cardColor, textCol, subTextCol),
                                      ),
                                    ],
                                  ),
                                ),
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