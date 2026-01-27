import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../phamacy/ReceiptScreen.dart';

class ServiceCart extends StatefulWidget {
  final Map<String, dynamic> user;
  const ServiceCart({Key? key, required this.user}) : super(key: key);

  @override
  _ServiceCartState createState() => _ServiceCartState();
}

class _ServiceCartState extends State<ServiceCart> {
  List<Map<String, dynamic>> _cartItems = [];
  double grandTotal = 0.0;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  int? _businessId;
  String _businessName = '';
  String _staffName = '';

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('users')
          .select('business_id, business_name, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          _businessId = profile['business_id'];
          _businessName = profile['business_name'] ?? '';
          _staffName = profile['full_name'] ?? '';
        });
        _loadCart();
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  Future<void> _loadCart() async {
    final supabase = Supabase.instance.client;
    try {
      final response = await supabase
          .from('servicecart')
          .select('*')
          .eq('user_id', supabase.auth.currentUser!.id);

      double total = 0.0;
      for (var item in response) {
        total += (item['price'] * item['quantity']);
      }

      if (mounted) {
        setState(() {
          _cartItems = List<Map<String, dynamic>>.from(response);
          grandTotal = total;
        });
      }
    } catch (e) {
      debugPrint("❌ Cart Load Error: $e");
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final supabase = Supabase.instance.client;
    try {
      final serviceData = await supabase
          .from('services')
          .select('remaining_quantity, unit')
          .eq('id', item['service_id'])
          .maybeSingle();

      if (serviceData != null && serviceData['unit'].toString().toLowerCase() != 'service') {
        int currentStock = serviceData['remaining_quantity'] ?? 0;
        await supabase.from('services').update({
          'remaining_quantity': currentStock + item['quantity']
        }).eq('id', item['service_id']);
      }

      await supabase.from('servicecart').delete().eq('id', item['id']);
      _loadCart();
      _showSnackbar("Bidhaa imeondolewa na stock imerudishwa", Colors.blueGrey);
    } catch (e) {
      debugPrint("❌ Delete & Restore Error: $e");
    }
  }

  Future<void> _checkout() async {
    if (_cartItems.isEmpty) return;
    if (_nameController.text.trim().isEmpty) {
      _showSnackbar("Tafadhali andika jina la mteja", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;
    final String receiptNo = "SRV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    final String now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    try {
      List<String> names = [];
      List<int> qtys = [];
      List<double> prices = [];
      List<String> units = [];
      List<String> sources = [];

      final List<Map<String, dynamic>> salesToInsert = [];

      for (var item in _cartItems) {
        final serviceData = await supabase
            .from('services')
            .select('buy, unit')
            .eq('id', item['service_id'])
            .maybeSingle();

        names.add(item['service_name']);
        qtys.add(item['quantity']);
        prices.add(item['price'].toDouble());
        units.add(serviceData?['unit'] ?? 'Pcs');
        sources.add('SERVICE');

        salesToInsert.add({
          'receipt_number': receiptNo,
          'service_id': item['service_id'],
          'name': item['service_name'],
          'quantity': item['quantity'],
          'buy_price': (serviceData?['buy'] ?? 0).toDouble(),
          'sell_price': item['price'],
          'customer_name': _nameController.text.trim(),
          'customer_phone': _phoneController.text.trim(),
          'business_id': _businessId,
          'business_name': _businessName,
          'sub_business_name': item['sub_business_name'],
          'confirmed_by': _staffName,
          'category': serviceData?['unit'] == 'Service' ? 'SERVICE' : 'ITEM',
          'status': 'Confirmed',
          'sale_date': now,
        });
      }

      await supabase.from('salesservice').insert(salesToInsert);
      await supabase.from('servicecart').delete().eq('user_id', supabase.auth.currentUser!.id);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              confirmedBy: _staffName,
              confirmedTime: now,
              customerName: _nameController.text.trim(),
              customerPhone: _phoneController.text.trim(),
              customerEmail: "",
              paymentMethod: "CASH",
              receiptNumber: receiptNo,
              medicineNames: names,
              medicineQuantities: qtys,
              medicinePrices: prices,
              medicineUnits: units,
              medicineSources: sources,
              totalPrice: grandTotal,
              remaining_quantity: 0,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackbar("Hitilafu wakati wa checkout: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat('#,###');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          children: [
            const Text("KAPU LA HUDUMA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("$_staffName @ $_businessName".toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
          ],
        ),
        backgroundColor: Colors.indigo[900],
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCustomerInfo(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(children: [Icon(Icons.list_alt, size: 16), SizedBox(width: 8), Text("Orodha ya Huduma/Bidhaa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))]),
          ),
          Expanded(
            child: _cartItems.isEmpty
                ? _emptyCartUI()
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _cartItems.length,
              itemBuilder: (ctx, i) {
                final item = _cartItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: Icon(Icons.miscellaneous_services, color: Colors.indigo[900])),
                    title: Text(item['service_name'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text("${item['quantity']} x ${currency.format(item['price'])} TSH"),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _removeItem(item),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildBottomSection(currency),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 4),
    );
  }

  Widget _buildCustomerInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.withOpacity(0.1))),
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: "Jina la Mteja",
              isDense: true,
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: "Namba ya Simu",
              isDense: true,
              prefixIcon: const Icon(Icons.phone_android_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCartUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.indigo.withOpacity(0.1)),
          const Text("Kapu lako ni tupu kwa sasa", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBottomSection(NumberFormat currency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("JUMLA KUU", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text("${currency.format(grandTotal)} TSH", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo[900])),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _checkout,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[900], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("KAMILISHA MALIPO", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            ),
          )
        ],
      ),
    );
  }
}