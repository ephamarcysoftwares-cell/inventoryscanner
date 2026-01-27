import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

// NOTE: Ensure these imports are correctly set up based on your project structure
// import '../CHATBOAT/chatboat.dart'; // Uncomment if needed in other parts of your app
import '../DB/database_helper.dart'; // Assumed dependency for database access

class ClosingstockViewMedicineScreen extends StatefulWidget {
  const ClosingstockViewMedicineScreen({super.key});

  @override
  _ClosingstockViewMedicineScreenState createState() => _ClosingstockViewMedicineScreenState();
}

class _ClosingstockViewMedicineScreenState extends State<ClosingstockViewMedicineScreen> {
  // --- State Variables ---
  late Future<List<Map<String, dynamic>>> medicines;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String businessName = "";
  double normalUsageTotal = 0.0;

  // Timer for recurring test report send
  Timer? _reportTimer;
  int _reportCount = 0; // Counter to track test sends

  // Business info fields
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';

  // Date filters for products
  DateTime? startDate;
  DateTime? endDate;

  // Date filters for expenses/usage
  DateTime? usageStartDate;
  DateTime? usageEndDate;

  @override
  void initState() {
    super.initState();
    loadMedicines();
    getBusinessName();
    getBusinessInfo();
    fetchTotalNormalUsageAmount().then((value) {
      setState(() {
        normalUsageTotal = value;
      });
      // INITIAL CALL: Run once immediately when the screen starts
      sendTestReport();

      // TIMER SETUP: Set up the recurring timer for 21 minutes
      // IMPORTANT: The timer is set to 21 minutes for testing the recurring send.
      _reportTimer = Timer.periodic(const Duration(minutes: 21), (timer) {
        sendTestReport();
      });
    });
  }

  // CANCELLATION: Crucial step to stop the timer when the screen is closed
  @override
  void dispose() {
    _reportTimer?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  //                          CORE LOGIC FUNCTIONS
  // -----------------------------------------------------------------

  void loadMedicines() {
    setState(() {
      medicines = fetchCombinedMedicines(searchQuery: searchQuery);
    });
  }

  Future<void> getBusinessInfo() async {
    try {
      // NOTE: Replace 'C:\\Users\\Public\\epharmacy\\epharmacy.db' with your actual database path or use DatabaseHelper
      // Assuming DatabaseHelper.instance.database is the standard way, but preserving the raw openDatabase for completeness based on context.
      // If DatabaseHelper is correctly set up, prefer: Database db = await DatabaseHelper.instance.database;
      Database db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name']?.toString() ?? '';
          businessEmail = result[0]['email']?.toString() ?? '';
          businessPhone = result[0]['phone']?.toString() ?? '';
          businessLocation = result[0]['location']?.toString() ?? '';
          businessLogoPath = result[0]['logo']?.toString() ?? '';
          address = result[0]['address']?.toString() ?? '';
          whatsapp = result[0]['whatsapp']?.toString() ?? '';
          lipaNumber = result[0]['lipa_number']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }

  Future<void> getBusinessName() async {
    // --- SHARED PREFERENCES USAGE: Retrieving userId ---
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    if (userId != null) {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'users',
        columns: ['businessName'],
        where: 'id = ?',
        whereArgs: [userId],
      );
      if (result.isNotEmpty) {
        setState(() {
          businessName = result.first['businessName']?.toString() ?? 'Unknown Business';
        });
      }
    }
  }

  Future<double> fetchTotalNormalUsageAmount() async {
    final db = await DatabaseHelper.instance.database;
    String where = '';
    List<dynamic> args = [];

    if (usageStartDate != null) {
      where += (where.isEmpty ? '' : ' AND ') + "date(usage_date) >= date(?)";
      args.add(DateFormat('yyyy-MM-dd').format(usageStartDate!));
    }

    if (usageEndDate != null) {
      where += (where.isEmpty ? '' : ' AND ') + "date(usage_date) <= date(?)";
      args.add(DateFormat('yyyy-MM-dd').format(usageEndDate!));
    }

    final result = await db.query(
      'normal_usage',
      columns: ['SUM(amount) as total'],
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
    );
    final total = result.first['total'];
    return total != null ? (total as num).toDouble() : 0.0;
  }

  // --- Medicine Fetching Functions (Combined for filtering logic) ---

  Future<List<Map<String, dynamic>>> fetchMedicines({String searchQuery = ''}) async {
    final db = await DatabaseHelper.instance.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR company LIKE ? OR expiry_date LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (startDate != null) {
      whereClauses.add("date(added_time) >= date(?)");
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate!));
    }

