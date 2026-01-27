import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdfWidgets;
import 'package:printing/printing.dart';
import '../DB/database_helper.dart';
import 'package:pdf/widgets.dart' as pw;

class SalesAnalysisPage extends StatefulWidget {
  const SalesAnalysisPage({super.key});

  @override
  State<SalesAnalysisPage> createState() => _SalesAnalysisPageState();
}

class _SalesAnalysisPageState extends State<SalesAnalysisPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Map<String, double> _result = {};
  List<Map<String, dynamic>> _saleItems = [];
  List<Map<String, dynamic>> _usageDetails = [];

  DateTime? _fromDate;
  DateTime? _toDate;

  Future<void> _pickDate(DateTime? selectedDate, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      await _calculateProfitLoss();
      _getSaleItems().then((saleItems) {
        setState(() {
          _saleItems = saleItems;
        });
      });
      _getUsageDetails().then((usageDetails) {
        setState(() {
          _usageDetails = usageDetails;
        });
      });
    }
  }

  Future<void> _calculateProfitLoss() async {
    final sales = await _dbHelper.querySaleItemsByDate(_fromDate, _toDate);
    double totalProfit = 0.0;
    double totalLoss = 0.0;
    double totalRevenue = 0.0;

    for (var sale in sales) {
      int medicineId = sale['medicine_id'] ?? 0;
      double sellPrice = (sale['price'] ?? 0.0) * 1.0;
      int remaining_quantity = sale['remaining_quantity'] ?? 0;
      double buyPrice = await _getMedicineBuyPrice(medicineId);

      double totalSell = sellPrice * remaining_quantity;
      double totalBuy = buyPrice * remaining_quantity;
      double profitOrLoss = totalSell - totalBuy;

      if (profitOrLoss >= 0) {
        totalProfit += profitOrLoss;
      } else {
        totalLoss += -profitOrLoss;
      }

      totalRevenue += totalSell;
    }

    double totalUsage = await _getTotalUsageCost();
    double netProfit = totalProfit - totalUsage;

    setState(() {
      _result = {
        'totalProfit': totalProfit ?? 0.0,
        'totalLoss': totalLoss ?? 0.0,
        'totalRevenue': totalRevenue ?? 0.0,
        'totalUsage': totalUsage ?? 0.0,
        'netProfit': netProfit ?? 0.0,
      };
    });

  }

  Future<double> _getMedicineBuyPrice(int medicineId) async {
    final medicine = await _dbHelper.queryMedicineById(medicineId);
    return (medicine?['buy_price'] ?? 0.0) * 1.0;
  }

  Future<double> _getTotalUsageCost() async {
    final usageList = await _dbHelper.queryUsageByDate(_fromDate, _toDate);
    double totalUsage = 0.0;
    for (var usage in usageList) {
      totalUsage += (usage['amount'] ?? 0.0) * 1.0;
    }
    return totalUsage;
  }

  Future<List<Map<String, dynamic>>> _getUsageDetails() async {
    final usageList = await _dbHelper.queryUsageByDate(_fromDate, _toDate);
    List<Map<String, dynamic>> usageDetails = [];

    for (var usage in usageList) {
      int medicineId = usage['medicine_id'] ?? 0;
      final medicine = await _dbHelper.queryMedicineById(medicineId);

      usageDetails.add({
        'category': usage['category'] ?? 'N/A',
        'amount': usage['amount'] ?? 0.0,
        'date': usage['usage_date'] ?? 'N/A',
        'medicineName': medicine['name'] ?? 'N/A',
        'buyPrice': medicine['buy_price'] ?? 0.0,
        'sellPrice': medicine['sell_price'] ?? 0.0,
        'description': usage['description'] ?? 'N/A',
        'added_by': usage['added_by'] ?? 'N/A',
      });
    }

    return usageDetails;
  }

  Future<List<Map<String, dynamic>>> _getSaleItems() async {
    final saleItems = await _dbHelper.querySaleItemsByDate(_fromDate, _toDate);
    List<Map<String, dynamic>> items = [];

    for (var sale in saleItems) {
      int medicineId = sale['medicine_id'] ?? 0;
      final medicine = await _dbHelper.queryMedicineById(medicineId);
      String medicineName = medicine['name'] ?? 'Unknown';

      double sellPrice = sale['price'] ?? 0.0;
      int remaining_quantity = sale['remaining_quantity'] ?? 0;
      String dateAdded = sale['date_added'] ?? 'N/A';

      items.add({
        'medicineName': medicineName,
        'remaining_quantity': remaining_quantity,
        'sellPrice': sellPrice,
        'totalRevenue': sellPrice * remaining_quantity,
        'date_added': dateAdded,
      });
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    _calculateProfitLoss();
    _getSaleItems().then((saleItems) {
      setState(() {
        _saleItems = saleItems;
      });
    });
    _getUsageDetails().then((usageDetails) {
      setState(() {
        _usageDetails = usageDetails;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromText = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : 'From Date';
    final toText = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : 'To Date';

    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Sales & Profit Analysis",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () {
              _exportToPDF();
            },
          ),
        ],
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_fromDate, true),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "From Date"),
                    child: Text(fromText),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_toDate, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "To Date"),
                    child: Text(toText),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_result.isNotEmpty) ...[
            Text('Total Revenue: TSH ${(_result['totalRevenue'] ?? 0.0).toStringAsFixed(2)}'),
            Text('Total Profit: TSH ${(_result['totalProfit'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green)),
            Text('Total Loss: TSH ${(_result['totalLoss'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red)),
            Text('Usage Cost: TSH ${(_result['totalUsage'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.orange)),
            Text('Net Profit: TSH ${(_result['netProfit'] ?? 0.0).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),
          ],

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usage Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Epenses Details:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_usageDetails.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _usageDetails.length,
                        itemBuilder: (context, index) {
                          final usage = _usageDetails[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              title: Text('${usage['category']}'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Amount: TSH ${usage['amount'].toStringAsFixed(2)}'),
                                  Text('Usage Date: ${usage['date']}'),
                                  Text('Description: ${usage['description']}'),
                                  Text('Staff: ${usage['added_by']}'),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const Text('No Expenses data available.'),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Sale Items
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sale Item Details:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (_saleItems.isNotEmpty)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _saleItems.length,
                        itemBuilder: (context, index) {
                          final sale = _saleItems[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              title: Text(sale['medicineName']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Date: ${sale['date_added']}'),
                                  Text('Quantity: ${sale['remaining_quantity']}'),
                                  Text('Sell Price: TSH ${sale['sellPrice'].toStringAsFixed(2)}'),
                                  Text('Total: TSH ${sale['totalPrice'].toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    else
                      const Text('No sale items data available.'),
                  ],
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text('Sales & Profit Analysis', style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 10),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}', style: pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Text('Total Revenue: TSH ${_result['totalRevenue']!.toStringAsFixed(2)}'),
              pw.Text('Total Profit: TSH ${_result['totalProfit']!.toStringAsFixed(2)}'),
              pw.Text('Total Loss: TSH ${_result['totalLoss']!.toStringAsFixed(2)}'),
              pw.Text('Usage Cost: TSH ${_result['totalUsage']!.toStringAsFixed(2)}'),
              pw.Text('Net Profit: TSH ${_result['netProfit']!.toStringAsFixed(2)}'),
              pw.SizedBox(height: 20),
              pw.Text('Sale Items:', style: pw.TextStyle(fontSize: 16)),
              for (var sale in _saleItems)
                pw.Row(
                  children: [
                    pw.Text(sale['medicineName']),
                    pw.SizedBox(width: 10),
                    pw.Text('Quantity: ${sale['remaining_quantity']}'),
                    pw.SizedBox(width: 10),
                    pw.Text('Total: TSH ${sale['totalPrice'].toStringAsFixed(2)}'),
                  ],
                ),
              pw.SizedBox(height: 20),
              pw.Text('Usage Details:', style: pw.TextStyle(fontSize: 16)),
              for (var usage in _usageDetails)
                pw.Row(
                  children: [
                    pw.Text('${usage['category']}'),
                    pw.SizedBox(width: 10),
                    pw.Text('Amount: TSH ${usage['amount'].toStringAsFixed(2)}'),
                  ],
                ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}

extension SalesQueries on DatabaseHelper {
  Future<List<Map<String, dynamic>>> querySaleItemsByDate(DateTime? from, DateTime? to) async {
    final db = await database;
    String query = "SELECT * FROM sale_items";
    List<String> where = [];
    List<dynamic> args = [];

    if (from != null && to != null) {
      where.add("DATE(date_added) BETWEEN ? AND ?");
      args.add(DateFormat('yyyy-MM-dd').format(from));
      args.add(DateFormat('yyyy-MM-dd').format(to));
    }

    if (where.isNotEmpty) {
      query += " WHERE " + where.join(" AND ");
    }

    return await db.rawQuery(query, args);
  }

  Future<List<Map<String, dynamic>>> queryUsageByDate(DateTime? from, DateTime? to) async {
    final db = await database;
    String query = "SELECT * FROM normal_usage";
    List<String> where = [];
    List<dynamic> args = [];

    if (from != null && to != null) {
      where.add("DATE(usage_date) BETWEEN ? AND ?");
      args.add(DateFormat('yyyy-MM-dd').format(from));
      args.add(DateFormat('yyyy-MM-dd').format(to));
    }

    if (where.isNotEmpty) {
      query += " WHERE " + where.join(" AND ");
    }

    return await db.rawQuery(query, args);
  }

  Future<Map<String, dynamic>> queryMedicineById(int medicineId) async {
    final db = await database;
    final result = await db.query('medicines', where: 'id = ?', whereArgs: [medicineId]);
    return result.isNotEmpty ? result.first : {};
  }
}
