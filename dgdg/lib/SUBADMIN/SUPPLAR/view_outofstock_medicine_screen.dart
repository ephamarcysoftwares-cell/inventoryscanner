import 'package:flutter/material.dart';

import '../../DB/database_helper.dart';
import '../../FOTTER/CurvedRainbowBar.dart';


class ViewOutOfStockMedicineScreen extends StatefulWidget {
  const ViewOutOfStockMedicineScreen({super.key});

  @override
  _ViewOutOfStockMedicineScreenState createState() =>
      _ViewOutOfStockMedicineScreenState();
}

class _ViewOutOfStockMedicineScreenState
    extends State<ViewOutOfStockMedicineScreen> {
  late Future<List<Map<String, dynamic>>> outOfStockMedicines;

  @override
  void initState() {
    super.initState();
    outOfStockMedicines = DatabaseHelper.instance.fetchOutOfStockMedicines();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Out of Stock Products",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: outOfStockMedicines,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No out-of-stock products available.'));
          } else {
            final medicines = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.builder(
                itemCount: medicines.length,
                itemBuilder: (context, index) {
                  final medicine = medicines[index];
                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      title: Text(medicine['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Category: ${medicine['category']}'),
                          Text('Expiry Date: ${medicine['expiryDate']}'),
                          Text('Quantity: ${medicine['quantity']}'),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
