import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../phamacy/ReceiptScreen.dart';

class MobilePaymentsScreen extends StatefulWidget {
  final String customerPhone;
  final String customerName;
  final String customerEmail;
  final double totalAmount;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic> user;

  const MobilePaymentsScreen({
    super.key,
    required this.customerPhone,
    required this.customerName,
    required this.totalAmount,
    required this.cartItems,
    required this.user,
    required this.customerEmail,
  });

  @override
  State<MobilePaymentsScreen> createState() => _MobilePaymentsScreenState();
}

class _MobilePaymentsScreenState extends State<MobilePaymentsScreen> {
  String _clientId = "";
  String _apiKey = "";
  String _waInstance = "";
  String _waToken = "";

  final _supabase = Supabase.instance.client;
  Timer? _countdownTimer;
  Timer? _refreshTimer;

  bool _isProcessing = true;
  bool _isSaleFinalized = false;
  bool _isAlreadyPaid = false;
  bool _hasError = false;
  int _secondsRemaining = 25;
  String _controlNumber = "";
  bool _showControlNumber = false;
  String _debugStatus = "Anza: Inatafuta mipangilio...";

  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.customerPhone);
    _loadBusinessCredentials();
  }

  // REGENERATE: Safisha kila kitu na anza upya
  void _resetAndRetry() {
    debugPrint("🔄 ACTION: Regenerate imebonyezwa. Inasafisha state...");
    setState(() {
      _isProcessing = true;
      _showControlNumber = false;
      _hasError = false;
      _secondsRemaining = 25;
      _controlNumber = "";
      _debugStatus = "Inatengeneza upya...";
    });
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _loadBusinessCredentials();
  }

  // 1. KUVUTA KEYS
  Future<void> _loadBusinessCredentials() async {
    try {
      final businessId = widget.user['business_id'] ?? widget.user['id'];
      debugPrint("🔍 DEBUG 1: Inatafuta biashara kwa ID: $businessId");

      if (businessId == null) throw "ID ya biashara haikupatikana.";

      final data = await _supabase
          .from('businesses')
          .select('api_key, client_id, whatsapp_instance_id, whatsapp_access_token')
          .eq('id', businessId)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            _apiKey = (data['api_key'] ?? "").toString().trim();
            _clientId = (data['client_id'] ?? "").toString().trim();
            _waInstance = (data['whatsapp_instance_id'] ?? "").toString().trim();
            _waToken = (data['whatsapp_access_token'] ?? "").toString().trim();
          });
          _handlePayment();
        }
      } else {
        setState(() {
          _isProcessing = false;
          _hasError = true;
          _debugStatus = "Kosa: Mipangilio haikupatikana.";
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _hasError = true;
        _debugStatus = "Database Error: $e";
      });
    }
  }

  // 2. GENERATE TOKEN
  Future<String?> _getCleanToken() async {
    try {
      final resp = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
          headers: {'api-key': _apiKey, 'client-id': _clientId, 'Content-Type': 'application/json'}
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return body['token'].toString().replaceFirst("Bearer ", "");
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 3. USSD PUSH
  Future<void> _handlePayment() async {
    final String orderRef = "ORD${DateTime.now().millisecondsSinceEpoch}";
    try {
      String phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) phone = "255${phone.substring(1)}";

      setState(() => _debugStatus = "Inatengeneza Access Token...");
      String? token = await _getCleanToken();

      if (token == null) throw "Imeshindwa kutengeneza Token";

      setState(() => _debugStatus = "Inatuma ombi la USSD Push...");
      await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/payments/initiate-ussd-push-request"),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
          body: jsonEncode({
            "amount": widget.totalAmount.toStringAsFixed(0),
            "currency": "TZS",
            "phoneNumber": phone,
            "orderReference": orderRef
          })
      );

      await _supabase.from('contropayement_payments').insert({
        'business_name': widget.user['business_name'] ?? "ONLINE STORE",
        'order_reference': orderRef,
        'status': 'INITIATED',
        'customer_name': widget.customerName,
        'phone_number': phone,
        'staff_name': widget.user['full_name'] ?? widget.user['email'] ?? "Unknown",
        'created_at': DateTime.now().toIso8601String(),
      });

      _startCountdown(orderRef);
    } catch (e) {
      if(mounted) setState(() { _isProcessing = false; _hasError = true; _debugStatus = "Kosa: $e"; });
    }
  }

  void _startCountdown(String orderRef) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        if(mounted) setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        _fetchControlNumber(orderRef);
      }
    });
  }

  // 4. CONTROL NUMBER
  Future<void> _fetchControlNumber(String orderRef) async {
    if (!mounted) return;
    setState(() => _debugStatus = "Inatengeneza Control Number...");

    try {
      String? freshToken = await _getCleanToken();
      if (freshToken == null) throw "Token failed";

      String phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) phone = "255${phone.substring(1)}";

      final resp = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/billpay/create-customer-control-number"),
          headers: {'Authorization': 'Bearer $freshToken', 'Content-Type': 'application/json'},
          body: jsonEncode({
            'billAmount': widget.totalAmount.toStringAsFixed(0),
            'customerName': widget.customerName,
            'customerPhone': phone,
            'billDescription': "Sale: ${widget.customerName}"
          })
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        String? cNumber = data['billPayNumber']?.toString();
        if (cNumber == null) throw "Namba haikupatikana";

        await _supabase.from('contropayement_payments').update({
          'control_number': cNumber,
          'status': 'PENDING',
          'amount': widget.totalAmount,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('order_reference', orderRef);

        _sendWhatsAppInstructions(cNumber);

        if(mounted) {
          setState(() {
            _controlNumber = cNumber;
            _showControlNumber = true;
            _isProcessing = false;
            _debugStatus = "Tunasubiri Malipo...";
          });
        }
        _startAutoTracking(orderRef, cNumber);
      } else {
        throw "Fail";
      }
    } catch (e) {
      if(mounted) setState(() { _isProcessing = false; _hasError = true; _debugStatus = "Kosa la kutengeneza namba ya malipo."; });
    }
  }

  // 5. AUTO TRACKING
  void _startAutoTracking(String orderRef, String cNumber) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (_isSaleFinalized || _isAlreadyPaid) {
        timer.cancel();
        return;
      }
      try {
        String? token = await _getCleanToken();
        if (token == null) return;

        final response = await http.get(
          Uri.parse("https://api.clickpesa.com/third-parties/payments/$cNumber"),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        );

        if (response.statusCode != 200) return;
        final raw = jsonDecode(response.body);
        final Map<String, dynamic> data = (raw is List && raw.isNotEmpty) ? raw.first : raw;
        final status = data['status']?.toString().toUpperCase().trim() ?? '';

        if (['PAID', 'SUCCESS', 'SETTLED'].contains(status)) {
          timer.cancel();
          if (!mounted) return;
          setState(() {
            _isAlreadyPaid = true;
            _isProcessing = true;
            _showControlNumber = false;
            _debugStatus = "Malipo Yamepokelewa!";
          });
          await _supabase.from('contropayement_payments').update({
            'status': 'SETTLED',
            'payment_id': data['paymentReference'],
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('order_reference', orderRef);
          await _finalizeSale(cNumber);
        }
      } catch (e) { debugPrint("Tracking Error: $e"); }
    });
  }

  // 6. FINALIZE SALE
  Future<void> _finalizeSale(String cNumber) async {
    if (_isSaleFinalized) return;
    _isSaleFinalized = true;
    try {
      final String rNumber = "REC${DateTime.now().millisecondsSinceEpoch}";
      String bName = widget.user['business_name']?.toString() ?? "ONLINE STORE";
      String staffName = widget.user['full_name'] ?? widget.user['email'] ?? "Staff";

      for (var item in widget.cartItems) {
        await _supabase.rpc('decrement_stock', params: {'row_id': item['id'], 'amount': item['quantity'] ?? 1});
      }

      final List<Map<String, dynamic>> salesData = widget.cartItems.map((item) {
        return {
          'business_name': bName,
          'product_name': item['product_name']?.toString() ?? "Item",
          'quantity': item['quantity'] ?? 0,
          'price': item['price'] ?? 0.0,
          'total': (item['price'] ?? 0.0) * (item['quantity'] ?? 0),
          'customer_name': widget.customerName,
          'payment_method': 'Mobile',
          'control_number': cNumber,
          'receipt_number': rNumber,
          'staff_name': staffName,
          'created_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      await _supabase.from('sales').insert(salesData);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              confirmedBy: staffName,
              confirmedTime: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
              customerName: widget.customerName,
              customerPhone: widget.customerPhone,
              customerEmail: widget.customerEmail,
              paymentMethod: 'Mobile Payment',
              receiptNumber: rNumber,
              medicineNames: widget.cartItems.map((e) => e['product_name']?.toString() ?? "Item").toList(),
              medicineQuantities: widget.cartItems.map((e) => (e['quantity'] as num).toInt()).toList(),
              medicinePrices: widget.cartItems.map((e) => (e['price'] as num).toDouble()).toList(),
              medicineUnits: widget.cartItems.map((e) => e['unit']?.toString() ?? "Pcs").toList(),
              medicineSources: const [],
              totalPrice: widget.totalAmount,
              remaining_quantity: 0,
            ),
          ),
        );
      }
    } catch (e) {
      _isSaleFinalized = false;
      debugPrint("Finalize Error: $e");
    }
  }

  // 7. WHATSAPP
  Future<void> _sendWhatsAppInstructions(String cNumber) async {
    if (_waInstance.isEmpty || _waToken.isEmpty) return;

    // Formatting phone number
    String phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = "255${phone.substring(1)}";

    final String amountFormatted = NumberFormat('#,###').format(widget.totalAmount);

    // Building the detailed message
    StringBuffer buffer = StringBuffer();
    buffer.writeln("📌 *Hello ${widget.customerName},*");
    buffer.writeln("\nYour order has generated a payment control number.");
    buffer.writeln("*Control Number:* $cNumber");
     // Ensure you have this in your widget
    buffer.writeln("*Amount:* $amountFormatted TZS");
    buffer.writeln("*Customer Name:* ${widget.customerName}");
    buffer.writeln("*Customer Phone:* $phone\n");

    buffer.writeln("💰 *Making Payments with Customer BillPay Control Numbers*");
    buffer.writeln("Customers can pay using their assigned control number through mobile money, SIM banking, or CRDB Wakalas.\n");

    List<String> networks = ['Airtel Money', 'Halopesa', 'CRDB', 'M-Pesa/Mixx'];

    for (var net in networks) {
      buffer.writeln("👉 *Pay via $net*");
      buffer.writeln("USSD / APP steps:");

      if (net == 'Airtel Money') {
        buffer.writeln("Piga *150*60#\nChagua 5 (Lipia Bili)\nChagua 2 (Chagua Kampuni)\nChagua 7 (Chagua Kampuni)\nWeka Namba: 47");
        buffer.writeln("Weka Namba ya Kumbukumbu: $cNumber\nIngiza Kiasi: $amountFormatted\nChagua 1 (Ndio)\nWeka PIN\n");
      } else if (net == 'Halopesa') {
        buffer.writeln("Piga *150*88#\nChagua 4 (Lipia Bili)\nChagua 3 (Ingiza Namba ya Kampuni)\nIngiza Namba: 889999");
        buffer.writeln("Weka Kumbukumbu: $cNumber\nIngiza Kiasi: $amountFormatted\nWeka PIN\nChagua 1 (Ndio)\n");
      } else if (net == 'CRDB') {
        buffer.writeln("Piga *150*03#\nChagua 1 (Simbanking)\nWeka PIN\nChagua 4 (Pay Bills)\nChagua 6 (Taasisi)\nChagua 7 (Nyinginezo)\nChagua Next mpaka upate CLICKPESA");
        buffer.writeln("Weka Namba ya Malipo: $cNumber\nIngiza Kiasi: $amountFormatted\nThibitisha\n");
      } else {
        buffer.writeln("Piga *150*01# au *150*00#\nChagua 4 (Lipia Bili)\nChagua 3 (Ingiza Namba ya Kampuni)\nIngiza Namba: 889999");
        buffer.writeln("Weka Kumbukumbu: $cNumber\nIngiza Kiasi: $amountFormatted\nWeka PIN\n");
      }
    }

    try {
      await http.post(
        Uri.parse("https://wawp.net/wp-json/awp/v1/send"),
        body: {
          'instance_id': _waInstance,
          'access_token': _waToken,
          'chatId': phone,
          'message': buffer.toString()
        },
      );
    } catch (e) {
      debugPrint("WhatsApp error: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Malipo ya Simu"),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          actions: [IconButton(onPressed: _resetAndRetry, icon: const Icon(Icons.refresh))]
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(widget.customerName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
                "TSH ${NumberFormat('#,###').format(widget.totalAmount)}",
                style: const TextStyle(fontSize: 32, color: Colors.green, fontWeight: FontWeight.bold)
            ),
            const Divider(height: 30),

            if (_hasError) ...[
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 10),
              Text(_debugStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Namba ya simu ya malipo:"),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                child: TextField(
                  controller: _phoneController,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "07xxxxxxxx"),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _resetAndRetry,
                icon: const Icon(Icons.replay_outlined),
                label: const Text("JARIBU TENA"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              )
            ],

            if (_isProcessing && !_showControlNumber && !_hasError) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 15),
              Text(_debugStatus, style: const TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 10),
              Text("Inasubiri PIN kwenye simu ya mteja (${_phoneController.text})...", style: const TextStyle(fontSize: 12)),
            ],

            if (_showControlNumber) ...[
              const Text("LIPIA KWA CONTROL NUMBER:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo, width: 2)),
                child: Column(
                  children: [
                    SelectableText(_controlNumber, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 2)),
                    const SizedBox(height: 5),
                    const Text("Lipa kwa Mitandao yote\n(Kampuni Namba: 889999)", textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              const Text("Tunasubiri malipo... Usifunge screen hii.", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              TextButton.icon(onPressed: _resetAndRetry, icon: const Icon(Icons.refresh), label: const Text("Regenerate")),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _refreshTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }
}