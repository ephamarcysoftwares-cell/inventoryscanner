import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../Dispensing/cart.dart';
import 'package:flutter_tts/flutter_tts.dart';
// --------------------------------------------------------------------------
// UNIVERSAL TERMINAL PAGE - ALL IN ONE SCANNER (600+ LINES)
// --------------------------------------------------------------------------

class UniversalScannerPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UniversalScannerPage({super.key, required this.user});

  @override
  State<UniversalScannerPage> createState() => _UniversalScannerPageState();
}

class _UniversalScannerPageState extends State<UniversalScannerPage> with SingleTickerProviderStateMixin {
  // Database & Auth
  final SupabaseClient _supabase = Supabase.instance.client;

  // Scanner Controls
  MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  // UI State
  bool _isScanning = true;
  bool _isLoading = false;
  bool _isDarkMode = false;
  String _statusMessage = "Ready to scan...";
  Color _statusColor = Colors.white70;
  final stt.SpeechToText _speech = stt.SpeechToText(); // Inatengeneza engine ya sauti
  bool _isListening = false;                          // Inafuatilia kama mic ipo wazi
  String _lastWords = "";
  final FlutterTts _tts = FlutterTts();
  // Data State
  List<Map<String, dynamic>> _currentCartItems = [];
  double _totalCartAmount = 0.0;
  int _totalCartQty = 0;

