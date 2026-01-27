import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewExpiredMedicineScreen extends StatefulWidget {
  const ViewExpiredMedicineScreen({super.key});

  @override
  _ViewExpiredMedicineScreenState createState() => _ViewExpiredMedicineScreenState();
}

class _ViewExpiredMedicineScreenState extends State<ViewExpiredMedicineScreen> {
  late Future<List<Map<String, dynamic>>> expiredMedicines;

  @override
  void initState() {
    super.initState();
    expiredMedicines = fetchExpiredMedicines();
    sendExpiredMedicinesToAdmin(); // Send email on load
  }

  Future<List<Map<String, dynamic>>> fetchExpiredMedicines() async {
    final db = await DatabaseHelper.instance.database;
    final dateNow = DateTime.now().toIso8601String().split('T')[0];
    return await db.query(
      'medicines',
      where: 'expiry_date < ?',
      whereArgs: [dateNow],
    );
  }

  Future<String?> getAdminEmail() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );
    if (result.isNotEmpty) {
      return result.first['email'] as String?;
    }
    return null;
  }

  Future<void> sendExpiredMedicinesToAdmin() async {
    final List<Map<String, dynamic>> expired = await fetchExpiredMedicines();
    if (expired.isEmpty) return;

    String? adminEmail = await getAdminEmail();
    if (adminEmail == null) {
      print("Admin email not found.");
      return;
    }
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );
     // Use your app password here

    String body = 'The following Products have expired:\n\n';
    for (var med in expired) {
      body +=
      '- ${med['name']} (Qty: ${med['quantity']}, Price: TSH ${med['price']}, Expired: ${med['expiry_date']})\n';
    }

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
      ..recipients.add(adminEmail)
      ..subject = 'Expired product Report - ${DateTime.now().toLocal()}'
      ..text = body;

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: ${sendReport.toString()}');
    } catch (e) {
      print('Email failed to send: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Expired Products",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: expiredMedicines,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No expired products.'));
          }

          final expiredList = snapshot.data!;

          return Column(
            children: [
              // Use SingleChildScrollView to enable vertical scrolling
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(Colors.teal[100]),
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Price')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Available')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('MFG')),
                        DataColumn(label: Text('EXP')),
                        // DataColumn(label: Text('Delete')),
                      ],
                      rows: expiredList.map((med) {
                        return DataRow(cells: [
                          DataCell(Text(med['name'] ?? '')),
                          DataCell(Text('TSH ${NumberFormat('#,##0.00', 'en_US').format(med['price'] ?? 0)}')),

                          DataCell(Text('${med['total_quantity'] ?? '0'}')),
                          DataCell(Text('${med['remaining_quantity'] ?? '0'}')),
                          DataCell(Text(med['unit'] ?? '')),
                          DataCell(Text(med['manufacture_date'] ?? '')),
                          DataCell(Text(
                            med['expiry_date'] ?? '',
                            style: TextStyle(color: Colors.red),
                          )),
                          // DataCell(
                          //   IconButton(
                          //     icon: Icon(Icons.delete, color: Colors.red),
                          //     onPressed: () {
                          //       _confirmDelete(context, med['id']);
                          //     },
                          //   ),
                          // ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),

    );
  }

  void _confirmDelete(BuildContext context, int medicineId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Deletion"),
          content: Text("Are you sure you want to delete this expired Product?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                _deleteExpiredMedicine(medicineId);
                Navigator.of(context).pop();
              },
              child: Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteExpiredMedicine(int medicineId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'medicines',
      where: 'id = ?',
      whereArgs: [medicineId],
    );
    setState(() {
      expiredMedicines = fetchExpiredMedicines(); // Refresh the list
    });
  }
}
