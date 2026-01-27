import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewNormalUsageScreen extends StatefulWidget {
  @override
  _ViewNormalUsageScreenState createState() => _ViewNormalUsageScreenState();
}

class _ViewNormalUsageScreenState extends State<ViewNormalUsageScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _usageList = [];
  List<Map<String, dynamic>> _filteredUsageList = [];
  bool _isLoading = true;
  bool _isDarkMode = false;
  String _userRole = 'staff'; // Default role
  String _myFullName = '';
  String _mySubBranch = '';

  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  String business_name = 'PAKIA...';
  String businessLocation = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _searchController.addListener(_filterSearchResults);
    _initializeData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  // ✅ 1. PATA TAARIFA ZA USER NA BIASHARA KWANZA
  Future<void> _initializeData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Pata Profile ya aliye login
      final profile = await supabase
          .from('users')
          .select('role, full_name, sub_business_name, business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _userRole = profile['role']?.toString().toLowerCase() ?? 'staff';
          _myFullName = profile['full_name'] ?? '';
          _mySubBranch = profile['sub_business_name'] ?? '';
          business_name = profile['business_name']?.toString().toUpperCase() ?? 'MY BUSINESS';
        });
        await _fetchUsageData();
      }
    } catch (e) {
      debugPrint('❌ Init Error: $e');
    }
  }

  // ✅ 2. PATA DATA KULINGANA NA NANI AMELOGIN (STRICT FILTERING)
  Future<void> _fetchUsageData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('normal_usage').select();

      // HIERARCHY LOGIC
      if (_userRole == 'admin') {
        // Admin anaona kila kitu cha biashara hii
        query = query.eq('business_name', business_name);
      } else if (_userRole == 'sub_admin') {
        // Sub-Admin anaona ya tawi lake pekee
        query = query.eq('sub_business_name', _mySubBranch);
      } else {
        // Staff anaona aliyoweka yeye tu
        query = query.eq('added_by', _myFullName);
      }

      final response = await query.order('usage_date', ascending: false);

      if (mounted) {
        setState(() {
          _usageList = List<Map<String, dynamic>>.from(response);
          _filteredUsageList = _usageList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 3. FUTA REKODI (ADMIN NA SUB-ADMIN TU)
  Future<void> _deleteRecord(int id) async {
    try {
      await supabase.from('normal_usage').delete().eq('id', id);
      _fetchUsageData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rekodi imefutwa!"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("🚨 Error Deleting: $e");
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Futa Rekodi?"),
        content: const Text("Je, una uhakika unataka kufuta rekodi hii?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("HAPANA")),
          TextButton(
            onPressed: () {
              _deleteRecord(id);
              Navigator.pop(context);
            },
            child: const Text("NDIO, FUTA", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _filterByDateRange() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _filteredUsageList = _usageList.where((usage) {
          final usageDate = DateTime.parse(usage['usage_date']);
          return usageDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
              usageDate.isBefore(_endDate!.add(const Duration(days: 1)));
        }).toList();
      });
    }
  }

  void _filterSearchResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsageList = _usageList.where((usage) {
        final category = usage['category']?.toLowerCase() ?? '';
        final description = usage['description']?.toLowerCase() ?? '';
        final staff = usage['added_by']?.toLowerCase() ?? '';
        return category.contains(query) || description.contains(query) || staff.contains(query);
      }).toList();
    });
  }

  double _getTotalAmount() => _filteredUsageList.fold(0.0, (sum, usage) => sum + (double.tryParse(usage['amount'].toString()) ?? 0.0));

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
        _filterByDateRange();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(business_name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            Text(_userRole == 'admin' ? "RIPOTI KUU YA MATUMIZI" : "MATUMIZI YANGU", style: const TextStyle(fontSize: 9, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0277BD), Color(0xFF03A9F4)]))),
        actions: [
          if (_userRole != 'staff') IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _generatePDF)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF03A9F4)))
          : Column(
        children: [
          // STAFF HAONI JUMLA KUU (STATS)
          if (_userRole != 'staff') _buildHeaderStats(),

          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
                children: [
                  _buildFilters(isDark, cardColor),
                  const SizedBox(height: 10),
                  Expanded(child: _buildUsageList(isDark, cardColor)),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0277BD), Color(0xFF03A9F4)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(35)),
      ),
      child: Column(
        children: [
          Text("JUMLA YA MATUMIZI", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text("TSH ${NumberFormat('#,##0').format(_getTotalAmount())}",
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark, Color cardColor) {
    return Transform.translate(
      offset: const Offset(0, -15),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _dateBtn(true),
                const SizedBox(width: 10),
                _dateBtn(false),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Tafuta aina, maelezo au staff...",
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF03A9F4)),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F9FF),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBtn(bool isStart) {
    String txt = isStart ? (_startDate == null ? "Kuanzia" : DateFormat('dd MMM').format(_startDate!))
        : (_endDate == null ? "Mwisho" : DateFormat('dd MMM').format(_endDate!));
    return Expanded(
      child: InkWell(
        onTap: () => _pickDate(isStart),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: Border.all(color: Colors.blue.withOpacity(0.1)), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month, size: 14, color: Color(0xFF03A9F4)),
              const SizedBox(width: 5),
              Text(txt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageList(bool isDark, Color cardColor) {
    if (_filteredUsageList.isEmpty) return const Center(child: Text("Hakuna kumbukumbu!"));

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: _filteredUsageList.length,
      itemBuilder: (context, index) {
        final item = _filteredUsageList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item['category'] ?? 'Other', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                  ),

                  // STAFF HAONI DELETE
                  if (_userRole != 'staff')
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _confirmDelete(item['id']),
                    ),

                  Text("TSH ${NumberFormat('#,##0').format(item['amount'])}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 14)),
                ],
              ),
              const Divider(height: 15, thickness: 0.5),
              Text("MAELEZO:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey.withOpacity(0.6))),
              const SizedBox(height: 2),
              Text(item['description'] ?? 'No description',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Color(0xFF03A9F4)),
                      const SizedBox(width: 4),
                      Text("By: ${item['added_by'] ?? 'Unknown'}",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
                    ],
                  ),
                  Text(DateFormat('dd MMM yyyy').format(DateTime.parse(item['usage_date'])),
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // PDF LOGIC (ILIYOBORESHWA)
  Future<void> _generatePDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      build: (pw.Context context) => [
        pw.Header(level: 0, child: pw.Text(business_name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
        pw.Text("Ripoti ya Matumizi - ${_userRole.toUpperCase()} VIEW"),
        pw.Divider(),
        pw.Table.fromTextArray(
          headers: ['Category', 'Description', 'Amount', 'Date', 'Staff'],
          data: _filteredUsageList.map((u) => [
            u['category'],
            u['description'] ?? '-',
            u['amount'].toString(),
            u['usage_date'].toString().substring(0, 10),
            u['added_by'] ?? '-'
          ]).toList(),
        ),
      ],
    ));
    final output = await getApplicationDocumentsDirectory();
    final file = File("${output.path}/Matumizi_Report.pdf");
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Saved to Documents")));
  }
}