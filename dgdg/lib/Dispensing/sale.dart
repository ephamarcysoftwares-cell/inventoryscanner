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
import 'SaleOtherproduct.dart';
import 'cart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SaleScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const SaleScreen({super.key, required this.user});

  @override
  _SaleScreenState createState() => _SaleScreenState();
}

class _SaleScreenState extends State<SaleScreen> {
  List<Map<String, dynamic>> allMedicines = [];
  List<Map<String, dynamic>> filteredMedicines = [];
  TextEditingController searchController = TextEditingController();
  Map<int, int> quantities = {};
  Map<int, TextEditingController> quantityControllers = {};
  Timer? _timer;

  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      String cleaned = value.trim();
      if (cleaned.isEmpty) return 0;
      int? directInt = int.tryParse(cleaned);
      if (directInt != null) return directInt;
      double? doubleVal = double.tryParse(cleaned);
      return doubleVal?.toInt() ?? 0;
    }
    return 0;
  }

  String business_name = '';
  int? _currentUserBusinessId;
  String sub_business_name = '';
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
    loadMedicines();
    getBusinessInfo();
    searchController.addListener(_filterMedicines);

    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      loadMedicines();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _timer?.cancel();
    quantityControllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  void loadMedicines() async {
    List<Map<String, dynamic>> data = await fetchMedicines();
    if (!mounted) return;

    setState(() {
      allMedicines = data;
      if (searchController.text.isEmpty) {
        filteredMedicines = allMedicines;
      } else {
        _filterMedicines();
      }

      for (var med in allMedicines) {
        final int id = med['id'];
        quantities[id] = quantities[id] ?? 1;
        if (!quantityControllers.containsKey(id)) {
          quantityControllers[id] = TextEditingController(text: quantities[id].toString());
        } else {
          String newText = quantities[id].toString();
          if (quantityControllers[id]?.text != newText) {
            quantityControllers[id]?.text = newText;
          }
        }
      }
    });
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<List<Map<String, dynamic>>> fetchMedicines() async {
    try {
      debugPrint("🔍 [FETCH] Inaanza kutafuta bidhaa...");

      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📡 [ERROR] Hakuna intaneti.");
        return [];
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        debugPrint("👤 [ERROR] Mtumiaji hayupo.");
        return [];
      }

      // 1. Pata business_id na tawi la mtumiaji
      final userProfile = await supabase
          .from('users')
          .select('business_id, sub_business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null || userProfile['business_id'] == null) {
        debugPrint("⚠️ [WARNING] Profile haijapatikana.");
        return [];
      }

      final int myBusinessId = userProfile['business_id'];
      // Tunatumia .trim() kuondoa nafasi zilizoachwa bahati mbaya
      final String mySubBusiness = (userProfile['sub_business_name'] ?? "").toString().trim();

      debugPrint("🏢 [INFO] Business ID: $myBusinessId | Tawi: ${mySubBusiness.isEmpty ? 'MAIN STORE' : mySubBusiness}");

      // 2. Query ya Msingi (Lazima Business ID ifanane)
      var query = supabase.from('medicines').select().eq('business_id', myBusinessId);

      // 3. LOGIC YA VIZUIZI (Main Store vs Branch)
      // Kama tawi ni tupu au limeandikwa "MAIN BRANCH" au "MAIN STORE"
      if (mySubBusiness.isEmpty ||
          mySubBusiness.toUpperCase() == "MAIN STORE" ||
          mySubBusiness.toUpperCase() == "MAIN BRANCH") {

        debugPrint("🏬 [QUERY] Inatafuta bidhaa za Duka Kuu...");
        // Inatafuta ambapo sub_business ni NULL, TUPU, au neno MAIN STORE
        query = query.or('sub_business_name.is.null, sub_business_name.eq."", sub_business_name.ilike.main%');

      } else {
        debugPrint("📍 [QUERY] Inatafuta bidhaa za TAWI: $mySubBusiness");
        // .ilike inasaidia kupata hata kama herufi ni KUBWA au ndogo (Case-insensitive)
        query = query.ilike('sub_business_name', mySubBusiness);
      }

      final response = await query.order('name', ascending: true);

      if (response is List) {
        debugPrint("✅ [SUCCESS] Bidhaa ${response.length} zimepatikana.");
        return List<Map<String, dynamic>>.from(response);
      }

      return [];
    } catch (e) {
      debugPrint("❌ [CRITICAL ERROR]: $e");
      return [];
    }
  }

  void _filterMedicines() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredMedicines = allMedicines.where((medicine) {
        return medicine['name'].toLowerCase().contains(query);
      }).toList();
    });
  }

  void _updateQuantity(int medicineId, int available, int change) {
    setState(() {
      int currentQuantity = quantities[medicineId] ?? 1;
      int newQuantity = currentQuantity + change;
      if (newQuantity >= 1 && newQuantity <= available) {
        quantities[medicineId] = newQuantity;
        quantityControllers[medicineId]?.text = newQuantity.toString();
      }
    });
  }

  // --- NEW DISCOUNT LOGIC FOR ADMIN ---
