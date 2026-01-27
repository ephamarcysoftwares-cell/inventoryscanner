import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum ReportType { fullYear, monthly }

class BusinessReportsPage extends StatefulWidget {
  const BusinessReportsPage({Key? key}) : super(key: key);
  @override
  State<BusinessReportsPage> createState() => _BusinessReportsPageState();
}

class _BusinessReportsPageState extends State<BusinessReportsPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Logic & Security State
  String? businessName;
  int? currentBusinessId;
  String? userRole;
  bool _isLoading = true;
  bool _isDarkMode = false;

  late int _selectedYear;
  int _selectedMonth = DateTime.now().month;
  ReportType _reportType = ReportType.monthly;

  // Data Futures
  Future<Map<String, dynamic>>? _summaryFuture;
  Future<List<dynamic>>? _staffFuture;
  Future<List<dynamic>>? _topProductsFuture;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
    _loadSettings();
    _fetchBizAndLoad();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  /// 🔐 Hatua ya 1: Vuta taarifa za mtumiaji na zuia asione tawi lingine
  Future<void> _fetchBizAndLoad() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('users')
            .select('business_name, business_id, role, sub_business_name')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            userRole = data['role']?.toString().toLowerCase();
            // Geuza ID kuwa integer kwa ajili ya SQL RPC
            currentBusinessId = int.tryParse(data['business_id']?.toString() ?? '');

            // Uteuzi wa jina la kuonyesha (Tawi vs Makao Makuu)
            if (userRole == 'admin') {
              businessName = data['business_name'] ?? "MAIN BUSINESS";
            } else {
              businessName = data['sub_business_name'] ?? data['business_name'] ?? "MY BRANCH";
            }
            _isLoading = false;
          });

          debugPrint("🚀 [DEBUG] USER AUTH: Role=$userRole, BranchID=$currentBusinessId, Name=$businessName");
          _refreshReports();
        }
      }
    } catch (e) {
      debugPrint("❌ [DEBUG] Error loading user info: $e");
    }
  }

  /// 🔄 Hatua ya 2: Refresh data zote kwa kutumia ID ya tawi husika
  void _refreshReports() {
    if (currentBusinessId == null) {
      debugPrint("⚠️ [DEBUG] Refresh aborted: currentBusinessId is null");
      return;
    }
    setState(() {
      _summaryFuture = _getSummary();
      _staffFuture = _getStaffPerformance();
      _topProductsFuture = _getTopProducts();
    });
  }

  /// 🛠️ Hatua ya 3: Tengeneza vigezo vya RPC (Hapa ndipo ulinzi ulipo)
  Map<String, dynamic> _getParams() {
    DateTime start, end;
    if (_reportType == ReportType.fullYear) {
      start = DateTime(_selectedYear, 1, 1);
      end = DateTime(_selectedYear, 12, 31, 23, 59, 59);
    } else {
      start = DateTime(_selectedYear, _selectedMonth, 1);
      end = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59);
    }

    final params = {
      'p_business_id': currentBusinessId,
      'start_date': start.toUtc().toIso8601String(),
      'end_date': end.toUtc().toIso8601String(),
    };

    debugPrint("📡 [DEBUG] RPC PARAMS: $params");
    return params;
  }

  // --- RPC Fetchers ---
  Future<Map<String, dynamic>> _getSummary() async =>
      Map<String, dynamic>.from(await supabase.rpc('get_business_summary_final', params: _getParams()));

  Future<List<dynamic>> _getStaffPerformance() async =>
      List<dynamic>.from(await supabase.rpc('get_staff_performance', params: _getParams()));

  Future<List<dynamic>> _getTopProducts() async =>
      List<dynamic>.from(await supabase.rpc('get_top_sold_products', params: _getParams()));

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.indigo)));

    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF1F5F9);
    final Color cardColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(businessName!.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("LOGGED AS: ${userRole?.toUpperCase()}", style: const TextStyle(fontSize: 8, color: Colors.white70)),
          ],
        ),
        backgroundColor: _isDarkMode ? const Color(0xFF16213E) : const Color(0xFF1A237E),
        elevation: 0, centerTitle: true,
        actions: [
          IconButton(onPressed: _generatePdf, icon: const Icon(Icons.picture_as_pdf, color: Colors.white)),
          IconButton(onPressed: _refreshReports, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { _refreshReports(); },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterCard(cardColor, textColor),
              const SizedBox(height: 20),
              _SummaryGrid(
                future: _summaryFuture,
                cardColor: cardColor,
                textColor: textColor,
                onTrack: (title, rpc) => _showDrillDown(context, title, rpc),
              ),
              const SizedBox(height: 25),
              _sectionTitle("STOCK & VALUATION", textColor),
              _StockValuationSection(
                future: _summaryFuture,
                cardColor: cardColor,
                textColor: textColor,
                onTrack: (title, rpc, isStatic) => _showDrillDown(context, title, rpc, isStatic: isStatic),
              ),
              const SizedBox(height: 25),
              _sectionTitle("TOP 10 PRODUCTS", textColor),
              _TopProductsSection(future: _topProductsFuture, cardColor: cardColor, textColor: textColor),
              const SizedBox(height: 25),
              _sectionTitle("STAFF RANKING", textColor),
              _StaffPerformanceSection(
                future: _staffFuture,
                cardColor: cardColor,
                textColor: textColor,
                onTrack: (title, rpc, staffId) => _showDrillDown(context, title, rpc, staffId: staffId),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔎 Hatua ya 4: Drill Down (Miamala ya kina)
  void _showDrillDown(BuildContext context, String title, String rpcName, {bool isStatic = false, String? staffId}) {
    final Color modalBg = _isDarkMode ? const Color(0xFF0A1128) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : const Color(0xFF0F172A);

    Map<String, dynamic> params = _getParams();
    if (staffId != null) params['staff_user_name'] = staffId;

    debugPrint("🔍 [DEBUG] DrillDown RPC: $rpcName with Params: $params");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(color: modalBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(children: [
            const SizedBox(height: 15),
            Center(child: Text(title.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: textColor))),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: supabase.rpc(rpcName, params: params).then((v) => List<dynamic>.from(v)),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snap.hasError) return Center(child: Text("RPC Error: ${snap.error}"));
                  if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text("No records for this branch."));

                  return ListView.builder(
                    controller: controller,
                    itemCount: snap.data!.length,
                    itemBuilder: (context, i) {
                      final item = snap.data![i];
                      return ListTile(
                        leading: const Icon(Icons.history, size: 20),
                        title: Text(item['item_name']?.toString() ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(item['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.parse(item['created_at'])) : "N/A"),
                        trailing: Text(NumberFormat("#,###").format(item['amount'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent)),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // --- UI Filter Components ---
  Widget _buildFilterCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: [
          _filterTypeOption("Monthly", ReportType.monthly),
          const SizedBox(width: 20),
          _filterTypeOption("Yearly", ReportType.fullYear),
        ]),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _customDropdown("Year", _selectedYear, [2024, 2025, 2026], (v) { setState(() => _selectedYear = v!); _refreshReports(); }, textColor, cardColor)),
          if (_reportType == ReportType.monthly) ...[
            const SizedBox(width: 12),
            Expanded(child: _customDropdown("Month", _selectedMonth, List.generate(12, (i) => i + 1), (v) { setState(() => _selectedMonth = v!); _refreshReports(); }, textColor, cardColor)),
          ],
        ]),
      ]),
    );
  }

  Widget _filterTypeOption(String title, ReportType type) {
    bool isSel = _reportType == type;
    return GestureDetector(
      onTap: () { setState(() => _reportType = type); _refreshReports(); },
      child: Row(children: [
        Icon(isSel ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: isSel ? Colors.indigo : Colors.grey),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, color: isSel ? Colors.indigo : Colors.grey)),
      ]),
    );
  }

  Widget _customDropdown(String label, dynamic val, List<dynamic> items, Function(dynamic) onChg, Color txt, Color bg) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, color: txt.withOpacity(0.5))),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(dropdownColor: bg, value: val, isExpanded: true, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e is int && label == "Month" ? DateFormat('MMMM').format(DateTime(0, e)) : e.toString()))).toList(), onChanged: onChg, style: TextStyle(color: txt, fontWeight: FontWeight.bold))),
      ),
    ],
  );

  Widget _sectionTitle(String title, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: color.withOpacity(0.4), letterSpacing: 1.2)),
  );

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final d = await _summaryFuture;
    if (d == null) return;
    final String reportDate = _reportType == ReportType.monthly ? "${DateFormat('MMMM').format(DateTime(0, _selectedMonth))} $_selectedYear" : "$_selectedYear";

    pdf.addPage(pw.MultiPage(build: (pw.Context context) => [
      pw.Header(level: 0, child: pw.Text("${businessName?.toUpperCase()} REPORT ($reportDate)")),
      pw.TableHelper.fromTextArray(data: [
        ['Revenue', NumberFormat("#,###").format(d['revenue'] ?? 0)],
        ['Expenses', NumberFormat("#,###").format(d['expenses'] ?? 0)],
        ['Net Profit', NumberFormat("#,###").format(d['net_profit'] ?? 0)],
      ]),
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

// --- SUB COMPONENTS (STRICTLY ISOLATED) ---
class _SummaryGrid extends StatelessWidget {
  final Future<Map<String, dynamic>>? future;
  final Color cardColor, textColor;
  final Function(String, String) onTrack;
  const _SummaryGrid({required this.future, required this.cardColor, required this.textColor, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        final d = snap.data!;
        return GridView(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 75, crossAxisSpacing: 10, mainAxisSpacing: 10),
          children: [
            _card("REVENUE", d['revenue'], Colors.blue, Icons.payments, "get_sales_drilldown"),
            _card("EXPENSES", d['expenses'], Colors.redAccent, Icons.shopping_bag, "get_usage_drilldown"),
            _card("DEBIT (OUT)", d['debit_issued'], Colors.orange, Icons.money_off, "get_debit_issued_drilldown"),
            _card("DEBIT PAID", d['debit_paid'], Colors.green, Icons.check_circle, "get_debit_paid_drilldown"),
          ],
        );
      },
    );
  }

  Widget _card(String t, dynamic v, Color c, IconData i, String rpc) => InkWell(
    onTap: () => onTrack(t, rpc),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))),
      child: Row(children: [
        Icon(i, color: c, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
          FittedBox(child: Text(NumberFormat("#,###").format(v ?? 0), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: textColor))),
        ])),
      ]),
    ),
  );
}

