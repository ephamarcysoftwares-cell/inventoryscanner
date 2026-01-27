import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for NetworkAssetBundle
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvoiceForm extends StatefulWidget {
  const InvoiceForm({super.key});

  @override
  _InvoiceFormState createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm> {
  // --- Business Profile Variables ---
  String business_name = 'STOCK & INVENTORY';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessLipaNumber = '';
  String businessWhatsapp = '';
  String businessAddress = '';
  bool _isDarkMode = false;

  // --- Form Controllers ---
  final customerController = TextEditingController();
  final itemController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();
  final discountController = TextEditingController(); // Discount Controller
  final formatter = NumberFormat('#,##0.00', 'en_US');

  // --- State Variables ---
  List<Map<String, dynamic>> items = [];
  String selectedUnit = 'Item';
  bool _isLoading = false;

  final List<String> units = [
    'Dozen', 'KG', 'Per Item', 'Liter', 'Pics', 'Box', 'Bottle',
    'Pack', 'Carton', 'Piece (pc)', 'Set', 'Strip', 'Tablet', 'Unit'
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getBusinessInfo();
    // Listen to discount changes to update the UI instantly
    discountController.addListener(() => setState(() {}));
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint("⚠️ No active session.");
        return;
      }

      // 1. Pata jina la biashara kutoka kwenye profile ya mtumiaji
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null && userProfile['business_name'] != null) {
        String userBusiness = userProfile['business_name'];

        // 2. Sasa vuta taarifa kamili za biashara hiyo pekee
        final data = await supabase
            .from('businesses')
            .select()
            .eq('business_name', userBusiness) // FILTER: Biashara ya huyu mtu tu
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            // Kutumia variables zako mahususi
            business_name = data['business_name']?.toString() ?? 'STOCK & INVENTORY';
            businessEmail = data['email']?.toString() ?? '';
            businessPhone = data['phone']?.toString() ?? '';
            businessLocation = data['location']?.toString() ?? '';
            businessLogoPath = data['logo']?.toString() ?? '';
            businessLipaNumber = data['lipa_number']?.toString() ?? '';
            businessWhatsapp = data['whatsapp']?.toString() ?? '';
            businessAddress = data['address']?.toString() ?? ''; // Usisahau address
          });
          debugPrint('✅ Data loaded for: $business_name');
        }
      }
    } catch (e) {
      debugPrint('❌ Supabase Fetch Error: $e');
    }
  }

  double get totalAmount => items.fold(0.0, (sum, item) => sum + (item['total'] ?? 0.0));
  double get currentDiscount => double.tryParse(discountController.text) ?? 0.0;
  double get grandTotal => totalAmount - currentDiscount;

  void addItem() {
    final item = itemController.text.trim();
    final qty = int.tryParse(qtyController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0.0;

    if (item.isEmpty || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid item and quantity.')));
      return;
    }

    setState(() {
      items.add({
        'item': item,
        'qty': qty,
        'unit': selectedUnit,
        'price': price,
        'total': qty * price,
      });
      itemController.clear();
      qtyController.clear();
      priceController.clear();
      selectedUnit = 'Item';
    });
  }

  Future<void> saveAndPrintInvoice() async {
    if (items.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final String groupInvoiceId = 'INV-${DateTime.now().millisecondsSinceEpoch}';
      final String customer = customerController.text.trim().isEmpty ? "Walk-in" : customerController.text.trim();

      // Calculate discount per row for DB storage
      double discPerRow = currentDiscount / items.length;

      final List<Map<String, dynamic>> toInsert = items.map((e) => {
        'invoice_no': groupInvoiceId,
        'item_name': e['item'],
        'quantity': e['qty'],
        'price': e['price'],
        'total': e['total'],
        'unit': e['unit'],
        'discount': discPerRow, // SAVING DISCOUNT TO SUPABASE
        'customer_name': customer,
        'business_name': business_name,
        'added_time': DateTime.now().toIso8601String(),
      }).toList();

      await Supabase.instance.client.from('invoices').insert(toInsert);
      await _buildProfessionalPdf(groupInvoiceId, customer);

      setState(() {
        items.clear();
        customerController.clear();
        discountController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buildProfessionalPdf(String invId, String customer) async {
    final pdf = pw.Document();

    // --- NETWORK LOGO LOADER ---
    pw.Widget logoWidget = pw.SizedBox(width: 60, height: 60);
    if (businessLogoPath.isNotEmpty) {
      try {
        final ByteData data = await NetworkAssetBundle(Uri.parse(businessLogoPath)).load("");
        logoWidget = pw.Image(pw.MemoryImage(data.buffer.asUint8List()), width: 60, height: 60);
      } catch (e) {
        logoWidget = pw.PdfLogo();
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              logoWidget,
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(business_name.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(businessLocation, style: const pw.TextStyle(fontSize: 9)),
                  pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1, color: PdfColors.teal),
          pw.SizedBox(height: 15),
          pw.Text("INVOICE NO: $invId", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Customer: $customer"),
          pw.Text("Date: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}"),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Description', 'Qty', 'Unit', 'Price', 'Total'],
            data: items.map((e) => [e['item'], e['qty'], e['unit'], formatter.format(e['price']), formatter.format(e['total'])]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignments: {4: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 20),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text("Subtotal: TSH ${formatter.format(totalAmount)}"),
                if (currentDiscount > 0)
                  pw.Text("Discount: - TSH ${formatter.format(currentDiscount)}", style: const pw.TextStyle(color: PdfColors.red)),
                pw.SizedBox(width: 150, child: pw.Divider(thickness: 0.5)), // FIXED WIDTH DIVIDER
                pw.Text("GRAND TOTAL: TSH ${formatter.format(grandTotal)}",
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
              ],
            ),
          ),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            color: PdfColors.grey100,
            width: double.infinity,
            child: pw.Center(child: pw.Text("Lipa Namba: $businessLipaNumber | WhatsApp: $businessWhatsapp", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
          )
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    const Color primaryPurple = Color(0xFF673AB7);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(business_name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF311B92), primaryPurple]))),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputCard(isDark, cardColor, primaryPurple),
            const SizedBox(height: 20),
            _buildListCard(isDark, cardColor, primaryPurple),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isDark, Color cardColor, Color primaryPurple) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _field(customerController, "Customer", Icons.person, isDark),
            const SizedBox(height: 10),
            _field(itemController, "Item Name", Icons.inventory, isDark),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _field(priceController, "Price", Icons.sell, isDark, isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(qtyController, "Qty", Icons.shopping_bag, isDark, isNum: true)),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: addItem,
                style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text("ADD TO INVOICE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(bool isDark, Color cardColor, Color primaryPurple) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            ...items.map((e) => ListTile(
              dense: true,
              title: Text(e['item'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              subtitle: Text("${e['qty']} ${e['unit']} x ${e['price']}"),
              trailing: Text("TSH ${formatter.format(e['total'])}"),
              onLongPress: () => setState(() => items.remove(e)),
            )),
            const Divider(),
            _field(discountController, "Apply Total Discount (TSH)", Icons.card_giftcard, isDark, isNum: true),
            const SizedBox(height: 15),
            _row("Subtotal", totalAmount, isDark ? Colors.white70 : Colors.black54),
            _row("Discount", -currentDiscount, Colors.red),
            _row("GRAND TOTAL", grandTotal, Colors.teal, isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, bool isDark, {bool isNum = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.teal, size: 20),
        filled: true,
        fillColor: Colors.teal.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _row(String label, double val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 13)),
          Text("TSH ${formatter.format(val)}", style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 13)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : saveAndPrintInvoice,
      icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.print),
      label: const Text("FINALIZE & PRINT"),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}