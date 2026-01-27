import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mailer/mailer.dart'; // Hii ndio inatambua Address, Message, na send
class UniversalControlNumberPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UniversalControlNumberPage({super.key, this.user});

  @override
  State<UniversalControlNumberPage> createState() => _UniversalControlNumberPageState();
}

class _UniversalControlNumberPageState extends State<UniversalControlNumberPage> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  // Business Info Variables
  String business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessAddress = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String waInstanceId = '';
  String waToken = '';
  String _apiKey = "";
  String _clientId = "";
  dynamic _businessId;

  Timer? _refreshTimer;
  String _paymentMode = "EXACT"; // Default mode
  bool _isLoading = false;
  bool _isAlreadyPaid = false;
  bool _isSaleFinalized = false;
  bool _showControlNumber = false;

  String _generatedNumber = "";
  String _orderRef = "";
  String _debugStatus = "Inasubiri Malipo...";

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _amountController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // --- 1. FETCH BUSINESS INFO (LOGIC YAKO KAMILI) ---
  Future<void> getBusinessInfo() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final userData = await _supabase.from('users').select('business_name, business_id').eq('id', user.id).maybeSingle();

      if (userData != null) {
        final bId = userData['business_id'];
        final bName = userData['business_name']?.toString() ?? '';

        var query = _supabase.from('businesses').select();
        final response = bId != null
            ? await query.eq('id', bId).limit(1)
            : await query.eq('business_name', bName).limit(1);

        if (response.isNotEmpty) {
          var data = response.first;

          if (data['is_main_business'] == false && data['parent_id'] != null) {
            final parent = await _supabase.from('businesses').select().eq('id', data['parent_id']).maybeSingle();
            if (parent != null) data = parent;
          }

          if (mounted) {
            setState(() {
              _businessId = data['id'];
              business_name = data['business_name']?.toString() ?? '';
              businessEmail = data['email']?.toString() ?? '';
              businessPhone = data['phone']?.toString() ?? '';
              businessAddress = data['address']?.toString() ?? '';
              businessLocation = data['location']?.toString() ?? '';
              businessLogoPath = data['logo']?.toString() ?? '';
              waInstanceId = data['whatsapp_instance_id']?.toString() ?? '';
              waToken = data['whatsapp_access_token']?.toString() ?? '';
              _apiKey = data['api_key']?.toString() ?? '';
              _clientId = data['client_id']?.toString() ?? '';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error Fetching Business Info: $e');
    }
  }

  // --- 2. API TOKEN & TRACKING ---
  Future<String?> _getCleanToken() async {
    try {
      final resp = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
          headers: {'api-key': _apiKey, 'client-id': _clientId, 'Content-Type': 'application/json'}
      );
      if (resp.statusCode == 200) return jsonDecode(resp.body)['token'].toString().replaceFirst("Bearer ", "");
      return null;
    } catch (e) { return null; }
  }

  void _startAutoTracking(String orderRef, String cNumber) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (_isSaleFinalized || _isAlreadyPaid) { timer.cancel(); return; }
      try {
        String? token = await _getCleanToken();
        if (token == null) return;
        final response = await http.get(
          Uri.parse("https://api.clickpesa.com/third-parties/payments/$cNumber"),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        );
        if (response.statusCode == 200) {
          final raw = jsonDecode(response.body);
          final Map<String, dynamic> data = (raw is List && raw.isNotEmpty) ? raw.first : raw;
          if (['PAID', 'SUCCESS', 'SETTLED'].contains(data['status']?.toString().toUpperCase())) {
            timer.cancel();
            setState(() { _isAlreadyPaid = true; _showControlNumber = false; });
            await _supabase.from('payment_tracking_records').update({'status': 'SETTLED'}).eq('order_reference', orderRef);
          }
        }
      } catch (e) { debugPrint("Tracking Error: $e"); }
    });
  }

  // --- 3. ACTION: GENERATE & SEND ---
  Future<void> _generateAndSend() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? token = await _getCleanToken();
      if (token == null) throw "Token Error: Hakuweza kupata token.";

      // Phone formatting logic
      String rawInput = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      String cleanPhone = rawInput.startsWith('0') ? "255${rawInput.substring(1)}" : rawInput;

      _orderRef = "ORD-${DateTime.now().millisecondsSinceEpoch}";
      String description = _descController.text.isEmpty ? "Malipo ya Huduma" : _descController.text;

      final bResp = await http.post(
        Uri.parse("https://api.clickpesa.com/third-parties/billpay/create-customer-control-number"),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'billAmount': _amountController.text.trim(),
          'customerName': _nameController.text.trim(),
          'customerPhone': cleanPhone,
          'customerEmail': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          'billDescription': description,
          'billPaymentMode': _paymentMode,
        }),
      );

      if (bResp.statusCode == 200 || bResp.statusCode == 201) {
        final cNumber = jsonDecode(bResp.body)['billPayNumber'];

        // 1. Save taarifa kwenye Database
        await _supabase.from('payment_tracking_records').insert({
          'business_id': _businessId,
          'order_reference': _orderRef,
          'control_number': cNumber,
          'amount': double.parse(_amountController.text),
          'customer_name': _nameController.text.trim(),
          'customer_phone': cleanPhone,
          'status': 'PENDING',
        });

        setState(() {
          _generatedNumber = cNumber;
          _showControlNumber = true;
        });

        // 2. Tuma maelezo kwa WhatsApp (Tayari ipo kwenye kodi yako)
        await _sendWhatsAppDetailedInstructions(cNumber, cleanPhone, description);

        // 3. --- KIPENGELE KIPYA: AUTO PDF & EMAIL ---
        // Hii itazalisha PDF na kuituma kwa email ya mteja kimyakimya
        await _autoGenerateAndEmailPdf(cNumber);

        // 4. Anza kufuatilia malipo
        _startAutoTracking(_orderRef, cNumber);

      } else {
        throw "Error ClickPesa: ${bResp.body}";
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- 4. WHATSAPP MESSAGE (YENYE TAARIFA ZOTE) ---
  Future<void> _sendWhatsAppDetailedInstructions(String cNumber, String phone, String description) async {
    if (waInstanceId.isEmpty || waToken.isEmpty) return;
    final String amountFormatted = NumberFormat('#,###').format(double.parse(_amountController.text));
    final String customerName = _nameController.text.trim();

    StringBuffer buffer = StringBuffer();
    buffer.writeln("🏢 *MESEJI KUTOKA: ${business_name.toUpperCase()}*");
    buffer.writeln("--------------------------------------------");
    buffer.writeln("📌 *Habari $customerName,*");
    buffer.writeln("\nUmefanikiwa kutengeneza Namba ya Malipo (Control Number).");
    buffer.writeln("🔹 *Control Number:* `$cNumber` ");
    buffer.writeln("🔹 *Description:* $description");
    buffer.writeln("🔹 *Amount:* $amountFormatted TZS");
    buffer.writeln("🔹 *Customer Name:* $customerName\n");

    buffer.writeln("💰 *JINSI YA KULIPIA:*");

    // Airtel
    buffer.writeln("\n👉 *Pay via Airtel Money*");
    buffer.writeln("Piga *150*60#\nChagua 5 (Lipia Bili)\nChagua 2 (Chagua Kampuni)\nChagua 7 (Chagua Kampuni)\nWeka Namba: 47\nWeka Kumbukumbu: `$cNumber` \nIngiza Kiasi: $amountFormatted\nPIN -> Thibitisha.");

    // Halopesa
    buffer.writeln("\n👉 *Pay via Halopesa*");
    buffer.writeln("Piga *150*88#\nChagua 4 (Lipia Bili)\nChagua 3 (Ingiza Namba ya Kampuni)\nIngiza Namba: 889999\nWeka Kumbukumbu: `$cNumber` \nIngiza Kiasi: $amountFormatted\nPIN -> Thibitisha.");

    // CRDB
    buffer.writeln("\n👉 *Pay via CRDB / SimBanking*");
    buffer.writeln("Piga *150*03#\nChagua 1 (Simbanking)\nWeka PIN\nChagua 4 (Pay Bills)\nChagua 6 (Taasisi)\nChagua 7 (Nyinginezo)\nChagua Next mpaka uone CLICKPESA\nWeka Namba ya Malipo: `$cNumber` \nIngiza Kiasi: $amountFormatted\nThibitisha.");

    // M-Pesa / Mixx
    buffer.writeln("\n👉 *Pay via M-Pesa / Mixx by Yas*");
    buffer.writeln("Piga *150*01#\nChagua 4 (Lipia Bili)\nChagua 3 (Ingiza Namba ya Kampuni)\nIngiza Namba: 889999\nWeka Kumbukumbu: `$cNumber` \nIngiza Kiasi: $amountFormatted\nPIN -> Thibitisha.");

    buffer.writeln("\n--------------------------------------------");
    buffer.writeln("🙏 *Asante kwa kuchagua ${business_name}!*");

    await http.post(
      Uri.parse("https://wawp.net/wp-json/awp/v1/send"),
      body: {'instance_id': waInstanceId, 'access_token': waToken, 'chatId': phone, 'message': buffer.toString()},
    );
  }

  Future<void> _autoGenerateAndEmailPdf(String cNumber) async {
    if (_emailController.text.isEmpty) return; // Kama hamna email, usihangaike

    try {
      final pdf = pw.Document();
      final String amountFormatted = NumberFormat('#,###').format(double.parse(_amountController.text));
      final String stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();

      // 1. Maandalizi ya Logo
      pw.ImageProvider? netImage;
      if (businessLogoPath.isNotEmpty) {
        try { netImage = await networkImage(businessLogoPath); } catch (e) { debugPrint("Logo error: $e"); }
      }

      // 2. Jenga PDF kwa kutumia Layout yako kamili
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // HEADER (Logo & Business Info)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (netImage != null) pw.Container(width: 80, height: 80, child: pw.Image(netImage)),
                    pw.SizedBox(height: 10),
                    pw.Text(business_name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text("$businessLocation, $businessAddress", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Simu: $businessPhone", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("PROFORMA INVOICE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5), color: PdfColors.indigo50, child: pw.Text("Tarehe: $stampDate", style: const pw.TextStyle(fontSize: 10))),
                    pw.SizedBox(height: 10),
                    pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: cNumber, width: 60, height: 60),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 10), pw.Divider(thickness: 2, color: PdfColors.indigo900), pw.SizedBox(height: 20),

            // CUSTOMER BOX
            pw.Container(
              width: double.infinity, padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("MTEJA (BILL TO):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
                pw.SizedBox(height: 5),
                pw.Text(_nameController.text.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text("Simu: ${_phoneController.text}", style: const pw.TextStyle(fontSize: 11)),
              ]),
            ),

            pw.SizedBox(height: 30),

            // CONTROL NUMBER BOX
            pw.Container(
              padding: const pw.EdgeInsets.all(20), decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.indigo900), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10))),
              child: pw.Center(child: pw.Column(children: [
                pw.Text("PAYMENT CONTROL NUMBER", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.SizedBox(height: 10),
                pw.Text(cNumber, style: pw.TextStyle(fontSize: 36, fontWeight: pw.FontWeight.bold, letterSpacing: 2, color: PdfColors.indigo900)),
                pw.SizedBox(height: 10), pw.Divider(color: PdfColors.grey400),
                pw.Text("TOTAL AMOUNT DUE", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("TSH $amountFormatted", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              ])),
            ),

            pw.SizedBox(height: 30),

            // INSTRUCTIONS
            pw.Text("INSTRUCTIONS / HATUA ZA KULIPIA:", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
            pw.SizedBox(height: 10),
            _buildPdfStep("AIRTEL MONEY: Piga *150*60# -> 5 -> 2 -> 7 -> Kampuni: 47 -> Kumb: $cNumber"),
            _buildPdfStep("HALOPESA: Piga *150*88# -> 4 -> 3 -> Kampuni: 889999 -> Kumb: $cNumber"),
            _buildPdfStep("CRDB BANK: Simbanking -> Pay Bills -> Taasisi -> CLICKPESA -> Namba: $cNumber"),
            _buildPdfStep("M-PESA: Piga *150*01# -> 4 -> 3 -> Kampuni: 889999 -> Kumb: $cNumber"),

            pw.Spacer(),

            // FOOTER (Watermark & Seal)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("STATUS: UNPAID", style: pw.TextStyle(fontSize: 25, color: PdfColors.grey300, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text("Tafadhali kamilisha malipo ili kupokea risiti.", style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                ]),
                _buildBusinessSeal(context), // Hapa tunaita Seal yako
              ],
            ),
          ],
        ),
      ));

      // 3. Save PDF temporary
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Invoice_$cNumber.pdf");
      await file.writeAsBytes(await pdf.save());

      // 4. Tuma kupitia Mailer
      final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz', username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 465, ssl: true);

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', business_name)
        ..recipients.add(_emailController.text.trim())
        ..subject = 'INVOICE: $cNumber - $business_name'
        ..html = "<h3>Habari ${_nameController.text},</h3><p>Umefanikiwa kutengeneza namba ya malipo ya <b>TSH $amountFormatted</b>. Tafadhali pakua PDF iliyoambatishwa hapa chini kwa maelezo zaidi.</p>"
        ..attachments.add(FileAttachment(file));

      await send(message, smtpServer);
      debugPrint("✅ Email ikiwa na Seal na Logo imetumwa!");

    } catch (e) {
      debugPrint("❌ Error Email: $e");
    }
  }
  // --- 5. PDF RECEIPT (YENYE LOGO NA MAELEZO KAMILI) ---
  Future<void> _generatePdfReceipt(String cNumber) async {
    final pdf = pw.Document();
    final String amountFormatted = NumberFormat('#,###').format(double.parse(_amountController.text));
    final String stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();

    // 1. Maandalizi ya Logo
    pw.ImageProvider? netImage;
    if (businessLogoPath.isNotEmpty) {
      try {
        netImage = await networkImage(businessLogoPath);
      } catch (e) {
        debugPrint("Logo error: $e");
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30), // Padding nzuri pembeni
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // --- HEADER: LOGO NA TAARIFA ZA BIASHARA ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (netImage != null)
                    pw.Container(width: 80, height: 80, child: pw.Image(netImage)),
                  pw.SizedBox(height: 10),
                  pw.Text(business_name.toUpperCase(),
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Text("$businessLocation, $businessAddress", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Simu: $businessPhone", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Email: $businessEmail", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text("PROFORMA INVOICE",
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: PdfColors.indigo50,
                    child: pw.Text("Tarehe: $stampDate", style: const pw.TextStyle(fontSize: 10)),
                  ),
                  pw.SizedBox(height: 10),
                  pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: cNumber, width: 60, height: 60),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 10),
          pw.Divider(thickness: 2, color: PdfColors.indigo900),
          pw.SizedBox(height: 20),

          // --- CUSTOMER DETAILS ---
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("MTEJA (BILL TO):", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)),
                pw.SizedBox(height: 5),
                pw.Text(_nameController.text.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text("Simu: ${_phoneController.text}", style: const pw.TextStyle(fontSize: 11)),
                if (_emailController.text.isNotEmpty) pw.Text("Email: ${_emailController.text}", style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // --- CONTROL NUMBER BOX (MAIN SECTION) ---
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2, color: PdfColors.indigo900),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
            ),
            child: pw.Center(child: pw.Column(children: [
              pw.Text("PAYMENT CONTROL NUMBER", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Text(cNumber, style: pw.TextStyle(fontSize: 36, fontWeight: pw.FontWeight.bold, letterSpacing: 2, color: PdfColors.indigo900)),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 5),
              pw.Text("TOTAL AMOUNT DUE", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("TSH $amountFormatted", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
            ])),
          ),

          pw.SizedBox(height: 30),

          // --- INSTRUCTIONS ---
          pw.Text("INSTRUCTIONS / HATUA ZA KULIPIA:",
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
          pw.SizedBox(height: 10),

          _buildPdfStep("AIRTEL MONEY: Piga *150*60# -> 5 -> 2 -> 7 -> Kampuni: 47 -> Kumbukumbu: $cNumber"),
          _buildPdfStep("HALOPESA: Piga *150*88# -> 4 -> 3 -> Kampuni: 889999 -> Kumbukumbu: $cNumber"),
          _buildPdfStep("CRDB BANK: Simbanking -> Pay Bills -> Taasisi -> CLICKPESA -> Namba: $cNumber"),
          _buildPdfStep("M-PESA / TIGO: Piga *150*01# / *150*00# -> 4 -> 3 -> Kampuni: 889999 -> Kumb: $cNumber"),

          pw.Spacer(),

          // --- FOOTER: SEAL & STATUS ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Upande wa Kushoto: Status Watermark
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("STATUS: UNPAID",
                        style: pw.TextStyle(fontSize: 25, color: PdfColors.grey300, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 5),
                    pw.Text("Tafadhali kamilisha malipo ili kupokea risiti kamili.",
                        style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                  ]
              ),

              // Upande wa Kulia: OFFICIAL SEAL
              _buildBusinessSeal(context),
            ],
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

// --- OFFICIAL SEAL WIDGET YAKO ---
  pw.Widget _buildBusinessSeal(pw.Context context) {
    final stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
    const stampColor = PdfColors.blue;
    const secondaryStampColor = PdfColors.red900;

    return pw.Container(
      width: 170,
      height: 110,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: stampColor, width: 3.5),
      ),
      child: pw.Container(
        width: 160,
        height: 100,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: stampColor, width: 1.0),
        ),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              business_name.toUpperCase(),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: stampColor),
            ),
            pw.SizedBox(height: 2),
            pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: stampColor, height: 8, thickness: 0.5),
            pw.Text(
              '${businessAddress.isNotEmpty ? businessAddress : ''}${businessAddress.isNotEmpty && businessLocation.isNotEmpty ? ' • ' : ''}${businessLocation.isNotEmpty ? businessLocation : ''}'.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor),
            ),
            if (businessPhone.isNotEmpty)
              pw.Text('TEL: $businessPhone'.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor)),
            pw.SizedBox(height: 4),
            pw.Text('DATE: $stampDate', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: stampColor)),
          ],
        ),
      ),
    );
  }

