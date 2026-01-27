import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../FOTTER/CurvedRainbowBar.dart';

class SalaryTableScreen extends StatefulWidget {
  const SalaryTableScreen({Key? key}) : super(key: key);

  @override
  State<SalaryTableScreen> createState() => _SalaryTableScreenState();
}

class _SalaryTableScreenState extends State<SalaryTableScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _salaryList = [];
  String _searchQuery = '';
  bool _isFetching = false;

  String business_name = '';
  String businessLocation = '';
  String businessPhone = '';
  String businessLogoPath = '';

  // Light Blue Theme Colors
  final Color primaryBlue = const Color(0xFF0288D1);
  final Color bgBlue = const Color(0xFFF1F9FF);

  @override
  void initState() {
    super.initState();
    _startUp();
  }

  Future<void> _startUp() async {
    await getBusinessInfo();
    if (business_name.isNotEmpty) {
      _fetchSalaries();
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();
      if (profile != null) {
        final data = await supabase.from('businesses').select().eq('business_name', profile['business_name']).maybeSingle();
        if (data != null && mounted) {
          setState(() {
            business_name = data['business_name']?.toString() ?? '';
            businessLocation = data['location']?.toString() ?? '';
            businessPhone = data['phone']?.toString() ?? '';
            businessLogoPath = data['logo']?.toString() ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Business Fetch Error: $e');
    }
  }

  Future<void> _fetchSalaries() async {
    setState(() => _isFetching = true);
    try {
      final data = await supabase
          .from('salaries')
          .select('*, users(full_name, email)')
          .eq('business_name', business_name)
          .order('pay_date', ascending: false);

      setState(() {
        _salaryList = List<Map<String, dynamic>>.from(data).map((item) {
          final user = item['users'] as Map<String, dynamic>?;
          return {
            'id': item['id'],
            'amount': item['amount'],
            'pay_date': item['pay_date'] ?? '',
            'full_name': user?['full_name'] ?? 'Unknown Staff',
            'email': user?['email'] ?? 'No Email',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSalaries {
    if (_searchQuery.isEmpty) return _salaryList;
    return _salaryList.where((s) => s['full_name'].toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  Future<void> _generatePdfForSalary(Map<String, dynamic> salary) async {
    try {
      final pdf = pw.Document();
      pw.MemoryImage? logoImage;

      if (businessLogoPath.isNotEmpty && businessLogoPath.startsWith('http')) {
        final response = await http.get(Uri.parse(businessLogoPath));
        if (response.statusCode == 200) logoImage = pw.MemoryImage(response.bodyBytes);
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
                    pw.Text(business_name.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Text("OFFICIAL RECEIPT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.blue100),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
              headers: ['Description', 'Details'],
              data: [
                ['Staff Name', salary['full_name']],
                ['Payment Date', salary['pay_date'].toString().split('T').first],
                ['Amount Paid', 'TSH ${NumberFormat('#,##0').format(salary['amount'])}'],
              ],
            ),
            pw.SizedBox(height: 60),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(children: [
                    pw.SizedBox(width: 100, child: pw.Divider(thickness: 1)),
                    pw.Text("Employee Signature", style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
                pw.Expanded(
                  child: pw.Column(children: [
                    pw.SizedBox(width: 100, child: pw.Divider(thickness: 1)),
                    pw.Text("Manager Signature & Stamp", style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ));

      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        final file = File('$path/Salary_${salary['full_name']}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(await pdf.save());
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Receipt Saved to $path"), backgroundColor: primaryBlue));
      }
    } catch (e) {
      debugPrint('❌ PDF Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text("SALARY HISTORY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar Section
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search staff name...',
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: primaryBlue),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // List Section
          Expanded(
            child: _isFetching
                ? const Center(child: CircularProgressIndicator())
                : _filteredSalaries.isEmpty
                ? const Center(child: Text("No records found"))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: _filteredSalaries.length,
              itemBuilder: (context, index) {
                final s = _filteredSalaries[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor: bgBlue,
                      child: Icon(Icons.person, color: primaryBlue),
                    ),
                    title: Text(
                      s['full_name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text("Date: ${s['pay_date'].split('T').first}"),
                        Text(
                          "Amount: TSH ${NumberFormat('#,##0').format(s['amount'])}",
                          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      onPressed: () => _generatePdfForSalary(s),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}