// --- CORRECTED DISCOUNT DIALOG WITH WORKING CHECKBOX ---

  Future<void> _showDiscountDialog(Map<String, dynamic> medicine, int quantity) async {
    final bool isAdmin = widget.user['role']?.toString().toLowerCase() == 'admin';
    bool applyDiscount = false;
    TextEditingController discController = TextEditingController(text: "0");
    double originalPrice = (medicine['price'] ?? 0).toDouble();

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          double customDisc = double.tryParse(discController.text) ?? 0.0;
          bool isInvalid = customDisc > originalPrice;
          double finalPrice = isInvalid ? 0.0 : (originalPrice - customDisc);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Text("Add ${medicine['name']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Quantity: $quantity", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Original Price: $originalPrice TZS"),
                const SizedBox(height: 10),
                if (isAdmin) ...[
                  const Divider(),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Je Unataka uweke Punguzo? Tiki hapa",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    value: applyDiscount,
                    activeColor: const Color(0xFF673AB7),
                    onChanged: (bool? value) {
                      setDialogState(() {
                        applyDiscount = value ?? false;
                        if (!applyDiscount) discController.text = "0";
                      });
                    },
                  ),
                  if (applyDiscount) ...[
                    TextField(
                      controller: discController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: "Ingiza Kiasi Cha Punguzo",
                        border: const OutlineInputBorder(),
                        prefixText: "TZS ",
                        errorText: isInvalid ? "Punguzo limezidi bei!" : null,
                      ),
                      onChanged: (v) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Bei ya Mauzo: ${finalPrice.toStringAsFixed(2)} TZS",
                      style: TextStyle(
                          color: isInvalid ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 15
                      ),
                    ),
                  ],
                ] else ...[
                  const Text("Huna ruhusa ya kutoa punguzo.",
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CANCEL", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: isInvalid ? Colors.grey : const Color(0xFF673AB7)
                ),
                onPressed: isInvalid ? null : () async {
                  double discountValue = applyDiscount ? (double.tryParse(discController.text) ?? 0) : 0;

                  // 🔥 REKEBISHO HAPA:
                  // Tunahifadhi kwa kutumia jina la bidhaa: 'discount_${medicine['name']}'
                  // Ili iendane na kule kwenye _generateReceiptPdf
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setDouble('discount_${medicine['name']}', discountValue);

                  if (mounted) Navigator.pop(context);

                  _addToCart(
                      medicine,
                      quantity,
                      adminDiscount: discountValue > 0 ? discountValue : null
                  );
                },
                child: const Text("ADD TO CART", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }
  Future<void> _addToCart(Map<String, dynamic> medicine, int quantity, {double? adminDiscount}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final supabase = Supabase.instance.client;
    final String userId = widget.user['id'].toString();

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No internet connection.')));
        return;
      }

      // 1. Fetch current profile to get correct sub_business_name
      final userProfile = await supabase
          .from('users')
          .select('business_name, sub_business_name')
          .eq('id', userId)
          .maybeSingle();

      final String myBusiness = userProfile?['business_name'] ?? business_name;
      final String? mySubBusiness = userProfile?['sub_business_name'];

      // 2. Verify Stock and current Cloud Price
      final cloudData = await supabase
          .from('medicines')
          .select('remaining_quantity, price, discount')
          .eq('id', medicine['id'])
          .maybeSingle();

      if (cloudData == null) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found!')));
        return;
      }

      int currentStock = int.tryParse(cloudData['remaining_quantity'].toString()) ?? 0;
      if (quantity > currentStock) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Stock limited! Available: $currentStock')));
        return;
      }

      // 3. Price Calculation
      double basePrice = double.tryParse(cloudData['price']?.toString() ?? '0') ?? 0.0;
      double appliedDiscount = adminDiscount ?? (double.tryParse(cloudData['discount']?.toString() ?? '0') ?? 0.0);
      double finalSellingPrice = basePrice - appliedDiscount;
      if (finalSellingPrice < 0) finalSellingPrice = 0.0;

      // 4. PREPARE CART DATA WITH BRANCH INFO