    if (endDate != null) {
      whereClauses.add("date(added_time) <= date(?)");
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate!));
    }

    final result = await db.query(
      'medicines',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'added_time DESC',
    );

    return result.map((medicine) {
      final mutable = Map<String, dynamic>.from(medicine);
      final qty = int.tryParse(mutable['remaining_quantity']?.toString() ?? '0') ?? 0;
      mutable['remaining_quantity'] = qty < 0 ? 0 : qty;
      mutable['isDeleted'] = false; // Mark as active medicine
      return mutable;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDeletedMedicines({String searchQuery = ''}) async {
    final db = await DatabaseHelper.instance.database;
    List<String> whereClauses = [];
    List<dynamic> whereArgs = [];

    if (searchQuery.trim().isNotEmpty) {
      whereClauses.add('(name LIKE ? OR company LIKE ? OR expiry_date LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }

    if (startDate != null) {
      whereClauses.add("date(date_added) >= date(?)");
      whereArgs.add(DateFormat('yyyy-MM-dd').format(startDate!));
    }

    if (endDate != null) {
      whereClauses.add("date(date_added) <= date(?)");
      whereArgs.add(DateFormat('yyyy-MM-dd').format(endDate!));
    }

    final result = await db.query(
      'deleted_medicines',
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'date_added DESC',
    );

    return result.map((medicine) {
      final mutable = Map<String, dynamic>.from(medicine);
      final qty = int.tryParse(mutable['remaining_quantity']?.toString() ?? '0') ?? 0;
      mutable['remaining_quantity'] = qty < 0 ? 0 : qty;
      mutable['isDeleted'] = true; // Mark as deleted medicine
      return mutable;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCombinedMedicines({String searchQuery = ''}) async {
    final active = await fetchMedicines(searchQuery: searchQuery);
    final deleted = await fetchDeletedMedicines(searchQuery: searchQuery);
    return [...active, ...deleted];
  }

  // --- Filtering & UI Reset ---

  void resetFilters() {
    setState(() {
      startDate = null;
      endDate = null;
      searchQuery = "";
      searchController.clear();
      loadMedicines();
    });
  }

  void resetUsageFilters() {
    setState(() {
      usageStartDate = null;
      usageEndDate = null;
    });
    fetchTotalNormalUsageAmount().then((value) {
      setState(() {
        normalUsageTotal = value;
      });
    });
  }

  // -----------------------------------------------------------------
  //                          WHATSAPP API LOGIC
  // -----------------------------------------------------------------

  // Fetches and normalizes admin phone numbers for WhatsApp
  Future<List<String>> getAdminPhones() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users',
        columns: ['phone'], where: 'role = ?', whereArgs: ['admin']);

    return result.map((row) {
      String phone = row['phone']?.toString().trim() ?? '';
      if (phone.isNotEmpty) {
        phone = phone.replaceAll(RegExp(r'\D'), '');
        // Converts 07... to 2557... (Tanzania, adjust country code as needed)
        if (phone.startsWith('0')) {
          phone = '255' + phone.substring(1);
        } else if (phone.length == 9 && !phone.startsWith('255')) {
          // Assuming 9 digits is a local number missing the country code
          phone = '255' + phone;
        }
      }
      return phone;
    }).toList().where((p) => p.length >= 10).toList();
  }

  // Completes the WhatsApp sending function using http
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      // --- SHARED PREFERENCES USAGE: Retrieving WhatsApp credentials ---
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString('C9CB714B785A') ?? '';
      final accessToken = prefs.getString('jOos7Fc3cE7gj2') ?? '';

      if (instanceId.isEmpty || accessToken.isEmpty) {
        return "❌ WhatsApp error: ID/Token not configured (Saved in SharedPreferences). Contact +255742448965.";
      }

      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final chatId = '$cleanPhone@c.us'; // Format required by the API

      Future<http.Response> post(String url, Map<String, String> payload) async {
        return await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: payload,
        );
      }

      // ⚠️ IMPORTANT: Verify this URL and API endpoint are correct and active!
      final response = await post('https://wawp.net/wp-json/awp/v1/sendMessage', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': chatId,
        'message': messageText,
      }).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return "✅ WhatsApp message sent to $phoneNumber!";
      } else {
        // This is the CRUCIAL line for debugging message send issues
        print('WhatsApp API Error: Status ${response.statusCode}, Body: ${response.body}');
        return "❌ Failed to send WhatsApp message. API Status: ${response.statusCode}. Check console for body.";
      }
    } catch (e) {
      print('Error sending WhatsApp message: $e');
      return "❌ An unexpected error occurred: $e";
    }
  }

  // Generates the textual summary of the report
  String generateReportSummary(
      int totalProducts,
      double totalBuyingCost,
      double expectedAfterSales,
      double totalPotentialProfit,
      double normalUsageTotal,
      double totalRemainingStockValue,
      double finalProfitAfterUsage,
      ) {
    final String dateRangeText;
    if (startDate != null || endDate != null) {
      final startText = startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '...';
      final endText = endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '...';
      dateRangeText = 'Product Period: $startText to $endText';
    } else {
      dateRangeText = 'Product Period: All time (Full Stock)';
    }

    final String usageRangeText;
    if (usageStartDate != null || usageEndDate != null) {
      final startText = usageStartDate != null ? DateFormat('yyyy-MM-dd').format(usageStartDate!) : '...';
      final endText = usageEndDate != null ? DateFormat('yyyy-MM-dd').format(usageEndDate!) : '...';
      usageRangeText = 'Expenses Period: $startText to $endText';
    } else {
      usageRangeText = 'Expenses Period: All time';
    }

    final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // Check if this is a test report or a manual send
    final reportTitle = _reportCount > 0
        ? '*CLOSING STOCK & PROFIT REPORT (TEST $_reportCount)* 🧪'
        : '*CLOSING STOCK & PROFIT REPORT (MANUAL SEND)* 📤';

    return '''
$reportTitle
Date: $now
Business: $businessName
$dateRangeText
$usageRangeText

*Summary Overview:*
- Total products: $totalProducts
- Total Invested Cost: TSH ${NumberFormat('#,##0.00').format(totalBuyingCost)}
- Expected Sales Income: TSH ${NumberFormat('#,##0.00').format(expectedAfterSales)}
- Total Potential Profit: TSH ${NumberFormat('#,##0.00').format(totalPotentialProfit)}
- Total Expenses: TSH ${NumberFormat('#,##0.00').format(normalUsageTotal)}
- Remaining Stock Value: TSH ${NumberFormat('#,##0.00').format(totalRemainingStockValue)}

*NET PROFIT (Potential - Expenses - Stock Value):*
TSH ${NumberFormat('#,##0.00').format(finalProfitAfterUsage)}
''';
  }


  // Report generation and sending function (Used for recurring test)
  Future<void> sendTestReport() async {
    _reportCount++;
    print('*** Running Test Report Send #$_reportCount at ${DateTime.now()} ***');

    // --- Report Generation Logic ---
    final medicinesList = await fetchCombinedMedicines(searchQuery: searchQuery);

    int totalProducts = 0;
    double totalBuyingCost = 0;
    double expectedAfterSales = 0;
    double totalPotentialProfit = 0;
    double totalRemainingStockValue = 0;

    for (var m in medicinesList) {
      totalProducts++;
      final totalQty = int.tryParse(m['total_quantity']?.toString() ?? '0') ?? 0;
      final remainingQty = int.tryParse(m['remaining_quantity']?.toString() ?? '0') ?? 0;
      final buy = double.tryParse(m['buy']?.toString() ?? '0') ?? 0.0;
      final price = double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;

      // Only count totals for active (non-deleted) products with remaining stock
      if (remainingQty > 0 && !(m['isDeleted'] ?? false)) {
        totalBuyingCost += totalQty * buy;
        expectedAfterSales += totalQty * price;
        totalPotentialProfit += (totalQty * price) - (totalQty * buy);
        totalRemainingStockValue += remainingQty * price;
      }
    }

    final double finalProfitAfterUsage =
        totalPotentialProfit - normalUsageTotal - totalRemainingStockValue;

    // Temporarily set _reportCount to 0 so the generateSummary does not show the test tag
    final currentReportCount = _reportCount;
    _reportCount = currentReportCount; // Restore test count for title

    final reportMessage = generateReportSummary(
      totalProducts,
      totalBuyingCost,
      expectedAfterSales,
      totalPotentialProfit,
      normalUsageTotal,
      totalRemainingStockValue,
      finalProfitAfterUsage,
    );

    // --- Distribution ---
    final adminPhones = await getAdminPhones();

    // Send via WhatsApp
    for (String phone in adminPhones) {
      print('Attempting WhatsApp send to PHONE: $phone');
      final result = await sendWhatsApp(phone, reportMessage);
      print('WhatsApp result for $phone: $result');
    }

    print('Test Report #$_reportCount successfully generated and distributed!');
    if(mounted) {
      setState(() {});
    }
  }

  // --- NEW: Report generation and sending function (Used for manual button press) ---
  Future<void> sendReportToWhatsApp() async {
    // Reset test count for the manual send summary title
    final originalReportCount = _reportCount;
    _reportCount = 0;

    // Show a loading indicator/dialog or toast
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report and sending via WhatsApp...')),
      );
    }

    // --- Report Generation Logic (Same as sendTestReport) ---
    final medicinesList = await fetchCombinedMedicines(searchQuery: searchQuery);

    int totalProducts = 0;
    double totalBuyingCost = 0;
    double expectedAfterSales = 0;
    double totalPotentialProfit = 0;
    double totalRemainingStockValue = 0;

    for (var m in medicinesList) {
      totalProducts++;
      final totalQty = int.tryParse(m['total_quantity']?.toString() ?? '0') ?? 0;
      final remainingQty = int.tryParse(m['remaining_quantity']?.toString() ?? '0') ?? 0;
      final buy = double.tryParse(m['buy']?.toString() ?? '0') ?? 0.0;
      final price = double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;

      // Only count totals for active (non-deleted) products with remaining stock
      if (remainingQty > 0 && !(m['isDeleted'] ?? false)) {
        totalBuyingCost += totalQty * buy;
        expectedAfterSales += totalQty * price;
        totalPotentialProfit += (totalQty * price) - (totalQty * buy);
        totalRemainingStockValue += remainingQty * price;
      }
    }

    // Adjusted final profit calculation
    final double finalProfitAfterUsage =
        totalPotentialProfit - normalUsageTotal - totalRemainingStockValue;


    final reportMessage = generateReportSummary(
      totalProducts,
      totalBuyingCost,
      expectedAfterSales,
      totalPotentialProfit,
      normalUsageTotal,
      totalRemainingStockValue,
      finalProfitAfterUsage,
    );

    // --- Distribution ---
    final adminPhones = await getAdminPhones();

    String finalResult = 'Report Summary:\n\n$reportMessage\n\nDistribution Results:\n';

    if (adminPhones.isEmpty) {
      finalResult += "❌ No admin phone numbers found in the database!";
    } else {
      for (String phone in adminPhones) {
        final result = await sendWhatsApp(phone, reportMessage);
        finalResult += result + '\n';
      }
    }

    // Restore original test count
    _reportCount = originalReportCount;

    // Show final result to the user
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(finalResult),
          duration: const Duration(seconds: 10),
        ),
      );
    }
  }


  // -----------------------------------------------------------------
  //                              PDF LOGIC
  // -----------------------------------------------------------------

  Future<void> exportToPDF(
      int totalProducts,
      double totalBuyingCost,
      double expectedAfterSales,
      double totalPotentialProfit,
      double normalUsageTotal,
      double totalRemainingStockValue,
      double finalProfitAfterUsage,
      ) async {
    final pdf = pw.Document();

    final logo = (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync())
        ? pw.MemoryImage(File(businessLogoPath).readAsBytesSync())
        : null;

    final now = DateTime.now();
    final printedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    String dateRangeText;
    if (startDate != null || endDate != null) {
      final startText = startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '...';
      final endText = endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '...';
      dateRangeText = 'Report between: $startText TO $endText';
    } else {
      dateRangeText = 'Report for: All time';
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          if (logo != null) pw.Center(child: pw.Image(logo, height: 80)),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              businessName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Email: $businessEmail | Phone: $businessPhone | Location: $businessLocation',
              style: pw.TextStyle(fontSize: 10)),
          pw.Text('Address: $address | WhatsApp: $whatsapp',
              style: pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          pw.SizedBox(height: 4),
          pw.Text(dateRangeText, style: pw.TextStyle(fontSize: 10)),
          pw.Text('Printed at: $printedTime', style: pw.TextStyle(fontSize: 10)),
          pw.Divider(),
          pw.Center(
              child: pw.Text('Summary Overview',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Text('Total products: $totalProducts'),
          pw.Text('Total buying cost (Invested): TSH ${NumberFormat('#,##0.00').format(totalBuyingCost)}'),
          pw.Text('Expected after-sales income: TSH ${NumberFormat('#,##0.00').format(expectedAfterSales)}'),
          pw.Text('Total potential profit: TSH ${NumberFormat('#,##0.00').format(totalPotentialProfit)}'),
          pw.Text('Total Expenses: TSH ${NumberFormat('#,##0.00').format(normalUsageTotal)}'),
          pw.Text('Total remaining stock value: TSH ${NumberFormat('#,##0.00').format(totalRemainingStockValue)}'),
          pw.Divider(),
          pw.Text(
            'Net Profit (Potential Profit - Expenses - Remaining Stock): '
                'TSH ${NumberFormat('#,##0.00').format(finalProfitAfterUsage)}',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.teal),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // -----------------------------------------------------------------
  //                                UI
  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "CLOSING STOCK & OPENING STOCK (Available product=$_reportCount)", // Updated title for test visibility
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Business name & logo card
            Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync())
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.file(
                            File(businessLogoPath),
                            height: 80,
                          ),
                        ),
                      Text(
                        ' $businessName',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Date filter row for medicines
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                          loadMedicines();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        startDate != null
                            ? 'Product Start: ${DateFormat('yyyy-MM-dd').format(startDate!)}'
                            : 'Select product Start Date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          endDate = picked;
                          loadMedicines();
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        endDate != null
                            ? 'Product End: ${DateFormat('yyyy-MM-dd').format(endDate!)}'
                            : 'Select product End Date',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  tooltip: 'Reset filters',
                  onPressed: resetFilters,
                )
              ],
            ),

            if (startDate != null || endDate != null)
              Text(
                'Showing products from ${startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : '...'}'
                    ' to ${endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : '...'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

            const SizedBox(height: 6),

            // Date filter row for expenses
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: usageStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          usageStartDate = picked;
                        });
                        fetchTotalNormalUsageAmount().then((value) {
                          setState(() {
                            normalUsageTotal = value;
                          });
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        usageStartDate != null
                            ? 'Expenses Start: ${DateFormat('yyyy-MM-dd').format(usageStartDate!)}'
                            : 'Select Expenses Start',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: usageEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          usageEndDate = picked;
                        });
                        fetchTotalNormalUsageAmount().then((value) {
                          setState(() {
                            normalUsageTotal = value;
                          });
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        usageEndDate != null
                            ? 'Expenses End: ${DateFormat('yyyy-MM-dd').format(usageEndDate!)}'
                            : 'Select Expenses End',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  tooltip: 'Reset usage filters',
                  onPressed: resetUsageFilters,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Search
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) {
                setState(() {
                  searchQuery = v;
                  loadMedicines();
                });
              },
            ),

            const SizedBox(height: 10),

            // --- WhatsApp & PDF Buttons Row ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => sendReportToWhatsApp(), // Calls the WhatsApp function
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'Send Report via WhatsApp',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, // WhatsApp green
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      // Re-run the calculations before PDF export
                      final medicinesList = await fetchCombinedMedicines(searchQuery: searchQuery);
                      int totalProducts = 0;
                      double totalBuyingCost = 0;
                      double expectedAfterSales = 0;
                      double totalPotentialProfit = 0;
                      double totalRemainingStockValue = 0;

                      for (var m in medicinesList) {
                        totalProducts++;
                        final totalQty = int.tryParse(m['total_quantity']?.toString() ?? '0') ?? 0;
                        final remainingQty = int.tryParse(m['remaining_quantity']?.toString() ?? '0') ?? 0;
                        final buy = double.tryParse(m['buy']?.toString() ?? '0') ?? 0.0;
                        final price = double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;

                        // Only count totals for active (non-deleted) products with remaining stock
                        if (remainingQty > 0 && !(m['isDeleted'] ?? false)) {
                          totalBuyingCost += totalQty * buy;
                          expectedAfterSales += totalQty * price;
                          totalPotentialProfit += (totalQty * price) - (totalQty * buy);
                          totalRemainingStockValue += remainingQty * price;
                        }
                      }

                      final double finalProfitAfterUsage =
                          totalPotentialProfit - normalUsageTotal - totalRemainingStockValue;

                      await exportToPDF(
                        totalProducts,
                        totalBuyingCost,
                        expectedAfterSales,
                        totalPotentialProfit,
                        normalUsageTotal,
                        totalRemainingStockValue,
                        finalProfitAfterUsage,
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                    label: const Text(
                      'Export to PDF',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // --- END: Buttons Row ---

            // Report list container
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: medicines,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No product found.'));
                  }

                  final medicinesList = snapshot.data!;

                  int totalProducts = 0;
                  double totalBuyingCost = 0;
                  double expectedAfterSales = 0;
                  double totalPotentialProfit = 0;
                  double totalRemainingStockValue = 0;
                  double currentNormalUsageTotal = normalUsageTotal; // Use state value

                  final cards = medicinesList.map((m) {
                    totalProducts++;

                    final totalQty = int.tryParse(m['total_quantity']?.toString() ?? '0') ?? 0;
                    final remainingQty = int.tryParse(m['remaining_quantity']?.toString() ?? '0') ?? 0;
                    final buy = double.tryParse(m['buy']?.toString() ?? '0') ?? 0.0;
                    final price = double.tryParse(m['price']?.toString() ?? '0') ?? 0.0;

                    final buyingCost = totalQty * buy;
                    final productExpectedAfterSales = totalQty * price;
                    final potentialProfit = productExpectedAfterSales - buyingCost;
                    final remainingStockValue = remainingQty * price;

                    expectedAfterSales += productExpectedAfterSales;

                    // Only count totals for active (non-deleted) products with remaining stock
                    if (remainingQty > 0 && !(m['isDeleted'] ?? false)) {
                      totalBuyingCost += buyingCost;
                      totalPotentialProfit += potentialProfit;
                      totalRemainingStockValue += remainingStockValue;
                    }

                    final bool isDeleted = m['isDeleted'] == true;

                    return Card(
                      color: isDeleted ? Colors.grey.shade300 : Colors.white,
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_hospital, color: isDeleted ? Colors.grey : Colors.teal),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${m['name']?.toString() ?? ''}${isDeleted ? ' (Deleted)' : ''}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDeleted ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                ),
                                Text(
                                  'TSH ${NumberFormat('#,##0.00').format(remainingStockValue)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDeleted ? Colors.grey : Colors.blueGrey,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 8),
                            Text('Company: ${m['company']?.toString() ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                            Text('Expiry: ${m['expiry_date']?.toString() ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                            Text('Batch: ${m['batchNumber']?.toString() ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Qty: ${totalQty}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                Text('Remaining Qty: $remainingQty', style: const TextStyle(fontSize: 12, color: Colors.red)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Buy Price: TSH ${NumberFormat('#,##0.00').format(buy)}', style: const TextStyle(fontSize: 12)),
                                Text('Sell Price: TSH ${NumberFormat('#,##0.00').format(price)}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!isDeleted)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    'Remaining Value (Sell): TSH ${NumberFormat('#,##0.00').format(remainingStockValue)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList();

                  final double finalProfitAfterUsage =
                      totalPotentialProfit - currentNormalUsageTotal - totalRemainingStockValue;

                  return Column(
                    children: [
                      // Grand Totals Card (Summary)
                      Card(
                        color: Colors.lightBlue.shade50,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                  child: Text('CLOSING STOCK SUMMARY',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                              const Divider(height: 12),
                              _buildSummaryRow('Total Active Products :', totalProducts.toString()),
                              _buildSummaryRow('Total Invested Cost:', 'TSH ${NumberFormat('#,##0.00').format(totalBuyingCost)}', color: Colors.deepOrange),
                              _buildSummaryRow('Total Potential Profit:', 'TSH ${NumberFormat('#,##0.00').format(totalPotentialProfit)}', color: Colors.green),
                              _buildSummaryRow('Total Expenses:', 'TSH ${NumberFormat('#,##0.00').format(currentNormalUsageTotal)}', color: Colors.red),
                              _buildSummaryRow('Total Remaining Stock Value:', 'TSH ${NumberFormat('#,##0.00').format(totalRemainingStockValue)}', color: Colors.blueGrey),
                              const Divider(height: 12, thickness: 2),
                              _buildSummaryRow(
                                'NET PROFIT (Potential - Expenses - Stock Value):',
                                'TSH ${NumberFormat('#,##0.00').format(finalProfitAfterUsage)}',
                                color: finalProfitAfterUsage >= 0 ? Colors.teal.shade800 : Colors.red.shade800,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // List of products
                      Expanded(
                        child: ListView(
                          children: cards,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for summary rows
  Widget _buildSummaryRow(String label, String value, {Color color = Colors.black87, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}