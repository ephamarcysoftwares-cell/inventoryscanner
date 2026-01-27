import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../phamacy/ReceiptScreen.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  final _supabase = Supabase.instance.client;
  String _searchQuery = "";
  String? _myBusinessName;
  bool _isLoadingName = true;

  // Date Range
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchMyBusinessName();
  }

  /// 1. FUNCTION YA KUPATA JINA LA BIASHARA KUTOKA SUPABASE
  Future<void> _fetchMyBusinessName() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _myBusinessName = "STOCK & INVENTORY SOFTWARE";
          _isLoadingName = false;
        });
        return;
      }

      final response = await _supabase
          .from('users')
          .select('business_name')
          .eq('id', userId)
          .maybeSingle();

      setState(() {
        if (response != null && response['business_name'] != null) {
          _myBusinessName = response['business_name'].toString();
        } else {
          _myBusinessName = "STOCK & INVENTORY SOFTWARE";
        }
        _isLoadingName = false;
      });
    } catch (e) {
      debugPrint('⚠️ Error: $e');
      setState(() {
        _myBusinessName = "STOCK & INVENTORY SOFTWARE";
        _isLoadingName = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'SETTLED':
      case 'PAID':
      case 'SUCCESS':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'FAILED':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        // INAONYESHA JINA LA BIASHARA KWENYE TITLE
        title: Text(_myBusinessName ?? "Ripoti ya Malipo"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoadingName
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : Column(
        children: [
          // 1. HEADER SECTION (DATE, SEARCH & BUSINESS NAME)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 5, 16, 20),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
            ),
            child: Column(
              children: [
                // ONESHA BUSINESS_NAME CHINI YA TITLE
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.store, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _myBusinessName?.toUpperCase() ?? "",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    Expanded(child: _dateBox("FROM", _startDate, _pickDateRange)),
                    const SizedBox(width: 12),
                    Expanded(child: _dateBox("TO", _endDate, _pickDateRange)),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Tafuta mteja au control number...",
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. ORODHA YA MALIPO (FILTERED)
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // .eq INAHAKIKISHA BIASHARA A HAONI DATA ZA BIASHARA B
              stream: _supabase
                  .from('contropayement_payments')
                  .stream(primaryKey: ['id'])
                  .eq('business_name', _myBusinessName!)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text("Hakuna malipo kwa biashara ya $_myBusinessName"),
                  );
                }

                final rawData = snapshot.data!;

                // Filter kwa Tarehe na Search Bar
                final filtered = rawData.where((p) {
                  final createdAt = DateTime.parse(p['created_at']).toLocal();
                  final name = p['customer_name']?.toString().toLowerCase() ?? "";
                  final control = p['control_number']?.toString().toLowerCase() ?? "";

                  bool dateMatch = createdAt.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
                      createdAt.isBefore(_endDate.add(const Duration(days: 1)));
                  bool searchMatch = name.contains(_searchQuery) || control.contains(_searchQuery);

                  return dateMatch && searchMatch;
                }).toList();

                double totalPaid = filtered
                    .where((p) => ['SETTLED', 'PAID', 'SUCCESS'].contains(p['status']?.toString().toUpperCase().trim()))
                    .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0.0));

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.only(top: 10),
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final String status = (p['status'] ?? '').toString().toUpperCase().trim();
                          final bool canPrint = ['PAID', 'SUCCESS', 'SETTLED'].contains(status);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                child: Icon(canPrint ? Icons.check_circle : Icons.payment, color: _getStatusColor(status)),
                              ),
                              title: Text(p['customer_name'] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("TSH ${NumberFormat('#,###').format(p['amount'] ?? 0)}"),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      _infoRow("Duka/Business", p['business_name'] ?? "N/A"),
                                      _infoRow("Order Ref", p['order_reference'] ?? "N/A"),
                                      _infoRow("Control No", p['control_number'] ?? "N/A"),
                                      _infoRow("Transaction ID", p['payment_id'] ?? "Bado"),
                                      _infoRow("Channel", p['channel'] ?? "N/A"),
                                      _infoRow("Simu", p['phone_number'] ?? "N/A"),
                                      _infoRow("Staff", p['staff_name'] ?? "N/A"),
                                      _infoRow("Tarehe", DateFormat('dd/MM HH:mm').format(DateTime.parse(p['created_at']).toLocal())),

                                      const Divider(height: 30),
                                      if (canPrint)
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () => _navigateToReceipt(p),
                                            icon: const Icon(Icons.print),
                                            label: const Text("PRINT RECEIPT"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        )
                                      else
                                        const Text("❌ Risiti haipatikani: Haijalipwa", style: TextStyle(color: Colors.red, fontSize: 11)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // TOTAL FOOTER
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("TOTAL PAID:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            "TSH ${NumberFormat('#,###').format(totalPaid)}",
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ZA ZIADA ---

  Widget _dateBox(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey, fontSize: 13)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
  );

  void _navigateToReceipt(Map<String, dynamic> payment) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(
      confirmedBy: payment['staff_name'] ?? "Staff",
      confirmedTime: DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(payment['updated_at'] ?? payment['created_at']).toLocal()),
      customerName: payment['customer_name'] ?? "N/A",
      customerPhone: payment['phone_number'] ?? "",
      customerEmail: payment['customer_email'] ?? "",
      paymentMethod: 'Mobile (${payment['channel'] ?? "N/A"})',
      receiptNumber: "REC-${payment['id']}",
      medicineNames: [payment['items_summary'] ?? "General Items"],
      medicineQuantities: [1],
      medicinePrices: [(payment['amount'] as num?)?.toDouble() ?? 0.0],
      medicineUnits: ["Pcs"],
      medicineSources: const [],
      totalPrice: (payment['amount'] as num?)?.toDouble() ?? 0.0,
      remaining_quantity: 0,
    )));
  }
}