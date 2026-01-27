import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../DB/database_helper.dart';
import 'FOTTER/CurvedRainbowBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;
class SalesReportScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const SalesReportScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _SalesReportScreenState createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  final supabase = Supabase.instance.client;

  // Data Futures
  late Future<List<Map<String, dynamic>>> salesData = Future.value([]);
  late Future<double> salesTotal = Future.value(0.0);
  late Future<double> paidLentTotal = Future.value(0.0);
  late Future<double> debtTotal = Future.value(0.0);
  late Future<Map<String, double>> totalsBySourceFuture = Future.value({});

  // UI Controllers
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  bool _isDarkMode = false;

  // Business & Security State
  String _realRoleFromDB = '';
  dynamic currentBusinessId;
  String business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = DateTime(now.year, now.month, now.day);
    getBusinessInfo();
  }

  // ✅ FIXED: Inatumia .limit(1) kuzuia PostgrestException (multiple rows returned)
  Future<void> getBusinessInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata Profile ya mtumiaji
      final userProfileResponse = await supabase
          .from('users')
          .select('business_name, business_id, role')
          .eq('id', user.id)
          .limit(1);

      if (!mounted || userProfileResponse.isEmpty) return;

      final profile = userProfileResponse.first;
      setState(() {
        _realRoleFromDB = profile['role']?.toString().toLowerCase() ?? '';
        currentBusinessId = profile['business_id'];
        business_name = profile['business_name']?.toString() ?? 'N/A';
      });

      // 2. Pata Details za Biashara (Logo n.k) kwa ID
      if (currentBusinessId != null) {
        final bizResponse = await supabase
            .from('businesses')
            .select()
            .eq('id', currentBusinessId)
            .limit(1);

        if (bizResponse.isNotEmpty && mounted) {
          final biz = bizResponse.first;
          setState(() {
            businessEmail = biz['email']?.toString() ?? '';
            businessPhone = biz['phone']?.toString() ?? '';
            businessLogoPath = biz['logo']?.toString() ?? '';
          });
        }
      }

      // 3. ✅ MABADILIKO: Hakiki Role (Admin, Sub-Admin, Accountant, HR)
      // Hawa wote sasa wanaruhusiwa kuona ripoti kulingana na matawi yao
      final allowedRoles = ['admin', 'sub_admin', 'accountant', 'hr'];

      if (allowedRoles.contains(_realRoleFromDB)) {
        _applyFilters();
      } else {
        // Kama role si mojawapo ya hizo (mfano 'sales_person'), anakataliwa
        _showAccessDeniedDialog();
      }

    } catch (e) {
      debugPrint('❌ Supabase Debug Error: $e');
    }
  }

  void _applyFilters() async {
    if (startDate == null || endDate == null) return;
    if (mounted) setState(() => isLoading = true);

    try {
      final List<Map<String, dynamic>> rpcRows = await _fetchSalesData();

      double tempSales = 0.0;
      double tempPaidDebt = 0.0;
      double tempNewDebt = 0.0;

      Set<String> processedDebtReceipts = {};
      Map<String, double> tempBySource = {};
      DateTime today = DateTime.now();

      for (var row in rpcRows) {
        // BUSINESS ISOLATION (non-admin)
        if (_realRoleFromDB != 'admin' &&
            row['business_id']?.toString() != currentBusinessId?.toString()) continue;

        String receipt = (row['receipt_number'] ?? row['receipt'] ?? '').toString();
        double price = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        String table = row['origin_table'] ?? 'sales';
        String source = row['source'] ?? 'General';
        String method = (row['payment_method'] ?? '').toString().toUpperCase();

        // Paid debt
        if (table == 'logs' || table == 'To_lent_payedlogs') {
          tempPaidDebt += price;
          tempBySource["Debt Paid ($source)"] =
              (tempBySource["Debt Paid ($source)"] ?? 0.0) + price;
          continue;
        }

        // Full Cash
        if (method.contains('FULL')) {
          tempSales += price;
          tempBySource["Cash Sales ($source)"] =
              (tempBySource["Cash Sales ($source)"] ?? 0.0) + price;
          continue;
        }

        // Partial Payment
        if (method.contains('PARTIAL')) {
          tempSales += price;
          tempBySource["Cash Sales ($source)"] =
              (tempBySource["Cash Sales ($source)"] ?? 0.0) + price;

          // Count debt only once per receipt, today only
          DateTime receiptDate = DateTime.parse(row['created_at'].toString());
          bool isToday = receiptDate.year == today.year &&
              receiptDate.month == today.month &&
              receiptDate.day == today.day;

          if (isToday && !processedDebtReceipts.contains(receipt)) {
            tempNewDebt += price;
            processedDebtReceipts.add(receipt);
          }
          continue;
        }

        // Mkopo / Lend
        if (method.contains('LEND') || method.contains('MKOPO')) {
          if (!processedDebtReceipts.contains(receipt)) {
            tempNewDebt += price;
            processedDebtReceipts.add(receipt);
          }
          continue;
        }

        // Fallback → treat as cash
        tempSales += price;
        tempBySource["Cash Sales ($source)"] =
            (tempBySource["Cash Sales ($source)"] ?? 0.0) + price;
      }

      if (mounted) {
        setState(() {
          salesData = Future.value(rpcRows);
          salesTotal = Future.value(tempSales);
          paidLentTotal = Future.value(tempPaidDebt);
          debtTotal = Future.value(tempNewDebt);
          totalsBySourceFuture = Future.value(tempBySource);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Filter Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }
  // --- MUHURI WA BIASHARA ---
  pw.Widget _buildBusinessSeal(pw.Context context) {
    final stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
    final stampColor = PdfColors.blue;
    return pw.Container(
      width: 170, height: 110,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(20),
          border: pw.Border.all(color: stampColor, width: 3.5)
      ),
      child: pw.Container(
        width: 160, height: 100,
        decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(16),
            border: pw.Border.all(color: stampColor, width: 1.0)
        ),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(business_name.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: stampColor)),
            pw.SizedBox(height: 3),
            pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: stampColor, height: 8, thickness: 0.5),
            pw.Text('$businessLocation'.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900)),
            pw.Text('TEL: +255${businessPhone.replaceAll('+255', '')}'.toUpperCase(), style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900)),
            pw.SizedBox(height: 5),
            pw.Text('DATE: $stampDate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: stampColor)),
          ],
        ),
      ),
    );
  }

