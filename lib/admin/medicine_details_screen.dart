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
    double price = medicine['price']?.toDouble() ?? 0.0;
    int total_quantity = medicine['total_quantity'] ?? 0;
    int remain_quantity = medicine['remain_quantity'] ?? 0;

    String manufacturedDate = medicine['manufacture_date'] ?? 'N/A';
    String expiryDate = medicine['expiry_date'] ?? 'N/A';
    String addedBy = medicine['added_by'] ?? 'Unknown';
    String addedTime = medicine['added_time'] ?? 'Unknown Time';

    return Scaffold(
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            name,
            textAlign: TextAlign.center,
            softWrap: true, // Inaruhusu jina kushuka mstari kwenye AppBar
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        toolbarHeight: 80, // Inatoa nafasi kwa jina refu kwenye AppBar
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // Inahakikisha page nzima ina-scroll ikibidi
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 40,
                  // MUHIMU: Inaruhusu row kurefuka kulingana na jina
                  dataRowMinHeight: 50,
                  dataRowMaxHeight: double.infinity,
                  columns: const [
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
                      const DataCell(Text("Name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      DataCell(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.5, // 50% ya upana wa screen
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 16),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                      ),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Company", style: TextStyle(fontSize: 16))),
                      DataCell(Text(company, style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Price", style: TextStyle(fontSize: 16))),
                      DataCell(Text("TSH ${NumberFormat('#,##0.00', 'en_US').format(price)}", style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Total Qty", style: TextStyle(fontSize: 16))),
                      DataCell(Text("$total_quantity", style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Rem Qty", style: TextStyle(fontSize: 16))),
                      DataCell(Text("$remain_quantity", style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("MFG Date", style: TextStyle(fontSize: 16))),
                      DataCell(Text(manufacturedDate, style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Expiry Date", style: TextStyle(fontSize: 16))),
                      DataCell(Text(expiryDate, style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Added By", style: TextStyle(fontSize: 16))),
                      DataCell(Text(addedBy, style: const TextStyle(fontSize: 16))),
                    ]),
                    DataRow(cells: [
                      const DataCell(Text("Time Added", style: TextStyle(fontSize: 16))),
                      DataCell(Text(addedTime, style: const TextStyle(fontSize: 16))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Tunatumia Wrap badala ya Row ili button isilete overflow kwenye screen ndogo
              Wrap(
                spacing: 20, // Nafasi ya pembeni
                runSpacing: 15, // Nafasi ya kwenda chini kama zikijipanga Column
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 20),
                    label: const Text("Edit Product", style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final rawSynced = medicine['synced'];
                      int safeSynced = (rawSynced is bool) ? (rawSynced ? 1 : 0) : (rawSynced ?? 0);

                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditMedicineScreen(
                            id: medicine['id'],
                            name: name,
                            company: company,
                            total_quantity: total_quantity,
                            remaining_quantity: remain_quantity,
                            buy: medicine['buy']?.toDouble() ?? 0.0,
                            price: price,
                            batchNumber: medicine['batchNumber'] ?? '',
                            manufacturedDate: manufacturedDate,
                            expiryDate: expiryDate,
                            added_by: addedBy,
                            discount: medicine['discount']?.toDouble() ?? 0.0,
                            added_time: addedTime,
                            unit: medicine['unit'] ?? '',
                            businessName: medicine['businessName'] ?? '',
                            synced: safeSynced,
                            user: const {},
                          ),
                        ),
                      );
                      if (result == true) Navigator.pop(context, true);
                    },
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete, size: 20),
                    label: const Text("Delete Product", style: TextStyle(fontSize: 18)), // Punguza kidogo size hapa
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Delete Product"),
                          content: const Text("Are you sure you want to delete this Product?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Delete", style: TextStyle(color: Colors.red))
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true) {
                        bool deleted = await deleteMedicine(medicine['id']);
                        if (deleted) {
                          Navigator.pop(context, true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Failed to delete the Product.")),
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
