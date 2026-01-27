import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

// ==========================================
// 1. SCREEN YA MALIPO (MAIN SCREEN)
// ==========================================
class ClickPesaPaymentScreen extends StatefulWidget {
  const ClickPesaPaymentScreen({super.key});

  @override
  State<ClickPesaPaymentScreen> createState() => _ClickPesaPaymentScreenState();
}

class _ClickPesaPaymentScreenState extends State<ClickPesaPaymentScreen> {
  // CREDENTIALS
  final String _clientId = "IDZdzneti4V2DNdsuFemUgxLcPmkxkyL";
  final String _apiKey = "SKrEvNLpJ6nRdPns5rwZJzE8SkqfTG0MZzW7kTd3kR";
  final String _waInstance = "27E9E9F88CC1";
  final String _waToken = "jOos7Fc3cE7gj2";

  // CONTROLLERS
  final _searchController = TextEditingController();
  final _paymentPhoneController = TextEditingController(text: "0");
  Timer? _searchDebounce;
  Timer? _countdownTimer;
  Timer? _refreshTimer;

  // STATE
  String _foundBusinessName = "";
  dynamic _foundBusinessId;
  String _foundBusinessEmail = "";
  bool _isSearching = false;
  bool _isProcessing = false;
  bool _isAlreadyPaid = false;
  int _secondsRemaining = 30;

  double _unitPriceAfterDiscount = 10500.0;
  int _discountPercent = 0;
  int _selectedMonths = 1;
  String _finalPayAmount = "10500";
  String _controlNumber = "";
  bool _showControlNumber = false;

  // ---------------------------------------------------------
  // LOGIC 1: AUTO-TRACKER (Imeunganishwa kutoka Tracker yako)
  // ---------------------------------------------------------
  void _startAutoTracking(String orderRef, String cNumber) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      debugPrint("🔵 Inahakiki malipo kwa Control No: $cNumber");

      try {
        // A. Pata Token
        final tokenResp = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
          headers: {'api-key': _apiKey, 'client-id': _clientId},
        );
        final token = jsonDecode(tokenResp.body)['token'].toString().replaceFirst("Bearer ", "");

