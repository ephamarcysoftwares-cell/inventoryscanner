import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class BusinessSummaryScreen extends StatefulWidget {
  const BusinessSummaryScreen({Key? key}) : super(key: key);

  @override
  _BusinessSummaryScreenState createState() => _BusinessSummaryScreenState();
}

class _BusinessSummaryScreenState extends State<BusinessSummaryScreen> {
  double totalIncome = 0.0;
  double cashInHand = 0.0;
  double totalSales = 0.0;
  double usageCost = 0.0;
  double totalInvestment = 0.0;
  double totalStockValue = 0.0;
  double totalExpenses = 0.0;
  double profit = 0.0;

  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';

  DateTime? _startDate;
  DateTime? _endDate;

  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    getBusinessInfo();
    _loadSummary();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate! : _endDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    if (_startDate == null || _endDate == null) return;

    final startStr = _dateToString(_startDate!);
    final endStr = _dateToString(_endDate!);

    final incomeResult = await dbHelper.queryTotalIncome(startStr, endStr);
    totalIncome = _parseValue(incomeResult, 'total_income');

    final salesResult = await dbHelper.queryTotalSales(startStr, endStr);
    totalSales = _parseValue(salesResult, 'total_sales');

    final usageResult = await dbHelper.queryTotalExpenses(startStr, endStr);
    usageCost = _parseValue(usageResult, 'total_expenses');

    // ✅ Filtered by date range
    final medicalLogs = await dbHelper.queryMedicalLogsByDate(startStr, endStr);

    totalInvestment = medicalLogs.fold(0.0, (sum, log) {
      final buy = double.tryParse(log['buy_price'].toString()) ?? 0.0;
      final qty = int.tryParse(log['total_quantity'].toString()) ?? 0;
      return sum + (buy * qty);
    });

    // Stock value from `medicine` table
    final medicines = await dbHelper.queryAllMedicines();

    totalStockValue = medicines.fold(0.0, (sum, med) {
      final price = double.tryParse(med['price'].toString()) ?? 0.0;
      final remainingQty = int.tryParse(med['remaining_quantity'].toString()) ?? 0;
      return sum + price * remainingQty;
    });

    if (totalStockValue < 0) totalStockValue = 0;

    final expensesResult = await dbHelper.queryTotalExpenses(startStr, endStr);
    totalExpenses = _parseValue(expensesResult, 'total_expenses');

    cashInHand = totalSales - totalExpenses;
    if (cashInHand < 0) cashInHand = 0;

    profit = totalIncome - totalInvestment - usageCost;

    setState(() {});
  }

  double _parseValue(List<Map<String, dynamic>> result, String key) {
    return result.isNotEmpty && result.first[key] != null
        ? double.tryParse(result.first[key].toString()) ?? 0.0
        : 0.0;
  }

  String _dateToString(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatDate(DateTime? date) {
    return date != null ? DateFormat('yyyy-MM-dd').format(date) : 'Select Date';
  }

  Future<void> getBusinessInfo() async {
    try {
      final db = await dbHelper.database;
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');

      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name']?.toString() ?? '';
          businessEmail = result[0]['email']?.toString() ?? '';
          businessPhone = result[0]['phone']?.toString() ?? '';
          businessLocation = result[0]['location']?.toString() ?? '';
          businessLogoPath = result[0]['logo']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }

  Future<void> generateBusinessSummaryPDF() async {
    final pdf = pw.Document();

    final generatedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final logoFile = File(businessLogoPath);
    final logoBytes = await logoFile.readAsBytes();
    final logoImage = pw.MemoryImage(logoBytes);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Header Row: Business Info and Logo
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Business Name: $businessName', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Email: $businessEmail'),
                  pw.Text('Phone: $businessPhone'),
                  pw.Text('Location: $businessLocation'),
                ],
              ),
              pw.Image(logoImage, width: 80, height: 80),
            ],
          ),
          pw.SizedBox(height: 20),

          // Title and Divider
          pw.Text('Business Financial Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Text('Report From: ${_formatDate(_startDate)} to ${_formatDate(_endDate)}', style: pw.TextStyle(fontSize: 14)),

          // Spacer
          pw.SizedBox(height: 20),

          // Table with Data
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 1),
            children: [
              _buildPDFTableRow("Total Income", totalIncome),
              _buildPDFTableRow("Cash in Hand", cashInHand),
              // _buildPDFTableRow("Total Sales", totalSales),
              _buildPDFTableRow("Total Expenses", usageCost),
              _buildPDFTableRow("Total you  Invested", totalInvestment),
              _buildPDFTableRow("Stock remain Value", totalStockValue),
              // _buildPDFTableRow("Monthly Expenses", totalExpenses),
              _buildPDFTableRow("Net Profit", profit),
            ],
          ),

          // Spacer
          pw.SizedBox(height: 20),

          // Report Footer: Generated time
          pw.Text('Report Generated On: $generatedTime', style: pw.TextStyle(fontSize: 14)),
        ],
      ),
    );

    // Save PDF to file
    final dir = await getApplicationDocumentsDirectory();
    final formattedDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File("${dir.path}/business_summary_$formattedDate.pdf");
    await file.writeAsBytes(await pdf.save());

    // Show Snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved at: ${file.path}')),
    );
  }

  // Helper method to build rows in the table
  final _currencyFormat = NumberFormat('#,##0.00', 'en_US');

// Method to generate a row with formatted currency
  pw.TableRow _buildPDFTableRow(String label, double value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8.0),
          child: pw.Text(label, style: pw.TextStyle(fontSize: 14)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8.0),
          child: pw.Text('TZS ${_currencyFormat.format(value)}', style: pw.TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

// Full PDF Generation Example
  pw.Document generatePdf() {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Table(
                  children: [
                    _buildPDFTableRow('Total Income', 400000.0),
                    _buildPDFTableRow('Total Expenses', 250000.0),
                    _buildPDFTableRow('Net Income', 150000.0),
                    // Add more rows as needed
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }

  // Create a NumberFormat instance for formatting as you described


// Your PDF row builder
  pw.Widget _buildPDFRow(String title, double value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(title),
        pw.Text('TZS ${_currencyFormat.format(value)}'),  // Apply custom format here
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Business Summary",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context, true),
                  icon: const Icon(Icons.date_range),
                  label: Text('From: ${_formatDate(_startDate)}'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _selectDate(context, false),
                  icon: const Icon(Icons.date_range),
                  label: Text('To: ${_formatDate(_endDate)}'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                children: [
                  _buildSummaryCard('💰 Total Income', totalIncome),
                  _buildSummaryCard('🧾 Cash in Hand', cashInHand),
                  // _buildSummaryCard('📦 Total Sales (from items)', totalSales),
                  _buildSummaryCard('📉 Expenses', usageCost),
                  _buildSummaryCard('📥 Total Value you Invested', totalInvestment),
                  _buildSummaryCard('📊 Remaining Stock Value ', totalStockValue),
                  // _buildSummaryCard('💸 Monthly Expenses', totalExpenses),
                  _buildSummaryCard('💵 Net Profit (Invest - Income - Expensive)', profit),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: generateBusinessSummaryPDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export Summary to PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildSummaryCard(String title, double value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.analytics, color: Colors.teal),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),

// Inside your widget
        trailing: Text('TZS ${NumberFormat('#,##0.00', 'en_US').format(value)}'),

      ),
    );
  }
}