// import 'package:flutter/material.dart';
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:path_provider/path_provider.dart';
// import 'dart:io';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../DB/database_helper.dart';
// import '../admin/medicine_details_screen.dart'; // To navigate to the edit screen
//
// class ManageStore extends StatefulWidget {
//   const ManageStore({super.key});
//
//   @override
//   _ManageStoreState createState() => _ManageStoreState();
// }
//
// class _ManageStoreState extends State<ManageStore> {
//   late Future<List<Map<String, dynamic>>> medicines;
//   TextEditingController searchController = TextEditingController();
//   String searchQuery = "";
//   DateTime? startDate;
//   DateTime? endDate;
//
//   Map<int, bool> isSelected = {}; // Tracks if each medicine is selected
//   Map<int, double> selectedMedicines = {}; // Maps selected ID to discount
//   double defaultDiscountValue = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     loadMedicines();
//   }
//
//   void loadMedicines() {
//     setState(() {
//       medicines = fetchMedicines();
//     });
//   }
//
//   Future<List<Map<String, dynamic>>> fetchMedicines() async {
//     final db = await DatabaseHelper.instance.database;
//
//     String dateRangeCondition = "";
//     List<dynamic> whereArgs = [];
//
//     if (searchQuery.isNotEmpty) {
//       dateRangeCondition =
//       "name LIKE ? OR company LIKE ? OR batchNumber LIKE ?";
//       whereArgs = [
//         '%$searchQuery%',
//         '%$searchQuery%',
//         '%$searchQuery%',
//       ];
//     }
//
//     if (startDate != null && endDate != null) {
//       dateRangeCondition +=
//       "${dateRangeCondition.isEmpty ? "" : " AND "}added_time BETWEEN ? AND ?";
//       whereArgs.add(startDate!.toIso8601String());
//       whereArgs.add(endDate!.toIso8601String());
//     }
//
//     if (dateRangeCondition.isEmpty) {
//       return await db.query('store');
//     } else {
//       return await db.query(
//         'store',
//         where: dateRangeCondition,
//         whereArgs: whereArgs,
//       );
//     }
//   }
//
//   void deleteMedicine(int id) async {
//     await DatabaseHelper.instance.deleteMedicine(id);
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text('Medicine deleted!')));
//     loadMedicines();
//   }
//
//   Future<void> migrateStoreToMedicinesWithDiscount({
//     required String businessName,
//     required Map<int, double> selectedMedicines,
//   }) async {
//     final db = await DatabaseHelper.instance.database;
//
//     for (final id in selectedMedicines.keys) {
//       final medicine =
//       await db.query('store', where: 'id = ?', whereArgs: [id]);
//
//       if (medicine.isNotEmpty) {
//         final item = medicine.first;
//         double discount = selectedMedicines[id] ?? 0;
//
//         await db.insert('medicines', {
//           'name': item['name'],
//           'company': item['company'],
//           'quantity': item['quantity'],
//           'price': item['price'],
//           'buy': item['buy'],
//           'discount': discount,
//           'manufacture_date': item['manufacture_date'],
//           'expiry_date': item['expiry_date'],
//           'batchNumber': item['batchNumber'],
//           'added_by': item['added_by'],
//           'added_time': item['added_time'],
//         });
//
//         await db.delete('store', where: 'id = ?', whereArgs: [id]);
//       }
//     }
//
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       content: Text("Migration complete!"),
//     ));
//
//     loadMedicines();
//   }
//
//   Future<String> getLoggedInUserName() async {
//     SharedPreferences prefs = await SharedPreferences.getInstance();
//     return prefs.getString('user') ?? '..........';
//   }
//
//   Future<void> _selectStartDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: startDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != startDate)
//       setState(() {
//         startDate = picked;
//         loadMedicines();
//       });
//   }
//
//   Future<void> _selectEndDate(BuildContext context) async {
//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: endDate ?? DateTime.now(),
//       firstDate: DateTime(2000),
//       lastDate: DateTime(2101),
//     );
//     if (picked != null && picked != endDate)
//       setState(() {
//         endDate = picked;
//         loadMedicines();
//       });
//   }
//
//   Future<void> generateAndSavePdf() async {
//     final pdf = pw.Document();
//     final directory = await getApplicationDocumentsDirectory();
//     final path = "${directory.path}/selected_medicines_report.pdf";
//
//     final medicinesList = await medicines;
//
//     pdf.addPage(
//       pw.Page(
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Text('Selected Medicines Report',
//                   style: pw.TextStyle(
//                       fontSize: 22, fontWeight: pw.FontWeight.bold)),
//               pw.SizedBox(height: 10),
//               pw.Table.fromTextArray(
//                 headers: [
//                   'Name',
//                   'Company',
//                   'Quantity',
//                   'Price',
//                   'Discount',
//                 ],
//                 data: selectedMedicines.entries.map((entry) {
//                   final id = entry.key;
//                   final medicine =
//                   medicinesList.firstWhere((med) => med['id'] == id);
//                   return [
//                     medicine['name'] ?? '',
//                     medicine['company'] ?? '',
//                     medicine['quantity'].toString(),
//                     medicine['price'].toString(),
//                     entry.value.toStringAsFixed(2),
//                   ];
//                 }).toList(),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//
//     final file = File(path);
//     await file.writeAsBytes(await pdf.save());
//
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text("PDF saved at: $path")));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     double screenWidth = MediaQuery.of(context).size.width;
//     double screenHeight = MediaQuery.of(context).size.height;
//
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.green,
//         title: Text('Store Medicines'),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.upload_rounded),
//             tooltip: 'Migrate Selected',
//             onPressed: () {
//               if (selectedMedicines.isNotEmpty) {
//                 migrateStoreToMedicinesWithDiscount(
//                   businessName: "E-PHARMACY",
//                   selectedMedicines: selectedMedicines,
//                 );
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                     SnackBar(content: Text("No medicine selected")));
//               }
//             },
//           ),
//           IconButton(
//             icon: Icon(Icons.picture_as_pdf),
//             tooltip: 'Export to PDF',
//             onPressed: () {
//               if (selectedMedicines.isNotEmpty) {
//                 generateAndSavePdf();
//               } else {
//                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                     content: Text("No medicine selected to generate PDF")));
//               }
//             },
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(screenWidth * 0.01),
//         child: Column(
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   onPressed: () => _selectStartDate(context),
//                   child: Text(startDate == null
//                       ? 'Start Date'
//                       : '${startDate!.toLocal()}'.split(' ')[0]),
//                 ),
//                 ElevatedButton(
//                   onPressed: () => _selectEndDate(context),
//                   child: Text(endDate == null
//                       ? 'End Date'
//                       : '${endDate!.toLocal()}'.split(' ')[0]),
//                 ),
//               ],
//             ),
//             SizedBox(height: screenHeight * 0.01),
//             TextField(
//               controller: searchController,
//               decoration: InputDecoration(
//                 labelText: 'Search Medicine',
//                 prefixIcon: Icon(Icons.search),
//                 border: OutlineInputBorder(),
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   searchQuery = value;
//                   loadMedicines();
//                 });
//               },
//             ),
//             SizedBox(height: screenHeight * 0.01),
//             FutureBuilder<List<Map<String, dynamic>>>(
//               future: medicines,
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting)
//                   return CircularProgressIndicator();
//                 if (snapshot.hasError)
//                   return Text('Error: ${snapshot.error}');
//                 final data = snapshot.data ?? [];
//
//                 return Expanded(
//                   child: SingleChildScrollView(
//                     scrollDirection: Axis.horizontal,
//                     child: DataTable(
//                       columns: [
//                         DataColumn(label: Text('Select')),
//                         DataColumn(label: Text('Name')),
//                         DataColumn(label: Text('Company')),
//                         DataColumn(label: Text('Qty')),
//                         DataColumn(label: Text('Buy')),
//                         DataColumn(label: Text('Price')),
//                         DataColumn(label: Text('Batch')),
//                         DataColumn(label: Text('MFD')),
//                         DataColumn(label: Text('EXP')),
//                         DataColumn(label: Text('By')),
//                         DataColumn(label: Text('Time')),
//                         DataColumn(label: Text('Actions')),
//                       ],
//                       rows: data.map((medicine) {
//                         int id = medicine['id'];
//                         return DataRow(
//                           cells: [
//                             DataCell(Checkbox(
//                               value: isSelected[id] ?? false,
//                               onChanged: (value) {
//                                 setState(() {
//                                   isSelected[id] = value ?? false;
//                                   if (value == true) {
//                                     selectedMedicines[id] = defaultDiscountValue;
//                                   } else {
//                                     selectedMedicines.remove(id);
//                                   }
//                                 });
//                               },
//                             )),
//                             DataCell(Text(medicine['name'] ?? '')),
//                             DataCell(Text(medicine['company'] ?? '')),
//                             DataCell(Text(medicine['quantity'].toString())),
//                             DataCell(Text(medicine['buy'].toString())),
//                             DataCell(Text(medicine['price'].toString())),
//                             DataCell(Text(medicine['batchNumber'] ?? '')),
//                             DataCell(Text(medicine['manufacture_date'] ?? '')),
//                             DataCell(Text(medicine['expiry_date'] ?? '')),
//                             DataCell(Text(medicine['added_by'] ?? '')),
//                             DataCell(Text(medicine['added_time'] ?? '')),
//                             DataCell(Row(
//                               children: [
//                                 IconButton(
//                                   icon: Icon(Icons.edit),
//                                   onPressed: () {
//                                     Navigator.push(
//                                       context,
//                                       MaterialPageRoute(
//                                           builder: (context) => MedicineDetailsScreen(medicineId: id, medicine: {},)),
//                                     );
//                                   },
//                                 ),
//                                 IconButton(
//                                   icon: Icon(Icons.delete),
//                                   onPressed: () {
//                                     deleteMedicine(id);
//                                   },
//                                 ),
//                               ],
//                             )),
//                           ],
//                         );
//                       }).toList(),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
