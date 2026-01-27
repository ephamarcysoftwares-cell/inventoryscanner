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

class UniversalTerminalPage extends StatefulWidget {
  final Map<String, dynamic> user;

  const UniversalTerminalPage({super.key, required this.user});

  @override
  State<UniversalTerminalPage> createState() => _UniversalTerminalPageState();
}

class _UniversalTerminalPageState extends State<UniversalTerminalPage> with SingleTickerProviderStateMixin {
  // Database & Auth
  final SupabaseClient _supabase = Supabase.instance.client;

  // Scanner Controls
// Badilisha sehemu hii ya kodi yako:
  MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    formats: [BarcodeFormat.all],
    // Jaribu kuongeza hii kama simu inaruhusu zoom
    autoStart: true,
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
  late AnimationController _controller;
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
    // ANZISHA HAPA: Inachukua sekunde 2 kwenda na kurudi
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }
  void _initSpeech() async {
    await _speech.initialize();
  }

  @override
  void dispose() {
    // 1. Zima Scanner kwanza ili isipitishe picha mpya
    scannerController.dispose();

    // 2. Funga speech engine
    _speech.stop();

    // 3. Shughulikia Animation Controller kwa usalama
    // Hatutumii isAnimating hapa, tunapiga dispose moja kwa moja
    _controller.dispose();

    // 4. Mwisho kabisa piga super
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
    // 1. Zuia kuendelea mapema kuzuia "double scanning"
    if (!_isScanning || _isLoading) return;

    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // SITISHA SCANNER PAPO HAPO (Hardware na Software)
    setState(() {
      _isScanning = false;
      _isLoading = true;
      _statusMessage = "🔎 Inatafuta: $code";
    });

    try {
      // Zima kamera hardware ili kuzuia kelele za sensor
      await scannerController.stop();
      HapticFeedback.vibrate();

      Map<String, dynamic>? product;
      String sourceTable = '';

      // Search Logic - Inapita kwenye meza zako za Supabase (Medicines -> Other -> Services)
      product = await _supabase.from('medicines').select().eq('item_code', code).eq('business_id', _businessId).maybeSingle();

      if (product != null) {
        sourceTable = 'medicines';
      } else {
        product = await _supabase.from('other_product').select().eq('qr_code_url', code).eq('business_id', _businessId).maybeSingle();
        if (product != null) {
          sourceTable = 'other_product';
        } else {
          product = await _supabase.from('services').select().eq('item_code', code).eq('business_id', _businessId).maybeSingle();
          if (product != null) sourceTable = 'services';
        }
      }

      if (product != null) {
        // 1. IKIWA IMEPATIKANA
        _speak("PRODUCT DETECTED");
        if (mounted) _showDecisionHub(product, sourceTable);
      } else {
        // 2. IKIWA HAIJAPATIKANA (Sauti na Ujumbe)
        _speak("Product not available");
        _handleError("Bidhaa '$code' haipo!");

        // Subiri kidogo kisha washa scanner tena
        await Future.delayed(const Duration(seconds: 2));
        _resumeScanner();
      }
    } catch (e) {
      // 3. IKIWA KUNA HITILAFU (Mfano: Mtandao)
      _speak(" error detected please try again");
      _handleError("Tatizo la kiufundi!");
      _resumeScanner();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. DECISION HUB (BOTTOM SHEET)
  void _showDecisionHub(Map<String, dynamic> item, String table) {
    // 1. Kutayarisha data (Handle majina tofauti ya column kwenye meza 3)
    String name = item['name'] ?? item['medicine_name'] ?? item['service_name'] ?? 'Unknown Item';

    // Kutumia num kuzuia error ya int/double kwenye stock
    num stockNum = num.tryParse(item['remaining_quantity']?.toString() ?? '0') ?? 0;

    double price = double.tryParse((item['selling_price'] ?? item['price'] ?? 0).toString()) ?? 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle ya kuvuta chini
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),

            Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("Ref: ${item['item_code'] ?? item['qr_code_url'] ?? 'N/A'}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoCard("PRICE", "${NumberFormat('#,###').format(price)} TSH", Colors.green),
                _infoCard("STOCK", "$stockNum", Colors.blue),
              ],
            ),

            const Divider(height: 40),

            // --- ACTION BUTTONS ---

            // 1. SELL BUTTON
            _actionButton(
              title: "SELL / ADD TO CART",
              subtitle: "Piga mauzo ya bidhaa hii",
              icon: Icons.shopping_cart_checkout,
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _showSellDialog(item, table);
              },
            ),

            const SizedBox(height: 15),

            // 2. RESTOCK BUTTON (Kwa Admin Tu)
            if (widget.user['role'] == 'admin')
              _actionButton(
                title: "RESTOCK INVENTORY",
                subtitle: "Ongeza mzigo mpya stoo",
                icon: Icons.add_business,
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showRestockDialog(item, table);
                },
              ),

            const SizedBox(height: 15),

            // 3. DETAILS VIEW (HAPA NDIPO PAMEBADILIKA)
            _actionButton(
              title: "PRODUCT DETAILS",
              subtitle: "Historia ya mauzo & logs kwa tarehe",
              icon: Icons.analytics_outlined,
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                // REKEBISHO: Tunapitisha 'item' NA 'table' (arguments mbili)
                _showDetailsView(item, table);
              },
            ),

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
  Widget _detailRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const Spacer(),
          Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black87)
          ),
        ],
      ),
    );
  }
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
  // --------------------------------------------------------------------------
