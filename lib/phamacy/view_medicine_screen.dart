import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewMedicineScreen extends StatefulWidget {
  // If you want to show user's name, pass user map to constructor like this:
  final Map<String, dynamic>? user;
  const ViewMedicineScreen({Key? key, this.user}) : super(key: key);

  @override
  _ViewMedicineScreenState createState() => _ViewMedicineScreenState();
}

class _ViewMedicineScreenState extends State<ViewMedicineScreen> {
  late Future<List<Map<String, dynamic>>> medicines;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    loadMedicines();
  }

  void loadMedicines() {
    setState(() {
      medicines = fetchMedicines(searchQuery: searchQuery);
    });
  }

  Future<List<Map<String, dynamic>>> fetchMedicines({
    String searchQuery = '',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await DatabaseHelper.instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery.isNotEmpty) {
      whereClause = '(name LIKE ? OR company LIKE ? OR expiry_date LIKE ?)';
      whereArgs.addAll([
        '%$searchQuery%',
        '%$searchQuery%',
        '%$searchQuery%',
      ]);
    }

    if (startDate != null && endDate != null) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'expiry_date BETWEEN ? AND ?';
      whereArgs.add(startDate.toIso8601String());
      whereArgs.add(endDate.toIso8601String());
    }

    List<Map<String, dynamic>> results;
    if (whereClause.isEmpty) {
      results = await db.query('medicines');
    } else {
      results = await db.query(
        'medicines',
        where: whereClause,
        whereArgs: whereArgs,
      );
    }

    // Fix negative remaining_quantity and set status
    return results.map((medicine) {
      final mutableMedicine = Map<String, dynamic>.from(medicine);
      int remaining_quantity = int.tryParse(
          mutableMedicine['remaining_quantity'].toString()) ?? 0;

      if (remaining_quantity < 0) {
        remaining_quantity = 0;
      }

      mutableMedicine['remaining_quantity'] = remaining_quantity;
      mutableMedicine['status'] =
      remaining_quantity <= 0 ? 'OUT OF STOCK' : 'Issued';

      return mutableMedicine;
    }).toList();
  }

  Widget _buildSaleSection(BuildContext context) {
    // You can customize this widget if you want
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Sales summary here (customize as needed)',
        style: TextStyle(color: Colors.green[800]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "VIEW NORMAL PRODUCTS",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.user != null && widget.user!['full_name'] != null) ...[
              Text(
                'Welcome, ${widget.user!['full_name']}!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.teal[800],
                ),
              ),
              SizedBox(height: 20),
            ],
            Text(
              'Sales Overview',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[600]),
            ),
            SizedBox(height: 10),
            _buildSaleSection(context),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Search product',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green, width: 2),
                  ),
                ),
                onChanged: (value) {
                  searchQuery = value;
                  loadMedicines();
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: medicines,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(child: Text('No product available.'));
                  }

                  final medicineList = snapshot.data!;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: ConstrainedBox(
                          constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                          child: DataTable(
                            columnSpacing: 12,
                            headingRowHeight: 32,
                            dataRowHeight: 48,
                            columns: [
                              DataColumn(
                                  label: Text('Product',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('Company',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('Price',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('Stocked',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('Available',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('MFG',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('EXP',
                                      style: TextStyle(fontSize: 13))),
                              DataColumn(
                                  label: Text('Unit',
                                      style: TextStyle(fontSize: 13))),
                            ],
                            rows: medicineList.map((medicine) {
                              int totalQuantity =
                                  medicine['total_quantity'] ?? 0;
                              int remainingQuantity =
                                  medicine['remaining_quantity'] ?? 0;

                              return DataRow(cells: [
                                DataCell(Text(medicine['name'] ?? '',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(medicine['company'] ?? '',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(
                                    'TSH ${NumberFormat('#,##0.00', 'en_US').format(medicine['price'] ?? 0)}',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(
                                    '${NumberFormat('#,##0', 'en_US').format(totalQuantity)}',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(
                                  remainingQuantity > 0
                                      ? '$remainingQuantity'
                                      : 'Out of Stock',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: remainingQuantity > 0
                                        ? Colors.black
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                                DataCell(Text(medicine['manufacture_date'] ?? '',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(medicine['expiry_date'] ?? '',
                                    style: TextStyle(fontSize: 12))),
                                DataCell(Text(medicine['unit'] ?? '',
                                    style: TextStyle(fontSize: 12))),
                              ]);
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
