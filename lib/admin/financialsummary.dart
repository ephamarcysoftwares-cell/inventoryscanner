import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class FinancialSummaryScreen extends StatefulWidget {
  const FinancialSummaryScreen({super.key});

  @override
  _FinancialSummaryScreenState createState() => _FinancialSummaryScreenState();
}

class _FinancialSummaryScreenState extends State<FinancialSummaryScreen> {
  final supabase = Supabase.instance.client;

  // Data State
  List<dynamic> staffSales = [];
  double totalSalesOnly = 0.0;
  double totalLendOnly = 0.0;
  double grandTotalMoney = 0.0;
  int grandTotalItems = 0;

  String currentBusinessName = "Syncing...";
  bool _isLoading = true;
  bool _isDarkMode = false;
  DateTime? fromDate;
  DateTime? toDate;
  final formatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadTheme();
    final now = DateTime.now();
    fromDate = DateTime(now.year, now.month, now.day - 7);
    toDate = now;
    _fetchAssociatedSummary();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _fetchAssociatedSummary() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("❌ Error: No active user session.");
        return;
      }

      // 1. Fetch current business name from Supabase Profile
      // This is the security step to ensure the user only sees their own business
      final bizProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (bizProfile == null || bizProfile['business_name'] == null) {
        setState(() {
          currentBusinessName = "No Linked Business";
          _isLoading = false;
        });
        return;
      }

      final String myBiz = bizProfile['business_name'].toString().trim();
      setState(() => currentBusinessName = myBiz);

      // 2. Call the RPC strictly on Supabase
      // Parameter names MUST match the SQL function exactly
      final response = await supabase.rpc('get_financial_summary', params: {
        'from_date_text': DateFormat('yyyy-MM-dd').format(fromDate!),
        'to_date_text': DateFormat('yyyy-MM-dd').format(toDate!),
        'current_biz_name': myBiz,
      });

      if (response != null) {
        debugPrint("✅ Data Fetched from Cloud: $response");

        setState(() {
          // Parse the JSON object returned by the RPC
          staffSales = response['staff_data'] ?? [];
          totalSalesOnly = double.tryParse(response['sales_total'].toString()) ?? 0.0;
          totalLendOnly = double.tryParse(response['lend_total'].toString()) ?? 0.0;
          grandTotalItems = int.tryParse(response['grand_total_items'].toString()) ?? 0;
          grandTotalMoney = totalSalesOnly + totalLendOnly;
        });
      }

    } catch (e) {
      debugPrint("❌ Supabase Fetch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cloud Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color textCol = isDark ? Colors.white : Colors.black87;

    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            const Text("Financial Summary", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300)),
            Text(currentBusinessName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple, lightViolet],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : RefreshIndicator(
        onRefresh: _fetchAssociatedSummary,
        color: primaryPurple,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildDateRangeHeader(isDark, textCol),
            const SizedBox(height: 20),
            _buildFinancialCards(isDark, deepPurple, primaryPurple),
            const SizedBox(height: 25),
            Text("Staff Performance Summary",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? lightViolet : deepPurple)),
            Divider(color: isDark ? Colors.white10 : Colors.grey.shade300),
            _buildStaffTable(isDark, textCol),
            const SizedBox(height: 20),
            _buildTotalItemsFooter(isDark, deepPurple, lightViolet),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- UI HELPERS ---

  Widget _buildDateRangeHeader(bool isDark, Color textCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _dateButton(true, fromDate!, isDark),
        Icon(Icons.arrow_right_alt, color: isDark ? Colors.white38 : Colors.grey),
        _dateButton(false, toDate!, isDark),
      ],
    );
  }

  Widget _dateButton(bool isFrom, DateTime date, bool isDark) {
    return OutlinedButton.icon(
      onPressed: () => _selectDate(isFrom),
      icon: const Icon(Icons.calendar_month, size: 18, color: Color(0xFF673AB7)),
      label: Text(DateFormat('dd MMM yyyy').format(date), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.purple.withOpacity(0.2))),
    );
  }

  Widget _buildFinancialCards(bool isDark, Color deepPurple, Color primaryPurple) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [deepPurple, primaryPurple]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _moneyRow("Direct Sales", totalSalesOnly, Icons.sell),
          _moneyRow("Loans", totalLendOnly, Icons.handshake),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(color: Colors.white24)),
          _moneyRow("GRAND TOTAL", grandTotalMoney, Icons.account_balance_wallet, isGrand: true),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, IconData icon, {bool isGrand = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white, fontSize: isGrand ? 16 : 14, fontWeight: isGrand ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
        Text("TSH ${formatter.format(amount)}", style: TextStyle(color: Colors.white, fontSize: isGrand ? 18 : 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStaffTable(bool isDark, Color textCol) {
    if (staffSales.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("No records found.", style: TextStyle(color: textCol))));

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(isDark ? Colors.white10 : Colors.grey.shade100),
        columns: [
          DataColumn(label: Text("Staff", style: TextStyle(color: textCol))),
          DataColumn(label: Text("Qty", style: TextStyle(color: textCol))),
          DataColumn(label: Text("Total TSH", style: TextStyle(color: textCol))),
        ],
        rows: staffSales.map((staff) => DataRow(cells: [
          DataCell(Text(staff['confirmed_by']?.toString() ?? 'N/A', style: TextStyle(color: textCol))),
          DataCell(Text(staff['total_quantity']?.toString() ?? '0', style: TextStyle(color: textCol))),
          DataCell(Text(formatter.format(staff['total_price'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: textCol))),
        ])).toList(),
      ),
    );
  }

  Widget _buildTotalItemsFooter(bool isDark, Color deepPurple, Color lightViolet) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 20, color: isDark ? lightViolet : Colors.grey),
          const SizedBox(width: 10),
          Text("Grand Total Items Sold: $grandTotalItems",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Future<void> _selectDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? fromDate! : toDate!,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { if (isFrom) fromDate = picked; else toDate = picked; });
      _fetchAssociatedSummary();
    }
  }
}