class _StockValuationSection extends StatelessWidget {
  final Future<Map<String, dynamic>>? future;
  final Color cardColor, textColor;
  final Function(String, String, bool) onTrack;
  const _StockValuationSection({required this.future, required this.cardColor, required this.textColor, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        final d = snap.data!;
        return Column(children: [
          _wideCard("CURRENT STOCK VALUE", d['stock_buying_cost'], Colors.purple, Icons.store, "get_current_stock_drilldown", true),
          const SizedBox(height: 10),
          _wideCard("TOTAL NET PROFIT", d['net_profit'], Colors.indigo, Icons.trending_up, null, false),
        ]);
      },
    );
  }

  Widget _wideCard(String t, dynamic v, Color c, IconData i, String? rpc, bool isStatic) => InkWell(
    onTap: rpc == null ? null : () => onTrack(t, rpc, isStatic),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.1))),
      child: Row(children: [
        Icon(i, color: c, size: 20),
        const SizedBox(width: 15),
        Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.6))),
        const Spacer(),
        Text(NumberFormat("#,###").format(v ?? 0), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
        if (rpc != null) const Icon(Icons.chevron_right, size: 16),
      ]),
    ),
  );
}

class _TopProductsSection extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final Color cardColor, textColor;
  const _TopProductsSection({required this.future, required this.cardColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        return Container(
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
          child: Column(children: snap.data!.take(5).map((e) => ListTile(
            dense: true,
            title: Text(e['item_name']?.toString() ?? "N/A", style: TextStyle(fontSize: 12, color: textColor)),
            trailing: Text("Qty: ${e['total_qty']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          )).toList()),
        );
      },
    );
  }
}

class _StaffPerformanceSection extends StatelessWidget {
  final Future<List<dynamic>>? future;
  final Color cardColor, textColor;
  final Function(String, String, String) onTrack;
  const _StaffPerformanceSection({required this.future, required this.cardColor, required this.textColor, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const Text("No staff data");
        num max = snap.data!.isNotEmpty ? snap.data!.map((e) => e['total_sales'] as num).reduce((a, b) => a > b ? a : b) : 1;
        return Column(children: snap.data!.map((s) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
          child: Column(children: [
            Row(children: [Text(s['staff_name']?.toString() ?? "Staff", style: TextStyle(fontSize: 12, color: textColor)), const Spacer(), Text("Tsh ${NumberFormat("#,###").format(s['total_sales'])}")]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: max > 0 ? (s['total_sales']/max) : 0, color: Colors.indigo, minHeight: 4),
          ]),
        )).toList());
      },
    );
  }
}