  // Business Info from Widget.user
  late int _businessId;
  late String _businessName;
  late String _subBranch;
  late String _userRole;
  String? _businessLogo; // Variable ya Logo
  late String _staffName; // Variable ya Staff

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTheme();
    _subscribeToCart();
    _initSpeech();
  }
  void _initSpeech() async {
    await _speech.initialize();
  }
  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }
  void _initTTS() async {
    await _tts.setLanguage("sw-TZ"); // Inasema Kiswahili (au "en-US" kwa Kiingereza)
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5); // Kasi ya kuongea
  }
  // 1. INITIALIZATION & DATA SUBSCRIPTION
  void _initializeData() {
    _businessId = widget.user['business_id'] ?? 0;
    _businessName = widget.user['business_name'] ?? 'N/A';
    _subBranch = widget.user['sub_business_name'] ?? 'Main Branch';
    _userRole = (widget.user['role'] ?? 'staff').toString().toLowerCase();

    // LOGO: Inachukua URL kutoka kwenye column ya 'logo' ya table yako
    _businessLogo = widget.user['logo'];

    // STAFF: Inachukua username au jina la aliyelog-in
    _staffName = widget.user['username'] ?? widget.user['name'] ?? 'Staff';
  }
  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _subscribeToCart() {
    // Listen to cart changes in real-time
    _supabase
        .from('cart')
        .stream(primaryKey: ['id'])
        .eq('user_id', widget.user['id'])
        .listen((List<Map<String, dynamic>> data) {
      if (mounted) {
        setState(() {
          _currentCartItems = data;
          _calculateTotals();
        });
      }
    });
  }

  void _calculateTotals() {
    double total = 0;
    int qty = 0;
    for (var item in _currentCartItems) {
      total += (item['price'] ?? 0) * (item['quantity'] ?? 0);
      qty += (item['quantity'] as int);
    }
    _totalCartAmount = total;
    _totalCartQty = qty;
  }

  // 2. SCAN PROCESSING ENGINE
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isLoading) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isLoading = true;
      _statusMessage = "Inatafuta..."; // Ujumbe safi kwa mteja
      _statusColor = Colors.blueAccent;
    });

    HapticFeedback.mediumImpact();

    try {
      // Check Internet kwanza
      var connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        _handleError("Tafadhali washa data!");
        return;
      }

      Map<String, dynamic>? product;
      String sourceTable = '';

      // Tafuta kwenye meza zote (Sequential Search)
      product = await _supabase.from('medicines').select().eq('item_code', code).eq('business_id', _businessId).maybeSingle();
      if (product != null) {
        sourceTable = 'NORMAL PRODUCT';
      } else {
        product = await _supabase.from('other_product').select().eq('batch_number', code).eq('business_id', _businessId).maybeSingle();
        if (product != null) {
          sourceTable = 'OTHER_PRODUCT';
        } else {
          product = await _supabase.from('services').select().eq('item_code', code).eq('business_id', _businessId).maybeSingle();
          if (product != null) sourceTable = 'SERVICES';
        }
      }

      if (product != null) {
        if (mounted) _showDecisionHub(product, sourceTable);
      } else {
        _handleError("Bidhaa '$code' haipo!");
      }
    } catch (e) {
      // HAPA: Badala ya kutoa debug error, tunatoa ujumbe wa kijumla
      _handleError("Hitilafu ya mtandao!");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. DECISION HUB (BOTTOM SHEET)
  void _showDecisionHub(Map<String, dynamic> item, String table) {
    String name = item['name'] ?? item['service_name'] ?? 'Unknown Item';
    int stock = item['remaining_quantity'] ?? 0;
    double price = double.tryParse((item['selling_price'] ?? item['price'] ?? 0).toString()) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Ref: ${item['item_code'] ?? item['batch_number'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoCard("PRICE", "${NumberFormat('#,###').format(price)} TSH", Colors.green),
                _infoCard("STOCK", "$stock", Colors.blue),
              ],
            ),

            const Divider(height: 40),

            // ACTION BUTTONS
            _actionButton(
              title: "SELL / ADD TO CART",
              subtitle: "Create a new sale entry",
              icon: Icons.shopping_cart_checkout,
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showSellDialog(item, table);
              },
            ),

            if (_userRole == 'admin') ...[
              const SizedBox(height: 15),
              _actionButton(
                title: "RESTOCK INVENTORY",
                subtitle: "Add quantity to warehouse",
                icon: Icons.add_business,
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showRestockDialog(item, table);
                },
              ),
            ],

            const SizedBox(height: 15),
            // _actionButton(
            //   title: "PRODUCT DETAILS",
            //   subtitle: "Check expiry, company & units",
            //   icon: Icons.analytics_outlined,
            //   color: Colors.blue,
            //   onTap: () {
            //     Navigator.pop(context);
            //     _showDetailsView(item);
            //   },
            // ),

            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resumeScanner();
              },
              child: const Text("CLOSE & SCAN NEXT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
  void _listenToVoiceCommands(Map<String, dynamic> item, String source,
      TextEditingController qtyC, Function setDialogState, BuildContext dContext) async {

    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      setDialogState(() {});

      _speech.listen(
        onResult: (result) {
          setDialogState(() {
            _lastWords = result.recognizedWords.toLowerCase();

            // 1. KATAZA NA WEKA NAMBA (Mfano ukisema "Tano")
            RegExp regExp = RegExp(r'(\d+)');
            var match = regExp.firstMatch(_lastWords);
            if (match != null) {
              qtyC.text = match.group(0)!;
            }

            // 2. AMRI YA MOJA KWA MOJA (Ukisema "Weka", "Confirm", au "Tayari")
            if (_lastWords.contains("weka") ||
                _lastWords.contains("confirm") ||
                _lastWords.contains("tayari") ||
                _lastWords.contains("piga")) {

              _speech.stop();
              setState(() => _isListening = false);

              int q = int.tryParse(qtyC.text) ?? 1;
              int availableStock = item['remaining_quantity'] ?? 0;

              // Uthibitisho wa mwisho kabla ya ku-save
              if (q > 0 && (source == 'SERVICES' || q <= availableStock)) {
                Navigator.pop(dContext); // Funga Dialog
                _executeAddToCart(item, q, 0.0, source); // Save kwenye Cart
              }
            }
          });
        },
        listenFor: const Duration(seconds: 5), // Inasikiliza kwa sekunde 5
        pauseFor: const Duration(seconds: 3),  // Ikikaa kimya sekunde 3 inajizima
      );
    }
  }
  // 4. ACTION DIALOGS (SELL, RESTOCK, DETAILS)

  // SELL DIALOG
  void _showSellDialog(Map<String, dynamic> item, String table) {
    final TextEditingController qtyC = TextEditingController(text: "1");
    final TextEditingController discC = TextEditingController(text: "0");
    double basePrice = double.tryParse((item['selling_price'] ?? item['price'] ?? 0).toString()) ?? 0.0;
    int available = item['remaining_quantity'] ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (dContext, setDState) {
          int q = int.tryParse(qtyC.text) ?? 0;
          double d = double.tryParse(discC.text) ?? 0.0;
          double total = (basePrice - d) * q;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Sell ${item['name']}", textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (table != 'SERVICES')
                  Chip(label: Text("Stock: $available", style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),

                // Idadi Field
                TextField(
                  controller: qtyC,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Quantity", border: OutlineInputBorder()),
                  onChanged: (v) => setDState(() {}),
                ),

                const SizedBox(height: 20),

                // VOICE INTERFACE
                GestureDetector(
                  onTap: () => _listenToVoiceCommands(item, table, qtyC, setDState, dContext),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: _isListening ? Colors.red : Colors.blue.withOpacity(0.1),
                        child: Icon(_isListening ? Icons.graphic_eq : Icons.mic,
                            color: _isListening ? Colors.white : Colors.blue, size: 30),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? "Listening..." : "Tap to Speak (Qty/Weka)",
                        style: TextStyle(color: _isListening ? Colors.red : Colors.grey, fontSize: 12),
                      ),
                      if (_isListening)
                        Text("\"$_lastWords\"", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blue)),
                    ],
                  ),
                ),

                const Divider(height: 30),
                Text("Total: ${NumberFormat('#,###').format(total)} TSH",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            actions: [
              TextButton(onPressed: () {
                _speech.stop();
                setState(() => _isListening = false);
                Navigator.pop(context);
                _resumeScanner();
              }, child: const Text("CANCEL", style: TextStyle(color: Colors.red))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: (q > 0 && (table == 'SERVICES' || q <= available)) ? () async {
                  _speech.stop();
                  setState(() => _isListening = false);
                  Navigator.pop(context);
                  await _executeAddToCart(item, q, d, table);
                } : null,
                child: const Text("CONFIRM"),
              )
            ],
          );
        },
      ),
    );
  }

  // RESTOCK DIALOG
  void _showRestockDialog(Map<String, dynamic> item, String table) {
    final TextEditingController restockC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Restock Inventory"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Current Stock: ${item['remaining_quantity'] ?? 0}"),
            const SizedBox(height: 15),
            TextField(
              controller: restockC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "New Quantity to Add", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              int add = int.tryParse(restockC.text) ?? 0;
              if (add > 0) {
                Navigator.pop(context);
                await _executeRestock(item, add, table);
              }
            },
            child: const Text("UPDATE"),
          )
        ],
      ),
    ).then((_) => _resumeScanner());
  }

  // DETAILS VIEW
  void _showDetailsView(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item['name'] ?? 'Item Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Company", item['company']),
              _detailRow("Unit", item['unit']),
              _detailRow("Category", item['category_name']),
              _detailRow("Expiry Date", item['expiry_date']),
              _detailRow("Manufacturer", item['manufacturer']),
              _detailRow("Batch No", item['batch_number']),
              _detailRow("Item Code", item['item_code']),
              _detailRow("Location", item['location_shelf']),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      ),
    ).then((_) => _resumeScanner());
  }

  // 5. DATABASE EXECUTORS

  Future<void> _executeAddToCart(Map<String, dynamic> item, int q, double d, String source) async {
    if (mounted) setState(() => _isLoading = true);

    // 1. REKEBISHA JINA LA TABLE
    String tableName = source.toLowerCase().trim();

    if (tableName == 'normal product' || tableName == 'normal_product') {
      tableName = 'other_product';
    } else if (tableName == 'medicines') {
      tableName = 'medicines';
    } else if (tableName == 'services') {
      tableName = 'services';
    }

    debugPrint("🚀 TABLE ILIYOREKEBISHWA: $tableName");

    try {
      // 2. KAGUA NA PUNGUZA STOCK
      if (tableName != 'services') {
        int currentStock = int.tryParse(item['remaining_quantity'].toString()) ?? 0;

        if (currentStock < q) {
          _showNotification("Stock haitoshi!", Colors.orange);
          _speak("Samahani, stock haitoshi"); // Mrejesho wa sauti kama stock imekata
          return;
        }

        int newStock = currentStock - q;
        await _supabase.from(tableName).update({'remaining_quantity': newStock}).eq('id', item['id']);
        item['remaining_quantity'] = newStock;
      }

      // 3. INSERT KWENYE CART
      await _supabase.from('cart').insert({
        'medicine_id': item['id'],
        'medicine_name': item['name'] ?? item['service_name'] ?? 'Unknown',
        'price': (double.tryParse((item['selling_price'] ?? item['price'] ?? 0).toString()) ?? 0.0) - d,
        'quantity': q,
        'source': source.toUpperCase(),
        'business_id': _businessId,
        'user_id': widget.user['id'],
        'business_name': widget.user['business_name'],
        'date_added': DateTime.now().toIso8601String(),
      });

      // 4. MAFANIKIO: TOA NOTIFICATION NA SAUTI
      if (mounted) {
        _showNotification("Imewekwa kwenye cart!", Colors.green);

        // HAPA: App inaongea jina la bidhaa na kuthibitisha
        String itemName = item['name'] ?? item['service_name'] ?? 'Bidhaa';
        _speak("$itemName, imewekwa");

        HapticFeedback.lightImpact();
      }

    } catch (e) {
      debugPrint("🛑 ERROR MPYA: $e");
      if (mounted) {
        _showNotification("Imefeli! Jaribu tena.", Colors.red);
        _speak("Imefeli, jaribu tena"); // Mrejesho wa sauti kama kuna error ya mtandao
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _resumeScanner();
    }
  }

  Future<void> _executeRestock(Map<String, dynamic> item, int add, String table) async {
    setState(() => _isLoading = true);
    try {
      int newQty = (item['remaining_quantity'] as int) + add;
      await _supabase.from(table).update({'remaining_quantity': newQty}).eq('id', item['id']);
      _showNotification("Stock Updated Successfully!", Colors.blue);
    } catch (e) {
      _showNotification("Restock Error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
      _resumeScanner();
    }
  }

  // 6. HELPER METHODS
  void _resumeScanner() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
          _statusMessage = "Scanner Ready";
          _statusColor = Colors.white70;
        });
      }
    });
  }

  void _handleError(String msg) {
    setState(() {
      _statusMessage = msg;
      _statusColor = Colors.redAccent;
      _isLoading = false;
    });
    _showNotification(msg, Colors.red);
    Future.delayed(const Duration(seconds: 2), () => _resumeScanner());
  }

  void _showNotification(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  // 7. BUILD COMPONENTS

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // SCANNER LAYER
          Positioned.fill(
            child: MobileScanner(
              controller: scannerController,
              onDetect: _onDetect,
            ),
          ),

          // OVERLAY UI
          _buildScannerOverlay(),

          // CART LIST (BOTTOM DRAGGABLE)
          _buildBottomCartView(),

          // TOP ACTION BAR
          _buildTopBar(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Column(
      children: [
        const Spacer(),
        // Lengo la Scanner (Frame)
        Container(
          width: 250, height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: _statusColor, width: 2),
            borderRadius: BorderRadius.circular(30),
          ),
          child: _isLoading ? const Center(child: CircularProgressIndicator(color: Colors.white)) : null,
        ),
        const SizedBox(height: 25),

        // Status Message & Retry Button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withOpacity(0.3))
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_statusMessage, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),

                  // KITUFE CHA RETRY: Kinatokea tu kama scanner imezima au kuna error
                  if (!_isScanning && !_isLoading) ...[
                    const SizedBox(width: 15),
                    GestureDetector(
                      onTap: _resumeScanner,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.refresh, size: 16, color: Colors.black),
                            SizedBox(width: 4),
                            Text("RETRY", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const Spacer(flex: 2),
      ],
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 40, left: 20, right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black38),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => scannerController.toggleTorch(),
                icon: const Icon(Icons.flash_on, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () => scannerController.switchCamera(),
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black38),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBottomCartView() {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)],
        ),
        child: ListView(
          controller: scrollController,
          children: [
            Center(child: Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Current Cart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("$_totalCartQty Items added", style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Text("${NumberFormat('#,###').format(_totalCartAmount)} TSH", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
            if (_currentCartItems.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No items scanned yet.", style: TextStyle(color: Colors.grey))))
            else
              ..._currentCartItems.map((item) => _cartTile(item)).toList(),

            if (_currentCartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentCartItems.isEmpty) {
                      _showNotification("Cart is empty!", Colors.orange);
                      return;
                    }

                    // Navigate kwenda CartScreen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CartScreen(
                          user: widget.user, // Pitisha taarifa za biashara/user
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.payments_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        "PROCEED TO CHECKOUT",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
  Widget _buildBusinessHeader() {
    return Positioned(
      top: 50,
      left: 20,
      right: 80, // Inatoa nafasi kwa vitufe vya flash upande wa kulia
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7), // Background nzito ili maandishi yaonekana vizuri
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Row(
          children: [
            // 1. BUSINESS LOGO
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white38, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: _businessLogo != null
                    ? Image.network(
                  _businessLogo!,
                  width: 45, height: 45,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.store, color: Colors.white, size: 25),
                )
                    : const Icon(Icons.store, color: Colors.white, size: 25),
              ),
            ),
            const SizedBox(width: 12),

            // 2. TAARIFA ZA BIASHARA NA STAFF
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Jina la Biashara (mf: ONLINE STORE)
                  Text(
                    _businessName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Jina la Staff aliyelog-in
                  Row(
                    children: [
                      const Icon(Icons.person_outline, color: Colors.greenAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        "Staff: ${widget.user['username'] ?? widget.user['name'] ?? 'Admin'}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  // Tawi
                  Text(
                    _subBranch,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _cartTile(Map<String, dynamic> item) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF005696).withOpacity(0.1),
        child: const Icon(Icons.inventory_2, size: 18, color: Color(0xFF005696)),
      ),
      title: Text(
        item['medicine_name'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        "${item['quantity']} x ${NumberFormat('#,###').format(item['price'])} TSH",
        style: const TextStyle(fontSize: 13),
      ),
      // HAPA NIMEONDOA DELETE ICON NA KUWEKA TSH TOTAL YA MSTARI
      trailing: Text(
        "${NumberFormat('#,###').format((item['price'] ?? 0) * (item['quantity'] ?? 0))}",
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  // WIDGET HELPERS
  Widget _infoCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 15, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value.toString(), style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}