import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class FinishedMedicinesProfitScreen extends StatefulWidget {
  const FinishedMedicinesProfitScreen({Key? key}) : super(key: key);

  @override
  _FinishedMedicinesProfitScreenState createState() =>
      _FinishedMedicinesProfitScreenState();
}

class _FinishedMedicinesProfitScreenState
    extends State<FinishedMedicinesProfitScreen> {
  bool _isLoading = true;
  double _totalProfit = 0;
  List<Map<String, dynamic>> _finishedMedicines = [];

  final NumberFormat formatter = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _loadFinishedMedicinesData();
  }

  Future<void> _loadFinishedMedicinesData() async {
    try {
      final db = DatabaseHelper.instance;

      final totalProfit = await db.calculateProfitOnFinishedMedicines();

      final result = await (await db.database).query(
        'medicines',
        where: 'remaining_quantity <= 0',
      );

      print('Fetched medicines: ${result.length}');

      setState(() {
        _totalProfit = totalProfit;
        _finishedMedicines = result;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
        MaterialStateColor.resolveWith((states) => Colors.teal.shade100),
        columns: const [
          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Quantity', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Selling', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Buying', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Profit', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: _finishedMedicines.map((medicine) {
          final name = medicine['name'] ?? 'Unnamed';
          final totalQuantity = (medicine['total_quantity'] ?? 0) is int
              ? medicine['total_quantity'] as int
              : int.tryParse(medicine['total_quantity'].toString()) ?? 0;
          final sellingPrice = double.tryParse(medicine['price'].toString()) ?? 0;
          final buyingPrice = double.tryParse(medicine['buy'].toString()) ?? 0;

          final totalSales = totalQuantity * sellingPrice;
          final totalCost = totalQuantity * buyingPrice;
          final profit = totalSales - totalCost;

          return DataRow(cells: [
            DataCell(Text(name)),
            DataCell(Text('$totalQuantity')),
            DataCell(Text('TSH ${formatter.format(sellingPrice)}')),
            DataCell(Text('TSH ${formatter.format(buyingPrice)}')),
            DataCell(
              Text(
                'TSH ${formatter.format(profit)}',
                style: TextStyle(
                  color: profit >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,


      appBar: AppBar(
        title: Text(
          "📊 Finished Medicines Profit",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _finishedMedicines.isEmpty
          ? const Center(
        child: Text(
          '✅ No finished medicines found!',
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 20),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.green, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Profit',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'TSH ${formatter.format(_totalProfit)}',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildDataTable(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
