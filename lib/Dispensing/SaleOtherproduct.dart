import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../CHATBOAT/chatboat.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'cart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class SaleOther extends StatefulWidget {
  final Map<String, dynamic> user;

  const SaleOther({super.key, required this.user});

  @override
  _SaleOtherState createState() => _SaleOtherState();
}

class _SaleOtherState extends State<SaleOther> {
  List<Map<String, dynamic>> allOtherProducts = [];
  List<Map<String, dynamic>> filteredOtherProducts = [];
  TextEditingController searchController = TextEditingController();
  Map<int, int> quantities = {};
  Map<int, TextEditingController> quantityControllers = {};
  Timer? _timer;

  String business_name = '';
  String sub_business_name = '';
  int? _businessId;
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    loadOtherProducts();
    getBusinessInfo();
    searchController.addListener(_filterOtherProducts);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      loadOtherProducts();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _timer?.cancel();
    quantityControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> loadOtherProducts() async {
    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) return;

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata Profile ya mtumiaji
      final userProfile = await supabase
          .from('users')
          .select('role, business_id, business_name, sub_business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || userProfile == null) return;

      final dynamic myBusinessId = userProfile['business_id'];
      final String mySubBranch = (userProfile['sub_business_name'] ?? '').toString().trim();

      // 2. QUERY ILIYOBORESHWA:
      // Tunachukua bidhaa ZOTE za biashara hii (business_id)
      // Bila kujali kama mtumiaji ni Staff au Admin, na bila kujali tawi.
      var query = supabase
          .from('other_product')
          .select()
          .eq('business_id', myBusinessId);

      final response = await query.order('name', ascending: true);

      if (response is List) {
        if (!mounted) return;
        setState(() {
          allOtherProducts = List<Map<String, dynamic>>.from(response);

          // Hifadhi data kwa ajili ya Cart
          _businessId = int.tryParse(myBusinessId.toString());
          sub_business_name = mySubBranch; // Tawi la mtumiaji (kwa ajili ya risiti)
          business_name = userProfile['business_name'] ?? '';

          // Maandalizi ya Quantity Controllers...
          for (var prod in allOtherProducts) {
            final dynamic id = prod['id'];
            quantities[id] = quantities[id] ?? 1;
            if (!quantityControllers.containsKey(id)) {
              quantityControllers[id] = TextEditingController(text: quantities[id].toString());
            }
          }
        });
        _filterOtherProducts();
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    }
  }
  void _filterOtherProducts() {
    String query = searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        filteredOtherProducts = List.from(allOtherProducts);
      } else {
        filteredOtherProducts = allOtherProducts.where((product) {
          final fieldsToSearch = [
            'name',
            'company',
            'batch_number',
            'manufacture_date',
            'expiry_date',
            'unit',
          ];
          return fieldsToSearch.any((field) {
            final fieldValue = product[field];
            return fieldValue != null && fieldValue.toString().toLowerCase().contains(query);
          });
        }).toList();
      }
    });
  }

  void _updateQuantity(int productId, int available, int change) {
    setState(() {
      int currentQuantity = quantities[productId] ?? 1;
      int newQuantity = currentQuantity + change;
      if (newQuantity < 1) newQuantity = 1;
      if (newQuantity > available) newQuantity = available;
      quantities[productId] = newQuantity;
      quantityControllers[productId]?.text = newQuantity.toString();
    });
  }

  Future<void> _addToCart(Map<String, dynamic> product, int quantity) async {
    debugPrint("🚀 STARTING: Supabase Add Other Product to Cart...");

    // 1. Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final supabase = Supabase.instance.client;
    final String userId = widget.user['id'].toString();

    try {
      // 2. Connectivity Check
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection.')),
        );
        return;
      }

      // 3. Fetch Real-time Stock and Business ID from Source
      // ✅ TUNAPATA business_id HALISI KUTOKA KWENYE BIDHAA HUSIKA
      final cloudData = await supabase
          .from('other_product')
          .select('remaining_quantity, business_id')
          .eq('id', product['id'])
          .maybeSingle();

      if (cloudData == null) {
        throw Exception("Product not found in inventory.");
      }

      int currentStock = int.tryParse(cloudData['remaining_quantity'].toString()) ?? 0;

      // ✅ Hapa tunahakikisha tunatumia business_id ya bidhaa husika
      final dynamic finalBusinessId = cloudData['business_id'] ?? _businessId;

      if (finalBusinessId == null) {
        throw Exception("Missing Business ID. Please re-login.");
      }

      // 4. Validation
      if (quantity > currentStock) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Not enough stock! Available: $currentStock')),
        );
        return;
      }

      final int newStock = currentStock - quantity;
      final String currentDate = DateTime.now().toIso8601String();

      // 5. Prepare Cart Item
      final cartItem = {
        'user_id': userId,
        'business_id': finalBusinessId, // ✅ IMETHIBITISHWA: Haitakuwa NULL
        'medicine_id': product['id'],
        'medicine_name': product['name'],
        'company': product['company'] ?? 'N/A',
        'price': (product['selling_price'] ?? 0).toDouble(),
        'quantity': quantity,
        'unit': product['unit'] ?? 'Pcs',
        'source': 'OTHER PRODUCT',
        'date_added': currentDate,
        'business_name': business_name,
        'sub_business_name': sub_business_name ?? '', // ✅ Kinga ya null kwa tawi
      };

      // 6. Execute Supabase Updates
      // A. Punguza stock
      await supabase.from('other_product')
          .update({'remaining_quantity': newStock})
          .eq('id', product['id']);

      // B. Ingiza kwenye cart
      await supabase.from('cart').insert(cartItem);

      debugPrint("✅ SUCCESS: Added to Cart for Business ID: $finalBusinessId");

      // 7. UI Refresh and Navigation
      if (mounted) {
        setState(() {
          quantities[product['id']] = 1;
          quantityControllers[product['id']]?.text = '1';
        });

        Navigator.pop(context); // Funga Loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product['name']} added to cart'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CartScreen(user: widget.user))
        );
      }

    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint("‼️ ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Cloud Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

// Helper to handle double/int parsing from different DB sources
  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase
          .from('users')
          .select('business_name, sub_business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || userProfile == null) return;

      final String myBusiness = userProfile['business_name'] ?? '';
      final String mySub = userProfile['sub_business_name'] ?? '';

      // MABADILIKO HAPA: Tumia .select().eq().limit(1) badala ya maybeSingle
      final response = await supabase
          .from('businesses')
          .select()
          .eq('business_name', myBusiness)
          .limit(1); // Inachukua moja tu hata kama zipo mbili

      if (mounted && response.isNotEmpty) {
        final data = response.first; // Chukua ya kwanza
        setState(() {
          business_name = data['business_name']?.toString() ?? '';
          sub_business_name = mySub;
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
          businessWhatsapp = data['whatsapp']?.toString() ?? '';
          businessLipaNumber = data['lipa_number']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('❌ Business Info Error: $e');
    }
  }




  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 50,
        // 1. Hii inalazimisha icon ya kurudi iwe nyeupe
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // 2. Inazuia mfumo usitengeneze button nyingine ya ziada
        automaticallyImplyLeading: false,

        title: const Text(
          "OTHER PRODUCTS",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, letterSpacing: 1.2, fontSize: 16),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple, lightViolet],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (business_name.isNotEmpty) _buildBusinessHeader(isDark ? primaryPurple : deepPurple),
                const SizedBox(height: 10),
                // ✅ Onyesha jina la mtumiaji na tawi analofanyia kazi sasa
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Hi, ${widget.user['full_name'].split(' ')[0]}!',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : primaryPurple)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        sub_business_name.isEmpty ? "MAIN STORE" : "BRANCH: ${sub_business_name.toUpperCase()}",
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CartScreen(user: widget.user))),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Pending Bill', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.medication, size: 18),
                      label: const Text("GO TO DASHBOARD", style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 45,
                  child: TextField(
                    controller: searchController,
                    style: TextStyle(color: textCol, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search Products...',
                      hintStyle: TextStyle(color: subTextCol, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: primaryPurple, size: 20),
                      filled: true,
                      fillColor: cardColor,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            color: isDark ? primaryPurple : deepPurple,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('PRODUCT / BRANCH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 1, child: Text('PRICE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 1, child: Text('REMAIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text('ACTION', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: filteredOtherProducts.isEmpty
                ? Center(child: Text('No products found.', style: TextStyle(color: subTextCol)))
                : ListView.builder(
              itemCount: filteredOtherProducts.length,
              itemBuilder: (context, index) {
                final product = filteredOtherProducts[index];
                final int prodId = product['id'];

                // INVENTORY CALCULATIONS
                final int totalQuantity = _parseToInt(product['total_quantity']);
                final int remainingQuantity = _parseToInt(product['remaining_quantity']);
                final int soldQuantity = totalQuantity - remainingQuantity;
                final int quantityToSelect = quantities[prodId] ?? 1;

                // ✅ LOGIC YA TAWI LA BIDHAA (BRANCH)
                String itemBranch = (product['sub_business_name'] == null || product['sub_business_name'] == "")
                    ? "Main Store"
                    : product['sub_business_name'];

                // EXPIRY CHECK LOGIC
                bool isExpired = false;
                if (product['expiry_date'] != null) {
                  try {
                    DateTime expiry = DateTime.parse(product['expiry_date']);
                    isExpired = expiry.isBefore(DateTime.now());
                  } catch (e) {}
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: index % 2 == 0 ? cardColor : (isDark ? const Color(0xFF161E2D) : const Color(0xFFF9F8FF)),
                    border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. PRODUCT NAME: Tumeondoa maxLines na overflow ili li-wrap lenyewe
                            Text(
                              product['name'] ?? '',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13, // Ukubwa ulioboreshwa kidogo
                                color: isExpired ? Colors.red : textCol,
                              ),
                              softWrap: true, // Inaruhusu neno kushuka chini likiwa refu
                            ),

                            // ✅ Onyesha Tawi hapa
                            Text(
                                itemBranch,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic
                                )
                            ),

                            const SizedBox(height: 4),

                            if (isExpired)
                              const Text(
                                  "!!! EXPIRED !!!",
                                  style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)
                              ),

                            // ✅ Maelezo ya Stocked na Sold (Ukubwa wa 10-11 ni bora zaidi kwa screen ndogo)
                            Wrap( // Tumetumia Wrap badala ya Row ili kuzuia kutoonekana kwenye screen ndogo sana
                              spacing: 8,
                              children: [
                                Text(
                                    "Stocked: $totalQuantity",
                                    style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)
                                ),
                                Text(
                                    "Sold: $soldQuantity",
                                    style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('${product['selling_price']}', style: TextStyle(fontSize: 11, color: isDark ? lightViolet : deepPurple, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          remainingQuantity > 0 ? '$remainingQuantity' : 'OUT',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: remainingQuantity > 0 ? Colors.green : Colors.red),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: isExpired ? null : () => _updateQuantity(prodId, remainingQuantity, -1),
                              child: Icon(Icons.remove_circle_outline, color: isExpired ? Colors.grey : Colors.red, size: 18),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Text('$quantityToSelect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isExpired ? Colors.grey : textCol)),
                            ),
                            GestureDetector(
                              onTap: (quantityToSelect < remainingQuantity && !isExpired) ? () => _updateQuantity(prodId, remainingQuantity, 1) : null,
                              child: Icon(Icons.add_circle_outline, color: (quantityToSelect < remainingQuantity && !isExpired) ? Colors.green : Colors.grey, size: 18),
                            ),
                            const SizedBox(width: 5),
                            if (remainingQuantity > 0)
                              GestureDetector(
                                onTap: isExpired ? null : () => _addToCart(product, quantityToSelect),
                                child: Icon(Icons.add_shopping_cart, color: isExpired ? Colors.grey : primaryPurple, size: 20),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 35),
    );
  }
  Widget _buildBusinessHeader(Color deepPurple) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
          )
        ],
      ),
      child: Row(
        children: [
          if (businessLogoPath.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                businessLogoPath,
                width: 35,
                height: 35,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.storefront, color: Colors.grey),
              ),
            )
          else
            const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFF1F5F9),
              child: Icon(Icons.storefront, size: 18, color: Color(0xFF673AB7)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business_name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                  ),
                ),
                Text(
                  businessLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
