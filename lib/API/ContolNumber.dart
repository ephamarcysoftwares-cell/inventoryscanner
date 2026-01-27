import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TrackControlNumbersPage extends StatefulWidget {
  const TrackControlNumbersPage({super.key});

  @override
  State<TrackControlNumbersPage> createState() => _TrackControlNumbersPageState();
}

class _TrackControlNumbersPageState extends State<TrackControlNumbersPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  // Date Filters
  DateTime? _fromDate;
  DateTime? _toDate;

  // Summaries
  double _totalSettled = 0;
  double _totalPending = 0;
  int _totalTransactions = 0;

  @override
  void initState() {
    super.initState();
    _fetchRecords();
  }

  // --- LOGIC YA KUVUTA DATA KUTOKA SUPABASE ---
  Future<void> _fetchRecords() async {
    setState(() => _isLoading = true);
    try {
      final userAuth = _supabase.auth.currentUser;
      if (userAuth == null) return;

      // 1. Pata business_id ya mtumiaji aliyelogin
      final userData = await _supabase
          .from('users')
          .select('business_id')
          .eq('id', userAuth.id)
          .single();

      final myBusinessId = userData['business_id'];

      // 2. Jenga Query ya miamala
      var query = _supabase
          .from('payment_tracking_records')
          .select()
          .eq('business_id', myBusinessId);

      // Chuja kwa Tarehe (Kama zimechaguliwa)
      if (_fromDate != null) {
        query = query.gte('created_at', _fromDate!.toIso8601String());
      }
      if (_toDate != null) {
        // Tunahakikisha toDate inafika hadi mwisho wa siku 23:59:59
        final endOfDay = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        query = query.lte('created_at', endOfDay.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false);
      final data = List<Map<String, dynamic>>.from(response);

      // 3. Piga hesabu za Summary
      double settled = 0;
      double pending = 0;

      for (var item in data) {
        double amt = double.tryParse(item['amount'].toString()) ?? 0;
        if (item['status'] == 'SETTLED' || item['status'] == 'PAID' || item['status'] == 'SUCCESS') {
          settled += amt;
        } else {
          pending += amt;
        }
      }

      setState(() {
        _records = data;
        _filteredRecords = data;
        _totalSettled = settled;
        _totalPending = pending;
        _totalTransactions = data.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Error fetching data: $e");
      setState(() => _isLoading = false);
    }
  }

  // --- DATE PICKER LOGIC ---
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.indigo[900]!),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchRecords(); // Inajivuta yenyewe baada ya kuchagua tarehe
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("UFUATILIAJI WA MALIPO-CNUMBER"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRecords,
          )
        ],
      ),
      body: Column(
        children: [
          // --- TOP SECTION: DASHBOARD & DATE PICKERS ---
          Container(
            padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
            decoration: BoxDecoration(
              color: Colors.indigo[900],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // 1. Summary Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTopStat("MIAMALA", _totalTransactions.toString(), Colors.white),
                    _buildTopStat("SETTLED", "TZS ${fmt.format(_totalSettled)}", Colors.greenAccent),
                    _buildTopStat("PENDING", "TZS ${fmt.format(_totalPending)}", Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 25),

                // 2. Date Filter Boxes (Left & Right)
                Row(
                  children: [
                    Expanded(
                      child: _buildDateButton("Kuanzia (From)", _fromDate, true),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildDateButton("Hadi (To)", _toDate, false),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // --- TRANSACTIONS LIST ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _fetchRecords,
              child: _filteredRecords.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                itemCount: _filteredRecords.length,
                padding: const EdgeInsets.symmetric(vertical: 15),
                itemBuilder: (context, index) {
                  final item = _filteredRecords[index];
                  final status = item['status'].toString().toUpperCase();
                  final isPaid = status == 'SETTLED' || status == 'PAID' || status == 'SUCCESS';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, spreadRadius: 1)
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(15),
                      leading: CircleAvatar(
                        backgroundColor: isPaid ? Colors.green[50] : Colors.orange[50],
                        child: Icon(
                          isPaid ? Icons.check_circle : Icons.hourglass_empty,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                      title: Text(
                        item['customer_name']?.toString().toUpperCase() ?? "MTEJA",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text("CN: ${item['control_number']}",
                              style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                          Text(DateFormat('dd MMM yyyy • HH:mm').format(DateTime.parse(item['created_at']))),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "TZS ${fmt.format(item['amount'])}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isPaid ? Colors.green : Colors.orange,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isPaid ? "IMELIPWA" : "PENDING",
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildTopStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildDateButton(String label, DateTime? date, bool isFrom) {
    return InkWell(
      onTap: () => _selectDate(context, isFrom),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9)),
                  Text(
                    date == null ? "Chagua" : DateFormat('dd/MM/yyyy').format(date),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Hakuna miamala iliyopatikana", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          if (_fromDate != null || _toDate != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                });
                _fetchRecords();
              },
              child: const Text("Ondoa Filters"),
            ),
        ],
      ),
    );
  }
}