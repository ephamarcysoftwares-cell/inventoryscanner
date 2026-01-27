import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSubscriptionPage extends StatefulWidget {
  const AdminSubscriptionPage({super.key});

  @override
  State<AdminSubscriptionPage> createState() => _AdminSubscriptionPageState();
}

class _AdminSubscriptionPageState extends State<AdminSubscriptionPage> {
  final supabase = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _adminDataFuture;
  bool isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final res = await supabase.from('users').select('email').eq('id', user.id).maybeSingle();
    if (res != null && res['email'].toString().toLowerCase() == "mlyukakenedy@gmail.com") {
      setState(() => isAuthorized = true);
      _refreshData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied!")));
        Navigator.pop(context);
      }
    }
  }

  void _refreshData() {
    setState(() {
      _adminDataFuture = supabase
          .from('businesses')
          .select('real_id:id, business_name, expiry_date, subscriptions(*)')
          .order('business_name');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isAuthorized) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("ADMIN BILLING PANEL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData)],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _adminDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text("Data Error: ${snapshot.error}"));

          final allData = snapshot.data ?? [];

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.indigo[50]),
                columns: const [
                  DataColumn(label: Text('Business')),
                  DataColumn(label: Text('Discount')),
                  DataColumn(label: Text('Payable (After Disc)')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Expiry')),
                  DataColumn(label: Text('Action')),
                ],
                rows: allData.map((biz) {
                  final rawSub = biz['subscriptions'];
                  Map<String, dynamic>? sub = (rawSub is List && rawSub.isNotEmpty) ? rawSub[0] : null;

                  double base = double.tryParse(sub?['price_per_month']?.toString() ?? "10500") ?? 10500;
                  int disc = sub?['discount_percent'] ?? 0;
                  double netPayable = base - (base * (disc / 100));

                  return DataRow(cells: [
                    DataCell(Text(biz['business_name'] ?? "Unnamed", style: const TextStyle(fontWeight: FontWeight.bold))),
                    // Inaonyesha asilimia ya discount
                    DataCell(Text("$disc%", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                    // Inaonyesha Bei baada ya discount na ile ya mwanzo
                    DataCell(Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("TZS ${NumberFormat("#,###").format(netPayable)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                        if (disc > 0)
                          Text("Old: ${NumberFormat("#,###").format(base)}",
                              style: const TextStyle(fontSize: 9, decoration: TextDecoration.lineThrough, color: Colors.grey)),
                      ],
                    )),
                    DataCell(_statusBadge(sub?['payment_status'] ?? "Pending")),
                    DataCell(Text(biz['expiry_date'] ?? "Not Set")),
                    DataCell(IconButton(
                      icon: const Icon(Icons.edit_note, color: Colors.indigo),
                      onPressed: () => _showEditDialog(biz, sub),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status.toLowerCase() == 'active' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  void _showEditDialog(Map<String, dynamic> biz, Map<String, dynamic>? sub) {
    final pController = TextEditingController(text: sub?['price_per_month']?.toString() ?? "10500");
    final dController = TextEditingController(text: sub?['discount_percent']?.toString() ?? "0");
    String currentStatus = sub?['payment_status'] ?? "Pending";
    DateTime? selectedDate = biz['expiry_date'] != null ? DateTime.tryParse(biz['expiry_date']) : DateTime.now();

    final int targetId = biz['real_id'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          double b = double.tryParse(pController.text) ?? 0;
          int d = int.tryParse(dController.text) ?? 0;
          double net = b - (b * (d / 100));

          return AlertDialog(
            title: Text("Edit ${biz['business_name']}"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: pController,
                    decoration: const InputDecoration(labelText: "Original Price"),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setDialogState(() {}),
                  ),
                  TextField(
                    controller: dController,
                    decoration: const InputDecoration(labelText: "Discount %"),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 15),
                  // Kiboksi cha kuonyesha hesabu LIVE
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.yellow[100], borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Price After Discount:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        Text("TZS ${NumberFormat("#,###").format(net)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: currentStatus,
                    items: ["Pending", "Active", "Suspended"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setDialogState(() => currentStatus = val!),
                    decoration: const InputDecoration(labelText: "Status"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await supabase.from('subscriptions').upsert({
                      'business_id': targetId,
                      'price_per_month': pController.text,
                      'discount_percent': int.tryParse(dController.text) ?? 0,
                      'payment_status': currentStatus,
                      'last_payment_date': DateTime.now().toIso8601String(),
                    }, onConflict: 'business_id');

                    await supabase.from('businesses').update({
                      'expiry_date': DateFormat('yyyy-MM-dd').format(selectedDate!),
                    }).eq('id', targetId);

                    if (mounted) Navigator.pop(ctx);
                    _refreshData();
                  } catch (e) { print(e); }
                },
                child: const Text("SAVE CHANGES"),
              ),
            ],
          );
        },
      ),
    );
  }
}