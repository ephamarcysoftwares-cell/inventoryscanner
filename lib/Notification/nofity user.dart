import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerListScreen extends StatefulWidget {
  @override
  _CustomerListScreenState createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> sales = [];
  List<bool> selectedCustomers = [];
  bool selectAll = false, isLoading = false, _isDarkMode = false;
  bool _sendWhatsapp = true, _sendSms = false, _isProcessingBulk = false;

  String businessName = '', businessPhone = '', businessEmail = '', businessAddress = '', businessLogo = '';
  String waInstanceId = '', waToken = '', smsKey = '';
  double _uploadProgress = 0;
  int _completedCount = 0;

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

      final userData = await supabase.from('users').select('business_name, business_id').eq('id', user.id).maybeSingle();
      if (userData != null) {
        var query = await supabase.from('businesses').select().or('id.eq.${userData['business_id']},business_name.eq.${userData['business_name']}').limit(1);

        if (query.isNotEmpty) {
          var data = query.first;
          if (data['is_main_business'] == false && data['parent_id'] != null) {
            final parent = await supabase.from('businesses').select().eq('id', data['parent_id']).maybeSingle();
            if (parent != null) data = parent;
          }

          if (mounted) setState(() {
            businessName = data['business_name']?.toString() ?? '';
            businessPhone = data['phone']?.toString() ?? '';
            businessEmail = data['email']?.toString() ?? '';
            businessAddress = data['address']?.toString() ?? '';
            businessLogo = data['logo']?.toString() ?? '';
            waInstanceId = data['whatsapp_instance_id']?.toString() ?? '';
            waToken = data['whatsapp_access_token']?.toString() ?? '';
            smsKey = data['sms_api_key']?.toString() ?? '';
          });
        }
      }
    } catch (e) { debugPrint('❌ Error: $e'); }
  }

  Future<void> _fetchSales() async {
    if (businessName.isEmpty) return;
    setState(() => isLoading = true);
    try {
      var query = Supabase.instance.client.from('sales').select().eq('business_name', businessName);
      if (_searchController.text.isNotEmpty) query = query.or('customer_name.ilike.%${_searchController.text}%,customer_phone.ilike.%${_searchController.text}%');
      final res = await query.order('confirmed_time', ascending: false);
      setState(() {
        sales = List<Map<String, dynamic>>.from(res);
        selectedCustomers = List.generate(sales.length, (_) => false);
      });
    } finally { setState(() => isLoading = false); }
  }

  Future<bool> sendWhatsApp(String phone, String msg) async {
    if (waInstanceId.isEmpty || waToken.isEmpty) return false;
    try {
      String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('0')) cleanPhone = '255${cleanPhone.substring(1)}';
      else if (!cleanPhone.startsWith('255')) cleanPhone = '255$cleanPhone';

      final res = await http.post(Uri.parse('https://wawp.net/wp-json/awp/v1/send'), body: {
        'instance_id': waInstanceId, 'access_token': waToken, 'chatId': cleanPhone,
        'message': msg, if (businessLogo.isNotEmpty) 'media_url': businessLogo, if (businessLogo.isNotEmpty) 'type': 'image'
      });
      return res.statusCode == 200 || res.body.contains('true');
    } catch (e) { return false; }
  }

  Future<void> _sendToCustomer(Map<String, dynamic> customer) async {
    String rcp = customer['id'].toString(), phone = customer['customer_phone'] ?? '', name = customer['customer_name'] ?? 'Mteja';
    setState(() { sendingStatus[rcp] = true; statusLog[rcp] = "Inatuma..."; });

    // HAPA NDIPO TAARIFA ZA BIASHARA ZIMEUNGANISHWA KWENYE UJUMBE
    final msg = "Habari *$name*,\n\n"
        "${_bodyController.text}\n\n"
        "--- ujumbe huu Umetumwa na ---\n"
        "🏢 *Biashara:* $businessName\n"
        "📧 *Email:* ${businessEmail.isNotEmpty ? businessEmail : 'N/A'}\n"
        "📞 *Simu:* $businessPhone\n"
        "📍 *Address:* ${businessAddress.isNotEmpty ? businessAddress : 'Arusha, TZ'}";

    String resMsg = "";
    if (_sendWhatsapp && phone.isNotEmpty) resMsg += (await sendWhatsApp(phone, msg)) ? "WA ✅ " : "WA ❌ ";
    if (_sendSms && phone.isNotEmpty && smsKey.isNotEmpty) {
      final res = await http.post(Uri.parse("https://app.sms-gateway.app/services/send.php"), body: {'number': phone, 'message': msg, 'key': smsKey});
      resMsg += (res.statusCode == 200) ? "SMS ✅" : "SMS ❌";
    }

    if (mounted) setState(() { statusLog[rcp] = resMsg.isEmpty ? "Error" : resMsg; sendingStatus[rcp] = false; });
  }

  void _processBulk() async {
    List<int> targets = [for (int i=0; i<selectedCustomers.length; i++) if (selectedCustomers[i]) i];
    if (targets.isEmpty) return;
    setState(() { _isProcessingBulk = true; _uploadProgress = 0; _completedCount = 0; });
    for (int i in targets) {
      await _sendToCustomer(sales[i]);
      setState(() { _completedCount++; _uploadProgress = _completedCount / targets.length; });
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    setState(() => _isProcessingBulk = false);
  }

  @override
  Widget build(BuildContext context) {
    const Color waGreen = Color(0xFF075E54);
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121B22) : const Color(0xFFF0F2F5),
      appBar: AppBar(backgroundColor: waGreen, title: Text("Marketing - $businessName", style: const TextStyle(fontSize: 14, color: Colors.white))),
      body: Column(
        children: [
          Container(color: waGreen, child: Row(children: [
            Expanded(child: _tabItem("CHAGUA WOTE", onTap: () => setState(() { selectAll = !selectAll; selectedCustomers = List.generate(sales.length, (_) => selectAll); }))),
            Expanded(child: _tabItem("WATEJA (${sales.length})", isActive: true)),
          ])),
          _buildSearchBar(),
          if (_isProcessingBulk) _buildProgressBar(),
          Expanded(child: ListView.separated(
            itemCount: sales.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              onTap: () => setState(() => selectedCustomers[i] = !selectedCustomers[i]),
              leading: _buildAvatar(selectedCustomers[i]),
              title: Text(sales[i]['customer_name'] ?? 'Mteja', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(statusLog[sales[i]['id'].toString()] ?? sales[i]['customer_phone'], style: const TextStyle(fontSize: 11)),
              trailing: sendingStatus[sales[i]['id'].toString()] == true ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send, size: 14),
            ),
          )),
          _buildChannelSelector(),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() => Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Progress: $_completedCount..."), Text("${(_uploadProgress * 100).toInt()}%")]),
    LinearProgressIndicator(value: _uploadProgress, color: Colors.green, minHeight: 6),
  ]));

  Widget _buildChannelSelector() => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(FontAwesomeIcons.whatsapp, size: 16, color: Colors.green), Switch(value: _sendWhatsapp, activeColor: Colors.green, onChanged: (v) => setState(() => _sendWhatsapp = v)),
    const SizedBox(width: 20),
    const Icon(Icons.sms, size: 16, color: Colors.blue), Switch(value: _sendSms, activeColor: Colors.blue, onChanged: (v) => setState(() => _sendSms = v)),
  ]);

  Widget _buildInputArea() => Container(padding: const EdgeInsets.fromLTRB(10, 5, 10, 25), child: Row(children: [
    Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: TextField(controller: _bodyController, decoration: const InputDecoration(hintText: "Ujumbe...", border: InputBorder.none)))),
    const SizedBox(width: 8),
    CircleAvatar(backgroundColor: Colors.green, child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _isProcessingBulk ? null : _processBulk)),
  ]));

  Widget _buildSearchBar() => Padding(padding: const EdgeInsets.all(8), child: TextField(controller: _searchController, onChanged: (v) => _fetchSales(),
      decoration: InputDecoration(hintText: "Tafuta...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))));

  Widget _buildAvatar(bool sel) => Stack(children: [
    CircleAvatar(backgroundImage: businessLogo.isNotEmpty ? NetworkImage(businessLogo) : null, child: businessLogo.isEmpty ? const Icon(Icons.person) : null),
    if (sel) const Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 8, backgroundColor: Colors.green, child: Icon(Icons.check, size: 10, color: Colors.white))),
  ]);

  Widget _tabItem(String t, {bool isActive = false, VoidCallback? onTap}) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isActive ? Colors.white : Colors.transparent, width: 3))), child: Center(child: Text(t, style: TextStyle(color: isActive ? Colors.white : Colors.white60, fontWeight: FontWeight.bold, fontSize: 11)))));

  Future<void> _loadTheme() async { final prefs = await SharedPreferences.getInstance(); setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false); }
}