import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewMedicineStock extends StatefulWidget {
  const ViewMedicineStock({super.key});

  @override
  _ViewMedicineStockState createState() => _ViewMedicineStockState();
}

class _ViewMedicineStockState extends State<ViewMedicineStock> {
  late Future<List<Map<String, dynamic>>> medicines = Future.value([]);

  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  DateTime? startDate;
  DateTime? endDate;
  bool _isDarkMode = false;
  String activeBusinessName = "BRACH NAME"; // Default or dynamic

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null && res['business_name'] != null) {
        if (mounted) setState(() => activeBusinessName = res['business_name']);
      }
    }
    _fetchLogs();
  }

  void _fetchLogs() {
    setState(() {
      medicines = fetchMedicines();
    });
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<List<Map<String, dynamic>>> fetchMedicines() async {
    try {
      var query = Supabase.instance.client
          .from('medical_logs')
          .select()
          .eq('business_name', activeBusinessName);

      // --- DATE FILTER ---
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!);
        query = query.gte('date_added', '$start 00:00:00').lte('date_added', '$end 23:59:59');
      }

      // --- SEARCH FILTER ---
      if (searchQuery.isNotEmpty) {
        query = query.ilike('medicine_name', '%$searchQuery%');
      }

      final data = await query.order('date_added', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint("❌ Supabase Error: $e");
      return [];
    }
  }

  // --- PDF Export Logic ---
  void _generatePdf(List<Map<String, dynamic>> list) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) => [
          pw.Center(child: pw.Text(activeBusinessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Center(child: pw.Text("Stock Inventory Report")),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Medicine', 'Batch', 'Total', 'Rem.', 'Price', 'Expiry'],
            data: list.map((m) => [
              m['medicine_name'] ?? '',
              m['batch_number'] ?? '',
              m['total_quantity']?.toString() ?? '0',
              m['remaining_quantity']?.toString() ?? '0',
              m['selling_price']?.toString() ?? '0',
              m['expiry_date'] ?? '',
            ]).toList(),
          ),
        ],
      ),
    );

    String? path = await FilePicker.platform.saveFile(fileName: 'Report.pdf', type: FileType.custom, allowedExtensions: ['pdf']);
    if (path != null) await File(path).writeAsBytes(await pdf.save());
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
              activeBusinessName.isEmpty ? "INVENTORY" : activeBusinessName.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            const Text(
              "MASTER STOCK LOGS",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchLogs),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: () async => _generatePdf(await medicines),
          ),
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
          // Pass theme variables to helper
          _buildFilters(primaryPurple, cardColor, textCol, isDark),
          Expanded(child: _buildDataTable(primaryPurple, cardColor, textCol, subTextCol, isDark)),
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
          // --- Search Bar with Shadow ---
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4)
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: "Search Product name...",
                hintStyle: TextStyle(color: textCol.withOpacity(0.5)),
                prefixIcon: Icon(Icons.search, color: themeColor),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (val) {
                searchQuery = val;
                _fetchLogs();
              },
            ),
          ),
          const SizedBox(height: 12),
          // --- Date Selectors ---
          Row(
            children: [
              Expanded(
                child: _buildDateBtn(
                  startDate == null ? "From Date" : DateFormat('dd/MM/yy').format(startDate!),
                  cardColor, textCol, isDark,
                      () async {
                    DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (p != null) setState(() => startDate = p);
                    _fetchLogs();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateBtn(
                  endDate == null ? "To Date" : DateFormat('dd/MM/yy').format(endDate!),
                  cardColor, textCol, isDark,
                      () async {
                    DateTime? p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (p != null) setState(() => endDate = p);
                    _fetchLogs();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateBtn(String label, Color cardColor, Color textCol, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF673AB7)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(Color themeColor, Color cardColor, Color textCol, Color subTextCol, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: medicines,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF673AB7)));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text("No inventory records found.", style: TextStyle(color: subTextCol)));
        }

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
                  blurRadius: 10
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 25,
                headingRowHeight: 50,
                headingRowColor: WidgetStateProperty.all(themeColor.withOpacity(0.05)),
                columns: [
                  _buildHeader('Product', isDark),
                  _buildHeader('Stock', isDark),
                  _buildHeader('Price (Sell)', isDark),
                  _buildHeader('Expiry', isDark),
                  _buildHeader('Unit', isDark),
                  _buildHeader('Batch', isDark),
                  _buildHeader('Buy Price', isDark),
                  _buildHeader('Company', isDark),
                  _buildHeader('Disc%', isDark),
                  _buildHeader('Added By', isDark),
                  _buildHeader('Sync', isDark),
                ],
                rows: snapshot.data!.map((m) {
                  double remaining = double.tryParse(m['remaining_quantity']?.toString() ?? '0') ?? 0;
                  bool isLow = remaining < 5;

                  return DataRow(
                    cells: [
                      DataCell(Text(m['medicine_name'] ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isLow ? Colors.red : (isDark ? const Color(0xFF9575CD) : themeColor)
                          ))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isLow ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text("${m['remaining_quantity']}",
                            style: TextStyle(color: isLow ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                      )),
                      DataCell(Text("TSH ${NumberFormat('#,##0').format(m['selling_price'] ?? 0)}", style: TextStyle(color: textCol))),
                      DataCell(Text(m['expiry_date'] ?? 'N/A', style: TextStyle(color: textCol))),
                      DataCell(Text(m['unit'] ?? '', style: TextStyle(color: textCol))),
                      DataCell(Text(m['batch_number'] ?? '', style: TextStyle(color: textCol))),
                      DataCell(Text(m['buy_price']?.toString() ?? '0', style: TextStyle(color: textCol))),
                      DataCell(Text(m['company'] ?? '', style: TextStyle(color: textCol))),
                      DataCell(Text("${m['discount']}%", style: TextStyle(color: textCol))),
                      DataCell(Text(m['added_by'] ?? '', style: TextStyle(color: textCol))),
                      DataCell(Icon(
                        m['synced'] == true ? Icons.cloud_done : Icons.cloud_off,
                        size: 18,
                        color: m['synced'] == true ? Colors.green : Colors.orange,
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _buildHeader(String label, bool isDark) {
    return DataColumn(
      label: Text(label, style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF9575CD) : const Color(0xFF311B92),
          fontSize: 13
      )),
    );
  }
}