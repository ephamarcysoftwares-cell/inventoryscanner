import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class PharmacistReportScreen extends StatefulWidget {
  final String userRole; // 'admin' or 'staff'
  final String userName; // Jina la aliyelogin

  const PharmacistReportScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _PharmacistReportScreenState createState() => _PharmacistReportScreenState();
}

class _PharmacistReportScreenState extends State<PharmacistReportScreen> {
  // --- Variables za State ---
  late Future<List<Map<String, dynamic>>> salesData = Future.value([]);
  late Future<double> salesTotal = Future.value(0.0);
  late Future<double> paidLentTotal = Future.value(0.0);
  late Future<double> debtTotal = Future.value(0.0);
  late Future<Map<String, double>> totalsBySourceFuture = Future.value({});

  bool _isDarkMode = false;
  bool isLoading = false;
  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  // --- Session & Business Info ---
  String business_name = '';
  int? businessId;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadTheme();

    // Set tarehe ya leo kama default
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, now.day);
    endDate = DateTime(now.year, now.month, now.day);

    // Anza kupata taarifa za biashara kwanza
    getBusinessInfo();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  // 1. Pata Taarifa za Biashara na Staff ID
  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase
          .from('users')
          .select('id, business_id, business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || userProfile == null) return;

      setState(() {
        currentUserId = userProfile['id'];
        businessId = userProfile['business_id'] != null
            ? int.tryParse(userProfile['business_id'].toString())
            : null;
        business_name = userProfile['business_name'] ?? 'ONLINE STORE';
      });

      // Baada ya kupata IDs, vuta data
      _applyFilters();
    } catch (e) {
      debugPrint('❌ Error getBusinessInfo: $e');
    }
  }

  // 2. Fetch Sales Data (RPC Call)
  Future<List<Map<String, dynamic>>> _fetchSalesDataRPC(String? userId) async {
    final supabase = Supabase.instance.client;

    if (startDate == null || endDate == null || businessId == null) return [];

    try {
      final List<dynamic> response = await supabase.rpc(
        'get_combined_sales_report1', // Tumia jina jipya hapa
        params: {
          'p_business_id': businessId,
          'p_user_id': userId, // UUID ya staff
          'p_user_role': 'staff', // Kwa kuwa hii ni page ya user tu
          'p_start_date': DateFormat('yyyy-MM-dd').format(startDate!),
          'p_end_date': DateFormat('yyyy-MM-dd').format(endDate!),
          'p_keyword': searchController.text.trim(),
        },
      );

      debugPrint('✅ Data imepatikana: ${response.length} rows');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ RPC Error: $e');
      return [];
    }
  }

  // 3. Apply Filters & Calculate Totals
  void _applyFilters() async {
    if (startDate == null || endDate == null || businessId == null) return;

    setState(() => isLoading = true);

    try {
      final List<Map<String, dynamic>> rpcRows = await _fetchSalesDataRPC(currentUserId);

      double tempSales = 0.0;
      double tempPaid = 0.0;
      double tempDebt = 0.0;
      Map<String, double> tempBySource = {};

      for (var row in rpcRows) {
        double price = (row['total_price'] as num?)?.toDouble() ?? 0.0;
        String table = row['origin_table'] ?? 'sales';
        String source = row['source'] ?? 'General';

        if (table == 'logs' || table == 'To_lent_payedlogs') {
          tempPaid += price;
        } else if (table == 'lend' || table == 'To_lend') {
          tempDebt += price;
        } else {
          tempSales += price;
        }

        String key = "$table ($source)";
        tempBySource[key] = (tempBySource[key] ?? 0.0) + price;
      }

      if (mounted) {
        setState(() {
          salesData = Future.value(rpcRows);
          salesTotal = Future.value(tempSales);
          paidLentTotal = Future.value(tempPaid);
          debtTotal = Future.value(tempDebt);
          totalsBySourceFuture = Future.value(tempBySource);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Filter Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) startDate = picked; else endDate = picked;
      });
      if (startDate != null && endDate != null) _applyFilters();
    }
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
              "BRANCH: ${business_name.toUpperCase()}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            const Text("STAFF SALES ANALYTICS",
                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w300)),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple]),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          )
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
                            columns: const [
                              DataColumn(label: Text('Receipt')),
                              DataColumn(label: Text('Customer')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('Total')),
                              DataColumn(label: Text('Method')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Source')),
                              // DataColumn(label: Text('Confirmed By')),
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
                                  DataCell(Text((sale['receipt_number'] ?? sale['receipt'] ?? 'N/A').toString())),
                                  DataCell(Text((sale['customer_name'] ?? sale['customer'] ?? 'N/A').toString().toUpperCase())),
                                  DataCell(Text((sale['medicine_name'] ?? sale['medicine'] ?? 'N/A').toString())),
                                  DataCell(Text(NumberFormat('#,##0').format(price))),
                                  DataCell(Text(method.toUpperCase(), style: TextStyle(color: isLent ? Colors.redAccent : Colors.tealAccent, fontWeight: FontWeight.bold))),
                                  DataCell(Text(formattedDate)),
                                  DataCell(Text((sale['source'] ?? 'N/A').toString())),
                                  // DataCell(Text((sale['confirmed_by'] ?? 'N/A').toString())),
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