// --- QR CODE GENERATOR ---
  pw.Widget _buildQRCode(String data) {
    return pw.Column(
      children: [
        pw.Container(
          width: 80,
          height: 80,
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: data,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text("Scan to Verify", style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }
  Future<void> _directPrint() async {
    try {
      final List<Map<String, dynamic>> data = await salesData;
      if (data.isEmpty) return;

      // Pakua Logo
      pw.MemoryImage? netImage;
      if (businessLogoPath.isNotEmpty) {
        final response = await http.get(Uri.parse(businessLogoPath));
        if (response.statusCode == 200) netImage = pw.MemoryImage(response.bodyBytes);
      }

      final pdf = pw.Document();

      // Data ya QR Code (Mfano: Link ya biashara au Report ID)
      String qrData = "Business: $business_name\nReport: Sales Audit\nDate: ${DateTime.now()}";

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a3.landscape,
          margin: const pw.EdgeInsets.all(30),
          build: (pw.Context context) => [
            // HEADER (Logo + Name)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  if (netImage != null) pw.Container(width: 70, height: 70, child: pw.Image(netImage)),
                  pw.SizedBox(width: 15),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(business_name.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Simu: +255${businessPhone.replaceAll('+255', '')}"),
                  ]),
                ]),
                pw.Text("SALES AUDIT REPORT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // TABLE
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Receipt', 'Customer', 'Product', 'Method', 'Total (TSH)'],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              data: data.map((item) => [
                item['confirmed_time']?.toString().split(' ')[0] ?? '-',
                item['receipt_number'] ?? '-',
                item['customer_name'] ?? '-',
                item['product_name'] ?? '-',
                item['payment_method'] ?? '-',
                NumberFormat('#,##0').format(double.tryParse(item['total_price'].toString()) ?? 0),
              ]).toList(),
            ),

            pw.Spacer(),

            // --- SEHEMU YA CHINI (Seal + QR + Signatures) ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // 1. Muhuri (Seal)
                _buildBusinessSeal(context),

                // 2. Signature & Approval
                pw.Column(children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                  pw.Text("Authorized By", style: const pw.TextStyle(fontSize: 10)),
                ]),

                // 3. QR Code
                _buildQRCode(qrData),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        format: PdfPageFormat.a3.landscape,
        name: 'Report_Final',
      );
    } catch (e) {
      _showSnackBar("Error: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
// ✅ Method ya kufungua kalenda na kuchagua tarehe
  Future<void> _selectDate(BuildContext context, bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
        } else {
          endDate = picked;
        }
      });
      // Baada ya kuchagua tarehe, vuta data upya
      _applyFilters();
    }
  }
  Future<List<Map<String, dynamic>>> _fetchSalesData() async {
    try {
      final int? bId = int.tryParse(currentBusinessId.toString());

      // 🔍 DEBUG 1: Angalia vigezo unavyotuma
      debugPrint("--- 🔍 DEBUG SALES REPORT ---");
      debugPrint("User Name: ${widget.userName}");
      debugPrint("User Role: $_realRoleFromDB");
      debugPrint("Business ID (bId): $bId");
      debugPrint("Start Date: ${DateFormat('yyyy-MM-dd').format(startDate!)}");
      debugPrint("End Date: ${DateFormat('yyyy-MM-dd').format(endDate!)}");
      debugPrint("Keyword: '${searchController.text.trim()}'");

      final List<dynamic> response = await supabase.rpc(
        'get_combined_sales_report',
        params: {
          'p_user_name': widget.userName,
          'p_user_role': _realRoleFromDB,
          'p_business_id': bId,
          'p_start_date': DateFormat('yyyy-MM-dd').format(startDate!),
          'p_end_date': DateFormat('yyyy-MM-dd').format(endDate!),
          'p_keyword': searchController.text.trim(),
        },
      );

      // 🔍 DEBUG 2: Angalia matokeo yanayorudi
      debugPrint("✅ RPC Response Length: ${response.length} rows");
      if (response.isNotEmpty) {
        debugPrint("📄 Kielelezo cha Row ya kwanza: ${response.first}");
      } else {
        debugPrint("⚠️ RPC imerudisha ZERO rows. Hakikisha tarehe na business_id viko sahihi kule DB.");
      }
      debugPrint("--- 🔍 END DEBUG ---");

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ RPC Error: $e");
      return [];
    }
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Access Denied"),
        content: const Text("Huruhusiwi kuona ripoti za matawi mengine."),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context); // Funga dialog
                Navigator.pop(context); // Rudi nyuma screen ya awali
              },
              child: const Text("OK")
          ),
        ],
      ),
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }



  @override
  Widget build(BuildContext context) {
    // --- Dark Mode Logic Integration ---
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);



    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 100,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "BRANCH: ${business_name.isEmpty ? 'LOADING...' : business_name.toUpperCase()}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
                _realRoleFromDB == 'admin' ? "MAIN ADMINISTRATION" : "SUB-ADMIN SALES ANALYTICS",
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple]),
          ),
        ),
        actions: [
          // ✅ KITUFE CHA PRINTING YA KAWAIDA
          IconButton(
            tooltip: "Print Report",
            icon: const Icon(Icons.print, color: Colors.white, size: 28),
            onPressed: () => _directPrint(),
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
        ),
      ),
      body: Column(
        children: [
          // 1. Date pickers
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 20, 15, 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: primaryPurple,
                      elevation: isDark ? 0 : 2,
                      side: isDark ? BorderSide(color: primaryPurple.withOpacity(0.3)) : BorderSide.none,
                    ),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    onPressed: () => _selectDate(context, true),
                    label: Text(startDate == null ? "Start Date" : DateFormat('dd MMM yy').format(startDate!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cardColor,
                      foregroundColor: primaryPurple,
                      elevation: isDark ? 0 : 2,
                      side: isDark ? BorderSide(color: primaryPurple.withOpacity(0.3)) : BorderSide.none,
                    ),
                    icon: const Icon(Icons.event, size: 16),
                    onPressed: () => _selectDate(context, false),
                    label: Text(endDate == null ? "End Date" : DateFormat('dd MMM yy').format(endDate!)),
                  ),
                ),
              ],
            ),
          ),

          // 2. Conditional Content
          if (startDate == null || endDate == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 80, color: primaryPurple.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text("Select a date range to audit sales",
                        style: TextStyle(color: subTextCol, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else ...[
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: textCol),
                decoration: InputDecoration(
                  hintText: "Search records...",
                  hintStyle: TextStyle(color: subTextCol.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: primaryPurple),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),

            // Totals Card
            isLoading
                ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                : FutureBuilder<List<double>>(
              future: Future.wait([salesTotal, paidLentTotal, debtTotal]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                double sales = snapshot.data![0];
                double paidLent = snapshot.data![1];
                double debt = snapshot.data![2];
                double cashTotal = sales + paidLent;

                return Container(
                  margin: const EdgeInsets.all(15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 20
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildTotalRow("DIRECT SALES", sales, Colors.blue, subTextCol),
                      _buildTotalRow("DEBT PAYMENTS", paidLent, Colors.tealAccent, subTextCol),
                      _buildTotalRow("NEW DEBT ISSUED", debt, Colors.redAccent, subTextCol),
                      Divider(height: 25, color: subTextCol.withOpacity(0.1)),
                      _buildTotalRow("TOTAL CASH FLOW", cashTotal, primaryPurple, textCol, isBold: true),
                    ],
                  ),
                );
              },
            ),

            // Source Breakdown
            FutureBuilder<Map<String, double>>(
              future: totalsBySourceFuture,
              builder: (context, snapshot) {
                if (isLoading || !snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      unselectedWidgetColor: subTextCol,
                    ),
                    child: ExpansionTile(
                      collapsedBackgroundColor: cardColor,
                      backgroundColor: cardColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      iconColor: primaryPurple,
                      leading: const Icon(Icons.account_tree_outlined, color: primaryPurple),
                      title: Text("Breakdown by Source",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textCol)),
                      children: snapshot.data!.entries.map((e) => ListTile(
                        dense: true,
                        title: Text(e.key.toUpperCase(), style: TextStyle(color: textCol, fontSize: 12)),
                        trailing: Text("TSH ${NumberFormat('#,##0').format(e.value)}",
                            style: TextStyle(fontWeight: FontWeight.w900, color: textCol, fontFamily: 'monospace')),
                      )).toList(),
                    ),
                  ),
                );
              },
            ),

            // Data Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(35))
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : FutureBuilder<List<Map<String, dynamic>>>(
                    future: salesData,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("No records found.", style: TextStyle(color: subTextCol)));

                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(isDark ? primaryPurple.withOpacity(0.2) : Colors.teal.shade700),
                            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            dataTextStyle: TextStyle(color: textCol),
                            // ✅ Safu ya "Business" imewekwa ya kwanza
                            columns: const [
                              DataColumn(label: Text('Business')),
                              DataColumn(label: Text('Receipt')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Method')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('Confirmed By')),
                            ],
                            rows: snapshot.data!.map((sale) {
                              final String method = (sale['payment_method'] ?? sale['method'] ?? '').toString().toLowerCase();
                              final bool isLent = method.contains('lend') || method.contains('mkopo');

                              // Date Parsing
                              String formattedDate = 'N/A';
                              var rawDate = sale['confirmed_time'] ?? sale['created_at'] ?? sale['paid_time'];
                              if (rawDate != null && rawDate.toString() != 'null') {
                                try {
                                  formattedDate = DateFormat('dd MMM yy').format(DateTime.parse(rawDate.toString()));
                                } catch (e) {
                                  formattedDate = rawDate.toString().split('T')[0];
                                }
                              }

                              // Price Parsing
                              var rawPrice = sale['total_price'] ?? sale['price'] ?? sale['amount'] ?? 0;
                              double price = double.tryParse(rawPrice.toString()) ?? 0.0;

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>(
                                      (states) => isLent ? (isDark ? Colors.red.withOpacity(0.1) : Colors.orange.shade50) : null,
                                ),
                                cells: [
                                  // ✅ Inashika jina la biashara (Noneria/Afro) mbele
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(
                                        (sale['business_name'] ?? 'N/A').toString().toUpperCase(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blueAccent),
                                      ),
                                    ),
                                  ),
                                  DataCell(Text((sale['receipt_number'] ?? sale['receipt'] ?? 'N/A').toString())),
                                  DataCell(Text((sale['customer_name'] ?? sale['customer'] ?? 'N/A').toString().toUpperCase())),
                                  // ✅ Product Name sasa inatumia key ya RPC tuliyorekebisha
                                  DataCell(Text((sale['product_name'] ?? sale['medicine_name'] ?? 'N/A').toString())),
                                  DataCell(Text(NumberFormat('#,##0').format(price))),
                                  DataCell(Text(method.toUpperCase(), style: TextStyle(color: isLent ? Colors.redAccent : Colors.tealAccent, fontWeight: FontWeight.bold))),
                                  DataCell(Text(formattedDate)),
                                  DataCell(Text((sale['source'] ?? 'N/A').toString())),
                                  DataCell(Text((sale['confirmed_by'] ?? 'N/A').toString())),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// Updated Helper for Dark Mode labels
  Widget _buildTotalRow(String label, double value, Color color, Color labelCol, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.w600, color: labelCol)),
          Text(
            "TSH ${NumberFormat('#,##0').format(value)}",
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: isBold ? 18 : 14, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

// Helper Widget for the Totals Card

}