        // B. Uliza ClickPesa kwa kutumia Control Number
        final response = await http.get(
          Uri.parse("https://api.clickpesa.com/third-parties/payments/$cNumber"),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final rawData = jsonDecode(response.body);
          Map<String, dynamic> data = (rawData is List) ? rawData.first : rawData;

          if (data['status'] == 'SETTLED' || data['status'] == 'PAID' || data['status'] == 'SUCCESS') {
            timer.cancel();
            // C. Sasisha Supabase (Kutumia Schema yako)
            await Supabase.instance.client.from('payments').update({
              'status': data['status'],
              'channel': data['channel'],
              'payment_reference': data['paymentReference'],
              'collected_amount': double.tryParse(data['collectedAmount'].toString()) ?? 0.0,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('order_reference', orderRef);

            setState(() {
              _isProcessing = false;
              _showControlNumber = false;
              _isAlreadyPaid = true;
            });
            _showSuccessDialog();
          }
        }
      } catch (e) {
        debugPrint("❌ Auto-track error: $e");
      }
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 70),
        content: const Text("MALIPO YAMEPOKELEWA!\n\nAsante, usajili wako umesasishwa.", textAlign: TextAlign.center),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("SAWA"))],
      ),
    );
  }

  // ---------------------------------------------------------
  // LOGIC 2: SEARCH & PAYMENT
  // ---------------------------------------------------------
  void _lookupBusiness(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (value.trim().length < 3) return;
      setState(() => _isSearching = true);
      try {
        final data = await Supabase.instance.client.from('businesses').select('id, business_name, email, subscriptions(*)').or('email.ilike.%$value%,phone.ilike.%$value%,business_name.ilike.%$value%').maybeSingle();
        if (data != null) {
          setState(() {
            _foundBusinessName = data['business_name'];
            _foundBusinessId = data['id'];
            _foundBusinessEmail = data['email'] ?? "";
          });
          _checkExistingStatus(data['id']);
        }
      } finally {
        setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _checkExistingStatus(dynamic busId) async {
    final lastPayment = await Supabase.instance.client.from('payments').select().eq('business_id', busId).order('created_at', ascending: false).limit(1).maybeSingle();
    if (lastPayment != null) {
      String status = lastPayment['status'].toString().toUpperCase();
      if (status == "PENDING" && lastPayment['control_number'] != null) {
        setState(() {
          _controlNumber = lastPayment['control_number'];
          _showControlNumber = true;
          _finalPayAmount = lastPayment['amount'].toString();
        });
        _startAutoTracking(lastPayment['order_reference'], lastPayment['control_number']);
      } else if (["SUCCESS", "SETTLED", "PAID"].contains(status)) {
        setState(() => _isAlreadyPaid = true);
      }
    }
  }

  Future<void> _handlePayment() async {
    setState(() { _isProcessing = true; _secondsRemaining = 30; });
    final String orderRef = "ORD${DateTime.now().millisecondsSinceEpoch}";
    try {
      await Supabase.instance.client.from('payments').insert({
        'business_id': _foundBusinessId,
        'amount': double.parse(_finalPayAmount),
        'months': _selectedMonths,
        'order_reference': orderRef,
        'status': 'INITIATED',
        'customer_name': _foundBusinessName,
        'customer_email': _foundBusinessEmail,
      });

      final tokenResp = await http.post(Uri.parse("https://api.clickpesa.com/third-parties/generate-token"), headers: {'api-key': _apiKey, 'client-id': _clientId});
      final token = jsonDecode(tokenResp.body)['token'].toString().replaceFirst("Bearer ", "");

      String phone = _paymentPhoneController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) phone = "255${phone.substring(1)}";

      await http.post(Uri.parse("https://api.clickpesa.com/third-parties/payments/initiate-ussd-push-request"), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({"amount": _finalPayAmount, "currency": "TZS", "phoneNumber": phone, "orderReference": orderRef}));

      _startCountdown(token, phone, orderRef);
    } catch (e) { _showSnack("Error: $e"); setState(() => _isProcessing = false); }
  }

  void _startCountdown(String token, String phone, String orderRef) {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
        await _fetchControlNumber(token, phone, orderRef);
      }
    });
  }

  Future<void> _fetchControlNumber(String token, String phone, String orderRef) async {
    try {
      final resp = await http.post(Uri.parse("https://api.clickpesa.com/third-parties/billpay/create-customer-control-number"), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'billAmount': _finalPayAmount, 'customerName': _foundBusinessName, 'customerPhone': phone}));
      final data = jsonDecode(resp.body);
      if (data['billPayNumber'] != null) {
        String cNumber = data['billPayNumber'];
        await Supabase.instance.client.from('payments').update({'control_number': cNumber, 'status': 'PENDING'}).eq('order_reference', orderRef);
        setState(() { _controlNumber = cNumber; _showControlNumber = true; _isProcessing = false; });
        _startAutoTracking(orderRef, cNumber);
      }
    } catch (e) { debugPrint("Error: $e"); setState(() => _isProcessing = false); }
  }

  void _updateTotalAmount() { setState(() => _finalPayAmount = (_unitPriceAfterDiscount * _selectedMonths).toStringAsFixed(0)); }
  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("1 STOCK - Malipo"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.track_changes),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AutoPaymentTracker())),
            tooltip: "Debug Tracker",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _searchController, onChanged: _lookupBusiness, decoration: const InputDecoration(labelText: "Tafuta Duka", prefixIcon: Icon(Icons.search), border: OutlineInputBorder())),
            const SizedBox(height: 20),
            if (_foundBusinessName.isNotEmpty) ...[
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(_foundBusinessName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                      const SizedBox(height: 15),
                      DropdownButton<int>(
                        value: _selectedMonths,
                        isExpanded: true,
                        items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(value: m, child: Text("$m Month(s)"))).toList(),
                        onChanged: _showControlNumber || _isAlreadyPaid ? null : (v) { setState(() { _selectedMonths = v!; _updateTotalAmount(); }); },
                      ),
                      const SizedBox(height: 15),
                      Text("JUMLA: Tsh $_finalPayAmount", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isAlreadyPaid)
                const Card(color: Colors.green, child: ListTile(leading: Icon(Icons.verified, color: Colors.white), title: Text("Duka hili limeshalipiwa kikamilifu.", style: TextStyle(color: Colors.white))))
              else if (!_showControlNumber) ...[
                TextField(controller: _paymentPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Namba ya Malipo", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _handlePayment,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    child: _isProcessing ? Text("Subiri... ($_secondsRemaining s)", style: const TextStyle(color: Colors.white)) : const Text("LIPIA SASA", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
              if (_showControlNumber) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(border: Border.all(color: Colors.indigo, width: 2), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      const Text("CONTROL NUMBER", style: TextStyle(fontWeight: FontWeight.bold)),
                      SelectableText(_controlNumber, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.brown)),
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 5),
                      const Text("Inasubiri malipo... Itajirefresh yenyewe ukishalipa.", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
              ]
            ]
          ],
        ),
      ),
    );
  }

  @override
  void dispose() { _searchDebounce?.cancel(); _countdownTimer?.cancel(); _refreshTimer?.cancel(); super.dispose(); }
}

