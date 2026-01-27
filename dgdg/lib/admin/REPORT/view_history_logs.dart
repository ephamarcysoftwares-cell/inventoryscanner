import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../FOTTER/CurvedRainbowBar.dart';


class ProductLogsPage extends StatefulWidget {
  const ProductLogsPage({Key? key}) : super(key: key);

  @override
  State<ProductLogsPage> createState() => _ProductLogsPageState();
}

class _ProductLogsPageState extends State<ProductLogsPage> {
  final supabase = Supabase.instance.client;

  // Data State
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;

  // Filtering State
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  DateTime? startDate;
  DateTime? endDate;

  // Business Info State
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// 🚀 Entry point: Fetch business identity first, then their logs
  Future<void> _initializeData() async {
    await getBusinessInfo();
    await fetchProducts();
  }

  /// ☁️ Get Business Identity based on Login Email
  Future<void> getBusinessInfo() async {
    try {
      final userEmail = supabase.auth.currentUser?.email;
      if (userEmail == null) return;

      final data = await supabase
          .from('businesses')
          .select()
          .eq('email', userEmail)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          businessName = data['business_name']?.toString() ?? '';
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('❌ Supabase Business Fetch Error: $e');
    }
  }

  /// ☁️ Fetch Product Logs (Only for this business)
  Future<void> fetchProducts() async {
    if (businessName.isEmpty) {
      // If business name isn't loaded yet, try to load it first
      await getBusinessInfo();
    }

    setState(() => _isLoading = true);
    try {
      var query = supabase
          .from('other_product_logs')
          .select()
          .eq('business_name', businessName); // 🔥 CRITICAL SECURITY FILTER

      // Search Filter (Name or Company)
      if (searchQuery.isNotEmpty) {
        query = query.or('name.ilike.%$searchQuery%,company.ilike.%$searchQuery%');
      }

      // Date Range Filter
      if (startDate != null && endDate != null) {
        query = query
            .gte('date_added', DateFormat('yyyy-MM-dd').format(startDate!))
            .lte('date_added', DateFormat('yyyy-MM-dd').format(endDate!));
      }

      final data = await query.order('date_added', ascending: false);

      setState(() {
        _allProducts = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("❌ Supabase Logs Fetch Error: $e");
      setState(() => _isLoading = false);
    }
  }

  /// 📄 PDF Generation (Using Supabase Data)
  /// 📄 PDF Generation with Business Logo and Details
  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    // 1. Prepare the Logo Widget if it exists
    pw.Widget? logoWidget;
    if (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync()) {
      final logoBytes = File(businessLogoPath).readAsBytesSync();
      final logoImage = pw.MemoryImage(logoBytes);
      logoWidget = pw.Image(logoImage, width: 70, height: 70, fit: pw.BoxFit.contain);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Landscape for more columns
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // --- BUSINESS HEADER SECTION ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(businessName.toUpperCase(),
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.teal)),
                  pw.SizedBox(height: 5),
                  pw.Text("Email: $businessEmail"),
                  pw.Text("Phone: $businessPhone"),
                  pw.Text("Location: $businessLocation"),
                ],
              ),
              if (logoWidget != null) logoWidget,
            ],
          ),
          pw.Divider(thickness: 2, color: PdfColors.teal),
          pw.SizedBox(height: 10),

          // --- REPORT TITLE ---
          pw.Center(
            child: pw.Text("OTHER PRODUCT STOCK REPORT",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text("Generated on: $timestamp", style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.SizedBox(height: 15),

          // --- DATA TABLE ---
          pw.Table.fromTextArray(
            headers: [
              'Product Name',
              'Company',
              'Initial',
              'Remain',
              'Buy Price',
              'Sell Price',
              'Unit',
              'Action',
              'Date Added'
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            data: _allProducts.map((p) => [
              p['name']?.toString() ?? '',
              p['company']?.toString() ?? '',
              p['total_quantity']?.toString() ?? '0',
              p['remaining_quantity']?.toString() ?? '0',
              p['buy_price']?.toString() ?? '0',
              p['selling_price']?.toString() ?? '0',
              p['unit']?.toString() ?? '',
              p['action']?.toString() ?? '',
              p['date_added']?.toString() ?? '',
            ]).toList(),
          ),

          // --- FOOTER ---
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey),
          pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text("Thank you for your business - End of Report",
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          ),
        ],
      ),
    );

    // 2. Save the File
    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Stock Report',
      fileName: 'Stock_Report_${businessName.replaceAll(' ', '_')}.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(await pdf.save());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF successfully saved to $outputFile'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("STOCK REPORT -BRANCH NAME: $businessName", style: const TextStyle(fontSize: 15, color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchProducts),
        ],
      ),
      body: Column(
        children: [
          _buildFilterArea(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allProducts.isEmpty
                ? const Center(child: Text("No product logs found for this branch."))
                : _buildLogsTable(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _allProducts.isEmpty ? null : generatePdf,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildFilterArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search product or company...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (val) {
              searchQuery = val;
              fetchProducts();
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(true),
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(startDate == null ? "Start Date" : DateFormat('yMd').format(startDate!)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectDate(false),
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(endDate == null ? "End Date" : DateFormat('yMd').format(endDate!)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
          border: TableBorder.all(color: Colors.grey.shade300),
          columns: const [
            DataColumn(label: Text('Product Name')),
            DataColumn(label: Text('Company')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Remain')),
            DataColumn(label: Text('Buy')),
            DataColumn(label: Text('Sell')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Action')),
            DataColumn(label: Text('Date Added')),
          ],
          rows: _allProducts.map((p) {
            return DataRow(cells: [
              DataCell(Text(p['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(p['company']?.toString() ?? '')),
              DataCell(Text(p['total_quantity']?.toString() ?? '0')),
              DataCell(Text(p['remaining_quantity']?.toString() ?? '0', style: const TextStyle(color: Colors.blue))),
              DataCell(Text(p['buy_price']?.toString() ?? '0')),
              DataCell(Text(p['selling_price']?.toString() ?? '0')),
              DataCell(Text(p['unit']?.toString() ?? '')),
              DataCell(Text(p['action']?.toString() ?? '', style: TextStyle(color: p['action'] == 'Stock Out' ? Colors.red : Colors.green))),
              DataCell(Text(p['date_added']?.toString() ?? '')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => isStart ? startDate = picked : endDate = picked);
      fetchProducts();
    }
  }
}