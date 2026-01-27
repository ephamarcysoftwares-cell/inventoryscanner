import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../DB/database_helper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http/http.dart' as http;

import '../FOTTER/CurvedRainbowBar.dart';


class SalesTrendPainter extends CustomPainter {
  final List<double> points;
  final Color themeColor;
  final bool isDark;

  SalesTrendPainter({required this.points, required this.themeColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = themeColor
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [themeColor.withOpacity(0.4), Colors.transparent],
      );

    final path = Path();
    final fillPath = Path();
    double maxVal = points.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;
    double spacing = size.width / (points.length - 1);

    for (int i = 0; i < points.length; i++) {
      double x = i * spacing;
      double y = size.height - (points[i] / maxVal * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
class PharmacistReportScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const PharmacistReportScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _PharmacistReportScreenState createState() => _PharmacistReportScreenState();
}

class _PharmacistReportScreenState extends State<PharmacistReportScreen> {
  final supabase = Supabase.instance.client;

  // Data Futures
  late Future<List<Map<String, dynamic>>> salesData = Future.value([]);
  late Future<double> salesTotal = Future.value(0.0);
  late Future<double> paidLentTotal = Future.value(0.0);
  late Future<double> debtTotal = Future.value(0.0);
  late Future<Map<String, double>> totalsBySourceFuture = Future.value({});
  List<double> trendPoints = [];
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
  String selectedCategory = "ALL";
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

      // 1. Pata Profile ya mtumiaji aliyelogin
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

      // 2. Pata Details za Biashara (Logo na Mawasiliano)
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
            // businessLocation inaweza kuchukuliwa hapa kama ipo kwenye DB
            businessLocation = biz['location']?.toString() ?? '';
          });
        }
      }

      // 3. ✅ MABADILIKO: Ruhusu Kila Mtu (Ila kwa Viwango Tofauti)
      // Hatumkatai mtu tena, tunaruhusu kila Role iendelee kwenye _applyFilters
      // Ambako huko ndani tayari tumeweka logic ya kuchuja data kulingana na Role.

      if (mounted) {
        _applyFilters();
      }

    } catch (e) {
      debugPrint('❌ Supabase Debug Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error loading profile: $e"))
        );
      }
    }
  }

  void _applyFilters() async {
    if (startDate == null || endDate == null) return;
    if (mounted) setState(() => isLoading = true);

    try {
      // 1. Vuta data kutoka RPC
      final List<Map<String, dynamic>> rpcRows = await _fetchSalesData();

      double tempSales = 0.0;
      double tempPaidDebt = 0.0;
      double tempNewDebt = 0.0;

      List<double> tempTrend = [];
      Map<String, double> tempBySource = {};

      for (var row in rpcRows) {
        // ✅ USALAMA: Hakikisha ni data za huyu Pharmacist pekee
        final String staff = (row['confirmed_by'] ?? row['full_name'] ?? '').toString().toLowerCase();
        if (staff != widget.userName.toLowerCase()) {
          continue;
        }

        double price = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        String table = (row['origin_table'] ?? 'unknown').toString().toLowerCase();
        String source = (row['source'] ?? 'General').toString();
        String method = (row['payment_method'] ?? '').toString().toUpperCase();

        // --- 1. SHUGHULIKIA HUDUMA & MAUZO (Services/Sales) ---
        if (table == 'services' || table == 'sales') {
          if (!method.contains('LEND')) {
            tempSales += price;
            // Tunajaza tempBySource kwa ajili ya ile Breakdown Table
            tempBySource[source] = (tempBySource[source] ?? 0.0) + price;
            if (price > 0) tempTrend.add(price);
          }
        }

        // --- 2. SHUGHULIKIA MALIPO YA MADENI ---
        if (table == 'logs' || table == 'to_lent_payedlogs') {
          tempPaidDebt += price;
          tempBySource["Debt Repayment"] = (tempBySource["Debt Repayment"] ?? 0.0) + price;
          if (price > 0) tempTrend.add(price);
        }

        // --- 3. SHUGHULIKIA MADENI MAPYA ---
        if (table == 'lend' || table == 'to_lend') {
          tempNewDebt += price;
        }
      }

      if (mounted) {
        setState(() {
          salesData = Future.value(rpcRows);
          salesTotal = Future.value(tempSales);
          paidLentTotal = Future.value(tempPaidDebt);
          debtTotal = Future.value(tempNewDebt);
          totalsBySourceFuture = Future.value(tempBySource); // ✅ Hii ndio inalisha ile Breakdown

          trendPoints = tempTrend;
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

      // 1. Hesabu ya Grand Total
      double grandTotal = 0;
      for (var item in data) {
        grandTotal += double.tryParse(item['total_price'].toString()) ?? 0;
      }

      // Pakua Logo
      pw.MemoryImage? netImage;
      if (businessLogoPath.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(businessLogoPath));
          if (response.statusCode == 200) netImage = pw.MemoryImage(response.bodyBytes);
        } catch (e) { print("Logo Error: $e"); }
      }

      final pdf = pw.Document();

      // Data ya QR Code
      String qrData = "Business: $business_name\nTotal Sales: TSH ${NumberFormat('#,##0').format(grandTotal)}\nDate: ${DateTime.now()}";

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
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text("SALES AUDIT REPORT", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Grand Total: TSH ${NumberFormat('#,##0').format(grandTotal)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                ]),
              ],
            ),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),

            // TABLE
            pw.TableHelper.fromTextArray(
              headers: [
                'Paid Time',
                'Lent At',
                'Receipt',
                'Customer',
                'Product',
                'Method',
                'Issued By',
                'Confirmed By',
                'Total (TSH)'
              ],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: data.map((item) {
                final String method = (item['payment_method'] ?? '').toString().toUpperCase();
                final String origin = item['origin_table'] ?? '';

                // Rangi kwa ajili ya Audit
                PdfColor rowColor = PdfColors.black;
                if (method.contains('LEND') || method.contains('MKOPO')) {
                  rowColor = PdfColors.red; // Mkopo mpya
                } else if (origin == 'To_lent_payedlogs') {
                  rowColor = PdfColors.green; // Malipo ya deni
                }

                return [
                  item['paid_time']?.toString().split('.')[0].replaceFirst('T', ' ') ?? '-',
                  item['original_lent_at']?.toString().split(' ')[0] ?? '-',
                  item['receipt_number'] ?? '-',
                  item['customer_name']?.toString().toUpperCase() ?? '-',
                  item['product_name'] ?? '-',
                  pw.Text(method, style: pw.TextStyle(color: rowColor, fontWeight: pw.FontWeight.bold)),
                  item['issued_by'] ?? '-',
                  item['confirmed_by'] ?? '-',
                  pw.Text(
                      NumberFormat('#,##0').format(double.tryParse(item['total_price'].toString()) ?? 0),
                      style: pw.TextStyle(color: rowColor, fontWeight: pw.FontWeight.bold)
                  ),
                ];
              }).toList(),
            ),

            // --- SEHEMU YA GRAND TOTAL CHINI YA TABLE ---
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                  child: pw.Text(
                    "GRAND TOTAL: TSH ${NumberFormat('#,##0').format(grandTotal)}",
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),

            pw.Spacer(),

            // --- SEHEMU YA CHINI (Seal + QR + Signatures) ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildBusinessSeal(context),

                pw.Column(children: [
                  pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                  pw.Text("Authorized By", style: const pw.TextStyle(fontSize: 10)),
                ]),

                _buildQRCode(qrData),
              ],
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        format: PdfPageFormat.a3.landscape,
        name: 'Sales_Audit_Report',
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
      // 1. Pata user aliyelogin sasa hivi kwa usalama zaidi
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final int? bId = int.tryParse(currentBusinessId.toString());

      // 2. Logic ya usalama: Kama si admin, lazima kichujio cha jina kitumike
      // Tunatumia widget.userName ambayo imepitishwa kwenye constructor
      String filterUserName = widget.userName;

      // Kama ni Admin au Roles zenye nguvu, tunaweza kuacha p_user_name ikiwa tupu
      // ili RPC ilete data za biashara nzima (au tawi zima)
      final privilegedRoles = ['admin', 'sub_admin', 'accountant'];
      if (privilegedRoles.contains(_realRoleFromDB)) {
        // Kama unataka Admin aone kila kitu, tunatuma string tupu au 'ALL'
        // Hii inategemea RPC yako imevumiliwa vipi upande wa SQL
        filterUserName = "";
      }

      debugPrint("--- 🔍 DEBUG SALES REPORT (FILTERED) ---");
      debugPrint("Fetching for User: ${filterUserName.isEmpty ? 'ALL (Privileged)' : filterUserName}");
      debugPrint("User Role: $_realRoleFromDB");
      debugPrint("Business ID: $bId");
      debugPrint("Range: ${DateFormat('yyyy-MM-dd').format(startDate!)} to ${DateFormat('yyyy-MM-dd').format(endDate!)}");

      final List<dynamic> response = await supabase.rpc(
        'get_combined_sales_report',
        params: {
          'p_user_name': filterUserName, // ✅ Sasa inatuma jina la mhusika tu
          'p_user_role': _realRoleFromDB,
          'p_business_id': bId,
          'p_start_date': DateFormat('yyyy-MM-dd').format(startDate!),
          'p_end_date': DateFormat('yyyy-MM-dd').format(endDate!),
          'p_keyword': searchController.text.trim(),
        },
      );

      debugPrint("✅ RPC Response: ${response.length} rows returned");

      // 3. Geuza kuwa List ya Map
      List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      // 4. USALAMA WA ZIADA (Client-side):
      // Hata kama RPC ikikosea, hapa tunahakikisha mauzo yasiyo yake yanatolewa
      if (!privilegedRoles.contains(_realRoleFromDB)) {
        data = data.where((row) =>
        row['confirmed_by']?.toString().toLowerCase() == widget.userName.toLowerCase() ||
            row['full_name']?.toString().toLowerCase() == widget.userName.toLowerCase()
        ).toList();
      }

      return data;
    } catch (e) {
      debugPrint("❌ RPC Error: $e");
      return [];
    }
  }

  void _showSaleDetailsDialog(BuildContext context, Map<String, dynamic> sale) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Column(
          children: [
            Text(
              (sale['business_name'] ?? 'SALE DETAILS').toString().toUpperCase(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const Divider(),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailItem("Receipt #", sale['receipt_number']),
              _detailItem("Customer", sale['customer_name']?.toString().toUpperCase()),
              _detailItem("Product", sale['product_name']),
              _detailItem("Total Amount", "TSH ${NumberFormat('#,##0').format(sale['total_price'] ?? 0)}"),
              _detailItem("Method", sale['payment_method']?.toString().toUpperCase(), isBold: true),
              const Divider(),
              _detailItem("Branch", sale['sub_business_name']?.toString().toUpperCase()),
              _detailItem("Transaction Time", _formatTime(sale['paid_time'])),
              if (sale['origin_table'] == 'To_lent_payedlogs') ...[
                const Divider(),
                _detailItem("Initial Loan Date", _formatDate(sale['original_lent_at']), color: Colors.red),
                _detailItem("Initial Issuer (Aliyekopesha)", sale['issued_by'], color: Colors.blue),
              ],
              _detailItem("Confirmed By (Aliyelipisha)", sale['confirmed_by'], isBold: true),
              _detailItem("Source", sale['source']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
// 1. Widget ya kutengeneza Chip
  Widget _buildFilterChip(String label) {
    bool isSelected = selectedCategory == label;
    return ChoiceChip(
      label: Text(label),
      labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.deepPurple,
          fontSize: 10,
          fontWeight: FontWeight.bold
      ),
      selected: isSelected,
      selectedColor: Colors.deepPurple,
      backgroundColor: Colors.white,
      onSelected: (bool selected) {
        setState(() {
          selectedCategory = label;
          _applyFilters(); // Hii itahakikisha mahesabu ya kadi (Totals) pia yanabadilika
        });
      },
    );
  }

// 2. Format ya muda
  String _formatTime(dynamic raw) {
    if (raw == null) return '-';
    try {
      return DateFormat('dd/MM HH:mm').format(DateTime.parse(raw.toString()));
    } catch (e) { return raw.toString(); }
  }
// Widget msaidizi kwa ajili ya mpangilio wa detail
  Widget _detailItem(String label, dynamic value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text("$label:", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              (value ?? '-').toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // String _formatTime(dynamic raw) {
  //   if (raw == null || raw == 'null') return '-';
  //   try {
  //     return DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(raw.toString()));
  //   } catch (e) { return raw.toString(); }
  // }

  String _formatDate(dynamic raw) {
    if (raw == null || raw == 'null') return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(raw.toString()));
    } catch (e) { return raw.toString(); }
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
        toolbarHeight: 90,
        // Hii itafanya Back Button iwe nyeupe moja kwa moja
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "BRANCH: ${business_name.isEmpty ? 'LOADING...' : business_name.toUpperCase()}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
                _realRoleFromDB == 'admin' ? "MAIN ADMINISTRATION" : "SUB-ADMIN SALES ANALYTICS",
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple]),
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Print Report",
            icon: const Icon(Icons.print, color: Colors.white, size: 24),
            onPressed: () => _directPrint(),
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Column(
        children: [
          // 1. DATE PICKERS
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: cardColor, foregroundColor: primaryPurple, elevation: 1),
                    icon: const Icon(Icons.calendar_today, size: 14),
                    onPressed: () => _selectDate(context, true),
                    label: Text(startDate == null ? "Start" : DateFormat('dd MMM').format(startDate!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: cardColor, foregroundColor: primaryPurple, elevation: 1),
                    icon: const Icon(Icons.event, size: 14),
                    onPressed: () => _selectDate(context, false),
                    label: Text(endDate == null ? "End" : DateFormat('dd MMM').format(endDate!)),
                  ),
                ),
              ],
            ),
          ),

          if (startDate == null || endDate == null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 80, color: primaryPurple.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    Text("Select dates to audit sales", style: TextStyle(color: subTextCol, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // --- SEARCH BAR ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                            child: TextField(
                              controller: searchController,
                              style: TextStyle(color: textCol),
                              decoration: InputDecoration(
                                hintText: "Search records...",
                                prefixIcon: const Icon(Icons.search, color: primaryPurple),
                                filled: true,
                                fillColor: cardColor,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                          ),

                          // --- QUICK FILTER TABS ---
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            child: Row(
                              children: [
                                _buildFilterChip("ALL"),
                                const SizedBox(width: 5),
                                _buildFilterChip("NORMAL PRODUCT"),
                                const SizedBox(width: 5),
                                _buildFilterChip("OTHER PRODUCT"),
                                const SizedBox(width: 5),
                                _buildFilterChip("SERVICES"),
                                const SizedBox(width: 5),
                                _buildFilterChip("DEBT"),
                              ],
                            ),
                          ),

                          // --- TREND GRAPH ---
                          if (trendPoints.isNotEmpty && !isLoading)
                            Container(
                              height: 100,
                              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("SALES TREND", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: primaryPurple)),
                                  Expanded(child: CustomPaint(size: Size.infinite, painter: SalesTrendPainter(points: trendPoints, themeColor: primaryPurple, isDark: isDark))),
                                ],
                              ),
                            ),

                          // --- TOTALS ---
                          isLoading
                              ? const CircularProgressIndicator()
                              : FutureBuilder<List<double>>(
                            future: Future.wait([salesTotal, paidLentTotal, debtTotal]),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox.shrink();
                              double cashTotal = snapshot.data![0] + snapshot.data![1];
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                                child: Column(
                                  children: [
                                    _buildTotalRow("CASH FLOW", cashTotal, primaryPurple, textCol, isBold: true),
                                    _buildTotalRow("NEW DEBT", snapshot.data![2], Colors.redAccent, subTextCol),
                                  ],
                                ),
                              );
                            },
                          ),

                          // --- GROUPED SOURCE BREAKDOWN ---
                          FutureBuilder<Map<String, double>>(
                            future: totalsBySourceFuture,
                            builder: (context, snapshot) {
                              if (isLoading || !snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                              Map<String, double> groupedTotals = {};
                              snapshot.data!.forEach((key, value) {
                                String upperKey = key.toUpperCase();
                                String groupName = "OTHER PRODUCTS";
                                if (upperKey.contains("NORMAL") || upperKey.contains("MEDICINE")) groupName = "NORMAL PRODUCTS";
                                else if (upperKey.contains("SERVICE")) groupName = "SERVICES";
                                else if (upperKey.contains("DEBT") || upperKey.contains("LEND")) groupName = " PAID DEBT ";
                                groupedTotals[groupName] = (groupedTotals[groupName] ?? 0) + value;
                              });

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
                                child: ExpansionTile(
                                  collapsedBackgroundColor: cardColor,
                                  backgroundColor: cardColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                  title: Text("Revenue Breakdown", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textCol)),
                                  children: groupedTotals.entries.map((e) => ListTile(
                                    dense: true,
                                    title: Text(e.key, style: TextStyle(fontSize: 11, color: textCol)),
                                    trailing: Text("TSH ${NumberFormat('#,##0').format(e.value)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  )).toList(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  ];
                },
                // 3. FULL WIDTH DATA TABLE
                body: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : FutureBuilder<List<Map<String, dynamic>>>(
                      future: salesData,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No records."));

                        final filteredList = snapshot.data!.where((item) {
                          String src = (item['source'] ?? '').toString().toUpperCase();
                          if (selectedCategory == "ALL") return true;
                          if (selectedCategory == "NORMAL PRODUCT") return src.contains("NORMAL") || src.contains("NORMAL PRODUCT");
                          if (selectedCategory == "OTHER PRODUCT") return src.contains("OTHER");
                          if (selectedCategory == "SERVICES") return src.contains("SERVICE");
                          if (selectedCategory == "DEBT") return (item['origin_table'] ?? '').toString().toLowerCase().contains('lend');
                          return true;
                        }).toList();

                        final bool hasHighAccess = ['admin', 'sub_admin'].contains(_realRoleFromDB.toLowerCase());

                        return Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: Scrollbar(
                              notificationPredicate: (notif) => notif.depth == 1,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                                  child: DataTable(
                                    showCheckboxColumn: false,
                                    headingRowHeight: 45,
                                    headingRowColor: WidgetStateProperty.all(primaryPurple),
                                    columnSpacing: 18,
                                    columns: [
                                      if (hasHighAccess) const DataColumn(label: Text('Business', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Receipt', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Customer', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Product', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Source', style: TextStyle(color: Colors.white, fontSize: 11))), // ✅ SOURCE COLUMN
                                      const DataColumn(label: Text('Total', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Method', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Time', style: TextStyle(color: Colors.white, fontSize: 11))),
                                      const DataColumn(label: Text('Action', style: TextStyle(color: Colors.white, fontSize: 11))),
                                    ],
                                    rows: filteredList.map((sale) {
                                      final String rawSrc = (sale['source'] ?? 'N/A').toString().toUpperCase();
                                      final String staffName = (sale['confirmed_by'] ?? sale['full_name'] ?? 'N/A').toString();

                                      // Logic ya Rangi za Source Badge
                                      String displayGroup = "OTHER";
                                      Color grpBg = Colors.teal.withOpacity(0.15);
                                      Color grpText = Colors.teal.shade900;

                                      if (rawSrc.contains("NORMAL") || rawSrc.contains("MEDICINE")) {
                                        displayGroup = "NORMAL";
                                        grpBg = Colors.blue.withOpacity(0.15);
                                        grpText = Colors.blue.shade900;
                                      } else if (rawSrc.contains("SERVICE")) {
                                        displayGroup = "SERVICE";
                                        grpBg = Colors.orange.withOpacity(0.15);
                                        grpText = Colors.orange.shade900;
                                      } else if (rawSrc.contains("DEBT") || rawSrc.contains("LEND")) {
                                        displayGroup = "DEBT";
                                        grpBg = Colors.red.withOpacity(0.15);
                                        grpText = Colors.red.shade900;
                                      }

                                      return DataRow(
                                        onSelectChanged: (_) => _showSaleDetailsDialog(context, sale),
                                        cells: [
                                          if (hasHighAccess) DataCell(Text((sale['business_name'] ?? '').toString(), style: const TextStyle(fontSize: 9))),
                                          DataCell(Text(sale['receipt_number'] ?? '-', style: const TextStyle(fontSize: 10))),
                                          DataCell(Text((sale['customer_name'] ?? '-').toString().toUpperCase(), style: const TextStyle(fontSize: 9))),

                                          // Product Cell
                                          DataCell(SizedBox(
                                              width: 120,
                                              child: Text(sale['medicine_name'] ?? sale['product_name'] ?? '-',
                                                  style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis)
                                          )),

                                          // ✅ SOURCE BADGE CELL
                                          DataCell(Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            decoration: BoxDecoration(color: grpBg, borderRadius: BorderRadius.circular(6)),
                                            child: Text(displayGroup, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: grpText)),
                                          )),

                                          // Staff Cell


                                          // Total Price Cell
                                          DataCell(Text(NumberFormat('#,##0').format(sale['total_price'] ?? 0),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),

                                          // Method Cell
                                          DataCell(Text((sale['payment_method'] ?? '').toString(), style: const TextStyle(fontSize: 9))),

                                          // Time Cell
                                          DataCell(Text(_formatTime(sale['paid_time'] ?? sale['created_at']),
                                              style: const TextStyle(fontSize: 9))),

                                          // Action Icon
                                          const DataCell(Icon(Icons.remove_red_eye_outlined, color: Colors.blue, size: 18)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
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