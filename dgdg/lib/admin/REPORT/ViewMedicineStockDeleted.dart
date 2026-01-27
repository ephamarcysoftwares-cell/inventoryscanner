import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// Ensure the path to your footer is correct
import '../../FOTTER/CurvedRainbowBar.dart';

class ViewEditHistory extends StatefulWidget {
  const ViewEditHistory({super.key});

  @override
  _ViewEditHistoryState createState() => _ViewEditHistoryState();
}

class _ViewEditHistoryState extends State<ViewEditHistory> {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> editLogs = Future.value([]);
  String businessName = 'Loading...';
  String searchQuery = "";
  bool _isDarkMode = false;
  // Date filter variables
  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getBusinessInfo();
    });
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> _getBusinessInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null || user.email == null) return;

      final data = await supabase
          .from('businesses')
          .select('business_name')
          .eq('email', user.email!)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          businessName = data['business_name']?.toString() ?? 'Unknown';
        });
        _refreshLogs();
      }
    } catch (e) {
      debugPrint('❌ Error fetching business: $e');
    }
  }

  void _refreshLogs() {
    if (mounted) {
      setState(() {
        editLogs = _fetchLogs();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchLogs() async {
    try {
      var query = supabase
          .from('edited_product_logs')
          .select()
          .eq('business_name', businessName);

      // --- APPLY DATE FILTER ---
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!);
        query = query.gte('edit_date', '$start 00:00:00').lte('edit_date', '$end 23:59:59');
      }

      // --- APPLY SEARCH FILTER ---
      if (searchQuery.isNotEmpty) {
        query = query.ilike('product_aftername', '%$searchQuery%');
      }

      final data = await query.order('edit_date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
      return [];
    }
  }



  @override
  Widget build(BuildContext context) {
    // Theme State Logic
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    // Admin Dashboard Style Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${businessName.toUpperCase()} EDITED-LOGS",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1),
            ),
            const SizedBox(height: 4),
            const Text(
              "SYSTEM AUDIT & CHANGE HISTORY",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshLogs,
          )
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Column(
        children: [
          // Pass context/theme to filters
          _buildFilters(primaryPurple, cardColor, textCol, isDark),
          Expanded(child: _buildLogList(primaryPurple, cardColor, textCol, subTextCol, isDark)),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildFilters(Color themeColor, Color cardColor, Color textCol, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: "Search Product name...",
                hintStyle: TextStyle(color: textCol.withOpacity(0.5)),
                prefixIcon: Icon(Icons.history, color: themeColor),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) {
                searchQuery = val;
                _refreshLogs();
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _datePickerButton(true, themeColor, cardColor, textCol, isDark)),
              const SizedBox(width: 10),
              Expanded(child: _datePickerButton(false, themeColor, cardColor, textCol, isDark)),
              if (startDate != null || endDate != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent),
                  onPressed: () {
                    setState(() { startDate = null; endDate = null; });
                    _refreshLogs();
                  },
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _datePickerButton(bool isStart, Color themeColor, Color cardColor, Color textCol, bool isDark) {
    String label = isStart
        ? (startDate == null ? "From" : DateFormat('dd MMM').format(startDate!))
        : (endDate == null ? "To" : DateFormat('dd MMM').format(endDate!));

    return InkWell(
      onTap: () async {
        DateTime? picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() { if (isStart) startDate = picked; else endDate = picked; });
          _refreshLogs();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 14, color: themeColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogList(Color themeColor, Color cardColor, Color textCol, Color subTextCol, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: editLogs,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: themeColor));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No edit records found.", style: TextStyle(color: subTextCol)));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final log = snapshot.data![index];
            DateTime editDate = DateTime.parse(log['edit_date']).toLocal();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 5)],
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  iconColor: themeColor,
                  collapsedIconColor: subTextCol,
                  leading: CircleAvatar(
                    backgroundColor: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                    child: const Icon(Icons.edit_note_rounded, color: Colors.orange),
                  ),
                  title: Text(
                    log['product_aftername'] ?? 'N/A',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? const Color(0xFF9575CD) : const Color(0xFF311B92)),
                  ),
                  subtitle: Text(
                    "Edited by ${log['edited_by']} • ${DateFormat('dd MMM, HH:mm').format(editDate)}",
                    style: TextStyle(fontSize: 11, color: subTextCol),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          Divider(color: isDark ? Colors.white10 : Colors.grey.shade100),
                          _buildComparisonTable(log, themeColor, textCol, isDark),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonTable(Map<String, dynamic> log, Color themeColor, Color textCol, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2),
          1: FlexColumnWidth(2),
          2: FlexColumnWidth(2),
        },
        children: [
          _tableRow("FIELD", "BEFORE", "AFTER", textCol, isDark, isHeader: true),
          _tableRow("Name", log['product_beforename'], log['product_aftername'], textCol, isDark),
          _tableRow("Qty", log['qty_before']?.toString(), log['qty_after']?.toString(), textCol, isDark),
          _tableRow("Price", log['price_before']?.toString(), log['price_after']?.toString(), textCol, isDark),
          _tableRow("Batch", log['batch_before'], log['batch_after'], textCol, isDark),
          _tableRow("Expiry", log['expiry_before'], log['expiry_after'], textCol, isDark),
        ],
      ),
    );
  }

  TableRow _tableRow(String field, String? before, String? after, Color textCol, bool isDark, {bool isHeader = false}) {
    bool isChanged = !isHeader && (before != after);
    Color headerTextCol = isDark ? const Color(0xFF9575CD) : const Color(0xFF311B92);
    Color activeTextCol = isHeader ? headerTextCol : textCol;

    return TableRow(
      decoration: BoxDecoration(
        color: isHeader
            ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50)
            : (isChanged ? Colors.orange.withOpacity(isDark ? 0.1 : 0.03) : Colors.transparent),
      ),
      children: [
        _tableCell(field, activeTextCol, isHeader, isBold: isHeader),
        _tableCell(before ?? '-', isHeader ? activeTextCol : (isDark ? Colors.redAccent : Colors.red.shade700), isHeader, isStrikethrough: isChanged),
        _tableCell(after ?? '-', isHeader ? activeTextCol : (isChanged ? (isDark ? Colors.greenAccent : Colors.green.shade700) : activeTextCol), isHeader, isBold: isChanged),
      ],
    );
  }

  Widget _tableCell(String text, Color color, bool isHeader, {bool isBold = false, bool isStrikethrough = false}) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 11 : 12,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color,
          decoration: isStrikethrough ? TextDecoration.lineThrough : null,
          decorationColor: color, // Ensures strikethrough color matches text
        ),
      ),
    );
  }
}