import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../DB/database_helper.dart';
import 'package:stock_and_inventory_software/admin/re-add.dart';

import '../../FOTTER/CurvedRainbowBar.dart';

class RestockCheckerScreenUser extends StatefulWidget {
  final Map<String, dynamic> user;

  RestockCheckerScreenUser({required this.user});

  @override
  _RestockCheckerScreenUserState createState() =>
      _RestockCheckerScreenUserState();
}

class _RestockCheckerScreenUserState extends State<RestockCheckerScreenUser> {
  final ScrollController _verticalScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _expiredOrOutOfStock = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllProducts();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllProducts() async {
    setState(() {
      _expiredOrOutOfStock.clear();
    });
    await _checkMedicines();
    await _checkOtherProducts();
  }

  Future<void> _checkOtherProducts() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    String whereClause = '''
      (remaining_quantity <= 0 OR expiry_date < ?)
    ''';
    List<dynamic> whereArgs = [now];

    if (_searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR batch_number LIKE ?)';
      String queryLike = '%${_searchQuery.trim()}%';
      whereArgs.addAll([queryLike, queryLike]);
    }

    final result = await db.query(
      'other_product',
      where: whereClause,
      whereArgs: whereArgs,
    );

    setState(() {
      _expiredOrOutOfStock.addAll(result.map((item) => {
        'name': item['name'],
        'batchNumber': item['batch_number'],
        'remaining_quantity': item['remaining_quantity'],
        'expiry_date': item['expiry_date'],
        'source': 'Other Product',
        ...item,
      }));
    });
  }

  Future<void> _checkMedicines() async {
    setState(() {
      _isLoading = true;
    });
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    String whereClause = '''
      (remaining_quantity <= 0 OR expiry_date < ?)
    ''';
    List<dynamic> whereArgs = [now];

    if (_searchQuery.trim().isNotEmpty) {
      whereClause += ' AND (name LIKE ? OR batchNumber LIKE ?)';
      String queryLike = '%${_searchQuery.trim()}%';
      whereArgs.addAll([queryLike, queryLike]);
    }

    final result = await db.query(
      'medicines',
      where: whereClause,
      whereArgs: whereArgs,
    );

    setState(() {
      _expiredOrOutOfStock.addAll(result.map((item) => {
        'name': item['name'],
        'batchNumber': item['batchNumber'],
        'remaining_quantity': item['remaining_quantity'],
        'expiry_date': item['expiry_date'],
        'source': 'Normal product',
        ...item,
      }));
      _isLoading = false;
    });
  }

  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return 'Invalid date';
    }
  }

  bool isExpired(String expiryDate) {
    try {
      final expiry = DateTime.parse(expiryDate);
      return expiry.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "STOCK & INVENTORY SOFTWARE - Expired & Out of Stock",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isLoading
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Loading products...'),
              ],
            ),
          )
              : _expiredOrOutOfStock.isEmpty
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: Colors.green.shade300,
                ),
                SizedBox(height: 16),
                Text(
                  'All products are in stock and not expired!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
              : Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            thickness: 10,
            radius: Radius.circular(10),
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  // Search box
                  LayoutBuilder(
                    builder: (context, constraints) {
                      double width = constraints.maxWidth > 500
                          ? 500
                          : constraints.maxWidth;
                      return Center(
                        child: SizedBox(
                          width: width,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText:
                              'Search by name or batch number',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                  _loadAllProducts();
                                },
                              )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                              _loadAllProducts();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.red, width: 2),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Center(
                          child: DataTable(
                            columnSpacing: 20,
                            headingRowColor:
                            MaterialStateProperty.all(
                                Colors.blue.shade100),
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(
                                  label: Text('Batch Number')),
                              DataColumn(
                                  label: Text('Remaining Qty')),
                              DataColumn(
                                  label: Text('Expiry Date')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Source')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: _expiredOrOutOfStock.map((med) {
                              final expired =
                              isExpired(med['expiry_date']);
                              final outOfStock =
                                  med['remaining_quantity'] <= 0;
                              final statusText = expired
                                  ? 'Expired'
                                  : outOfStock
                                  ? 'Out of Stock'
                                  : 'OK';
                              final statusColor = expired
                                  ? Colors.red.shade700
                                  : outOfStock
                                  ? Colors.orange.shade700
                                  : Colors.green.shade700;

                              return DataRow(cells: [
                                DataCell(Text(
                                  '${med['name']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                      Colors.green.shade900),
                                )),
                                DataCell(Text(
                                    '${med['batchNumber']}')),
                                DataCell(Text(
                                    '${med['remaining_quantity']}')),
                                DataCell(Text(
                                  formatDate(med['expiry_date']),
                                  style: TextStyle(
                                    color: expired
                                        ? Colors.red.shade700
                                        : Colors.grey.shade700,
                                    fontWeight: expired
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                )),
                                DataCell(Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                                DataCell(Text(
                                  '${med['source']}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade900),
                                )),
                                DataCell(
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                      Colors.green.shade600,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10),
                                      shape:
                                      RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(
                                            8),
                                      ),
                                    ),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReaddMedicineScreen(
                                                user: widget.user,
                                                initialData: med,
                                                // source: med['source'],
                                              ),
                                        ),
                                      );
                                      _loadAllProducts();
                                    },
                                    child: Text(
                                      "Re-Enter",
                                      style:
                                      TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
