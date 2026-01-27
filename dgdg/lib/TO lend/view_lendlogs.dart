import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaidLendLogsScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const PaidLendLogsScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _PaidLendLogsScreenState createState() => _PaidLendLogsScreenState();
}

class _PaidLendLogsScreenState extends State<PaidLendLogsScreen> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> paidLendData;
  late Future<double> paidLendTotal;

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  String businessName = 'Loading...';
  dynamic currentBusinessId;
  bool _isDarkMode = false;
  String get userRole => widget.userRole;
  String get userName => widget.userName;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    // ✅ Sasa kila mtu anaweza kuingia (anyone can view)
    _initializeAndFilter();
  }

  Future<void> _initializeAndFilter() async {
    setState(() => isLoading = true);
    await getBusinessInfo();
    _applyFilters();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  // Ongeza variable hii juu kwenye State class
  String _realRoleFromDB = '';

  Future<void> getBusinessInfo() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Tunavuta data kutoka public.users
      final data = await supabase
          .from('users')
          .select('business_name, business_id, role, sub_business_name')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          // Hapa ndipo ulinzi unapoanzia: business_id ya huyu user
          currentBusinessId = data['business_id'];
          _realRoleFromDB = data['role']?.toString().toLowerCase() ?? '';

          // Jina la kuonyesha kwenye AppBar
          // Kama ni sub_admin, accountant, au hr, tumia sub_business_name kama lipo
          if (['sub_admin', 'accountant', 'hr'].contains(_realRoleFromDB)) {
            businessName = data['sub_business_name'] ?? data['business_name'] ?? 'N/A';
          } else {
            businessName = data['business_name'] ?? 'N/A';
          }
        });

        debugPrint("🔐 AUTH CHECK: Role=$_realRoleFromDB, BranchID=$currentBusinessId");

        // Muhimu: Sasa tunaita applyFilters ambayo itatumia hii currentBusinessId kufanya uchuuzi
        _applyFilters();
      }
    } catch (e) {
      debugPrint('❌ Error fetching business info: $e');
    }
  }

  // --- SUPABASE FETCH METHODS (Supabase Only) ---

  Future<List<Map<String, dynamic>>> _fetchPaidLendData() async {
    try {
      // 🛡️ SECURITY CHECK: Kama hatuna ID ya biashara, usilete data yoyote
      if (currentBusinessId == null) return [];

      // Tunatumia .eq('business_id', currentBusinessId) kufunga data kwenye tawi husika
      var query = supabase
          .from('To_lent_payedlogs')
          .select()
          .eq('business_id', currentBusinessId); // Kigezo kikuu cha ulinzi

      // Filter ya Search
      if (searchController.text.trim().isNotEmpty) {
        String k = '%${searchController.text.trim()}%';
        query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k');
      }

      final response = await query.order('confirmed_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ Error fetching data: $e");
      return [];
    }
  }

  Future<double> _fetchPaidLendTotal() async {
    try {
      if (currentBusinessId == null) return 0.0;

      // Tunapiga hesabu ya total_price kwa business_id husika pekee
      var query = supabase
          .from('To_lent_payedlogs')
          .select('total_price')
          .eq('business_id', currentBusinessId);

      // Filter za Tarehe (Kama zimechaguliwa)
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!);
        query = query
            .gte('confirmed_time', '$start 00:00:00')
            .lte('confirmed_time', '$end 23:59:59');
      }

      final response = await query;

      double cloudTotal = 0.0;
      if (response is List) {
        for (var row in response) {
          cloudTotal += (double.tryParse(row['total_price']?.toString() ?? '0') ?? 0.0);
        }
      }
      return cloudTotal;
    } catch (e) {
      debugPrint("‼️ Error calculating total: $e");
      return 0.0;
    }
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      paidLendData = _fetchPaidLendData();
      paidLendTotal = _fetchPaidLendTotal();
    });
    Future.wait([paidLendData, paidLendTotal]).then((_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  // --- UI BUILDING SECTIONS ---

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) startDate = picked; else endDate = picked;
        isLoading = true;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.grey[600]!;
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 100, // Nimeongeza kidogo ili nafasi itoshe vizuri
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "DEBT RECOVERY REPORT",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon inayobadilika kulingana na Role
                  Icon(
                    _realRoleFromDB == 'accountant' ? Icons.account_balance_wallet : Icons.store_mall_directory,
                    color: Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      // Inaonyesha Role na Jina la Tawi: Mfano "ACCOUNTANT: ARUSHA ONLINE"
                      "${_realRoleFromDB.toUpperCase()}: ${businessName.trim().toUpperCase()}",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 5,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Curve nzuri ya chini kwa ajili ya muonekano wa kisasa wa simu
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(35),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: textCol),
                decoration: InputDecoration(
                  hintText: "Search records...",
                  prefixIcon: const Icon(Icons.search, color: primaryPurple),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
          ),
          // Date Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildDateBtn(startDate == null ? "Start Date" : DateFormat('yyyy-MM-dd').format(startDate!), cardColor, textCol, () => _selectDate(context, true))),
                const SizedBox(width: 12),
                Expanded(child: _buildDateBtn(endDate == null ? "End Date" : DateFormat('yyyy-MM-dd').format(endDate!), cardColor, textCol, () => _selectDate(context, false))),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Total Sum Card
          FutureBuilder<double>(
            future: paidLendTotal,
            builder: (context, snapshot) {
              final double total = snapshot.data ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withOpacity(0.2))),
                  child: Column(
                    children: [
                      Text("Total Debt Payments Collected", style: TextStyle(color: subTextCol, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("TSH ${NumberFormat('#,##0').format(total)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // Records List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                : FutureBuilder<List<Map<String, dynamic>>>(
              future: paidLendData,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final data = snapshot.data!;
                if (data.isEmpty) return Center(child: Text("No records available", style: TextStyle(color: subTextCol)));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final sale = data[index];
                    return _buildLogCard(sale, cardColor, textCol, subTextCol, primaryPurple, isDark);
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> sale, Color cardColor, Color textCol, Color subTextCol, Color primaryPurple, bool isDark) {
    // Logic ya kuonesha kama ni Main au Branch
    // Mfano: Kama 54 ndio Main Branch yako
    final bool isMainBranch = sale['business_id'] == 54;

    String formattedDate = 'N/A';
    if (sale['confirmed_time'] != null) {
      try {
        formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(sale['confirmed_time'].toString()));
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🏷️ Hii ndio Label inayoonesha aina ya tawi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isMainBranch ? Colors.blue.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isMainBranch ? "MAIN" : "BRANCH",
                style: TextStyle(
                  color: isMainBranch ? Colors.blue : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.receipt_long, size: 20),
          ],
        ),
        title: Text(sale['customer_name']?.toString() ?? 'Unknown Customer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textCol)),
        subtitle: Text("${sale['receipt_number'] ?? 'N/A'} • ${sale['payment_method'] ?? 'N/A'}",
            style: TextStyle(fontSize: 12, color: subTextCol)),
        trailing: Text("TSH ${NumberFormat('#,##0').format(sale['total_price'] ?? 0)}",
            style: TextStyle(fontWeight: FontWeight.bold, color: primaryPurple)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow("Branch Name", sale['business_name']?.toString(), textCol, subTextCol), // ✅ Inaonesha jina la tawi
                _infoRow("Product", sale['medicine_name']?.toString(), textCol, subTextCol),
                _infoRow("Staff", sale['confirmed_by']?.toString(), textCol, subTextCol),
                _infoRow("Date", formattedDate, textCol, subTextCol),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDateBtn(String text, Color bg, Color txt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withOpacity(0.2))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF673AB7)),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: txt)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? value, Color txtCol, Color subTxt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: subTxt, fontSize: 12)),
          Text(value ?? 'N/A', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: txtCol)),
        ],
      ),
    );
  }
}