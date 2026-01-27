import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// Hakikisha path hii ni sahihi kulingana na folder zako
import '../FOTTER/CurvedRainbowBar.dart';

class MobileMoneyPayoutScreen extends StatefulWidget {
  const MobileMoneyPayoutScreen({super.key});

  @override
  State<MobileMoneyPayoutScreen> createState() => _MobileMoneyPayoutScreenState();
}

class _MobileMoneyPayoutScreenState extends State<MobileMoneyPayoutScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient supabase = Supabase.instance.client;
  late TabController _tabController;

  // --- BUSINESS & API CREDENTIALS ---
  String _apiKey = "";
  String _clientId = "";
  String _dynamicChecksumKey = "";
  String businessName = '';
  String businessEmail = '';
  String? _businessId, _staffName;

  // --- TRANSACTION STATE ---
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _otpController = TextEditingController();
  final currencyFormatter = NumberFormat('#,##0.00', 'en_US');

  bool _isProcessing = false;
  bool _isDarkMode = false;
  String? _previewName, _previewFee, _channel, _generatedOtp;

  // --- HISTORY DATA ---
  List<Map<String, dynamic>> _payoutHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- 1. INITIALIZATION ---
  // Badilisha sehemu ya _loadInitialData na _sendOtpViaEmail kwenye kodi yako:

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('darkMode') ?? false;

    // Tumia microtask ili UI isikwame (Lag)
    Future.microtask(() async {
      setState(() => _isProcessing = true);
      bool loaded = await _loadCredentials();
      if (loaded) {
        await _fetchPayoutHistory();
      }
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  Future<void> _sendOtpViaEmail(String otp, int amount, String phone) async {
    if (businessEmail.isEmpty) {
      _showSnackBar("⚠️ Email ya mmiliki haijawekwa kwenye DB!");
      return;
    }

    // Sanitize email address
    final target = businessEmail.trim();

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
      allowInsecure: true,
      ignoreBadCertificate: true, // Muhimu kwa seva zenye self-signed SSL
    );

    final message = Message()
      ..from = const Address('suport@ephamarcysoftware.co.tz', 'PAYOUT VERIFICATION')
      ..recipients.add(target)
      ..subject = '🔐 KODI YA UHAKIKI: $businessName'
      ..html = """
    <div style="font-family: sans-serif; padding: 20px; border: 2px solid #311B92; border-radius: 10px;">
      <h2 style="color: #311B92; text-align: center;">OMBI LA MALIPO</h2>
      <p>Mfanyakazi <b>$_staffName</b> anajaribu kutuma pesa.</p>
      <div style="background: #f4f4f4; padding: 15px; border-radius: 5px;">
         <p>💰 <b>Kiasi:</b> TZS ${currencyFormatter.format(amount)}</p>
         <p>📞 <b>Namba:</b> $phone</p>
      </div>
      <p style="margin-top: 20px; text-align: center;">Ikiwa Umelirthia mpe   ili aweze kukamilisha muamala Kumbuka E-PHAMARCY SOFTWARE Haitahusika Na ubadhilifu wowote .Mpe Kodi Hii ya siri ni:</p>
      <h1 style="color: #d32f2f; text-align: center; font-size: 45px; letter-spacing: 10px;">$otp</h1>
      <h1 style="color: #d32f2f; text-align: center; font-size: 45px; letter-spacing: 10px;">E-PHAMARCY SOFTWARE</h1>
    </div>
    """;

    try {
      // Tunatumia timeout ili email isipozunguka sana kama internet ni dhaifu
      await send(message, smtpServer).timeout(const Duration(seconds: 15));
      debugPrint("✅ OTP Sent Successfully to $target");
    } catch (e) {
      debugPrint("❌ SMTP Error Detail: $e");
      // Kama SMTP inafeli, angalia kama ni Port 465 au 587
      _showSnackBar("⚠️ Tatizo la muunganisho wa Email.");
    }
  }

  Future<bool> _loadCredentials() async {
    try {
      final authUser = supabase.auth.currentUser;
      if (authUser == null) return false;

      final userData = await supabase
          .from('users')
          .select('business_id, full_name')
          .eq('id', authUser.id)
          .maybeSingle();

      _staffName = userData?['full_name'] ?? "Mtumishi";
      final bId = userData?['business_id'];

      if (bId != null) {
        final bizData = await supabase
            .from('businesses')
            .select('business_name, email, api_key, client_id, checksum_key')
            .eq('id', bId)
            .maybeSingle();

        if (bizData != null) {
          setState(() {
            businessName = bizData['business_name'] ?? "Stock Online";
            businessEmail = (bizData['email'] ?? "").toString().trim();
            _businessId = bId.toString();
            _apiKey = (bizData['api_key'] ?? "").toString().trim();
            _clientId = (bizData['client_id'] ?? "").toString().trim();
            _dynamicChecksumKey = (bizData['checksum_key'] ?? "").toString().trim();
          });
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("❌ Credential Error: $e");
      return false;
    }
  }

  Future<void> _fetchPayoutHistory() async {
    if (_businessId == null) return;
    try {
      final data = await supabase
          .from('payout_logs')
          .select('*')
          .eq('business_id', int.parse(_businessId!))
          .order('created_at', ascending: false)
          .limit(20);

      setState(() => _payoutHistory = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    }
  }

  // --- 2. SECURITY: SMTP EMAIL OTP ---


  // --- 3. CLICKPESA LOGIC ---
  String _generateChecksum(Map<String, dynamic> payload) {
    if (_dynamicChecksumKey.isEmpty) return "";
    var sortedKeys = payload.keys.toList()..sort();
    String payloadString = sortedKeys.map((k) => payload[k].toString()).join().toUpperCase();
    var key = utf8.encode(_dynamicChecksumKey.trim());
    var bytes = utf8.encode(payloadString);
    return Hmac(sha256, key).convert(bytes).toString().toUpperCase();
  }

  // --- 4. PAYOUT WORKFLOW ---
  void _startPayoutWorkflow() async {
    if (_phoneController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar("Jaza namba na kiasi.");
      return;
    }
    setState(() => _isProcessing = true);

    String rawPhone = _phoneController.text.trim();
    if (rawPhone.startsWith('0')) rawPhone = "255${rawPhone.substring(1)}";
    if (!rawPhone.startsWith('255')) rawPhone = "255$rawPhone";

    int amount = int.parse(_amountController.text.trim());

    try {
      final tokenRes = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
          headers: {"api-key": _apiKey, "client-id": _clientId}
      );
      if (tokenRes.statusCode != 200) throw "ClickPesa Auth Failed";
      String token = jsonDecode(tokenRes.body)['token'].replaceAll("Bearer ", "").trim();

      final res = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/payouts/preview-mobile-money-payout"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: jsonEncode({"amount": amount, "currency": "TZS", "orderReference": "REF${DateTime.now().millisecondsSinceEpoch}", "phoneNumber": rawPhone})
      );

      setState(() => _isProcessing = false);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _previewName = data['receiver']['accountName'];
          _previewFee = data['fee'].toString();
          _channel = data['channelProvider'];
        });
        _showConfirmationModal(amount, rawPhone);
      } else {
        _showSnackBar("Hitilafu: ${jsonDecode(res.body)['message']}");
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnackBar("Tatizo la kiufundi: $e");
    }
  }

  void _showConfirmationModal(int amount, String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("HAKIKI JINA"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_previewName ?? "HAIJAJULIKANA", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
            const Divider(),
            _infoRow("Kiasi:", "TZS ${currencyFormatter.format(amount)}"),
            _infoRow("Makato:", "TZS ${currencyFormatter.format(double.parse(_previewFee!))}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _initiateOtpFlow(amount, phone);
            },
            child: const Text("TUMA KODI KWA BOSS"),
          )
        ],
      ),
    );
  }

  void _initiateOtpFlow(int amount, String phone) async {
    setState(() => _isProcessing = true);
    _generatedOtp = (100000 + (DateTime.now().microsecond % 900000)).toString();
    await _sendOtpViaEmail(_generatedOtp!, amount, phone);
    setState(() => _isProcessing = false);
    _showOtpEntryDialog(amount, phone);
  }

  void _showOtpEntryDialog(int amount, String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Ingiza Kodi ya Boss", textAlign: TextAlign.center),
        content: TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          decoration: const InputDecoration(hintText: "******"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
          ElevatedButton(
            onPressed: () {
              if (_otpController.text.trim() == _generatedOtp) {
                Navigator.pop(context);
                _executeFinalPayout(amount, phone);
              } else {
                _showSnackBar("Kodi siyo sahihi!");
              }
            },
            child: const Text("THIBITISHA"),
          )
        ],
      ),
    );
  }

  Future<void> _executeFinalPayout(int amount, String phone) async {
    setState(() => _isProcessing = true);
    String orderRef = "PAY${DateTime.now().millisecondsSinceEpoch}";
    try {
      final tokenRes = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/generate-token"),
          headers: {"api-key": _apiKey, "client-id": _clientId}
      );
      String token = jsonDecode(tokenRes.body)['token'].replaceAll("Bearer ", "").trim();

      Map<String, dynamic> payload = {"amount": amount, "currency": "TZS", "orderReference": orderRef, "phoneNumber": phone};

      final response = await http.post(
          Uri.parse("https://api.clickpesa.com/third-parties/payouts/create-mobile-money-payout"),
          headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
          body: jsonEncode({...payload, "checksum": _generateChecksum(payload)})
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await supabase.from('payout_logs').insert({
          'business_id': int.parse(_businessId!),
          'staff_name': _staffName,
          'recipient_phone': phone,
          'amount': amount,
          'fee': double.parse(_previewFee!),
          'status': 'success',
          'reference': orderRef,
          'otp_used': _generatedOtp,
        });
        _showSuccess(amount, phone);
        _fetchPayoutHistory();
      } else {
        _showSnackBar("Muamala umefeli upande wa ClickPesa.");
      }
    } catch (e) {
      _showSnackBar("Error: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  void _showSuccess(int amount, String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Miamala Imekamilika!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "TZS ${currencyFormatter.format(amount)} imetumwa kikamilifu kwenda namba $phone.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF311B92),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  Navigator.pop(context); // Funga Dialog
                  _tabController.animateTo(1); // Mpeleke user kwenye tab ya Historia moja kwa moja
                },
                child: const Text("SAWA, NIMEFAHAMU", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final primary = const Color(0xFF311B92);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("PAYOUT PORTAL", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.send), text: "TUMA PESA"),
            Tab(icon: Icon(Icons.history), text: "HISTORIA"),
          ],
        ),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildPayoutTab(isDark, primary),
          _buildHistoryTab(isDark),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildPayoutTab(bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          _buildSummaryHeader(isDark),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                _buildCustomField(
                    controller: _phoneController,
                    label: "Namba ya Mpokeaji",
                    icon: Icons.phone_android,
                    isDark: isDark,
                    hint: "07XX XXX XXX"
                ),
                const SizedBox(height: 20),
                _buildCustomField(
                    controller: _amountController,
                    label: "Kiasi cha Kutuma (TZS)",
                    icon: Icons.payments_outlined,
                    isDark: isDark,
                    hint: "Mfano: 50,000"
                ),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 5
                    ),
                    onPressed: _startPayoutWorkflow,
                    child: const Text("HAKIKI & TUMA PESA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield, size: 14, color: Colors.grey),
              SizedBox(width: 5),
              Text("Miamala inalindwa na 2FA Encryption", style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_payoutHistory.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]), const Text("Hakuna historia ya malipo bado.")]));
    }
    return RefreshIndicator(
      onRefresh: _fetchPayoutHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _payoutHistory.length,
        separatorBuilder: (c, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = _payoutHistory[index];
          final bool isSuccess = item['status'] == 'success';
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSuccess ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2))
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: isSuccess ? Colors.green[50] : Colors.red[50],
                  child: Icon(isSuccess ? Icons.check : Icons.close, color: isSuccess ? Colors.green : Colors.red),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['recipient_phone'] ?? "No Phone", style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text("Ref: ${item['reference']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      Text("By: ${item['staff_name']}", style: const TextStyle(fontSize: 10, color: Colors.blue)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("TZS ${currencyFormatter.format(item['amount'])}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    Text(DateFormat('dd/MM HH:mm').format(DateTime.parse(item['created_at'])), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(bool isDark) {
    return Row(
      children: [
        CircleAvatar(radius: 25, backgroundColor: Colors.indigo[100], child: Text(_staffName?[0] ?? "S", style: const TextStyle(fontWeight: FontWeight.bold))),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Habari, $_staffName", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            Text(businessName, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        )
      ],
    );
  }

  Widget _buildCustomField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.indigo),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 18)
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showSnackBar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}