// Helper kwa ajili ya bullets
  pw.Widget _buildPdfStep(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text("• ", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }



  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : Colors.green));
  }

  // --- 6. UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("TENGENEZA CONTROL NUMBER"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        centerTitle: true, // Imewekwa katikati
        elevation: 0,
      ),
      body: _isAlreadyPaid ? _buildSuccessUI() : _buildFormUI(),

    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: "KIASI (TSH)", border: OutlineInputBorder(), fillColor: Colors.white, filled: true),
              validator: (v) => v!.isEmpty ? "Weka kiasi" : null,
            ),
            const SizedBox(height: 20),

            // Payment Mode Dropdown
            const Text("Aina ya Malipo:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paymentMode,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: "EXACT", child: Text("Lipa Kiasi Kamili (Mara Moja)")),
                    DropdownMenuItem(value: "ALLOW_PARTIAL_AND_OVER_PAYMENT", child: Text("Lipa Kidogo Kidogo (Partial)")),
                  ],
                  onChanged: (val) => setState(() => _paymentMode = val!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildInput(_nameController, "Jina la Mteja", Icons.person),
            _buildInput(_phoneController, "WhatsApp (Mf: 07xxx)", Icons.phone, isPhone: true),
            _buildInput(_emailController, "Barua Pepe (Email)", Icons.email),
            _buildInput(_descController, "Maelezo ya Malipo", Icons.description, isRequired: false),

            const SizedBox(height: 30),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (!_showControlNumber)
              ElevatedButton(
                onPressed: _generateAndSend,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
                child: const Text("TENGENEZA & TUMA WHATSAPP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              )
            else _buildControlCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    final String amountFormatted = NumberFormat('#,###').format(double.parse(_amountController.text));

    return Card(
      elevation: 4,
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.indigo[900]!, width: 2)
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Ikae kushoto kwa usomaji mzuri
          children: [
            Center(
              child: Column(children: [
                Text(_debugStatus, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("CONTROL NUMBER:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                SelectableText(
                    _generatedNumber,
                    style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 2)
                ),
                Text("KIASI: TSH $amountFormatted", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 18)),
              ]),
            ),

            const Divider(height: 30, thickness: 1),

            const Text("💰 JINSI YA KULIPIA:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),

            // --- MAELEZO YA KULIPIA (KAMA WHATSAPP) ---
            _buildInstructionText("👉 Pay via Airtel Money",
                "Piga *150*60# -> 5 -> 2 -> 7 -> Namba: 47 -> Kumb: $_generatedNumber -> Kiasi: $amountFormatted"),

            _buildInstructionText("👉 Pay via Halopesa",
                "Piga *150*88# -> 4 -> 3 -> Namba: 889999 -> Kumb: $_generatedNumber -> Kiasi: $amountFormatted"),

            _buildInstructionText("👉 Pay via CRDB / SimBanking",
                "Piga *150*03# -> PIN -> 4 -> 6 -> 7 -> CLICKPESA -> Namba: $_generatedNumber -> Kiasi: $amountFormatted"),

            _buildInstructionText("👉 Pay via M-Pesa / Mixx by Yas",
                "Piga *150*01# -> 4 -> 3 -> Namba: 889999 -> Kumb: $_generatedNumber -> Kiasi: $amountFormatted"),

            const Divider(height: 30),
            Center(child: Text("🙏 Asante kwa kuchagua $business_name!", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12))),
            const SizedBox(height: 20),

            // --- VITUFE ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _generatePdfReceipt(_generatedNumber),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text("PRINT PDF"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showControlNumber = false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], foregroundColor: Colors.white),
                    child: const Text("NEW"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Helper widget kwa ajili ya kuonyesha maelezo ya malipo kwenye screen
  Widget _buildInstructionText(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
          Text(body, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSuccessUI() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.check_circle, size: 100, color: Colors.green),
      const SizedBox(height: 20),
      const Text("MALIPO YAMEPOKELEWA!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      ElevatedButton(onPressed: () => setState(() { _isAlreadyPaid = false; _amountController.clear(); }), child: const Text("TENGENEZA MENGINE")),
    ]),
  );

  Widget _buildInput(ctrl, lbl, icon, {isPhone = false, bool isRequired = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: TextFormField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(labelText: lbl, prefixIcon: Icon(icon), border: const OutlineInputBorder(), fillColor: Colors.white, filled: true),
      validator: (v) => (isRequired && (v == null || v.isEmpty)) ? "Weka $lbl" : null,
    ),
  );
}