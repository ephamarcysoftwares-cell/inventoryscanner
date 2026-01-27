import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FullScannerPage extends StatefulWidget {
  const FullScannerPage({super.key});

  @override
  State<FullScannerPage> createState() => _FullScannerPageState();
}

class _FullScannerPageState extends State<FullScannerPage> {
  bool _isScanning = true;
  int? _currentUserBusinessId;
  String? businessName;
  String? _currentTable; // Itatunza: 'medicines', 'other_product', au 'services'
  Map<String, dynamic>? _scannedItem;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
  }

  // 1. PATA TAARIFA ZA BIASHARA
  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase.from('users').select('business_id').eq('id', user.id).maybeSingle();
      if (userProfile != null) {
        final bId = userProfile['business_id'];
        setState(() => _currentUserBusinessId = bId);

        final response = await supabase.from('businesses').select().eq('id', bId).maybeSingle();
        if (mounted && response != null) {
          setState(() => businessName = response['business_name']?.toString());
        }
      }
    } catch (e) {
      debugPrint('Error fetching business: $e');
    }
  }

  // 2. KUSHUGHULIKIA BARCODE (Tafuta kote: Medicines -> Other Product -> Services)
  Future<void> _handleBarcodeDetection(String code) async {
    // 1. Ulinzi wa awali: Zuia scan kama bado inafanya kazi au biashara haijatambuliwa
    if (!_isScanning || _currentUserBusinessId == null) return;

    setState(() {
      _isScanning = false;
      // Unaweza kuongeza variable ya _isLoading kuonyesha circular progress kwenye UI
    });

    // Mtetemo wa kumjulisha staff kuwa scan imefanikiwa
    HapticFeedback.mediumImpact();

    final supabase = Supabase.instance.client;
    final int bId = _currentUserBusinessId!;
    final String trimmedCode = code.trim();

    try {
      // A. TAFUTA KWENYE MEDICINES
      // Tunatumia maybeSingle kuzuia crash kama hakuna data
      final medData = await supabase
          .from('medicines')
          .select()
          .eq('item_code', trimmedCode)
          .eq('business_id', bId)
          .maybeSingle();

      if (medData != null) {
        if (mounted) {
          setState(() {
            _scannedItem = medData;
            _currentTable = 'medicines';
          });
          _showFullDetailsModal();
        }
        return;
      }

      // B. TAFUTA KWENYE OTHER PRODUCT (Kama medicines haipo)
      final otherData = await supabase
          .from('other_product')
          .select()
          .eq('batch_number', trimmedCode)
          .eq('business_id', bId)
          .maybeSingle();

      if (otherData != null) {
        if (mounted) {
          setState(() {
            _scannedItem = otherData;
            _currentTable = 'other_product';
          });
          _showFullDetailsModal();
        }
        return;
      }

      // C. TAFUTA KWENYE SERVICES
      // Nimeongeza kuangalia 'item_code' au 'id' kulingana na QR yako
      final serviceData = await supabase
          .from('services')
          .select()
          .or('id.eq.$trimmedCode,item_code.eq.$trimmedCode')
          .eq('business_id', bId)
          .maybeSingle();

      if (serviceData != null) {
        if (mounted) {
          setState(() {
            _scannedItem = serviceData;
            _currentTable = 'services';
          });
          _showFullDetailsModal();
        }
        return;
      }

      // 2. KAMA BIDHAA HAIJAONEKANA KOTE
      _showSnackBar("⚠️ Bidhaa haipo: $trimmedCode", Colors.orange);
      _resumeScanning();

    } catch (e) {
      // Badala ya kutoa debug error, mpe mteja maelekezo ya kirafiki
      _showSnackBar("❌ Tatizo la muunganisho! Angalia Internet yako.", Colors.red);
      _resumeScanning();
    }
  }

  // 3. UNIVERSAL RESTOCK (Inafanya kazi kwa Tables zote)
  Future<void> processRestock(Map<String, dynamic> item, int quantityToAdd) async {
    final now = DateTime.now().toIso8601String();
    final supabase = Supabase.instance.client;

    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackBar("Huna internet!", Colors.red);
      return;
    }

    try {
      int remainingQty = _parseToInt(item['remaining_quantity']);
      int totalQty = _parseToInt(item['total_quantity']);
      int finalTotal = totalQty + quantityToAdd;
      int finalRemaining = remainingQty + quantityToAdd;

      // UPDATE TABLE HUSIKA
      await supabase.from(_currentTable!).update({
        'total_quantity': finalTotal,
        'remaining_quantity': finalRemaining,
        'last_updated': now,
        'batch_number': item['batch_number'] ?? '',
      }).eq('id', item['id']);

      // LOGGING (Kulingana na Table)
      String logTable = _currentTable == 'medicines' ? 'medical_logs' :
      (_currentTable == 'services' ? 'services_logs' : 'other_product_logs');

      String nameKey = _currentTable == 'services' ? 'service_name' : 'name';
      if (_currentTable == 'medicines') nameKey = 'medicine_name';

      await supabase.from(logTable).insert({
        nameKey: item['name'] ?? item['service_name'],
        'action': 'RESTOCK (+ $quantityToAdd)',
        'total_quantity': quantityToAdd,
        'remaining_quantity': finalRemaining,
        'business_id': _currentUserBusinessId,
        'business_name': businessName,
        'date_added': now,
        'added_by': 'Scanner',
      });

      _showSnackBar("Stock imeongezwa kwa mafanikio!", Colors.green);
    } catch (e) {
      _showSnackBar("Update imeshindikana!", Colors.red);
    }
  }

  // 4. KUUZA BIDHAA MOJA (SALE)
  Future<void> _sellOneItem() async {
    // 1. ANZA KUKAGUA KAMA NI HUDUMA (SERVICES)
    final bool isService = _currentTable == 'services';
    final currentQty = _parseToInt(_scannedItem!['remaining_quantity']);
    final now = DateTime.now().toIso8601String();
    final supabase = Supabase.instance.client;

    // 2. KAMA SIYO HUDUMA, KAGUA STOCK
    if (!isService && currentQty <= 0) {
      _showSnackBar("Stock haina kitu!", Colors.red);
      return;
    }

    try {
      int newQty = isService ? 0 : currentQty - 1; // Services hazipunguzi chochote

      // 3. UPDATE DATABASE (Tu kama siyo huduma)
      if (!isService) {
        await supabase
            .from(_currentTable!)
            .update({'remaining_quantity': newQty, 'last_updated': now})
            .eq('id', _scannedItem!['id']);
      }

      // 4. REKODI KWENYE LOGS (Zote mbili zinarekodiwa hapa)
      String logTable = isService ? 'services_logs' :
      (_currentTable == 'medicines' ? 'medical_logs' : 'other_product_logs');

      String nameKey = isService ? 'service_name' : 'name';
      if (_currentTable == 'medicines') nameKey = 'medicine_name';

      await supabase.from(logTable).insert({
        nameKey: _scannedItem!['name'] ?? _scannedItem!['service_name'],
        'action': 'SALE',
        'total_quantity': 1,
        // Kama ni service, tunaweza kuweka 0 au null kwenye remaining_quantity ya log
        'remaining_quantity': isService ? 0 : newQty,
        'business_id': _currentUserBusinessId,
        'business_name': businessName,
        'date_added': now,
        'added_by': 'Scanner'
      });

      // 5. UPDATE LOCAL UI (Tu kama siyo huduma)
      if (!isService) {
        setState(() {
          _scannedItem!['remaining_quantity'] = newQty;
        });
      }

      Navigator.pop(context);
      _showSnackBar(isService ? "Huduma imerekodiwa!" : "Mauzo yamefanikiwa!", Colors.green);

    } catch (e) {
      _showSnackBar("Imefeli kukamilisha mauzo!", Colors.red);
      debugPrint("Sale Error: $e");
    }
  }

  // 5. DIRISHA LA TAARIFA ZOTE
  void _showFullDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Column(
                children: [
                  Icon(_currentTable == 'medicines' ? Icons.medication_liquid : Icons.inventory_2, size: 50, color: const Color(0xFF673AB7)),
                  Text(_scannedItem!['name'] ?? _scannedItem!['service_name'] ?? 'Unknown', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Table: ${_currentTable!.toUpperCase()}", style: const TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
            ),
            const Divider(height: 30),

            Row(
              children: [
                _buildSummaryCard("Bei", "Tsh ${_scannedItem!['price'] ?? _scannedItem!['selling_price']}", Colors.green),
                const SizedBox(width: 10),
                _buildSummaryCard("Stock", "${_scannedItem!['remaining_quantity']} ${_scannedItem!['unit'] ?? ''}", Colors.blue),
              ],
            ),
            const SizedBox(height: 20),

            _buildDetailItem(Icons.numbers, "Batch/ID", _scannedItem!['batch_number'] ?? _scannedItem!['item_code'] ?? _scannedItem!['id']),
            _buildDetailItem(Icons.business, "Kampuni", _scannedItem!['company'] ?? 'N/A'),
            _buildDetailItem(Icons.event_busy, "Expiry Date", _scannedItem!['expiry_date'], isCritical: true),

            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _sellOneItem,
                    icon: const Icon(Icons.sell),
                    label: const Text("UZA (1)"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _showRestockDialog,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text("RESTOCK"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                Navigator.pop(context);
                _showLogs();
              },
              icon: const Icon(Icons.list_alt),
              label: const Text("ANGALIA HISTORIA (LOGS)"),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeScanning());
  }

  void _showRestockDialog() {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ongeza Stock"),
        content: TextField(
          controller: qtyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: "Ingiza idadi", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Ghairi")),
          ElevatedButton(
              onPressed: () {
                int q = int.tryParse(qtyController.text) ?? 0;
                if (q > 0) {
                  Navigator.pop(context); // Funga Dialog
                  Navigator.pop(context); // Funga Details
                  processRestock(_scannedItem!, q);
                }
              },
              child: const Text("Ongeza")
          ),
        ],
      ),
    );
  }

  void _showLogs() async {
    String logTable = _currentTable == 'medicines' ? 'medical_logs' :
    (_currentTable == 'services' ? 'services_logs' : 'other_product_logs');

    String nameKey = _currentTable == 'services' ? 'service_name' : 'name';
    if (_currentTable == 'medicines') nameKey = 'medicine_name';

    final List<dynamic> logs = await Supabase.instance.client
        .from(logTable)
        .select()
        .eq('business_id', _currentUserBusinessId!)
        .eq(nameKey, _scannedItem!['name'] ?? _scannedItem!['service_name'])
        .order('date_added', ascending: false);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("LOGS ZA BIDHAA HII", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: logs.isEmpty ? const Center(child: Text("Hakuna kumbukumbu.")) : ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final l = logs[index];
                  bool isSale = l['action'].toString().contains("SALE");
                  return Card(
                    child: ListTile(
                      leading: Icon(isSale ? Icons.remove_circle : Icons.add_circle, color: isSale ? Colors.red : Colors.green),
                      title: Text("${l['action']}"),
                      subtitle: Text("Tarehe: ${_formatDate(l['date_added'])}"),
                      trailing: Text("Qty: ${l['remaining_quantity']}"),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeScanning());
  }

  // --- HELPERS ---
  int _parseToInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
  String _formatDate(dynamic d) => d != null ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(d.toString())) : "N/A";

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(children: [Text(title, style: TextStyle(fontSize: 11, color: color)), Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color))]),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, dynamic value, {bool isCritical = false}) {
    return ListTile(
      leading: Icon(icon, color: isCritical ? Colors.red : const Color(0xFF673AB7), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value?.toString() ?? 'N/A', style: TextStyle(fontWeight: FontWeight.w500, color: isCritical ? Colors.red : Colors.black)),
      contentPadding: EdgeInsets.zero,
    );
  }

  void _resumeScanning() { if (mounted) setState(() { _isScanning = true; _scannedItem = null; }); }
  void _showSnackBar(String msg, Color color) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(businessName ?? "Scanner"), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_isScanning) {
                final String? code = capture.barcodes.first.rawValue;
                if (code != null) _handleBarcodeDetection(code);
              }
            },
          ),
          Center(child: Container(width: 260, height: 260, decoration: BoxDecoration(border: Border.all(color: const Color(0xFF673AB7), width: 4), borderRadius: BorderRadius.circular(30)))),
        ],
      ),
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}