// RESTOCK DIALOG - KUONGEZA STOCK KWENYE MEZA ZOTE
// --------------------------------------------------------------------------
  void _showRestockDialog(Map<String, dynamic> item, String table) {
    final TextEditingController restockC = TextEditingController();

    // Kutambua jina kulingana na meza
    String itemName = item['name'] ?? item['medicine_name'] ?? item['service_name'] ?? 'Item';

    // Kupata stock ya sasa (Handle int na double)
    num currentStock = num.tryParse(item['remaining_quantity']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_business, color: Colors.orange),
            const SizedBox(width: 10),
            const Text("Restock Inventory"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bidhaa: $itemName", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Stock iliyopo:"),
                  Text("$currentStock", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: restockC,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                  labelText: "Ongeza Idadi Mpya",
                  hintText: "0.00",
                  prefixIcon: const Icon(Icons.exposure_plus_1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true,
                  fillColor: Colors.orange.withOpacity(0.05)
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "* Hii itaongeza idadi uliyoandika kwenye stock iliyopo sasa.",
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("GHAIRI", style: TextStyle(color: Colors.red))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () async {
              // Tunatumia double kwa sababu 'other_product' inaruhusu numeric
              double add = double.tryParse(restockC.text) ?? 0;
              if (add > 0) {
                Navigator.pop(context);
                await _executeRestock(item, add, table);
              } else {
                _showNotification("Tafadhali ingiza idadi sahihi!", Colors.red);
              }
            },
            child: const Text("UPDATE STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    ).then((_) => _resumeScanner());
  }

  // DETAILS VIEW
  void _showDetailsView(Map<String, dynamic> item, String sourceTable) {
    final String itemName = item['name'] ?? item['medicine_name'] ?? item['service_name'] ?? 'N/A';
    final int bId = widget.user['business_id'] ?? 0;

    // State ya tarehe (Default: Mwanzo wa mwezi hadi leo)
    DateTime startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime endDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          title: Column(
            children: [
              Text(itemName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _summarySmallCard("STOCK", "${item['remaining_quantity'] ?? 0}", Colors.blue),
                  const SizedBox(width: 10),
                  _summarySmallCard("PRICE", "${NumberFormat('#,###').format(item['selling_price'] ?? item['price'] ?? 0)}", Colors.green),
                ],
              ),
              const Divider(height: 25),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.98,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                // --- DATE PICKERS ---
                Row(
                  children: [
                    Expanded(
                      child: _dateBox("Kuanzia", startDate, () async {
                        final p = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                        if (p != null) setDState(() => startDate = p);
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dateBox("Hadi", endDate, () async {
                        final p = await showDatePicker(context: context, initialDate: endDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                        if (p != null) setDState(() => endDate = p);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // --- MAIN LIST ---
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchAllActivity(itemName, sourceTable, bId, startDate, endDate),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(child: Text("Hakuna kumbukumbu kipindi hiki."));
                      }

                      // Hesabu za Muhtasari
                      double totalSoldMoney = 0;
                      int totalSoldQty = 0;
                      int totalRestockQty = 0;

                      for (var row in snapshot.data!) {
                        if (row['type'] == 'OUT') {
                          totalSoldMoney += (row['amount'] ?? 0);
                          totalSoldQty += (int.tryParse(row['display_qty'].toString()) ?? 0);
                        } else {
                          totalRestockQty += (int.tryParse(row['display_qty'].toString()) ?? 0);
                        }
                      }

                      return Column(
                        children: [
                          _periodSummary(totalSoldMoney, totalSoldQty, totalRestockQty),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: snapshot.data!.length,
                              itemBuilder: (context, index) {
                                final act = snapshot.data![index];
                                bool isIN = act['type'] == 'IN';

                                return Card(
                                  elevation: 0.5,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: isIN ? Colors.blue.withOpacity(0.02) : Colors.red.withOpacity(0.02),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(color: isIN ? Colors.blue.withOpacity(0.1) : Colors.red.withOpacity(0.1))
                                  ),
                                  child: ExpansionTile(
                                    tilePadding: const EdgeInsets.symmetric(horizontal: 10),
                                    childrenPadding: const EdgeInsets.all(12),
                                    dense: true,
                                    // --- ICON YA KUSHOTO ---
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: isIN ? Colors.blue : Colors.red,
                                      child: Icon(
                                          isIN ? Icons.arrow_downward : Icons.arrow_upward,
                                          size: 16,
                                          color: Colors.white
                                      ),
                                    ),
                                    // --- KICHWA: IMEONGEZEKA AU IMEUZWA ---
                                    title: Text(
                                        isIN ? "IMEONGEZEKA: +${act['display_qty']}" : "IMEUZWA: -${act['display_qty']}",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isIN ? Colors.blue.shade800 : Colors.red.shade800
                                        )
                                    ),
                                    // --- MAELEZO YA NANI NA LINI ---
                                    subtitle: Text(
                                      "${DateFormat('dd MMM, HH:mm').format(DateTime.parse(act['display_date']))} | Aliyefanya: ${act['display_user']}",
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    // --- UPANDE WA KULIA: STOCK ILIYOBAKI ---
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          "Stock: ${act['remaining_quantity'] ?? '0'}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                              fontSize: 14
                                          ),
                                        ),
                                        const Text("Pcs Ilibaki", style: TextStyle(fontSize: 8, color: Colors.grey)),
                                      ],
                                    ),
                                    // --- MAELEZO YA NDANI YANAYOFUNGUKA ---
                                    children: [
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      if (isIN) ...[
                                        _detailRow(Icons.info_outline, "Sababu", act['display_title']),
                                        _detailRow(Icons.pin, "Batch No", act['batch_number'] ?? 'N/A'),
                                        _detailRow(Icons.event_busy, "Expiry Date", act['expiry_date'] ?? 'N/A'),
                                        _detailRow(Icons.factory, "Kampuni", act['company'] ?? 'N/A'),
                                      ] else ...[
                                        _detailRow(Icons.receipt, "Riziti Na.", act['receipt_number'] ?? 'N/A'),
                                        _detailRow(Icons.person, "Mteja", act['customer_name'] ?? 'Cash Customer'),
                                        _detailRow(Icons.payments, "Malipo", act['payment_method'] ?? 'Cash'),
                                        _detailRow(Icons.sell, "Bei ya Unit", "${NumberFormat('#,###').format(act['sell_price'] ?? act['selling_price'] ?? 0)} /-"),
                                        _detailRow(Icons.account_balance_wallet, "Jumla",
                                            "${NumberFormat('#,###').format(act['amount'] ?? 0)} /-",
                                            color: Colors.green),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    ).then((_) => _resumeScanner());
  }

// --- HELPER WIDGETS ---

  Widget _dateBox(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _periodSummary(double money, int sold, int restock) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem("Sold", "$sold", Colors.red),
          _statItem("Added", "$restock", Colors.blue),
          _statItem("Revenue", "${NumberFormat('#,###').format(money)}/-", Colors.green),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }



// --- WIDGET YA MUHTASARI WA CHINI YA TAREHE ---




  Widget _summarySmallCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

// --- HELPER WIDGET KWA AJILI YA DATE BOX ---


// --- LOGIC YA KUCHUJA DATA KWENYE MEZA ZOTE ---
  Future<List<Map<String, dynamic>>> _fetchAllActivity(
      String name, String source, int bId, DateTime start, DateTime end) async {

    String logTable = '';
    String logNameCol = 'name';

    // 1. TAREHE: Hakikisha inachukua siku nzima
    final String startDateStr = DateTime(start.year, start.month, start.day, 0, 0, 0).toIso8601String();
    final String endDateStr = DateTime(end.year, end.month, end.day, 23, 59, 59).toIso8601String();

    // 2. TAMBUA MEZA
    if (source == 'NORMAL PRODUCT' || source == 'MEDICINE') {
      logTable = 'medical_logs';
      logNameCol = 'medicine_name';
    } else if (source == 'OTHER_PRODUCT') {
      logTable = 'other_product_logs';
      logNameCol = 'name';
    } else if (source == 'SERVICES') {
      logTable = 'services_logs';
      logNameCol = 'service_name';
    }

    // --- DEBUG START ---
    debugPrint("🔍 DEBUG FETCH: Table=$logTable, NameCol=$logNameCol, ItemName=$name, BID=$bId");
    debugPrint("📅 RANGE: $startDateStr TO $endDateStr");
    // --- DEBUG END ---

    try {
      // 3. VUTA LOGS (STOCK IN)
      final logRes = await _supabase
          .from(logTable)
          .select()
          .eq(logNameCol, name)
          .eq('business_id', bId)
          .gte('date_added', startDateStr)
          .lte('date_added', endDateStr);

      debugPrint("📥 LOGS FOUND: ${logRes.length} records");

      // 4. VUTA SALES (STOCK OUT)
      final saleRes = await _supabase
          .from('sales')
          .select()
          .eq('medicine_name', name)
          .eq('business_id', bId)
          .gte('created_at', startDateStr)
          .lte('created_at', endDateStr);

      debugPrint("📤 SALES FOUND: ${saleRes.length} records");

      List<Map<String, dynamic>> combined = [];

      // Jaza Logs
      for (var item in logRes) {
        combined.add({
          ...item,
          'type': 'IN',
          'display_date': item['date_added'] ?? item['created_at'] ?? DateTime.now().toIso8601String(),
          'display_title': item['action'] ?? 'Mzigo Mpya',
          'display_qty': item['total_quantity'] ?? 0,
          'display_user': item['added_by'] ?? 'Staff',
        });
      }

      // Jaza Sales
      for (var item in saleRes) {
        combined.add({
          ...item,
          'type': 'OUT',
          'display_date': item['created_at'],
          'display_title': 'Mauzo: Riziti ${item['receipt_number'] ?? 'N/A'}',
          'display_qty': item['total_quantity'] ?? 0,
          'display_user': item['confirmed_by'] ?? item['full_name'] ?? 'Staff',
          'amount': item['total_price'],
        });
      }

      // 5. PANGA KWA TAREHE
      combined.sort((a, b) {
        DateTime dtA = DateTime.tryParse(a['display_date'].toString()) ?? DateTime.now();
        DateTime dtB = DateTime.tryParse(b['display_date'].toString()) ?? DateTime.now();
        return dtB.compareTo(dtA);
      });

      debugPrint("✅ TOTAL COMBINED: ${combined.length} activities");
      return combined;

    } catch (e, stack) {
      debugPrint("❌ FETCH ERROR: $e");
      debugPrint("📜 STACK: $stack");
      return [];
    }
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
        _showNotification("Added Successful to Pending bill!", Colors.green);

        // HAPA: App inaongea jina la bidhaa na kuthibitisha
        String itemName = item['name'] ?? item['service_name'] ?? 'Bidhaa';
        _speak("Congratulation! $itemName,   Added Successful to Pending bill!");

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

  // --------------------------------------------------------------------------
// EXECUTE RESTOCK - INAFANYA UPDATE NA KUWEKA REKODI KWENYE LOGS
// --------------------------------------------------------------------------
  Future<void> _executeRestock(Map<String, dynamic> item, double add, String source) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Kulingana na schema yako, column ni 'name'
    final String itemName = item['name'] ?? 'Bidhaa';
    final dynamic itemId = item['id'];

    try {
      String mainTable = '';
      String logTable = '';
      Map<String, dynamic> updateData = {};
      Map<String, dynamic> logData = {};

      double currentQty = double.tryParse(item['remaining_quantity']?.toString() ?? '0') ?? 0;
      double newTotalQty = currentQty + add;

      // Tambua Business ID na Name (Personalization kulingana na data yako)
      final bId = widget.user['business_id'];
      final bName = widget.user['business_name'] ?? 'Arusha Online Store';

      if (source == 'NORMAL PRODUCT') {
        mainTable = 'medicines';
        logTable = 'medical_logs';
        updateData = {
          'remaining_quantity': newTotalQty.toInt(),
          'last_updated': DateTime.now().toIso8601String(),
        };
        logData = {
          'medicine_name': itemName,
          'total_quantity': add.toInt(),
          'remaining_quantity': newTotalQty,
          'action': 'Restock: Aliongeza bidhaa',
          'added_by': widget.user['username'] ?? 'Staff',
          'business_id': bId,
          'business_name': bName,
        };
      } else if (source == 'OTHER_PRODUCT') {
        mainTable = 'other_product';
        logTable = 'other_product_logs';
        updateData = {'remaining_quantity': newTotalQty};
        logData = {
          'name': itemName,
          'total_quantity': add,
          'remaining_quantity': newTotalQty,
          'action': 'Restock: Aliongeza bidhaa',
          'added_by': widget.user['username'] ?? 'Staff',
          'business_id': bId,
          'business_name': bName,
        };
      } else if (source == 'SERVICES') {
        mainTable = 'services';
        logTable = 'services_logs';
        updateData = {'remaining_quantity': newTotalQty.toInt()};
        logData = {
          'service_name': itemName,
          'total_quantity': add.toInt(),
          'action': 'Restock: Aliongeza huduma',
          'added_by': widget.user['username'] ?? 'Staff',
          'business_id': bId,
          // Kumbuka: services_logs haina business_name kwenye schema yako
        };
      }

      // 1. UPDATE (Hapa ndipo PATCH method inatumika)
      // Kama bado unapata PATCH error, maana yake Hatua ya 1 (SQL) haijafanikiwa
      await _supabase.from(mainTable).update(updateData).eq('id', itemId);

      // 2. INSERT LOG
      await _supabase.from(logTable).insert(logData);

      _showNotification("Stock ya $itemName imesasishwa!", Colors.green);
      _speak("Tayari, mzigo mpya wa $itemName umeingizwa. Jumla sasa ni ${newTotalQty.toInt()}");

    } catch (e) {
      debugPrint("❌ ERROR: $e");
      _showNotification("Imeshindwa: Hakikisha Database imefunguliwa (RLS)", Colors.red);
      _speak("Samahani, kumeshindwa kusasisha stock.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _resumeScanner();
    }
  }
  // 6. HELPER METHODS
  void _resumeScanner() async {
    if (!mounted) return;

    setState(() {
      _statusMessage = "Ready to scan...";
      _statusColor = Colors.white70;
      _isScanning = true;
    });

    // Washa hardware ya kamera upya
    try {
      await scannerController.start();
    } catch (e) {
      debugPrint("Error starting scanner: $e");
    }
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
  @override
  Widget build(BuildContext context) {
    // Vipimo vya box letu la kulenga (Scanner Window)
    final double windowWidth = 280.0;
    final double windowHeight = 180.0;

    // Hii inatengeneza eneo ambalo kamera itasoma pekee
    final Rect scanWindow = Rect.fromCenter(
      center: Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      ),
      width: windowWidth,
      height: windowHeight,
    );

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // 1. LAYER YA CHINI: KAMERA
          Positioned.fill(
            child:MobileScanner(
              controller: scannerController,
              // scanWindow: scanWindow, // IWEKE COMMENT HII MSTARI
              onDetect: (capture) {
                // Hapa weka print ya haraka kuona kama inajibu
                print("!!! NIMESCAN KITU: ${capture.barcodes.first.rawValue}");
                _onDetect(capture);
              },
            ),
          ),

          // 2. LAYER YA KATIKATI: GIZA NA TUNDU (OVERLAY)
          Positioned.fill(
            child: CustomPaint(
              painter: ScannerOverlayPainter(
                windowWidth: windowWidth,
                windowHeight: windowHeight,
              ),
            ),
          ),

          // 3. LAYER YA JUU: KONA ZA KIJANI NA MSTARI UNAOTEMBEA
          Align(
            alignment: Alignment.center,
            child: CustomPaint(
              foregroundPainter: ScannerBorderPainter(),
              child: SizedBox(
                width: windowWidth,
                height: windowHeight,
                // Mstari mwekundu wa laser
                child: Center(child: _buildScannerLine(windowWidth)),
              ),
            ),
          ),

          // 4. STATUS MESSAGE (Inakaa juu kidogo ya box)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.3,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ),

          // TOP ACTION BAR (Branding yako)
          _buildTopBar(),

          // BOTTOM CART VIEW
          _buildBottomCartView(),
        ],
      ),
    );
  }

// Mstari unaocheza (Laser)
  Widget _buildScannerLine(double width) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -80 + (160 * _controller.value)),
          child: Container(
            width: width - 20,
            height: 2,
            decoration: BoxDecoration(
              color: Colors.redAccent,
              boxShadow: [
                BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
              ],
            ),
          ),
        );
      },
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


}
// --- CLASS YA KUTOBOLA TUNDU KWENYE GIZA ---
class ScannerOverlayPainter extends CustomPainter {
  final double windowWidth;
  final double windowHeight;

  ScannerOverlayPainter({required this.windowWidth, required this.windowHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.7);

    final scanWindowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: windowWidth,
      height: windowHeight,
    );

    // Mbinu ya kutoboa tundu: Background minus Shimo
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
      Path()..addRRect(RRect.fromRectAndRadius(scanWindowRect, const Radius.circular(15))),
    );

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(ScannerOverlayPainter oldDelegate) => false;
}

// --- CLASS YA KUCHORA KONA ZA KIJANI ---
class ScannerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final double c = 25; // urefu wa kila kona
    final path = Path();

    // Juu Kushoto
    path.moveTo(0, c); path.lineTo(0, 0); path.lineTo(c, 0);
    // Juu Kulia
    path.moveTo(size.width - c, 0); path.lineTo(size.width, 0); path.lineTo(size.width, c);
    // Chini Kushoto
    path.moveTo(0, size.height - c); path.lineTo(0, size.height); path.lineTo(c, size.height);
    // Chini Kulia
    path.moveTo(size.width - c, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, size.height - c);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}