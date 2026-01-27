import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceInventoryPage extends StatefulWidget {
  const ServiceInventoryPage({super.key});

  @override
  _ServiceInventoryPageState createState() => _ServiceInventoryPageState();
}

class _ServiceInventoryPageState extends State<ServiceInventoryPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  bool _isDarkMode = false;
  String _userRole = 'staff';
  int? _businessId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUserConfig();
  }

  Future<void> _loadUserConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);

    final user = supabase.auth.currentUser;
    if (user != null) {
      final data = await supabase
          .from('users')
          .select('role, business_id')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _userRole = data['role'].toString().toLowerCase();
          _businessId = int.tryParse(data['business_id'].toString());
        });
        _fetchServices();
      }
    }
  }

  Future<void> _fetchServices() async {
    if (_businessId == null) return;
    setState(() => _isLoading = true);

    try {
      // Kama ni Admin anaona zote, kama ni Sub-Admin unaweza kuongeza filter ya tawi hapa
      final response = await supabase
          .from('services')
          .select('*')
          .eq('business_id', _businessId!)
          .order('name', ascending: true);

      setState(() {
        _services = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _userRole == 'admin' || _userRole == 'sub_admin';
    final filteredServices = _services.where((s) =>
        s['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("STOCK & INVENTORY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF311B92),
        actions: [
          IconButton(onPressed: _fetchServices, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          _buildQuickSummary(filteredServices, isManager),
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: "Search product name...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final item = filteredServices[index];
                return _buildServiceCard(item, isManager);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSummary(List<Map<String, dynamic>> data, bool isManager) {
    int outOfStock = data.where((s) => (s['remaining_quantity'] ?? 0) <= 0).length;
    double stockValue = data.fold(0, (sum, item) => sum + ((item['remaining_quantity'] ?? 0) * (item['price'] ?? 0)));

    return Container(
      padding: const EdgeInsets.all(15),
      color: const Color(0xFF311B92),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem("TOTAL ITEMS", data.length.toString(), Colors.white),
          _summaryItem("OUT OF STOCK", outOfStock.toString(), Colors.redAccent),
          if (isManager) _summaryItem("STOCK VALUE", NumberFormat('#,###').format(stockValue), Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color col) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        Text(value, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> item, bool isManager) {
    final int qty = item['remaining_quantity'] ?? 0;
    final bool isLow = qty <= 5;
    final bool isExpired = DateTime.parse(item['expiry_date']).isBefore(DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isLow ? Border.all(color: Colors.red.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isLow ? Colors.red : Colors.green,
            child: Text(qty.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("Unit: ${item['unit']} | Added by: ${item['added_by']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (isExpired)
                  const Text("EXPIRED", style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(NumberFormat('#,###').format(item['price']), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue)),
              if (isManager)
                Text("Buy: ${NumberFormat('#,###').format(item['buy'])}", style: const TextStyle(fontSize: 10, color: Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }
}