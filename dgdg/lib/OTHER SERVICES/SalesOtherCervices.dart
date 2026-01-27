import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'Cartservices.dart';

class SaleServicesScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SaleServicesScreen({super.key, required this.user});

  @override
  _SaleServicesScreenState createState() => _SaleServicesScreenState();
}

class _SaleServicesScreenState extends State<SaleServicesScreen> {
  List<Map<String, dynamic>> allServices = [];
  List<Map<String, dynamic>> filteredServices = [];
  TextEditingController searchController = TextEditingController();
  Map<int, int> quantities = {};
  Timer? _timer;

  int? _currentUserBusinessId;
  String business_name = '';
  String sub_business_name = '';
  bool _isDarkMode = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getBusinessInfo();
    // Refresh data kila baada ya sekunde 15
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) => loadServices());
  }

  @override
  void dispose() {
    searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase
          .from('users')
          .select('business_id, sub_business_name, business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || userProfile == null) return;

      setState(() {
        _currentUserBusinessId = userProfile['business_id'];
        sub_business_name = userProfile['sub_business_name'] ?? 'Main Store';
        business_name = userProfile['business_name'] ?? '';
      });

      loadServices();
    } catch (e) {
      debugPrint('❌ Error getting business info: $e');
    }
  }

  void loadServices() async {
    if (_currentUserBusinessId == null) return;
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('services')
          .select()
          .eq('business_id', _currentUserBusinessId!)
          .order('name', ascending: true);

      if (mounted && response != null) {
        setState(() {
          allServices = List<Map<String, dynamic>>.from(response);
          _filterServices();
          for (var item in allServices) {
            quantities[item['id']] = quantities[item['id']] ?? 1;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Load Error: $e");
    }
  }

  void _filterServices() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredServices = allServices.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _addToServiceCart(Map<String, dynamic> service, int qty, {double disc = 0}) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      double finalPrice = (service['price'] ?? 0).toDouble() - disc;
      String unit = (service['unit'] ?? 'Pcs').toString();
      bool isDeductible = unit.toLowerCase() != 'service';

      if (isDeductible) {
        final response = await supabase
            .from('services')
            .select('remaining_quantity')
            .eq('id', service['id'])
            .single();

        int currentActualStock = response['remaining_quantity'] ?? 0;
        int newStock = currentActualStock - qty;

        if (currentActualStock >= qty) {
          await supabase
              .from('services')
              .update({'remaining_quantity': newStock})
              .eq('id', service['id']);
        } else {
          _showSnackbar("Stock haitoshi! Iliyopo: $currentActualStock", Colors.red);
          setState(() => _isLoading = false);
          return;
        }
      }

      await supabase.from('servicecart').insert({
        'user_id': user.id,
        'service_id': service['id'],
        'service_name': service['name'],
        'price': finalPrice,
        'quantity': qty,
        'business_id': _currentUserBusinessId,
        'business_name': business_name,
        'sub_business_name': sub_business_name,
        'source': 'SERVICE',
        'date_added': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSnackbar("${service['name']} imeongezwa!", Colors.green);
        Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceCart(user: widget.user)));
      }
    } catch (e) {
      _showSnackbar("Hitilafu: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      loadServices();
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _showDiscountDialog(Map<String, dynamic> service, int qty) async {
    bool applyDiscount = false;
    TextEditingController discController = TextEditingController(text: "0");
    double originalPrice = (service['price'] ?? 0).toDouble();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Weka Kapuni: ${service['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Bei ya Moja: ${NumberFormat('#,###').format(originalPrice)} TSH"),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Weka Punguzo?"),
                  value: applyDiscount,
                  onChanged: (v) => setDialogState(() => applyDiscount = v!),
                ),
                if (applyDiscount)
                  TextField(
                    controller: discController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Kiasi cha Punguzo (TSH)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.pop(context);
                  double dValue = double.tryParse(discController.text) ?? 0;
                  _addToServiceCart(service, qty, disc: applyDiscount ? dValue : 0);
                },
                child: const Text("HAKIKI", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');
    final Color cardCol = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = _isDarkMode ? Colors.white : Colors.blueGrey[900]!;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("HUDUMA NA BIDHAA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${widget.user['username'] ?? widget.user['full_name']} @ $business_name".toUpperCase(),
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
          ],
        ),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 65,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_basket_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceCart(user: widget.user))),
          )
        ],
      ),
      body: Column(
        children: [
          _buildSearchField(cardCol),
          if (_isLoading) const LinearProgressIndicator(color: Colors.green),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: filteredServices.length,
              itemBuilder: (context, index) {
                final item = filteredServices[index];
                int id = item['id'];
                int remain = item['remaining_quantity'] ?? 0;
                bool isService = (item['unit'] ?? '').toString().toLowerCase() == 'service';

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cardCol,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['name'].toString().toUpperCase(),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo[900])),
                            const SizedBox(height: 4),
                            Text(isService ? "HUDUMA" : "Stock: $remain ${item['unit']}",
                                style: TextStyle(fontSize: 12, color: isService ? Colors.blue : Colors.grey[600])),
                            Text("${currencyFormat.format(item['price'])} TSH",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              _qtyBtn(Icons.remove, () => setState(() => quantities[id] = (quantities[id]! > 1) ? quantities[id]! - 1 : 1)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                child: Text("${quantities[id]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              _qtyBtn(Icons.add, () => setState(() => quantities[id] = quantities[id]! + 1)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: (isService || remain > 0) ? Colors.green : Colors.grey,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: (isService || remain > 0) ? () => _showDiscountDialog(item, quantities[id]!) : null,
                            icon: const Icon(Icons.add_shopping_cart, size: 16, color: Colors.white),
                            label: const Text("WEKA", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 4),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: Colors.indigo),
      ),
    );
  }

  Widget _buildSearchField(Color fill) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: searchController,
        onChanged: (v) => _filterServices(),
        decoration: InputDecoration(
          hintText: "Tafuta bidhaa au huduma...",
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.indigo),
          filled: true,
          fillColor: fill,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}