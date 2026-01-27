import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ClickPesaStatementScreen extends StatefulWidget {
  const ClickPesaStatementScreen({super.key});

  @override
  State<ClickPesaStatementScreen> createState() => _ClickPesaStatementScreenState();
}

class _ClickPesaStatementScreenState extends State<ClickPesaStatementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  // State Variables
  bool _isLoading = false;
  bool _isDarkMode = false;
  Map<String, dynamic>? _biz;
  Map<String, dynamic>? _accountDetails;
  List<dynamic> _transactions = [];
  final currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  // Credentials placeholder
  String _apiKey = "";
  String _clientId = "";
  String _waInstance = "";
  String _waToken = "";

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initApp();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  // --- 1. LOAD CREDENTIALS LOGIC ---
  Future<bool> _loadCredentials() async {
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) throw "Hujatambuliwa. Login tena.";

      // Pata business_id kutoka table ya users
      final userData = await supabase
          .from('users')
          .select('business_id')
          .eq('id', authUser.id)
          .maybeSingle();

      final bId = userData?['business_id'];
      if (bId == null) throw "Mtumiaji hana Business ID.";

      // Pata taarifa za biashara kwa kutumia bId
      final bizData = await supabase
          .from('businesses')
          .select('business_name, api_key, client_id, whatsapp_instance_id, whatsapp_access_token')
          .eq('id', bId)
          .maybeSingle();

      if (bizData != null) {
        setState(() {
          _biz = bizData;
          _apiKey = (bizData['api_key'] ?? "").toString().trim();
          _clientId = (bizData['client_id'] ?? "").toString().trim();
          _waInstance = (bizData['whatsapp_instance_id'] ?? "").toString().trim();
          _waToken = (bizData['whatsapp_access_token'] ?? "").toString().trim();
        });
        return true;
      }
      return false;
    } catch (e) {
      _showSnackBar(e.toString());
      return false;
    }
  }

  // --- 2. INITIALIZE APP ---
  Future<void> _initApp() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    bool credentialsLoaded = await _loadCredentials();
    if (credentialsLoaded) {
      await _refreshData();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- 3. CLICKPESA API LOGIC ---
  Future<void> _refreshData() async {
    if (_apiKey.isEmpty || _clientId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Step A: Generate Token
      final tokenRes = await http.post(
        Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
        headers: {
          "api-key": _apiKey,
          "client-id": _clientId
        },
      );

      if (tokenRes.statusCode != 200) throw "ClickPesa Auth Failed";

      final token = jsonDecode(tokenRes.body)['token'].toString().replaceFirst("Bearer ", "").trim();

      // Step B: Fetch Statement
      String sDate = DateFormat('yyyy-MM-dd').format(_startDate);
      String eDate = DateFormat('yyyy-MM-dd').format(_endDate);

      final res = await http.get(
        Uri.parse("https://api.clickpesa.com/third-parties/account/statement?currency=TZS&startDate=$sDate&endDate=$eDate"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _transactions = data['transactions'] ?? [];
          _accountDetails = data['accountDetails'];
        });
      } else {
        _showSnackBar("Makosa: ${res.statusCode}");
      }
    } catch (e) {
      _showSnackBar("API Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 4. PDF GENERATION ---
  Future<void> _generatePdfStatement() async {
    final pdf = pw.Document();
    final stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("CLICKPESA STATEMENT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(_biz?['business_name']?.toUpperCase() ?? "", style: pw.TextStyle(fontSize: 12)),
            ]),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Date', 'Description', 'Amount (TZS)', 'Type'],
            data: _transactions.map((tx) => [
              DateFormat('dd/MM/yyyy').format(DateTime.parse(tx['date'])),
              tx['description'] ?? '',
              currencyFormatter.format(tx['amount']),
              tx['entry']
            ]).toList(),
          ),
          pw.SizedBox(height: 50),
          pw.Center(child: _buildPdfSeal(stampDate)),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildPdfSeal(String date) {
    return pw.Container(
      width: 160, height: 100,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue, width: 2), borderRadius: pw.BorderRadius.circular(10)),
      child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Text(_biz?['business_name']?.toUpperCase() ?? "OFFICIAL", style: pw.TextStyle(color: PdfColors.blue, fontWeight: pw.FontWeight.bold, fontSize: 8)),
        pw.Text("OFFICIAL STAMP", style: pw.TextStyle(color: PdfColors.red, fontSize: 6)),
        pw.Divider(color: PdfColors.blue, thickness: 0.5),
        pw.Text("DATE: $date", style: pw.TextStyle(color: PdfColors.blue, fontSize: 8, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    double balance = double.tryParse(_accountDetails?['closingBalance']?.toString() ?? "0") ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_biz?['business_name']?.toUpperCase() ?? "STATEMENT", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF311B92),
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.white), onPressed: _generatePdfStatement),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _refreshData),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF311B92),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const Text("ACCOUNT BALANCE (TZS)", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                FittedBox(child: Text(currencyFormatter.format(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _dateTile("FROM", _startDate, () => _pickDate(true), cardColor, isDark)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile("TO", _endDate, () => _pickDate(false), cardColor, isDark)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                bool isCredit = tx['entry'] == "Credit";
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.red, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tx['description'] ?? 'Transaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
                          Text(DateFormat('dd MMM, HH:mm').format(DateTime.parse(tx['date'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ]),
                      ),
                      Text("${isCredit ? '+' : '-'} ${currencyFormatter.format(tx['amount'])}", style: TextStyle(fontWeight: FontWeight.w900, color: isCredit ? Colors.green : Colors.red, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 50),
    );
  }

  Widget _dateTile(String label, DateTime date, VoidCallback onTap, Color cardColor, bool isDark) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(DateFormat('dd/MM/yyyy').format(date), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        ]),
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: isStart ? _startDate : _endDate, firstDate: DateTime(2023), lastDate: DateTime.now());
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
      _refreshData();
    }
  }
}