// Ndani ya function ya _addToCart
      // Hakikisha bId imeshapatikana kutoka kwenye userProfile kwanza
      final int? bId = userProfile?['business_id'];

      final cartItem = {
        'user_id': userId,
        'medicine_id': medicine['id'],
        'medicine_name': medicine['name'],
        'company': medicine['company'] ?? 'N/A',
        'price': finalSellingPrice,
        'quantity': quantity,
        'unit': medicine['unit'] ?? 'Pcs',
        'source': 'NORMAL PRODUCT',
        'date_added': DateTime.now().toIso8601String(),

        // ✅ MABADILIKO MAKUU HAPA:
        'business_id': bId, // Sasa tunahifadhi ID ya biashara (mfano: 35)
        'business_name': myBusiness, // Tunabaki nayo kwa ajili ya kuonyesha kwenye risiti haraka

        // ✅ LOGIC YA SEHEMU ALIPO (MAIN AU BRANCH):
        'sub_business_name': mySubBusiness ?? '',
      };

      // 5. UPDATE STOCK
      await supabase.from('medicines').update({
        'remaining_quantity': currentStock - quantity
      }).eq('id', medicine['id']);

      // 6. INSERT TO CART
      await supabase.from('cart').insert(cartItem);

      if (mounted) {
        Navigator.pop(context); // Close loading

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${medicine['name']} added to ${mySubBusiness ?? "Main Branch"} Cart'),
              backgroundColor: Colors.green,
            )
        );

        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CartScreen(user: widget.user))
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("❌ Cart Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata business_id moja kwa moja kutoka kwenye profile ya user
      final userProfile = await supabase
          .from('users')
          .select('business_id')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final int? bId = userProfile?['business_id'];
      if (bId == null) {
        debugPrint('⚠️ Onyo: Mtumiaji hana business_id iliyounganishwa!');
        return;
      }

      // 2. Vuta taarifa za biashara kwa kutumia ID (Hapa tunatumia ID 35 kama ulivyoelekeza)
      final response = await supabase
          .from('businesses')
          .select()
          .eq('id', bId)
          .maybeSingle();

      if (!mounted) return;

      if (response != null) {
        var data = response;

        // ✅ MANTIKI YA TAWI: Kama hii biashara ni tawi (is_main_business = false)
        // na ina parent_id, nenda kachukue Logo na Info za Duka Kuu lake.
        if (data['is_main_business'] == false && data['parent_id'] != null) {
          final parentData = await supabase
              .from('businesses')
              .select()
              .eq('id', data['parent_id'])
              .maybeSingle();

          if (parentData != null) {
            debugPrint("🔄 Tawi limepatikana, tunatumia Logo/Info za Duka Kuu.");
            data = parentData; // Tunatumia data za duka kuu kwa ajili ya risiti/muonekano
          }
        }

        setState(() {
          _currentUserBusinessId = bId; // Hakikisha ume-declare hii variable juu kwenye State
          business_name = data['business_name']?.toString() ?? '';
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
          businessWhatsapp = data['whatsapp']?.toString() ?? '';
          businessLipaNumber = data['lipa_number']?.toString() ?? '';
          // businessAddress = data['address']?.toString() ?? '';
        });

        debugPrint("✅ Data zimepakiwa kwa kutumia Business ID: $bId");
      }
    } catch (e) {
      if (mounted) debugPrint('❌ Supabase Fetch Error: $e');
    }
  }
  void _showProductDetails(BuildContext context, dynamic medicine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 15),
              Text(medicine['name'] ?? 'Product Info', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow("Price:", "${medicine['price'] ?? 0} TZS"),
              _detailRow("Remaining:", "${medicine['remaining_quantity'] ?? 0}"),
              _detailRow("Total Stock:", "${medicine['total_quantity'] ?? 0}"),
              _detailRow("Discount:", "${medicine['discount'] ?? 0}"),
              _detailRow("Expiry Date:", "${medicine['expiry_date'] ?? 'N/A'}"),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
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
        title: const Text("DISPENSING WINDOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300, fontSize: 18, letterSpacing: 1.2)),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple, lightViolet]),
          ),
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (business_name.isNotEmpty) _buildBusinessHeader(isDark ? primaryPurple : deepPurple),
            const SizedBox(height: 10),
            _buildSaleSection(context),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Hi, ${widget.user['full_name'].split(' ')[0]}!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : primaryPurple)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 45,
              child: TextField(
                controller: searchController,
                style: TextStyle(color: textCol, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search Product...',
                  hintStyle: TextStyle(color: subTextCol, fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: primaryPurple, size: 20),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: isDark ? primaryPurple : deepPurple, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Price', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Disc.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 1, child: Text('Remain', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                  Expanded(flex: 2, child: Text('Action', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filteredMedicines.length,
                itemBuilder: (context, index) {
                  final medicine = filteredMedicines[index];
                  int medId = medicine['id'];
                  int totalQuantity = medicine['total_quantity'] ?? 0;
                  int remainingQuantity = medicine['remaining_quantity'] ?? 0;
                  int soldQuantity = totalQuantity - remainingQuantity;
                  int quantityToSelect = quantities[medId] ?? 1;
                  double discVal = double.tryParse(medicine['discount']?.toString() ?? '0') ?? 0;

                  bool isExpired = false;
                  if (medicine['expiry_date'] != null) {
                    try {
                      DateTime expiry = DateTime.parse(medicine['expiry_date']);
                      isExpired = expiry.isBefore(DateTime.now());
                    } catch (e) {}
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? cardColor : (isDark ? const Color(0xFF161E2D) : const Color(0xFFF9F8FF)),
                      border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            // ✅ Inafungua maelezo zaidi ya bidhaa ikiguswa
                            onTap: () => _showProductDetails(context, medicine),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    medicine['name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isExpired ? Colors.red : textCol,
                                      decoration: TextDecoration.underline, // Inaonyesha kuwa inaweza kuguswa
                                      decorationColor: Colors.blue.withOpacity(0.3),
                                    )
                                ),
                                const SizedBox(height: 4),
                                if (isExpired) const Text("!!! EXPIRED !!!", style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold)),
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    Text("Stk: $totalQuantity", style: const TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    Text("Sold: $soldQuantity", style: const TextStyle(fontSize: 15, color: Colors.orange, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(flex: 1, child: Text('${medicine['price'] ?? 0}', style: TextStyle(fontSize: 11, color: isDark ? lightViolet : deepPurple, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('$discVal', style: TextStyle(fontSize: 11, color: discVal > 0 ? Colors.red : subTextCol, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text(remainingQuantity > 0 ? '$remainingQuantity' : 'OUT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: remainingQuantity > 0 ? Colors.green : Colors.red))),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(onTap: isExpired ? null : () => _updateQuantity(medId, remainingQuantity, -1), child: Icon(Icons.remove_circle_outline, color: isExpired ? Colors.grey : Colors.red, size: 18)),
                              Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('$quantityToSelect', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                              GestureDetector(onTap: (quantityToSelect < remainingQuantity && !isExpired) ? () => _updateQuantity(medId, remainingQuantity, 1) : null, child: Icon(Icons.add_circle_outline, color: (quantityToSelect < remainingQuantity && !isExpired) ? Colors.green : Colors.grey, size: 18)),
                              const SizedBox(width: 4),
                              if (remainingQuantity > 0)
                                GestureDetector(
                                  onTap: isExpired ? null : () => _showDiscountDialog(medicine, quantities[medId] ?? 1),
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
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 30),
    );
  }

  Widget _buildBusinessHeader(Color deepPurple) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
      child: Row(
        children: [
          if (businessLogoPath.isNotEmpty)
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(businessLogoPath, width: 35, height: 35, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.storefront, color: Colors.grey)))
          else
            const CircleAvatar(radius: 17, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.storefront, size: 18, color: Color(0xFF673AB7))),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(business_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: deepPurple)),
              Text(businessLocation, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleSection(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _compactActionButton(context, icon: Icons.shopping_basket, label: 'Other Sales', color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SaleOther(user: widget.user))))),
        const SizedBox(width: 8),
        Expanded(child: _compactActionButton(context, icon: Icons.medication, label: 'BACK', color: Colors.green, onTap: () => Navigator.pop(context))),
      ],
    );
  }

  Widget _compactActionButton(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)]),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))]),
      ),
    );
  }
}