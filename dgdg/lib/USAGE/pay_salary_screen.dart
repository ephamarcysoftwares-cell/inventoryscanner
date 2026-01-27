import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class PaySalaryScreen extends StatefulWidget {
  const PaySalaryScreen({Key? key}) : super(key: key);

  @override
  _PaySalaryScreenState createState() => _PaySalaryScreenState();
}

class _PaySalaryScreenState extends State<PaySalaryScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserEmail;

  final TextEditingController _amountController = TextEditingController();
  final formatter = NumberFormat('#,##0');

  String business_name = '';
  String businessLocation = '';
  String businessLogoPath = '';
  bool _isLoading = false;

  // Theme Colors (Light Blue)
  final Color primaryBlue = const Color(0xFF0288D1);
  final Color bgBlue = const Color(0xFFF1F9FF);

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await getBusinessInfo();
    if (business_name.isNotEmpty) await _loadUsers();
    setState(() => _isLoading = false);
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
            businessLogoPath = data['logo']?.toString() ?? '';
          });
        }
      }
    } catch (e) { debugPrint("Business Fetch Error: $e"); }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await supabase.from('users').select('id, full_name, email').eq('business_name', business_name);
      setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("User Load Error: $e"); }
  }

  void _onAmountChanged(String value) {
    if (value.isEmpty) return;
    String cleanValue = value.replaceAll(',', '');
    double? amount = double.tryParse(cleanValue);
    if (amount != null) {
      String formatted = formatter.format(amount);
      _amountController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // --- EMAIL NOTIFICATION ---
  Future<void> _sendSalaryEmail(String empName, String empEmail, double amount) async {
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final String formattedAmount = formatter.format(amount);
    final htmlContent = '''
    <div style="font-family: sans-serif; padding: 20px; border: 1px solid #E1F5FE; border-radius: 12px;">
      <h2 style="color: #0288D1;">Malipo ya Mshahara - $business_name</h2>
      <p>Habari <strong>$empName</strong>,</p>
      <p>Malipo yako yamefanikiwa. Kiasi kilichotumwa ni:</p>
      <div style="background: #E1F5FE; padding: 15px; border-radius: 8px; font-size: 20px; color: #01579B; font-weight: bold;">
        TSH $formattedAmount
      </div>
      <p style="margin-top: 20px; font-size: 12px; color: #777;">Asante kwa kuendelea kufanya kazi nasi.</p>
    </div>
    ''';

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', business_name)
      ..recipients.add(empEmail)
      ..bccRecipients.add('suport@ephamarcysoftware.co.tz')
      ..subject = 'Slip ya Mshahara: $empName'
      ..html = htmlContent;

    try { await send(message, smtpServer); } catch (e) { debugPrint("Email failed: $e"); }
  }

  Future<void> _submitSalary() async {
    if (_selectedUserId == null || _amountController.text.isEmpty) {
      _showSnackBar("Tafadhali jaza nafasi zote", isError: true);
      return;
    }

    setState(() => _isLoading = true);
    double amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    try {
      await supabase.from('salaries').insert({
        'user_id': _selectedUserId,
        'amount': amount,
        'pay_date': DateTime.now().toIso8601String(),
        'business_name': business_name,
      });

      await _generatePdf(amount, _selectedUserName ?? 'Staff');

      if (_selectedUserEmail != null && _selectedUserEmail!.contains('@')) {
        await _sendSalaryEmail(_selectedUserName!, _selectedUserEmail!, amount);
      }

      _showSnackBar("Mshahara Umelipwa & Email Imetumwa!", isError: false);
      _amountController.clear();
      setState(() => _selectedUserId = null);
    } catch (e) {
      _showSnackBar("Kosa: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- PDF GENERATION WITH OVERFLOW FIX ---
  Future<void> _generatePdf(double amount, String userName) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(35),
      build: (context) => pw.Column(
        children: [
          pw.Text(business_name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.blue700)),
          pw.Divider(color: PdfColors.blue100),
          pw.SizedBox(height: 20),
          pw.Text("SALARY SLIP", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("Staff: $userName"),
            pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}"),
          ]),
          pw.SizedBox(height: 30),
          pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue600),
              headers: ['Description', 'Amount (TSH)'],
              data: [['Monthly Salary', formatter.format(amount)]]
          ),
          pw.SizedBox(height: 80),

          // Row iliyorekebishwa kwa Expanded kuzuia Overflow
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(children: [
                  pw.SizedBox(width: 100, child: pw.Divider(thickness: 1)),
                  pw.Text("Staff Signature", style: const pw.TextStyle(fontSize: 9))
                ]),
              ),
              pw.Expanded(
                child: pw.Column(children: [
                  pw.SizedBox(width: 100, child: pw.Divider(thickness: 1)),
                  pw.Text("Manager Signature", style: const pw.TextStyle(fontSize: 9))
                ]),
              ),
            ],
          ),
        ],
      ),
    ));
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Salary_${userName.replaceAll(' ', '_')}.pdf');
    await file.writeAsBytes(await pdf.save());
  }

  void _showSnackBar(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? Colors.red : primaryBlue,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text("LIPA MSHAHARA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Card ya kwanza (Staff Selection)
          _buildCard(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: "Chagua Mfanyakazi",
                prefixIcon: Icon(Icons.person, color: primaryBlue),
                border: InputBorder.none,
              ),
              value: _selectedUserId,
              items: _users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text(u['full_name'] ?? 'Staff'))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedUserId = val;
                  final user = _users.firstWhere((u) => u['id'].toString() == val);
                  _selectedUserName = user['full_name'];
                  _selectedUserEmail = user['email'];
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          // Card ya pili (Amount Input)
          _buildCard(
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              onChanged: _onAmountChanged,
              style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 20),
              decoration: InputDecoration(
                labelText: "Kiasi cha Mshahara",
                prefixText: "TSH ",
                prefixIcon: Icon(Icons.account_balance_wallet, color: primaryBlue),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 40),
          // Kitufe cha Malipo
          ElevatedButton(
            onPressed: _submitSalary,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text("LIPA NA TUMA TAARIFA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: child,
    );
  }
}