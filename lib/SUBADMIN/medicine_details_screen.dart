import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '/DB/database_helper.dart';  // Import DatabaseHelper to access delete method
import 'edit_medicine_screen.dart';

class MedicineDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> medicine;

  const MedicineDetailsScreen({super.key, required this.medicine});

  @override
  Widget build(BuildContext context) {
    String name = medicine['name'] ?? 'Unknown Name';
    String company = medicine['company'] ?? 'Unknown Company';
    double price = medicine['price'] ?? 0.0;
    int total_quantity = medicine['total_quantity'] ?? 0;
    int remain_quantity = medicine['remain_quantity'] ?? 0;

    String manufacturedDate = medicine['manufacture_date'] ?? 'N/A';
    String expiryDate = medicine['expiry_date'] ?? 'N/A';
    String addedBy = medicine['added_by'] ?? 'Unknown';
    String addedTime = medicine['added_time'] ?? 'Unknown Time';

    return Scaffold(

      appBar: AppBar(
        title: Text(
          name,
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
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowHeight: 60,
                columns: [
                  DataColumn(
                    label: Text(
                      'Attribute',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Value',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
                rows: [
                  DataRow(cells: [
                    DataCell(Text("Name", style: TextStyle(fontSize: 16))),
                    DataCell(Text(name, style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Company", style: TextStyle(fontSize: 16))),
                    DataCell(Text(company, style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Price", style: TextStyle(fontSize: 16))),
                    DataCell(Text("TSH ${NumberFormat('#,##0.00', 'en_US').format(price)}", style: TextStyle(fontSize: 16))),

                  ]),
                  DataRow(cells: [
                    DataCell(Text("quantity", style: TextStyle(fontSize: 16))),
                    DataCell(Text("$total_quantity", style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Quantity", style: TextStyle(fontSize: 16))),
                    DataCell(Text("$remain_quantity", style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Manufactured Date", style: TextStyle(fontSize: 16))),
                    DataCell(Text(manufacturedDate, style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Expiry Date", style: TextStyle(fontSize: 16))),
                    DataCell(Text(expiryDate, style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Added By", style: TextStyle(fontSize: 16))),
                    DataCell(Text(addedBy, style: TextStyle(fontSize: 16))),
                  ]),
                  DataRow(cells: [
                    DataCell(Text("Time Added", style: TextStyle(fontSize: 16))),
                    DataCell(Text(addedTime, style: TextStyle(fontSize: 16))),
                  ]),
                ],
              ),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.edit, size: 20),
                  label: Text("Edit Product", style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    // CRITICAL: Convert bool to int before passing to the Edit screen
                    final rawSynced = medicine['synced'];
                    int safeSynced = 0;
                    if (rawSynced is bool) {
                      safeSynced = rawSynced ? 1 : 0;
                    } else if (rawSynced is int) {
                      safeSynced = rawSynced;
                    }

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditMedicineScreen(
                          id: medicine['id'],
                          name: name,
                          company: company,
                          total_quantity: medicine['total_quantity'] ?? 0,
                          remaining_quantity: remain_quantity,
                          buy: medicine['buy']?.toDouble() ?? 0.0,
                          price: price,
                          batchNumber: medicine['batchNumber'] ?? '',
                          manufacturedDate: manufacturedDate,
                          expiryDate: expiryDate,
                          added_by: medicine['added_by'] ?? '',
                          discount: medicine['discount']?.toDouble() ?? 0.0,
                          added_time: medicine['added_time'] ?? '',
                          unit: medicine['unit'] ?? '',
                          businessName: medicine['businessName'] ?? '',
                          synced: safeSynced, // Use the converted value here
                        ),
                      ),
                    );

                    if (result == true) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
                SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.delete, size: 20),
                  label: Text("Delete Product", style: TextStyle(fontSize: 24)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    bool confirmDelete = await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Delete Product"),
                          content: Text("Are you sure you want to delete this Product?"),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: Text("Delete", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        );
                      },
                    );

                    if (confirmDelete) {
                      bool deleted = await deleteMedicine(medicine['id']);

                      if (deleted) {
                        Navigator.pop(context, true); // Refresh list after deletion
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to delete the Product.")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Future<bool> deleteMedicine(int id) async {
    final db = await DatabaseHelper.instance.database;
    try {
      await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
      return true; // Return true if deletion is successful
    } catch (e) {
      return false; // Return false if there's an error
    }
  }
}
