import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../FOTTER/CurvedRainbowBar.dart';

class CustomerListScreen extends StatefulWidget {
  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> sales = [];
  List<bool> selectedCustomers = [];
  bool selectAll = false;
  bool isLoading = false;

  String businessName = '';
  String businessPhone = '';
  String waInstanceId = '';
  String waToken = '';
  String smsKey = '';

  bool _isDarkMode = false;
  bool _sendWhatsapp = true;
  bool _sendSms = false;

  Map<String, bool> sendingStatus = {};
  Map<String, String> statusLog = {};

  final _bodyController = TextEditingController(text: "Habari mpendwa mteja, tunakushukuru kwa kuendelea kuwa nasi!");
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await getBusinessInfo();
    await _fetchSales();
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();

      if (userProfile != null) {
        String userBusiness = userProfile['business_name'];
        final data = await supabase.from('businesses').select().eq('business_name', userBusiness).maybeSingle();

        if (data != null && mounted) {
          setState(() {
            businessName = data['business_name']?.toString() ?? '';
            businessPhone = data['phone']?.toString() ?? '';
            waInstanceId = data['whatsapp_instance_id']?.toString() ?? '';
            waToken = data['whatsapp_access_token']?.toString() ?? '';
            smsKey = data['sms_api_key']?.toString() ?? '';
          });
        }
      }
    } catch (e) { debugPrint('❌ Profile Error: $e'); }
  }

  Future<void> _fetchSales() async {
    if (businessName.isEmpty) return;
    setState(() => isLoading = true);
    try {
      var query = Supabase.instance.client.from('sales').select().eq('business_name', businessName);
      if (_searchController.text.isNotEmpty) {
        query = query.or('customer_name.ilike.%${_searchController.text}%,customer_phone.ilike.%${_searchController.text}%');
      }
      final response = await query.order('confirmed_time', ascending: false);
      setState(() {
        sales = List<Map<String, dynamic>>.from(response);
        selectedCustomers = List.generate(sales.length, (_) => false);
      });
    } finally { setState(() => isLoading = false); }
  }

  Future<bool> sendWhatsApp(String phoneNumber, String messageText) async {
    if (waInstanceId.isEmpty || waToken.isEmpty) return false;
    try {
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = '255${cleanPhone.substring(1)}';
      else if (!cleanPhone.startsWith('255')) cleanPhone = '255$cleanPhone';

      final res = await http.post(
        Uri.parse('https://wawp.net/wp-json/awp/v1/send'),
        body: {'instance_id': waInstanceId, 'access_token': waToken, 'chatId': cleanPhone, 'message': messageText},
      );
      // Ikiandika true au status code 200/201
      return res.statusCode == 200 || res.body.contains('true');
    } catch (e) { return false; }
  }

  // --- REKEBISHO LIKOO HAPA CHINI ---
  Future<void> _sendToCustomer(Map<String, dynamic> customer) async {
    // 1. CHUKUA TAARIFA ZA MTEJA
    String rcp = customer['id']?.toString() ?? '';
    String phone = customer['customer_phone'] ?? '';
    String customerName = customer['customer_name'] ?? 'Mpendwa Mteja';

    // 2. ANZA KUONYESHA STATUS (Inatuma...)
    if (!mounted) return;
    setState(() {
      sendingStatus[rcp] = true;
      statusLog[rcp] = "Inatuma...";
    });

    // 3. TENGENEZA UJUMBE WENYE JINA LA MTEJA
    // Hapa mwanzo unataja jina la mteja, kisha unaweka ujumbe wako wa body
    final msg = "Habari ndugu mpendwa wetu *$customerName*,\n\n"
        "${_bodyController.text}\n\n"
        "📞 *Msaada:* Ukiwa na changamoto wasiliana nami kupitia: $businessPhone\n"
        "🏢 *Kutoka:* $businessName";

    String finalResults = "";

    try {
      // 4. TUMA WHATSAPP
      if (_sendWhatsapp && phone.isNotEmpty) {
        bool ok = await sendWhatsApp(phone, msg);
        finalResults += ok ? "WA ✅ " : "WA ❌ ";
      }

      // 5. TUMA SMS
      if (_sendSms && phone.isNotEmpty && smsKey.isNotEmpty) {
        final res = await http.post(Uri.parse("https://app.sms-gateway.app/services/send.php"), body: {
          'number': phone.replaceAll(RegExp(r'\D'), ''),
          'message': msg,
          'key': smsKey
        });
        finalResults += (res.statusCode == 200) ? "SMS ✅" : "SMS ❌";
      }

      // 6. UPDATE MATOKEO KWENYE SCREEN
      if (mounted) {
        setState(() {
          statusLog[rcp] = finalResults.isEmpty ? "Imeshindwa" : finalResults;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          statusLog[rcp] = "Error ❌";
        });
      }
    } finally {
      // 7. ZIMA PROGRESS INDICATOR
      if (mounted) {
        setState(() {
          sendingStatus[rcp] = false;
        });
      }
    }
  }

  void _processBulk() async {
    if (_bodyController.text.isEmpty) return;
    for (int i = 0; i < sales.length; i++) {
      if (selectedCustomers[i]) {
        await _sendToCustomer(sales[i]);
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color waGreen = Color(0xFF075E54);
    const Color waAccent = Color(0xFF00A884);

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121B22) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: waGreen,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("WhatsApp Business", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            Text(businessName.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchSales),
          IconButton(icon: const Icon(Icons.more_vert, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: waGreen,
            child: Row(
              children: [
                Expanded(child: _tabItem("CHAGUA WOTE", onTap: () {
                  setState(() {
                    selectAll = !selectAll;
                    selectedCustomers = List.generate(sales.length, (_) => selectAll);
                  });
                })),
                Expanded(child: _tabItem("WATEJA (${sales.length})", isActive: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _fetchSales(),
              decoration: InputDecoration(
                hintText: "Tafuta jina au namba...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: _isDarkMode ? Colors.white10 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: sales.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 85),
              itemBuilder: (context, index) {
                final c = sales[index];
                final rcp = c['id']?.toString();
                final isSelected = selectedCustomers[index];

                return ListTile(
                  onTap: () => setState(() => selectedCustomers[index] = !selectedCustomers[index]),
                  leading: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, color: Colors.white, size: 35),
                      ),
                      if (isSelected)
                        const Positioned(
                          bottom: 0, right: 0,
                          child: CircleAvatar(radius: 10, backgroundColor: waAccent, child: Icon(Icons.check, size: 12, color: Colors.white)),
                        ),
                    ],
                  ),
                  title: Text(c['customer_name'] ?? 'Mteja', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(statusLog[rcp] ?? c['customer_phone'],
                      style: TextStyle(color: (statusLog[rcp]?.contains('✅') ?? false) ? waAccent : Colors.grey)),
                  trailing: sendingStatus[rcp] == true
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Leo", style: TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
          _buildWhatsAppInput(waAccent),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 20),
    );
  }

  Widget _tabItem(String title, {bool isActive = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? Colors.white : Colors.transparent, width: 3))),
        child: Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildWhatsAppInput(Color accentColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _isDarkMode ? const Color(0xFF1F2C34) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(hintText: "Andika ujumbe...", border: InputBorder.none),
                    ),
                  ),
                  const Icon(Icons.attach_file, color: Colors.grey),
                  const SizedBox(width: 10),
                  const Icon(Icons.camera_alt, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: _processBulk,
            child: CircleAvatar(
              radius: 25,
              backgroundColor: accentColor,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }
}