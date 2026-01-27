import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SubscriptionPaymentScreen extends StatefulWidget {
  final String? businessName;
  final dynamic businessId;

  const SubscriptionPaymentScreen({super.key, this.businessName, this.businessId});

  @override
  State<SubscriptionPaymentScreen> createState() => _SubscriptionPaymentScreenState();
}

class _SubscriptionPaymentScreenState extends State<SubscriptionPaymentScreen> {
  // --- CONFIGURATION ---
  final String _apiKey = "SKrEvNLpJ6nRdPns5rwZJzE8SkqfTG0MZzW7kTd3kR";
  final String _clientId = "IDZdzneti4V2DNdsuFemUgxLcPmkxkyL";
  final String _waInstance = "27E9E9F88CC1";
  final String _waToken = "jOos7Fc3cE7gj2";
  final _supabase = Supabase.instance.client;

  final TextEditingController _paymentPhoneController = TextEditingController();

  // --- STATE ---
  String _foundBusinessName = "";
  int? _foundBusinessId;
  Map<String, dynamic>? _myBusinessInfo;
  int _selectedMonths = 1;
  double _basePricePerMonth = 10500;
  double _finalPayAmount = 10500;
  int _discountPercent = 0;
  bool _isProcessing = false;
  bool _showControlNumber = false;
  bool _isAlreadyPaid = false;
  String _controlNumber = "";
  Timer? _statusChecker;

