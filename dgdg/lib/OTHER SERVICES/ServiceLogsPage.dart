import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceLogsPage extends StatefulWidget {
  const ServiceLogsPage({super.key});

  @override
  _ServiceLogsPageState createState() => _ServiceLogsPageState();
}

class _ServiceLogsPageState extends State<ServiceLogsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  bool _isDarkMode = false;
  int? _businessId;
  String _userRole = 'staff';

  @override
  void initState() {
    super.initState();
    _loadConfigAndFetch();
  }

  Future<void> _loadConfigAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);

    final user = supabase.auth.currentUser;
    if (user != null) {
      final userData = await supabase
          .from('users')
          .select('business_id, role')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null) {
        _businessId = int.tryParse(userData['business_id'].toString());
        _userRole = userData['role'].toString().toLowerCase();
        _fetchLogs();
      }
    }
  }

  Future<void> _fetchLogs() async {
    if (_businessId == null) return;
    setState(() => _isLoading = true);

    try {
      // Tunachuja logs kulingana na Business ID
      final response = await supabase
          .from('services_logs')
          .select('*')
          .eq('business_id', _businessId!)
          .order('date_added', ascending: false);

      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Logs Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("INVENTORY ACTIVITY LOGS", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _fetchLogs, icon: const Icon(Icons.sync)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildHeaderSummary(),
          Expanded(
            child: _logs.isEmpty
                ? const Center(child: Text("No activities recorded yet."))
                : ListView.builder(
              itemCount: _logs.length,
              padding: const EdgeInsets.all(10),
              itemBuilder: (context, index) {
                final log = _logs[index];
                return _buildLogTile(log, cardColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF1A237E),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Recent Stock Adjustments", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
          const SizedBox(height: 5),
          Text("${_logs.length} Actions Recorded", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log, Color cardColor) {
    final date = DateTime.parse(log['date_added'].toString());
    final String action = log['action'] ?? 'Updated';

    // Rangi kulingana na action
    Color actionColor = Colors.blue;
    if (action.contains('Added')) actionColor = Colors.green;
    if (action.contains('Deleted') || action.contains('Reduced')) actionColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: actionColor.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.history, color: actionColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(log['service_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Text(DateFormat('dd MMM, HH:mm').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(action, style: TextStyle(color: actionColor, fontWeight: FontWeight.bold, fontSize: 11)),
            const SizedBox(height: 5),
            Row(
              children: [
                _miniInfo("Qty: ${log['total_quantity']}"),
                const SizedBox(width: 10),
                _miniInfo("Sell: ${NumberFormat('#,###').format(log['selling_price'])}"),
                const SizedBox(width: 10),
                if (_userRole == 'admin') _miniInfo("Buy: ${NumberFormat('#,###').format(log['buy_price'])}"),
              ],
            ),
            const SizedBox(height: 5),
            Text("Done by: ${log['added_by'] ?? 'System'}", style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}