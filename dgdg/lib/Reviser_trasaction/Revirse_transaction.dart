import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ReverseTransaction extends StatefulWidget {
  final String userRole;
  final String userName;

  const ReverseTransaction({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _ReverseTransactionState createState() => _ReverseTransactionState();
}

class _ReverseTransactionState extends State<ReverseTransaction> {
  late Future<List<Map<String, dynamic>>> paidLendData;
  late Future<double> paidLendTotal;

  // Business State Variables
  String businessName = '';
  int? currentBusinessId;
  String subBranchName = '';
  String? adminEmail;

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;

  bool isLoading = false;
  bool isProcessing = false;
  String? generatedCode;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    paidLendData = Future.value([]);
    paidLendTotal = Future.value(0.0);
    _initializeData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _initializeData() async {
    await getBusinessInfo();
    if (widget.userRole.toLowerCase() != 'admin') {
      _showAccessDeniedDialog();
    } else {
      _applyFilters();
    }
  }

  Future<void> getBusinessInfo() async {
    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final userProfile = await supabase
          .from('users')
          .select('business_id, sub_business_name')
          .eq('id', currentUser.id)
          .single();

      final bId = userProfile['business_id'];

      final bizData = await supabase
          .from('businesses')
          .select('business_name, email')
          .eq('id', bId)
          .single();

      if (mounted) {
        setState(() {
          currentBusinessId = bId;
          businessName = bizData['business_name'] ?? '';
          adminEmail = bizData['email'];
          subBranchName = userProfile['sub_business_name'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching business info: $e");
    }
  }

  // ================== DATA FETCHING ===================

  Future<List<Map<String, dynamic>>> _fetchPaidLendData() async {
    final supabase = Supabase.instance.client;
    try {
      if (currentBusinessId == null) return [];

      var query = supabase.from('To_lent_payedlogs').select();
      query = query.eq('business_id', currentBusinessId!);

      if (startDate != null && endDate != null) {
        query = query.gte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(startDate!)} 00:00:00')
            .lte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(endDate!)} 23:59:59');
      }

      String keyword = searchController.text.trim();
      if (keyword.isNotEmpty) {
        query = query.or('receipt_number.ilike.%$keyword%,customer_name.ilike.%$keyword%,medicine_name.ilike.%$keyword%');
      }

      final response = await query.order('confirmed_time', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) { return []; }
  }

  Future<double> _fetchPaidLendTotal() async {
    final supabase = Supabase.instance.client;
    try {
      if (currentBusinessId == null) return 0.0;

      var query = supabase.from('To_lent_payedlogs').select('total_price');
      query = query.eq('business_id', currentBusinessId!);

      if (startDate != null && endDate != null) {
        query = query.gte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(startDate!)} 00:00:00')
            .lte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(endDate!)} 23:59:59');
      }

      final List<dynamic> response = await query;
      return response.fold<double>(0.0, (sum, item) =>
      sum + (double.tryParse(item['total_price'].toString()) ?? 0.0));
    } catch (e) { return 0.0; }
  }

  void _applyFilters() {
    setState(() {
      isLoading = true;
      paidLendData = _fetchPaidLendData();
      paidLendTotal = _fetchPaidLendTotal();
    });
    Future.wait([paidLendData, paidLendTotal]).then((_) {
      if (mounted) setState(() => isLoading = false);
    });
  }

  // ================== REVERSE LOGIC ===================

  Future<void> requestReverseApproval(Map<String, dynamic> paidRecord) async {
    if (adminEmail == null || adminEmail!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Email ya Admin haijasajiliwa!")));
      return;
    }

    setState(() => isProcessing = true);
    try {
      generatedCode = (100000 + Random().nextInt(900000)).toString();
      await sendEmail(
          adminEmail!,
          "REVERSE REQUEST - $businessName",
          "Ombi la kurudisha malipo ya deni:\n\n"
              "Risiti: ${paidRecord['receipt_number']}\n"
              "Mteja: ${paidRecord['customer_name']}\n"
              "Kiasi: TSH ${paidRecord['total_price']}\n\n"
              "CODE YA UTHIBITISHO: $generatedCode"
      );
      _showCodeInputDialog(paidRecord);
    } catch (e) {
      debugPrint("Email Request Error: $e");
    } finally {
      setState(() => isProcessing = false);
    }
  }

  Future<void> _reversePayment(Map<String, dynamic> paidRecord) async {
    final supabase = Supabase.instance.client;
    final dynamic recordId = paidRecord['id'];
    final String receiptNum = paidRecord['receipt_number'].toString();

    setState(() => isProcessing = true);

    try {
      final Map<String, dynamic> newLendRecord = {
        "customer_name": paidRecord['customer_name'],
        "customer_phone": paidRecord['customer_phone'],
        "medicine_name": paidRecord['medicine_name'],
        "total_quantity": paidRecord['total_quantity'],
        "total_price": paidRecord['total_price'],
        "receipt_number": receiptNum,
        "payment_method": "TO LEND(MKOPO)",
        "confirmed_time": paidRecord['confirmed_time'],
        "user_id": paidRecord['user_id'],
        "business_id": currentBusinessId,
        "sub_business_name": paidRecord['sub_business_name'] ?? subBranchName,
        "source": 'reverse',
        "created_at": DateTime.now().toIso8601String(),
      };

      await supabase.from('To_lend').insert(newLendRecord);
      await supabase.from('sales').delete().eq('receipt_number', receiptNum);
      await supabase.from('To_lent_payedlogs').delete().eq('id', recordId);

      if (mounted) {
        _applyFilters();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("✅ Malipo yamefutwa na deni limerudishwa!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      debugPrint("Reverse Error: $e");
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> sendEmail(String email, String subject, String body) async {
    final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 587, ssl: false);
    final mailMessage = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', 'REVERSE SYSTEM')
      ..recipients.add(email)
      ..subject = subject
      ..text = body;
    try { await send(mailMessage, smtpServer); } catch (e) { debugPrint(e.toString()); }
  }

  // ================== UI COMPONENTS ===================

  void _showAccessDeniedDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Access Denied"),
      content: const Text("Only admins can reverse transactions."),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
    ));
  }

  void _showCodeInputDialog(Map<String, dynamic> paidRecord) {
    TextEditingController codeController = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text("Verification Code", style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
          decoration: const InputDecoration(hintText: "Enter Code")
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900]),
            onPressed: () {
              if (codeController.text == generatedCode) {
                Navigator.pop(context);
                _reversePayment(paidRecord);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Code")));
              }
            },
            child: const Text("Verify", style: TextStyle(color: Colors.white))
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final Color cardCol = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = _isDarkMode ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("REVERSE DEBT PAYMENTS",
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
              // Date Range Picker UI
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(15)),
                child: Row(
                  children: [
                    _dateIndicator("From", startDate, Icons.calendar_today, Colors.indigo),
                    const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    _dateIndicator("To", endDate, Icons.event, Colors.redAccent),
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: "Search customer or receipt...",
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    filled: true,
                    fillColor: cardCol,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Data List
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: paidLendData,
                  builder: (context, snapshot) {
                    if (isLoading) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return _emptyState();

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final item = snapshot.data![index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: cardCol, borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            title: Text(item['customer_name']?.toString().toUpperCase() ?? 'N/A',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo[900])),
                            subtitle: Text("Receipt: #${item['receipt_number']}\nDate: ${item['confirmed_time']}",
                                style: const TextStyle(fontSize: 11)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("TSH ${item['total_price']}",
                                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(60, 25)),
                                  onPressed: () => requestReverseApproval(item),
                                  child: const Text("REVERSE", style: TextStyle(color: Colors.white, fontSize: 9)),
                                )
                              ],
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
            Container(color: Colors.black54, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 4),
    );
  }

  Widget _dateIndicator(String label, DateTime? date, IconData icon, Color color) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2023), lastDate: DateTime.now());
          if (picked != null) {
            setState(() { if(label == "From") startDate = picked; else endDate = picked; });
            _applyFilters();
          }
        },
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(date == null ? "Select" : DateFormat('dd/MM/yy').format(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.history_rounded, size: 60, color: Colors.indigo.withOpacity(0.1)),
      const Text("No transactions found", style: TextStyle(color: Colors.grey)),
    ]));
  }
}