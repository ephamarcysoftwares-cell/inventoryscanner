import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class OtherSevrcesReport extends StatefulWidget {
  final String userRole;
  final String userName;

  const OtherSevrcesReport({super.key, required this.userRole, required this.userName});

  @override
  _OtherSevrcesReportState createState() => _OtherSevrcesReportState();
}

class _OtherSevrcesReportState extends State<OtherSevrcesReport> {
  List<Map<String, dynamic>> _salesList = [];
  Map<String, double> branchPerformance = {};
  Map<String, double> staffPerformance = {};

  double _totalAmount = 0.0;
  double _totalProfit = 0.0;
  double _totalExpenses = 0.0;
  double _netProfit = 0.0;
  bool _isLoading = false;
  bool _isDarkMode = false;
  String? _actualRole;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  int? businessId;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _initData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final userData = await Supabase.instance.client
          .from('users')
          .select('business_id, role')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null && mounted) {
        setState(() {
          businessId = int.tryParse(userData['business_id'].toString());
          _actualRole = userData['role']?.toString().toLowerCase().trim();
        });
        _fetchReport();
      }
    } catch (e) {
      debugPrint("❌ User Error: $e");
    }
  }

  Future<void> _fetchReport() async {
    if (businessId == null) return;
    setState(() => _isLoading = true);

    try {
      final String roleToUse = _actualRole ?? widget.userRole.toLowerCase().trim();
      final response = await Supabase.instance.client.rpc('get_staff_sales_report10', params: {
        'p_business_id': businessId,
        'p_user_id': Supabase.instance.client.auth.currentUser!.id,
        'p_user_role': roleToUse,
        'p_start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'p_end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'p_keyword': _searchController.text.trim(),
      });

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      double total = 0;
      double grossProfit = 0;
      double expenses = data.isNotEmpty ? (data.first['total_expenses'] as num?)?.toDouble() ?? 0.0 : 0.0;

      Map<String, double> bPerf = {};
      Map<String, double> sPerf = {};

      for (var row in data) {
        double rowTotal = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        total += rowTotal;
        grossProfit += (row['profit'] as num?)?.toDouble() ?? 0.0;

        String branch = row['source'] ?? 'Main';
        String staff = row['confirmed_by'] ?? 'Unknown';
        bPerf[branch] = (bPerf[branch] ?? 0) + rowTotal;
        sPerf[staff] = (sPerf[staff] ?? 0) + rowTotal;
      }

      setState(() {
        _salesList = data;
        _totalAmount = total;
        _totalProfit = grossProfit;
        _totalExpenses = expenses;
        _netProfit = grossProfit - expenses;
        branchPerformance = bPerf;
        staffPerformance = sPerf;
      });
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String role = _actualRole ?? widget.userRole.toLowerCase().trim();
    final bool isAdmin = role == 'admin';
    final bool isSubAdmin = role == 'sub_admin';
    final bool isManager = isAdmin || isSubAdmin;
    final isDark = _isDarkMode;
    final Color cardCol = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          children: [
            Text(isAdmin ? "TOTAL SYSTEM REPORT" : isSubAdmin ? "BRANCH PERFORMANCE" : "MY SALES",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(widget.userName.toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
          ],
        ),
        backgroundColor: Colors.indigo[900],
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.indigo[900],
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(child: _dateTile("KUANZIA", _startDate, (d) => setState(() => _startDate = d))),
                const SizedBox(width: 12),
                Expanded(child: _dateTile("MPAKA", _endDate, (d) => setState(() => _endDate = d))),
              ],
            ),
          ),

          // SUMMARY PERFORMANCE SECTION (MANAGERS ONLY)
          if (isManager) _buildPerformanceSection(isAdmin, isSubAdmin, isDark),

          // Search Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _fetchReport(),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: isAdmin ? "Tafuta staff, tawi au bidhaa..." : "Tafuta bidhaa...",
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.indigo[900]),
                filled: true,
                fillColor: cardCol,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Main Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: _salesList.isEmpty
                  ? _emptyState()
                  : ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.indigo.withOpacity(0.05)),
                      columnSpacing: 25,
                      columns: [
                        DataColumn(label: _headerText('Tarehe')),
                        DataColumn(label: _headerText('Bidhaa')),
                        DataColumn(label: _headerText('Qty')),
                        DataColumn(label: _headerText('Jumla')),
                        if (isAdmin) DataColumn(label: _headerText('Tawi')),
                        if (isManager) DataColumn(label: _headerText('Mhusika')),
                        if (isManager) DataColumn(label: _headerText('Faida')),
                      ],
                      rows: _salesList.map((s) {
                        final date = DateTime.parse(s['sale_date'].toString());
                        return DataRow(cells: [
                          DataCell(Text(DateFormat('dd/MM HH:mm').format(date), style: const TextStyle(fontSize: 10.5))),
                          DataCell(Text(s['item_name']?.toString().toUpperCase() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600))),
                          DataCell(Text(s['quantity'].toString())),
                          DataCell(Text(NumberFormat('#,###').format(s['total_price'] ?? 0), style: const TextStyle(fontWeight: FontWeight.bold))),
                          if (isAdmin) DataCell(Text(s['source'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.blueGrey))),
                          if (isManager) DataCell(Text(s['confirmed_by'] ?? '', style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w500))),
                          if (isManager)
                            DataCell(Text(NumberFormat('#,###').format(s['profit'] ?? 0),
                                style: TextStyle(
                                    color: (s['profit'] ?? 0) >= 0 ? Colors.green[700] : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11))),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 4),
    );
  }

  Widget _headerText(String txt) => Text(txt, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo));

  Widget _buildPerformanceSection(bool isAdmin, bool isSubAdmin, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _summaryBox("MAUZO", _totalAmount, Colors.blue),
              const SizedBox(width: 8),
              _summaryBox("MATUMIZI", _totalExpenses, Colors.red),
              const SizedBox(width: 8),
              _summaryBox("FAIDA HALISI", _netProfit, Colors.green),
            ],
          ),
          const SizedBox(height: 16),
          if (isAdmin) ...[
            const Text(" MAUZO KWA MATAWI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 6),
            SizedBox(
              height: 55,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: branchPerformance.entries.map((e) => _miniPerfCard(e.key, e.value, Colors.blueGrey)).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(isSubAdmin ? " MAUZO YA STAFF WANGU" : " MAUZO KWA STAFF", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          SizedBox(
            height: 55,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: staffPerformance.entries.map((e) => _miniPerfCard(e.key, e.value, Colors.indigo)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(String title, double val, Color col) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: col.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: col, fontSize: 9, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(child: Text(NumberFormat('#,###').format(val), style: TextStyle(color: col, fontSize: 14, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
    );
  }

  Widget _miniPerfCard(String title, double value, Color color) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 12, backgroundColor: color.withOpacity(0.2), child: Icon(Icons.person, size: 12, color: color)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
                Text(NumberFormat('#,###').format(value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateTile(String label, DateTime dt, Function(DateTime) onPick) {
    return InkWell(
      onTap: () async {
        DateTime? p = await showDatePicker(context: context, initialDate: dt, firstDate: DateTime(2024), lastDate: DateTime(2100));
        if (p != null) { onPick(p); _fetchReport(); }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 14, color: Colors.white70),
            const SizedBox(width: 6),
            Text("${DateFormat('dd MMM').format(dt)}", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_chart_outlined, size: 80, color: Colors.indigo.withOpacity(0.1)),
          const Text("Hakuna kumbukumbu zilizopatikana", style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}