// ==========================================
// 2. DEBUG TRACKER SCREEN (Kama ulivyoomba)
// ==========================================
class AutoPaymentTracker extends StatefulWidget {
  const AutoPaymentTracker({super.key});

  @override
  State<AutoPaymentTracker> createState() => _AutoPaymentTrackerState();
}

class _AutoPaymentTrackerState extends State<AutoPaymentTracker> {
  final String _clientId = "IDZdzneti4V2DNdsuFemUgxLcPmkxkyL";
  final String _apiKey = "SKrEvNLpJ6nRdPns5rwZJzE8SkqfTG0MZzW7kTd3kR";

  bool _isLoading = false;
  String _message = "Kuanzisha uhakiki...";
  Map<String, dynamic>? _details;
  Timer? _refreshTimer;

  @override
  void initState() { super.initState(); _autoTrackLastPayment(); }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  Future<String?> _getAccessToken() async {
    try {
      final resp = await http.post(Uri.parse("https://api.clickpesa.com/third-parties/generate-token"), headers: {'api-key': _apiKey, 'client-id': _clientId});
      if (resp.statusCode == 200) return jsonDecode(resp.body)['token'].toString().replaceFirst("Bearer ", "");
    } catch (e) { debugPrint("Token Error: $e"); }
    return null;
  }

  Future<void> _autoTrackLastPayment() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; _message = "Inahakiki malipo..."; });
    try {
      final responseDb = await Supabase.instance.client.from('payments').select().not('status', 'in', '("SETTLED", "PAID", "SUCCESS")').not('control_number', 'is', null).order('created_at', ascending: false).limit(1).maybeSingle();

      if (responseDb == null) { setState(() => _message = "Hakuna malipo yanayosubiri."); return; }

      String controlNumber = responseDb['control_number'];
      String orderID = responseDb['order_reference'];
      String? token = await _getAccessToken();
      if (token == null) return;

      final response = await http.get(Uri.parse("https://api.clickpesa.com/third-parties/payments/$controlNumber"), headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final rawData = jsonDecode(response.body);
        Map<String, dynamic> data = (rawData is List) ? rawData.first : rawData;
        setState(() => _details = data);
        if (data['status'] == 'SETTLED' || data['status'] == 'PAID') {
          await _updateDatabase(orderID, data);
          setState(() => _message = "✅ Malipo yamekamilika!");
        } else {
          setState(() => _message = "⏳ Bado tunasubiri: ${data['status']}");
          _startAutoRefresh();
        }
      } else { setState(() => _message = "Bado tunasubiri muamala..."); _startAutoRefresh(); }
    } catch (e) { debugPrint("Track Error: $e"); } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _updateDatabase(String orderRef, Map<String, dynamic> data) async {
    await Supabase.instance.client.from('payments').update({
      'status': data['status'],
      'channel': data['channel'],
      'payment_reference': data['paymentReference'],
      'collected_amount': double.tryParse(data['collectedAmount'].toString()) ?? 0.0,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('order_reference', orderRef);
  }

  void _startAutoRefresh() { _refreshTimer?.cancel(); _refreshTimer = Timer(const Duration(seconds: 10), () { if (mounted) _autoTrackLastPayment(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Debug Tracker"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_details != null) ...[
                const SizedBox(height: 20),
                Text("Order: ${_details!['orderReference']}"),
                Text("Status: ${_details!['status']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 30),
              ElevatedButton(onPressed: _autoTrackLastPayment, child: const Text("HAKIKI MWENYEWE"))
            ],
          ),
        ),
      ),
    );
  }
}