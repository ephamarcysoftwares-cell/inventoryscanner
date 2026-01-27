import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../FOTTER/CurvedRainbowBar.dart';

class ViewInvoiceScreen extends StatefulWidget {
  const ViewInvoiceScreen({super.key});

  @override
  _ViewInvoiceScreenState createState() => _ViewInvoiceScreenState();
}

class _ViewInvoiceScreenState extends State<ViewInvoiceScreen> {
  // 1. DATA & STATE VARIABLES
  List<Map<String, dynamic>> groupedInvoices = [];
  bool _isLoading = false;
  final formatter = NumberFormat('#,##0.00', 'en_US');
  bool _isDarkMode = false;

  // 2. BUSINESS VARIABLES (Zako ulizozitoa)
  String? business_name;
  String? businessEmail;
  String? businessAddress;
  String? businessPhone;
  String? businessLocation;
  String? businessLogoPath;
  String? businessWhatsapp;
  String? businessLipaNumber;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _loadTheme();
    _initializeData();
  }

  void _checkAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut || data.session == null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _initializeData() async {
    await getBusinessInfo();
  }

  /// 3. KUPATA TAARIFA ZA BIASHARA (ASSOCIATED BY USER)
  Future<void> getBusinessInfo() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Pata business_name ya huyu user
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null && userProfile['business_name'] != null) {
        String userBusinessName = userProfile['business_name'];

        // Vuta taarifa kamili za biashara hiyo
        final businessData = await supabase
            .from('businesses')
            .select()
            .eq('business_name', userBusinessName)
            .maybeSingle();

        if (businessData != null && mounted) {
          setState(() {
            // TUNATUMIA VARIABLES ZAKO HAPA
            business_name = businessData['business_name']?.toString() ?? '';
            businessEmail = businessData['email']?.toString() ?? '';
            businessAddress = businessData['address']?.toString() ?? '';
            businessPhone = businessData['phone']?.toString() ?? '';
            businessLocation = businessData['location']?.toString() ?? '';
            businessLogoPath = businessData['logo']?.toString() ?? '';
            businessWhatsapp = businessData['whatsapp']?.toString() ?? '';
            businessLipaNumber = businessData['lipa_number']?.toString() ?? '';
          });

          await fetchInvoices(); // Vuta invoice sasa kwa kutumia business_name
        }
      }
    } catch (e) {
      debugPrint('❌ Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 4. FETCH INVOICES (FILTERED BY BUSINESS NAME)
  Future<void> fetchInvoices() async {
    if (business_name == null || business_name!.isEmpty) return;
    try {
      final List<dynamic> result = await Supabase.instance.client
          .from('invoices')
          .select()
          .eq('business_name', business_name!) // Filter muhimu
          .order('added_time', ascending: false);

      Map<String, Map<String, dynamic>> tempGroups = {};

      for (var row in result) {
        String invNo = row['invoice_no']?.toString() ?? 'NO-ID';
        if (!tempGroups.containsKey(invNo)) {
          tempGroups[invNo] = {
            'invoice_no': invNo,
            'customer_name': row['customer_name'] ?? 'Walk-in',
            'added_time': row['added_time'],
            'items': [],
            'subtotal': 0.0,
            'total_discount': 0.0,
          };
        }
        tempGroups[invNo]!['items'].add(row);
        tempGroups[invNo]!['subtotal'] += (row['total'] as num? ?? 0.0).toDouble();
        tempGroups[invNo]!['total_discount'] += (row['discount'] as num? ?? 0.0).toDouble();
      }

      if (mounted) setState(() => groupedInvoices = tempGroups.values.toList());
    } catch (e) {
      debugPrint('Fetch Error: $e');
    }
  }

  /// 5. PRINT PDF (USING YOUR BUSINESS VARIABLES)
  Future<void> _printInvoice(Map<String, dynamic> invoice) async {
    final pdf = pw.Document();
    final double subtotal = (invoice['subtotal'] as num? ?? 0.0).toDouble();
    final double discount = (invoice['total_discount'] as num? ?? 0.0).toDouble();

    pw.MemoryImage? logo;
    if (businessLogoPath != null && businessLogoPath!.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(businessLogoPath!));
        if (res.statusCode == 200) logo = pw.MemoryImage(res.bodyBytes);
      } catch (e) { debugPrint("Logo error: $e"); }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logo != null) pw.Image(logo, width: 65) else pw.SizedBox(width: 65),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(business_name?.toUpperCase() ?? "INVOICE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    pw.Text("Simu: $businessPhone"),
                    pw.Text("Email: $businessEmail"),
                    pw.Text("Location: $businessLocation"),
                    if (businessLipaNumber != null && businessLipaNumber!.isNotEmpty)
                      pw.Text("Lipa No: $businessLipaNumber"),
                  ]
              ),
            ],
          ),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          pw.Text("INVOICE NO: ${invoice['invoice_no']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("MTEJA: ${invoice['customer_name']}"),
          pw.Text("TAREHE: ${invoice['added_time'].toString().substring(0, 10)}"),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Item', 'Qty', 'Price', 'Total'],
            data: (invoice['items'] as List).map((i) => [
              i['item_name'], i['quantity'], formatter.format(i['price']), formatter.format(i['total'])
            ]).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Subtotal: TSH ${formatter.format(subtotal)}"),
                    pw.Text("Discount: TSH ${formatter.format(discount)}"),
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.SizedBox(
                        width: 150, // Hapa ndipo unaweka upana unaoutaka
                        child: pw.Divider(thickness: 1, color: PdfColors.grey),
                      ),
                    ),
                    pw.Text("GRAND TOTAL: TSH ${formatter.format(subtotal - discount)}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ]
              )
          )
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        // INAONYESHA JINA LA BIASHARA KWENYE TITLE
        title: Text((business_name ?? "INVOICES").toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)]))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : groupedInvoices.isEmpty
          ? const Center(child: Text("Bado hakuna invoice zilizorekodiwa."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: groupedInvoices.length,
        itemBuilder: (context, index) {
          final inv = groupedInvoices[index];
          return Card(
            color: cardColor,
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ExpansionTile(
              title: Text(inv['customer_name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              subtitle: Text("Invoice: ${inv['invoice_no']} | ${inv['added_time'].toString().substring(0,10)}", style: const TextStyle(fontSize: 10)),
              trailing: Text("TSH ${formatter.format(inv['subtotal'] - inv['total_discount'])}",
                  style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
              children: [
                const Divider(height: 1),
                ... (inv['items'] as List).map((i) => ListTile(
                  dense: true,
                  title: Text(i['item_name'] ?? "Bidhaa"),
                  trailing: Text("${i['quantity']} x ${formatter.format(i['price'])}"),
                )),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.print, color: Colors.teal), onPressed: () => _printInvoice(inv)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteInvoice(inv['invoice_no'])),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- DELETE FUNCTION (KAMA ILIVYOKUWA MWANZO) ---
  Future<void> _deleteInvoice(String invoiceNo) async {
    bool confirm = await showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Futa Invoice"),
      content: Text("Je, una uhakika unataka kufuta invoice $invoiceNo?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("HAPANA")),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("NDIYO", style: TextStyle(color: Colors.red))),
      ],
    )) ?? false;

    if (confirm) {
      try {
        setState(() => _isLoading = true);
        await Supabase.instance.client.from('invoices').delete().eq('invoice_no', invoiceNo);
        fetchInvoices();
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
}