  @override
  void initState() {
    super.initState();
    if (widget.businessId != null) {
      _foundBusinessId = int.tryParse(widget.businessId.toString());
      _foundBusinessName = widget.businessName ?? "ONLINE STORE";
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadMyBusinessDetails();
        _fetchPricingAndCheckStatus();
      });
    }
  }

  // --- HELPER: PHONE FORMATTER ---
  String _formatPhoneNumber(String input, {bool includePlus = false}) {
    // Ondoa kila kitu ambacho si namba
    String clean = input.replaceAll(RegExp(r'\D'), '');

    // Kama inaanza na 0, weka 255 badala yake
    if (clean.startsWith('0')) {
      clean = '255${clean.substring(1)}';
    }
    // Kama tayari inaanza na 255, iache (Case ya mteja kuanza na 255 au +255)

    return includePlus ? '+$clean' : clean;
  }

  // 1. LOAD YOUR BUSINESS INFO
  Future<void> _loadMyBusinessDetails() async {
    try {
      final data = await _supabase
          .from('businesses')
          .select()
          .eq('email', 'mlyukakenedy@gmail.com')
          .maybeSingle();
      if (data != null) setState(() => _myBusinessInfo = data);
    } catch (e) {
      debugPrint("Error loading provider details: $e");
    }
  }

  // 2. FETCH PRICING & STATUS
  Future<void> _fetchPricingAndCheckStatus() async {
    setState(() => _isProcessing = true);
    try {
      final subData = await _supabase
          .from('subscriptions')
          .select('price_per_month, discount_percent')
          .eq('business_id', _foundBusinessId!)
          .maybeSingle();

      if (subData != null) {
        _basePricePerMonth = double.tryParse(subData['price_per_month'].toString()) ?? 10500.0;
        _discountPercent = subData['discount_percent'] ?? 0;
      }
      _calculateFinalAmount();

      final lastP = await _supabase
          .from('payments')
          .select()
          .eq('business_id', _foundBusinessId!)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (lastP != null) {
        String status = lastP['status']?.toString().toUpperCase() ?? "";
        if (['PAID', 'SUCCESS', 'SETTLED', 'SETTED'].contains(status)) {
          _isAlreadyPaid = true;
        } else if (['PENDING', 'INITIATED'].contains(status)) {
          _controlNumber = lastP['control_number'].toString();
          _showControlNumber = true;
          _startAutoTracking(lastP['order_reference'], _controlNumber);
        }
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _calculateFinalAmount() {
    double discountValue = (_basePricePerMonth * _discountPercent) / 100;
    double priceAfterDiscount = _basePricePerMonth - discountValue;
    setState(() {
      _finalPayAmount = priceAfterDiscount * _selectedMonths;
    });
  }

  // 3. WHATSAPP: SEND INSTRUCTIONS
  Future<void> _sendWhatsAppInstructions(String cNumber, String rawPhone) async {
    // WhatsApp inahitaji +255XXX
    String formattedPhone = _formatPhoneNumber(rawPhone, includePlus: true);

    String message = "Habari *$_foundBusinessName*\n\n"
        "Control Number: *$cNumber*\n"
        "Kiasi: *TSH ${NumberFormat('#,###').format(_finalPayAmount)}*\n\n"
        "*JINSI YA KULIPIA:*\n"
        "1. Piga *150*01# (M-Pesa) au *150*88# (Halopesa)\n"
        "2. Chagua Lipia Bili (4)\n"
        "3. Namba ya Kampuni: *889999*\n"
        "4. Kumbukumbu No: *$cNumber*\n\n"
        "Utapokea ujumbe wa uthibitisho hapa malipo yakikamilika. Asante!";

    try {
      await http.post(Uri.parse("https://wawp.net/wp-json/awp/v1/send"),
          body: {'instance_id': _waInstance, 'access_token': _waToken, 'chatId': formattedPhone, 'message': message});
    } catch (e) { debugPrint("WA Error: $e"); }
  }

  // 4. WHATSAPP: SUCCESS NOTIFICATION
  Future<void> _sendPaymentSuccessWhatsApp(String rawPhone) async {
    String formattedPhone = _formatPhoneNumber(rawPhone, includePlus: true);

    String message = "✅ *MALIPO YAMEPOKELEWA*\n\n"
        "Habari *$_foundBusinessName*,\n"
        "Tumepokea kiasi cha *TSH ${NumberFormat('#,###').format(_finalPayAmount)}* kwa mafanikio.\n\n"
        "🗓 Muda: *$_selectedMonths Month(s)*\n"
        "🧾 Risiti imetengenezwa kwenye App yako.\n\n"
        "Asante kwa kutumia *STOCK & INVENTORY SOFTWARE*!";

    try {
      await http.post(Uri.parse("https://wawp.net/wp-json/awp/v1/send"),
          body: {'instance_id': _waInstance, 'access_token': _waToken, 'chatId': formattedPhone, 'message': message});
    } catch (e) { debugPrint("WA Success Error: $e"); }
  }

  // 5. AUTO TRACKING
  void _startAutoTracking(String orderRef, String cNumber) {
    _statusChecker?.cancel();
    _statusChecker = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (!mounted || _isAlreadyPaid) { timer.cancel(); return; }
      try {
        final tokenRes = await http.post(Uri.parse("https://api.clickpesa.com/third-parties/generate-token"), headers: {"api-key": _apiKey, "client-id": _clientId});
        String rawToken = jsonDecode(tokenRes.body)['token'];
        String cleanToken = rawToken.replaceAll("Bearer ", "").trim();

        final response = await http.get(Uri.parse("https://api.clickpesa.com/third-parties/payments/$cNumber"), headers: {'Authorization': 'Bearer $cleanToken'});

        if (response.statusCode == 200) {
          final data = (jsonDecode(response.body) is List) ? jsonDecode(response.body).first : jsonDecode(response.body);
          final status = data['status']?.toString().toUpperCase() ?? '';

          if (['PAID', 'SUCCESS', 'SETTLED', 'SETTED'].contains(status)) {
            timer.cancel();
            DateTime expiry = DateTime.now().add(Duration(days: 30 * _selectedMonths));

            await _supabase.from('payments').update({
              'status': 'SUCCESS',
              'payment_reference': data['paymentReference']?.toString(),
              'collected_amount': double.tryParse(data['collectedAmount'].toString()) ?? _finalPayAmount,
              'expiry_date': expiry.toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('order_reference', orderRef);

            await _sendPaymentSuccessWhatsApp(_paymentPhoneController.text.trim());

            if (mounted) {
              setState(() { _isAlreadyPaid = true; _showControlNumber = false; });
              _showSuccessDialog();
            }
          }
        }
      } catch (e) { debugPrint("Tracking Error: $e"); }
    });
  }

  // 6. GENERATE PDF RECEIPT
  Future<Uint8List> _generateReceiptPdf() async {
    final pdf = pw.Document();
    final String bName = _myBusinessInfo?['business_name'] ?? "AFRO-TECHNO";
    final String bAddr = _myBusinessInfo?['address'] ?? "P.O. BOX 3013, ARUSHA";
    final String bLoc = _myBusinessInfo?['location'] ?? "ARUSHA-TZ";
    final String bPhone = _myBusinessInfo?['phone'] ?? "+255742448965";
    final String businessLogoPath = _myBusinessInfo?['logo'] ?? "";

    pw.MemoryImage? logoImage;
    if (businessLogoPath.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(businessLogoPath));
        if (response.statusCode == 200) { logoImage = pw.MemoryImage(response.bodyBytes); }
      } catch (e) { debugPrint("Logo fetch failed: $e"); }
    }

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Stack(children: [
          pw.Center(child: pw.Transform.rotate(angle: -0.5, child: pw.Text('PAID', style: pw.TextStyle(fontSize: 150, color: PdfColor.fromInt(0x1100FF00), fontWeight: pw.FontWeight.bold)))),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                if (logoImage != null) pw.Container(height: 60, width: 60, child: pw.Image(logoImage))
                else pw.Text(bName.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text(bName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(bAddr, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(bLoc, style: const pw.TextStyle(fontSize: 9)),
                pw.Text("Tel: $bPhone", style: const pw.TextStyle(fontSize: 9)),
              ])
            ]),
            pw.SizedBox(height: 30),
            pw.Text("OFFICIAL PAYMENT RECEIPT", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.Divider(thickness: 2, color: PdfColors.blueGrey),
            pw.SizedBox(height: 15),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(_foundBusinessName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text("Control No: $_controlNumber"),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("RECEIPT NO:", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text("RCP-${DateTime.now().millisecondsSinceEpoch}"),
                pw.Text("Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}"),
              ]),
            ]),
            pw.SizedBox(height: 30),
            pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: [
              pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Description", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Amount (TZS)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
              ]),
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Software Subscription Service\nDuration: $_selectedMonths Month(s)")),
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(NumberFormat('#,###').format(_finalPayAmount))),
              ]),
            ]),
            pw.SizedBox(height: 20),
            pw.Align(alignment: pw.Alignment.centerRight, child: pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.indigo50), child: pw.Text("TOTAL PAID: ${NumberFormat('#,###').format(_finalPayAmount)} TZS", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)))),
            pw.Spacer(),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Thank you for your business!", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9)),
                pw.SizedBox(height: 5),
                pw.Text("Generated automatically by Stock System", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
              ]),
              _buildSeal(bName),
            ])
          ])
        ])
    ));
    return pdf.save();
  }

  pw.Widget _buildSeal(String name) {
    return pw.Container(
      width: 140, height: 60,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue, width: 1.5), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Text(name, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
        pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 5, color: PdfColors.red)),
        pw.Text("PAID: ${DateFormat('dd MMM yyyy').format(DateTime.now())}", style: pw.TextStyle(fontSize: 7, color: PdfColors.blue)),
      ]),
    );
  }

  void _showSuccessDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
      content: const Text("Malipo Yamepokelewa! Taarifa zako zimesasishwa.", textAlign: TextAlign.center),
      actions: [
        ElevatedButton.icon(onPressed: () async {
          final pdfData = await _generateReceiptPdf();
          await Printing.sharePdf(bytes: pdfData, filename: 'Receipt_$_controlNumber.pdf');
        }, icon: const Icon(Icons.download), label: const Text("RISITI")),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
      ],
    ));
  }

  // 7. HANDLE INITIAL PAYMENT
  Future<void> _handlePayment() async {
    String rawPhone = _paymentPhoneController.text.trim();
    if (rawPhone.isEmpty) { _showSnackBar("Weka namba ya WhatsApp!"); return; }

    // Safisha namba kwa ajili ya ClickPesa (255XXX)
    String clickPesaPhone = _formatPhoneNumber(rawPhone, includePlus: false);

    setState(() => _isProcessing = true);
    try {
      final tokenRes = await http.post(Uri.parse("https://api.clickpesa.com/third-parties/generate-token"), headers: {"api-key": _apiKey, "client-id": _clientId});
      String cleanToken = jsonDecode(tokenRes.body)['token'].replaceAll("Bearer ", "").trim();
      String orderRef = "SUB-${_foundBusinessId}-${DateTime.now().millisecondsSinceEpoch}";

      final billingRes = await http.post(
        Uri.parse("https://api.clickpesa.com/third-parties/billpay/create-customer-control-number"),
        headers: {"Authorization": "Bearer $cleanToken", "Content-Type": "application/json"},
        body: jsonEncode({
          'billDescription': "Subscription: $_foundBusinessName",
          'billAmount': _finalPayAmount,
          'customerName': _foundBusinessName,
          'customerPhone': clickPesaPhone, // Namba safi hapa
        }),
      );

      final billingData = jsonDecode(billingRes.body);
      if (billingData['billPayNumber'] != null) {
        _controlNumber = billingData['billPayNumber'].toString().trim();
        await _supabase.from('payments').insert({
          'business_id': _foundBusinessId, 'business_name': _foundBusinessName, 'amount': _finalPayAmount,
          'months': _selectedMonths, 'control_number': _controlNumber, 'status': 'INITIATED',
          'order_reference': orderRef, 'phone_number': rawPhone, 'customer_name': _foundBusinessName,
        });

        // Tuma WhatsApp (Namba itasafishwa ndani ya function kuwa +255XXX)
        await _sendWhatsAppInstructions(_controlNumber, rawPhone);

        setState(() { _showControlNumber = true; _isProcessing = false; });
        _startAutoTracking(orderRef, _controlNumber);
      } else {
        throw "Imeshindwa kutengeneza Control Number";
      }
    } catch (e) { setState(() => _isProcessing = false); _showSnackBar("Error: $e"); }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SUBSCRIPTION PAYMENT"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Sehemu ya Taarifa za Biashara na Kiasi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(_foundBusinessName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const Text("Muda wa Huduma:"),
                  DropdownButton<int>(
                      value: _selectedMonths,
                      isExpanded: true,
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(value: m, child: Text("$m Miezi")))
                          .toList(),
                      onChanged: _showControlNumber || _isAlreadyPaid
                          ? null
                          : (v) {
                        setState(() {
                          _selectedMonths = v!;
                          _calculateFinalAmount();
                        });
                      }),
                  Text(
                    "TSH ${NumberFormat('#,###').format(_finalPayAmount)}",
                    style: const TextStyle(
                        fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 1. Ikiwa tayari ameshalipa
            if (_isAlreadyPaid)
              const Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 80),
                  Text("MALIPO YAMEPOKELEWA ✅",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )

            // 2. Ikiwa Control Number imetengenezwa (Maelekezo ya Malipo)
            else if (_showControlNumber)
              Column(
                children: [
                  const Text("LIPA KWA CONTROL NUMBER:"),
                  SelectableText(_controlNumber,
                      style: const TextStyle(
                          fontSize: 38, fontWeight: FontWeight.bold, color: Colors.brown)),
                  const SizedBox(height: 5),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 20),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("JINSI YA KULIPIA:",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.indigo)),
                  ),
                  const SizedBox(height: 10),

                  // Card za Maelekezo kwa kila Mtandao
                  _buildPaymentInstructionCard(" TIGO/MIXX BY YAS ", "889999",
                      "1. Piga *150*01#  \n2. Chagua Lipia Bili (4)\n3. Chagua namba 3 na weka Namba ya Kampuni: 889999\n4. Kumbukumbu: $_controlNumber\n5. Weka kiasi inakuomba  Thibitisha Ingiza PIN.."),

                  _buildPaymentInstructionCard("AIRTEL MONEY", "47",
                      "1. Piga *150*60#\n2. Lipia Bili (5) > Chagua Kampuni (2)\n3. Chagua Kampuni (7) > Weka Namba: 47\n4. Kumbukumbu: $_controlNumber\n5. Weka kiasi inakuomba  Thibitisha Ingiza PIN.."),

                  _buildPaymentInstructionCard("HALOPESA", "889999",
                      "1. Piga *150*88#\n2. Lipia Bili (4) > Namba ya Kampuni (3)\n3. Kampuni: 889999\n4. Kumbukumbu: $_controlNumber\n5. Weka kiasi inakuomba  Thibitisha Ingiza PIN."),

                  _buildPaymentInstructionCard("CRDB SIMBANKING", "CLICKPESA",
                      "1. Piga *150*03# > Simbanking\n2. Pay Bills (4) > Taasisi (6)\n3. Nyinginezo (7) > Chagua N (Next)\n4. Chagua CLICKPESA\n5. Kumbukumbu: $_controlNumber\n6. Weka kiasi  Thibitisha."),
                ],
              )

            // 3. Fomu ya kuanza malipo
            else ...[
                TextField(
                    controller: _paymentPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: "Namba ya WhatsApp",
                        hintText: "Mfano: 07XXXXXXXX",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.call, color: Colors.green))),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handlePayment,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("LIPIA SASA"),
                  ),
                ),
              ]
          ],
        ),
      ),
    );
  }

// Widget msaidizi kwa ajili ya kuonyesha maelekezo vizuri
  Widget _buildPaymentInstructionCard(String title, String companyNum, String steps) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Namba ya Kampuni: $companyNum", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
        leading: const Icon(Icons.account_balance_wallet_outlined, color: Colors.indigo),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(steps, style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          )
        ],
      ),
    );
  }

  void _showSnackBar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  @override
  void dispose() { _statusChecker?.cancel(); super.dispose(); }
}