import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewDeliveryNoteScreen extends StatefulWidget {
  @override
  _ViewDeliveryNoteScreenState createState() => _ViewDeliveryNoteScreenState();
}

class _ViewDeliveryNoteScreenState extends State<ViewDeliveryNoteScreen> {
  List<Map<String, dynamic>> groupedDeliveries = [];
  List<Map<String, dynamic>> filteredDeliveries = [];
  bool _isLoading = false;

  String searchQuery = '';
  DateTime? selectedDate;
  final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  bool _isDarkMode = false;

  // Business Profile Info
  String? myBusinessName;
  String? myLogoPath;
  String? myEmail;
  String? myPhone;
  String? myLocation;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await getBusinessInfo();
    await fetchDeliveries();
    setState(() => _isLoading = false);
  }

  Future<void> getBusinessInfo() async {
    try {
      // 1. Check Connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint("📡 Offline: Cannot fetch business info.");
        return;
      }

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        debugPrint("⚠️ No active session found.");
        return;
      }

      // 2. Fetch User Profile to get their assigned Business Name
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile == null || userProfile['business_name'] == null) {
        debugPrint("⚠️ Current user has no business assigned in 'users' table.");
        return;
      }

      String userBusiness = userProfile['business_name'];
      debugPrint("🔍 User's assigned business: $userBusiness");

      // 3. Fetch specific business details (Logo, Phone, etc.)
      final businessData = await supabase
          .from('businesses')
          .select()
          .eq('business_name', userBusiness)
          .maybeSingle();

      if (businessData != null) {
        if (mounted) {
          setState(() {
            myBusinessName = businessData['business_name'];
            myLogoPath = businessData['logo'];
            myEmail = businessData['email'];
            myPhone = businessData['phone'];
            myLocation = businessData['location'];
          });

          // 4. Load deliveries ONLY after business name is confirmed
          await fetchDeliveries();
        }
        debugPrint("✅ Business info and deliveries loaded for: $userBusiness");
      } else {
        debugPrint("⚠️ Business details not found in 'businesses' table.");
      }
    } catch (e) {
      debugPrint('❌ Supabase Business Info Error: $e');
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> fetchDeliveries() async {
    if (myBusinessName == null) return; // Guard clause

    try {
      final List<dynamic> result = await Supabase.instance.client
          .from('invoices')
          .select()
          .eq('business_name', myBusinessName!) // Strict filtering by current user's business
          .order('added_time', ascending: false);

      Map<String, Map<String, dynamic>> tempGroups = {};
      for (var row in result) {
        String invNo = row['invoice_no'] ?? 'DN-ID';
        if (!tempGroups.containsKey(invNo)) {
          tempGroups[invNo] = {
            'delivery_id': invNo,
            'customer_name': row['customer_name'] ?? 'Walk-in',
            'added_time': row['added_time'],
            'items': [],
            'customer_address': '',
            'subtotal': 0.0,
            'total_discount': 0.0,
          };
        }
        tempGroups[invNo]!['items'].add(row);

        double itemTotal = (row['total'] as num? ?? 0.0).toDouble();
        double itemDisc = (row['discount'] as num? ?? 0.0).toDouble();

        tempGroups[invNo]!['subtotal'] += itemTotal;
        tempGroups[invNo]!['total_discount'] += itemDisc;
      }

      setState(() {
        groupedDeliveries = tempGroups.values.toList();
        filteredDeliveries = groupedDeliveries;
      });
    } catch (e) {
      debugPrint('Error fetching deliveries: $e');
    }
  }

  void filterDeliveries() {
    setState(() {
      filteredDeliveries = groupedDeliveries.where((delivery) {
        final customer = delivery['customer_name']?.toString().toLowerCase() ?? '';
        final matchesCustomer = customer.contains(searchQuery.toLowerCase());
        if (selectedDate != null && delivery['added_time'] != null) {
          final date = DateTime.tryParse(delivery['added_time']);
          return date != null &&
              date.year == selectedDate!.year &&
              date.month == selectedDate!.month &&
              date.day == selectedDate!.day &&
              matchesCustomer;
        }
        return matchesCustomer;
      }).toList();
    });
  }

  Future<void> previewDeliveryNote(Map<String, dynamic> delivery) async {
    TextEditingController addressController = TextEditingController(text: delivery['customer_address'] ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Shipping Address'),
        content: TextField(
          controller: addressController,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Enter Destination Address', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() => delivery['customer_address'] = addressController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Generate PDF'),
          ),
        ],
      ),
    );

    final pdf = await buildPdfDeliveryNote(delivery);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Future<pw.Document> buildPdfDeliveryNote(Map<String, dynamic> delivery) async {
    final pdf = pw.Document();

    // 🌐 FIXED: Network Logo Loading logic
    pw.Widget logoWidget = pw.SizedBox(width: 70, height: 70);
    if (myLogoPath != null && myLogoPath!.isNotEmpty) {
      try {
        final ByteData data = await NetworkAssetBundle(Uri.parse(myLogoPath!)).load("");
        logoWidget = pw.Image(pw.MemoryImage(data.buffer.asUint8List()), width: 70, height: 70);
      } catch (e) {
        logoWidget = pw.PdfLogo();
      }
    }

    final List items = delivery['items'];
    double subtotal = (delivery['subtotal'] as num? ?? 0.0).toDouble();
    double discount = (delivery['total_discount'] as num? ?? 0.0).toDouble();
    double grandTotal = subtotal - discount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                logoWidget,
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(myBusinessName?.toUpperCase() ?? "DELIVERY NOTE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(myPhone ?? "", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(myLocation ?? "", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.teal),
            pw.SizedBox(height: 10),
            pw.Text('DELIVERY NOTE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text('No: ${delivery['delivery_id']}'),
            pw.Text('Date: ${DateFormat('dd MMM yyyy').format(DateTime.now())}'),
            pw.SizedBox(height: 15),
            pw.Text('DELIVERED TO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text(delivery['customer_name'], style: const pw.TextStyle(fontSize: 12)),
            pw.Text('Address: ${delivery['customer_address']}', style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
              headers: ['Item', 'Qty', 'Unit', 'Price', 'Total'],
              data: items.map((i) => [
                i['item_name'], i['quantity'].toString(), i['unit'],
                currencyFormatter.format(i['price'] ?? 0), currencyFormatter.format(i['total'] ?? 0)
              ]).toList(),
            ),

            pw.SizedBox(height: 15),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: TSH ${currencyFormatter.format(subtotal)}'),
                    if (discount > 0)
                      pw.Text('Discount: - TSH ${currencyFormatter.format(discount)}', style: pw.TextStyle(color: PdfColors.red)),
                    pw.SizedBox(width: 120, child: pw.Divider()),
                    pw.Text('GRAND TOTAL: TSH ${currencyFormatter.format(grandTotal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                )
            ),

            pw.Spacer(),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureBox('Received By (Customer)'),
                _signatureBox('Delivered By (Store)'),
              ],
            ),
          ],
        ),
      ),
    );
    return pdf;
  }

  pw.Widget _signatureBox(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        pw.SizedBox(height: 35),
        pw.Container(
          width: 150,
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1, color: PdfColors.black)),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Signature & Stamp', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("DELIVERY NOTES", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple]),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : Column(
        children: [
          _buildFilters(),
          Expanded(
            child: filteredDeliveries.isEmpty
                ? Center(child: Text('No delivery notes found', style: TextStyle(color: subTextCol)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: filteredDeliveries.length,
              itemBuilder: (context, index) {
                final del = filteredDeliveries[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ListTile(
                    title: Text(del['customer_name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, color: textCol)),
                    subtitle: Text('ID: ${del['delivery_id']}', style: TextStyle(color: subTextCol, fontSize: 12)),
                    trailing: IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                      onPressed: () => previewDeliveryNote(del),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                searchQuery = val;
                filterDeliveries();
              },
            ),
          ),
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      filterDeliveries();
    }
  }
}