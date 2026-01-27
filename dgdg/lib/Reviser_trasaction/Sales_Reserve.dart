import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ReverseDirectSales extends StatefulWidget {
  final String userRole;
  final String userName;

  const ReverseDirectSales({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _ReverseDirectSalesState createState() => _ReverseDirectSalesState();
}

class _ReverseDirectSalesState extends State<ReverseDirectSales> {
  late Future<List<Map<String, dynamic>>> salesData;
  String businessName = '';
  int? currentBusinessId;
  String? adminEmail;

  // Filters
  DateTime? startDate;
  DateTime? endDate;
  TextEditingController searchController = TextEditingController();

  // State
  bool isProcessing = false;
  String? generatedCode;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    salesData = Future.value([]);
    _initializeData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _initializeData() async {
    await getBusinessInfo();
    _applyFilters();
  }

  Future<void> getBusinessInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final userProfile = await supabase.from('users').select('business_id').eq('id', user.id).single();
      final bId = userProfile['business_id'];
      final biz = await supabase.from('businesses').select('business_name, email').eq('id', bId).single();

      setState(() {
        currentBusinessId = bId;
        businessName = biz['business_name'] ?? '';
        adminEmail = biz['email'];
      });
    } catch (e) {
      debugPrint("Info Error: $e");
    }
  }

  void _applyFilters() {
    setState(() {
      salesData = _getSalesData();
    });
  }

  Future<List<Map<String, dynamic>>> _getSalesData() async {
    final supabase = Supabase.instance.client;
    if (currentBusinessId == null) return [];

    var query = supabase.from('sales').select().eq('business_id', currentBusinessId!);

    if (startDate != null && endDate != null) {
      String startStr = "${DateFormat('yyyy-MM-dd').format(startDate!)} 00:00:00";
      String endStr = "${DateFormat('yyyy-MM-dd').format(endDate!)} 23:59:59";
      query = query.gte('confirmed_time', startStr).lte('confirmed_time', endStr);
    }

    if (searchController.text.isNotEmpty) {
      query = query.or('receipt_number.ilike.%${searchController.text}%,medicine_name.ilike.%${searchController.text}%');
    }

    final response = await query.order('confirmed_time', ascending: false).limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  // ================== REVERSAL LOGIC ===================

  Future<void> requestReverse(Map<String, dynamic> sale) async {
    if (adminEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email ya Admin haipo!")));
      return;
    }

    setState(() => isProcessing = true);
    generatedCode = (100000 + Random().nextInt(900000)).toString();

    final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 587, ssl: false);

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', 'SALES REVERSE')
      ..recipients.add(adminEmail!)
      ..subject = "APPROVAL CODE: $generatedCode"
      ..text = "Ombi la kufuta mauzo:\nRisiti: ${sale['receipt_number']}\nBidhaa: ${sale['medicine_name']}\nKiasi: ${sale['total_quantity']}\n\nIngiza code: $generatedCode";

    try {
      await send(message, smtpServer);
      setState(() => isProcessing = false);
      _showVerifyDialog(sale);
    } catch (e) {
      setState(() => isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Hitilafu ya barua pepe: $e")));
    }
  }

  void _showVerifyDialog(Map<String, dynamic> sale) {
    TextEditingController codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Uthibitisho wa Admin", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ingiza namba ya uthibitisho iliyotumwa kwa barua pepe ya duka."),
            const SizedBox(height: 15),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 5),
              decoration: InputDecoration(
                hintText: "000000",
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Ghairi")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]),
            onPressed: () {
              if (codeCtrl.text == generatedCode) {
                Navigator.pop(context);
                _executeReverse(sale);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Code siyo sahihi!")));
              }
            },
            child: const Text("Verify & Execute", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _executeReverse(Map<String, dynamic> sale) async {
    final supabase = Supabase.instance.client;
    setState(() => isProcessing = true);

    try {
      final String source = (sale['source'] ?? "").toString().toUpperCase();
      final String targetTable = (source == "OTHER PRODUCT") ? 'other_product' : 'medicines';
      final String medicineName = sale['medicine_name'];
      final num soldQty = sale['total_quantity'] ?? 0;

      final productData = await supabase
          .from(targetTable)
          .select('id, remaining_quantity')
          .eq('name', medicineName)
          .eq('business_id', currentBusinessId!)
          .maybeSingle();

      if (productData != null) {
        num currentRemaining = productData['remaining_quantity'] ?? 0;
        await supabase.from(targetTable).update({
          'remaining_quantity': currentRemaining + soldQty,
          'last_updated': DateTime.now().toIso8601String(),
        }).eq('id', productData['id']);
      }

      await supabase.from('sales').delete().eq('id', sale['id']);

      if (mounted) {
        _applyFilters();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Stock imerudishwa na muamala umefutwa!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("❌ Hitilafu: $e");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  // ================== UI ===================

  @override
  Widget build(BuildContext context) {
    final Color cardCol = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = _isDarkMode ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("REVERSE CASH PAYMENTS",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Text("${widget.userName} @ $businessName".toUpperCase(),
                style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 65,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- DATE RANGE PICKER ---
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cardCol,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    _dateIndicator(
                        label: "Kuanzia",
                        date: startDate,
                        icon: Icons.calendar_today,
                        color: Colors.indigo,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
                          if (picked != null) { setState(() => startDate = picked); _applyFilters(); }
                        }
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ),
                    _dateIndicator(
                        label: "Mpaka",
                        date: endDate,
                        icon: Icons.event,
                        color: Colors.redAccent,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
                          if (picked != null) { setState(() => endDate = picked); _applyFilters(); }
                        }
                    ),
                  ],
                ),
              ),

              // --- SEARCH BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: "Tafuta risiti au bidhaa...",
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigo),
                    filled: true,
                    fillColor: cardCol,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // --- DATA LIST ---
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: salesData,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    if (snapshot.data!.isEmpty) return _emptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80, top: 5),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final sale = snapshot.data![index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardCol,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text("${sale['medicine_name']}".toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo[900])),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                RichText(
                                    text: TextSpan(
                                        style: TextStyle(color: textCol.withOpacity(0.7), fontSize: 12),
                                        children: [
                                          const TextSpan(text: "Risiti: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(text: "#${sale['receipt_number']}  "),
                                          const TextSpan(text: "Qty: ", style: TextStyle(fontWeight: FontWeight.bold)),
                                          TextSpan(text: "${sale['total_quantity']}"),
                                        ]
                                    )
                                ),
                                const SizedBox(height: 4),
                                Text(DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(sale['confirmed_time'])),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[400],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12)
                              ),
                              onPressed: () => requestReverse(sale),
                              child: const Text("REVERSE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          if (isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: const Padding(
                    padding: EdgeInsets.all(25.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text("Tafadhali subiri...", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 4),
    );
  }

  Widget _dateIndicator({required String label, DateTime? date, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(date == null ? "Chagua" : DateFormat('dd MMM yyyy').format(date),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: Colors.indigo.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text("Hakuna mauzo yaliyopatikana",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}