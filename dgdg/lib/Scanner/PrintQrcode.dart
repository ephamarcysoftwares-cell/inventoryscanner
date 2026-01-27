import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class ViewAllQRCodesPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const ViewAllQRCodesPage({super.key, required this.user});

  @override
  State<ViewAllQRCodesPage> createState() => _ViewAllQRCodesPageState();
}

class _ViewAllQRCodesPageState extends State<ViewAllQRCodesPage> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  String _selectedTable = "ZOTE";
  String _searchQuery = "";
  int _missingCount = 0;
  bool _isVerticalLayout = true;

  DateTime? _startDate;
  DateTime? _endDate;

  int? _currentUserBusinessId;
  String? businessName;

  // Colors
  final Color bgWhite = const Color(0xFFF8FAFC);
  final Color textBlack = const Color(0xFF1E293B);
  final Color lightGrey = const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  Future<void> _initializePage() async {
    await getBusinessInfo();
    await _fetchAllData();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userProfile = await supabase.from('users').select('business_id').eq('id', user.id).maybeSingle();
      if (userProfile != null) {
        final bId = userProfile['business_id'];
        if (mounted) setState(() => _currentUserBusinessId = bId);
        final response = await supabase.from('businesses').select().eq('id', bId).maybeSingle();
        if (mounted && response != null) {
          setState(() { businessName = response['business_name']?.toString() ?? "STORE"; });
        }
      }
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final supabase = Supabase.instance.client;
    final bId = _currentUserBusinessId ?? widget.user['business_id'];

    try {
      var medQuery = supabase.from('medicines').select('id, name, item_code, added_time').eq('business_id', bId);
      var otherQuery = supabase.from('other_product').select('id, name, batch_number, date_added').eq('business_id', bId);
      var serviceQuery = supabase.from('services').select('id, name, added_time').eq('business_id', bId);

      if (_startDate != null && _endDate != null) {
        String start = _startDate!.toIso8601String();
        String end = _endDate!.add(const Duration(days: 1)).toIso8601String();
        medQuery = medQuery.gte('added_time', start).lt('added_time', end);
        serviceQuery = serviceQuery.gte('added_time', start).lt('added_time', end);
        otherQuery = otherQuery.gte('date_added', start).lt('date_added', end);
      }

      final responses = await Future.wait([medQuery, otherQuery, serviceQuery]);
      List<Map<String, dynamic>> combined = [];
      int missing = 0;

      for (var item in (responses[0] as List)) {
        String code = item['item_code']?.toString() ?? "";
        if (code.isEmpty || code == 'null') { missing++; code = ""; }
        combined.add({'id': item['id'], 'name': item['name'], 'code': code, 'type': 'NORMAL', 'db_table': 'medicines', 'code_col': 'item_code'});
      }
      for (var item in (responses[1] as List)) {
        String code = item['batch_number']?.toString() ?? "";
        if (code.isEmpty || code == 'null') { missing++; code = ""; }
        combined.add({'id': item['id'], 'name': item['name'], 'code': code, 'type': 'OTHER', 'db_table': 'other_product', 'code_col': 'batch_number'});
      }
      for (var item in (responses[2] as List)) {
        combined.add({'id': item['id'], 'name': item['name'], 'code': item['id'].toString(), 'type': 'SERVICE', 'db_table': 'services', 'code_col': 'id'});
      }

      setState(() { _allItems = combined; _missingCount = missing; _isLoading = false; _setStateFilter(); });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", Colors.red);
    }
  }

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: Text(businessName ?? "QR MANAGER", style: TextStyle(color: textBlack, fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade100,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textBlack),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetchAllData),
        ],
      ),
      body: Column(
        children: [
          _buildTopStats(),
          _buildSearchBox(),
          _buildDateSelectors(),
          if (_missingCount > 0) _buildWarning(),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildItemList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: textBlack,
        onPressed: _printSelectedQRs,
        label: Text(_isVerticalLayout ? "Vertical PDF" : "Grid PDF", style: const TextStyle(color: Colors.white, fontSize: 12)),
        icon: const Icon(Icons.print, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildTopStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statCol("TOTAL", _allItems.length.toString(), Colors.blue),
          _statCol("MISSING", _missingCount.toString(), Colors.red),
          _layoutToggle(),
        ],
      ),
    );
  }

  Widget _statCol(String l, String v, Color color) => Column(children: [
    Text(v, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(l, style: const TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
  ]);

  Widget _layoutToggle() => Column(children: [
    const Text("LAYOUT", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
    SizedBox(height: 30, child: Switch(value: _isVerticalLayout, onChanged: (v) => setState(() => _isVerticalLayout = v), activeColor: textBlack)),
  ]);

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Column(children: [
        TextField(
          onChanged: (v) { _searchQuery = v; _setStateFilter(); },
          decoration: InputDecoration(
            hintText: "Search items...", prefixIcon: const Icon(Icons.search, size: 20),
            filled: true, fillColor: lightGrey,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ["ZOTE", "NORMAL", "OTHER", "SERVICE"].map((t) => Padding(
              padding: const EdgeInsets.only(right: 5),
              child: ChoiceChip(
                label: Text(t, style: const TextStyle(fontSize: 10)),
                selected: _selectedTable == t,
                onSelected: (s) { setState(() { _selectedTable = t; _setStateFilter(); }); },
                selectedColor: textBlack,
                labelStyle: TextStyle(color: _selectedTable == t ? Colors.white : textBlack, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
        )
      ]),
    );
  }

  Widget _buildDateSelectors() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: lightGrey))),
      child: Row(
        children: [
          Expanded(child: _dateTile(label: "FROM", date: _startDate, onTap: () => _selectDate(true))),
          const SizedBox(width: 8),
          Expanded(child: _dateTile(label: "TO", date: _endDate, onTap: () => _selectDate(false))),
          if (_startDate != null || _endDate != null)
            IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 20), onPressed: () {
              setState(() { _startDate = null; _endDate = null; });
              _fetchAllData();
            }),
        ],
      ),
    );
  }

  Widget _dateTile({required String label, DateTime? date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: lightGrey, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(date == null ? "Select" : DateFormat('dd MMM yy').format(date), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { if (isStart) _startDate = picked; else _endDate = picked; });
      if (_startDate != null && _endDate != null) _fetchAllData();
    }
  }

  Widget _buildWarning() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text("$_missingCount items hazina kodi", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
        TextButton(onPressed: _generateCodes, child: const Text("GENERATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange))),
      ]),
    );
  }

  Widget _buildItemList() {
    if (_filteredItems.isEmpty) return const Center(child: Text("Hakuna data."));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 5),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        bool hasCode = item['code'].isNotEmpty;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: lightGrey), borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            leading: hasCode
                ? SizedBox(width: 35, child: QrImageView(data: item['code'], size: 35, padding: EdgeInsets.zero))
                : const Icon(Icons.qr_code_2, color: Colors.redAccent),
            title: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text("${item['type']} | ${hasCode ? item['code'] : 'NO CODE'}", style: TextStyle(fontSize: 10, color: hasCode ? Colors.grey : Colors.red)),
          ),
        );
      },
    );
  }

  void _setStateFilter() {
    List<Map<String, dynamic>> temp = _selectedTable == "ZOTE" ? _allItems : _allItems.where((i) => i['type'] == _selectedTable).toList();
    if (_searchQuery.isNotEmpty) temp = temp.where((i) => i['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    setState(() => _filteredItems = temp);
  }

  Future<void> _generateCodes() async {
    final supabase = Supabase.instance.client;
    _showSnackBar("Generating codes...", Colors.blue);
    for (var item in _allItems) {
      if (item['code'].isEmpty) {
        String newCode = "ITM${Random().nextInt(899999) + 100000}";
        await supabase.from(item['db_table']).update({item['code_col']: newCode}).eq('id', item['id']);
      }
    }
    await _fetchAllData();
    _showSnackBar("Success!", Colors.green);
  }

  Future<void> _printSelectedQRs() async {
    final pdf = pw.Document();
    final items = _filteredItems.where((i) => i['code'].isNotEmpty).toList();
    if (items.isEmpty) return;

    final String title = businessName?.toUpperCase() ?? "QR MANAGER REPORT";

    if (_isVerticalLayout) {
      for (var i = 0; i < items.length; i += 7) {
        final chunk = items.sublist(i, i + 7 > items.length ? items.length : i + 7);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(children: [
            // Header ya Biashara iliyorembwa
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: PdfColors.teal700, // Rangi ya kijani/teal kama kule kwenye Form
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Center(
                child: pw.Text(title,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18, color: PdfColors.white)
                ),
              ),
            ),
            pw.SizedBox(height: 15),

            // List ya QR
            ...chunk.map((item) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(children: [
                // HAPA NDIPO PALEKEREBISHWA: Rangi ya QR lazima iwekwe
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: item['code'],
                  width: 60,
                  height: 60,
                  color: PdfColors.black, // Lazima iwe Black ili ionekane
                  backgroundColor: PdfColors.white,
                ),
                pw.SizedBox(width: 20),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(item['name'].toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  pw.Text("Type: ${item['type']}", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 4),
                  pw.Text("CODE: ${item['code']}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                ]),
              ]),
            )).toList(),
          ]),
        ));
      }
    } else {
      // Grid Layout
      for (var i = 0; i < items.length; i += 32) {
        final chunk = items.sublist(i, i + 32 > items.length ? items.length : i + 32);
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(children: [
            // Header ndogo ya biashara kwa grid layout
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 8),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal))),
              child: pw.Center(
                child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.teal900)),
              ),
            ),
            pw.SizedBox(height: 20),

            pw.Wrap(
              spacing: 12, runSpacing: 12,
              children: chunk.map((item) => pw.Container(
                width: (PdfPageFormat.a4.width - 80) / 4,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(children: [
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: item['code'],
                    width: 45,
                    height: 45,
                    color: PdfColors.black, // Lazima iwe Black
                    backgroundColor: PdfColors.white,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(item['name'], style: const pw.TextStyle(fontSize: 6), maxLines: 1, textAlign: pw.TextAlign.center),
                  pw.Text(item['code'], style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                ]),
              )).toList(),
            ),
          ]),
        ));
      }
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}