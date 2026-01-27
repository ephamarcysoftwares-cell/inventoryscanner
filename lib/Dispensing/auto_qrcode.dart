// import 'dart:async';
// import 'dart:io';
// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:multicast_dns/multicast_dns.dart';
// // import 'package:qr_code_scanner/qr_code_scanner.dart';
//
// import '../CHATBOAT/chatboat.dart';
// import '../DB/database_helper.dart';
// import 'SaleOtherproduct.dart';
// import 'cart.dart';
//
// class SaleScreen extends StatefulWidget {
//   final Map<String, dynamic> user;
//   const SaleScreen({super.key, required this.user});
//
//   @override
//   _SaleScreenState createState() => _SaleScreenState();
// }
//
// class _SaleScreenState extends State<SaleScreen> {
//   List<Map<String, dynamic>> allMedicines = [];
//   List<Map<String, dynamic>> filteredMedicines = [];
//   TextEditingController searchController = TextEditingController();
//   Map<int, int> quantities = {};
//   Timer? _timer;
//
//   // Business Info
//   String businessName = '';
//   String businessEmail = '';
//   String businessPhone = '';
//   String businessLocation = '';
//   String businessLogoPath = '';
//
//   // Node.js server IP
//   String? nodeServerIP;
//
//   @override
//   void initState() {
//     super.initState();
//     loadMedicines();
//     getBusinessInfo();
//     searchController.addListener(_filterMedicines);
//     discoverNodeServer();
//
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       loadMedicines();
//     });
//   }
//
//   @override
//   void dispose() {
//     searchController.dispose();
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   /// Load medicines from local DB
//   void loadMedicines() async {
//     final data = await fetchMedicines();
//     setState(() {
//       allMedicines = data;
//       filteredMedicines = searchController.text.isEmpty ? allMedicines : filteredMedicines;
//       for (var med in allMedicines) {
//         final medId = (med['id'] as int?) ?? 0;
//         quantities[medId] = quantities[medId] ?? 1;
//       }
//     });
//   }
//
//   Future<List<Map<String, dynamic>>> fetchMedicines() async {
//     final db = await DatabaseHelper.instance.database;
//     return await db.query('medicines');
//   }
//
//   void _filterMedicines() {
//     final query = searchController.text.toLowerCase();
//     setState(() {
//       filteredMedicines = allMedicines.where((med) {
//         final name = (med['name'] as String?) ?? '';
//         return name.toLowerCase().contains(query);
//       }).toList();
//     });
//   }
//
//   void _updateQuantity(int medicineId, int available, int change) {
//     setState(() {
//       final currentQuantity = quantities[medicineId] ?? 1;
//       final newQuantity = currentQuantity + change;
//       if (newQuantity >= 1 && newQuantity <= available) {
//         quantities[medicineId] = newQuantity;
//       }
//     });
//   }
//
//   Future<void> _addToCart(Map<String, dynamic> medicine, int quantity) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (_) => const Center(child: CircularProgressIndicator()),
//     );
//
//     final db = await DatabaseHelper.instance.database;
//     final currentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
//
//     try {
//       final result = await db.query(
//         'medicines',
//         where: 'id = ?',
//         whereArgs: [medicine['id']],
//       );
//
//       if (result.isEmpty) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine not found!')));
//         return;
//       }
//
//       final remainingQuantity = (result.first['remaining_quantity'] as int?) ?? 0;
//
//       if (quantity > remainingQuantity) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough stock!')));
//         return;
//       }
//
//       // Insert into local cart
//       await db.insert('cart', {
//         'user_id': widget.user['id'],
//         'medicine_id': medicine['id'],
//         'medicine_name': medicine['name'],
//         'company': medicine['company'],
//         'price': medicine['price'],
//         'quantity': quantity,
//         'unit': medicine['unit'],
//         'date_added': currentDate,
//         'source': 'NORMAL PRODUCT',
//       });
//
//       // Send to Node.js server if discovered
//       if (nodeServerIP != null) {
//         await sendToDesktop({
//           'user_id': widget.user['id'],
//           'medicine_id': medicine['id'],
//           'medicine_name': medicine['name'],
//           'company': medicine['company'],
//           'price': medicine['price'],
//           'quantity': quantity,
//           'unit': medicine['unit'],
//         });
//       }
//
//       // Update remaining quantity
//       int newRemaining = remainingQuantity - quantity;
//       if (newRemaining < 0) newRemaining = 0;
//
//       await db.update(
//         'medicines',
//         {'remaining_quantity': newRemaining},
//         where: 'id = ?',
//         whereArgs: [medicine['id']],
//       );
//
//       setState(() {
//         quantities[medicine['id']] = 1;
//       });
//
//       Navigator.pop(context); // close loader
//       Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(user: widget.user)));
//     } catch (e) {
//       Navigator.pop(context);
//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error adding product to cart.')));
//       print("Error: $e");
//     }
//   }
//
//   /// Discover Node.js server via mDNS
//   Future<void> discoverNodeServer() async {
//     final client = MDnsClient();
//     await client.start();
//
//     await for (final PtrResourceRecord ptr in client.lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('_http._tcp.local'))) {
//       await for (final SrvResourceRecord srv in client.lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))) {
//         await for (final IPAddressResourceRecord ip in client.lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))) {
//           setState(() {
//             nodeServerIP = ip.address.address;
//           });
//           print('Discovered Node.js server at $nodeServerIP:${srv.port}');
//           client.stop();
//           return;
//         }
//       }
//     }
//   }
//
//   /// Send product data to Node.js server
//   Future<void> sendToDesktop(Map<String, dynamic> productData) async {
//     if (nodeServerIP == null) return;
//     try {
//       final response = await http.post(
//         Uri.parse('http://$nodeServerIP:3000/add-to-cart'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode(productData),
//       );
//       if (response.statusCode == 200) {
//         print('Sent to desktop successfully!');
//       } else {
//         print('Failed: ${response.statusCode}');
//       }
//     } catch (e) {
//       print('Error sending to desktop: $e');
//     }
//   }
//
//   /// Load business info
//   Future<void> getBusinessInfo() async {
//     try {
//       final db = await DatabaseHelper.instance.database;
//       final result = await db.rawQuery('SELECT * FROM businesses');
//       if (result.isNotEmpty) {
//         setState(() {
//           businessName = result[0]['business_name']?.toString() ?? '';
//           businessEmail = result[0]['email']?.toString() ?? '';
//           businessPhone = result[0]['phone']?.toString() ?? '';
//           businessLocation = result[0]['location']?.toString() ?? '';
//           businessLogoPath = result[0]['logo']?.toString() ?? '';
//         });
//       }
//     } catch (e) {
//       print('Error loading business info: $e');
//     }
//   }
//
//   /// Open QR scanner
//   void _openQRScanner() {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => QRScanScreen(
//           onScanned: (scannedCode) async {
//             final medicine = allMedicines.firstWhere(
//                   (med) => (med['qr_code'] as String?) == scannedCode,
//               orElse: () => {},
//             );
//             if (medicine.isNotEmpty) {
//               final qty = quantities[(medicine['id'] as int?) ?? 0] ?? 1;
//               await _addToCart(medicine, qty);
//             } else {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Product not found for this QR!')),
//               );
//             }
//           },
//         ),
//       ),
//     );
//   }
//
//   /// Build UI
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('STOCK&INVENTORY SOFTWARE - DISPENSING WINDOW'),
//         backgroundColor: Colors.greenAccent,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             if (businessName.isNotEmpty)
//               Center(
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     if (businessLogoPath.isNotEmpty)
//                       Container(
//                         width: 60,
//                         height: 60,
//                         margin: const EdgeInsets.only(right: 12),
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(8),
//                           boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Image.file(File(businessLogoPath), fit: BoxFit.cover),
//                         ),
//                       ),
//                     Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(businessName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal[800])),
//                         Text('Email: $businessEmail', style: const TextStyle(fontSize: 13)),
//                         Text('Phone: $businessPhone', style: const TextStyle(fontSize: 13)),
//                         Text('Location: $businessLocation', style: const TextStyle(fontSize: 13)),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             const SizedBox(height: 20),
//             Text('Welcome, ${widget.user['full_name']}!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.teal[800])),
//             const SizedBox(height: 20),
//             Row(
//               children: [
//                 ElevatedButton.icon(onPressed: _openQRScanner, icon: const Icon(Icons.qr_code), label: const Text('Scan Product QR')),
//                 const SizedBox(width: 20),
//                 if (nodeServerIP != null)
//                   Text('Connected to desktop: $nodeServerIP', style: const TextStyle(color: Colors.green)),
//               ],
//             ),
//             const SizedBox(height: 16),
//             _buildSaleSection(context),
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 16.0),
//               child: TextField(
//                 controller: searchController,
//                 decoration: const InputDecoration(
//                   labelText: 'Search Product',
//                   border: OutlineInputBorder(),
//                   prefixIcon: Icon(Icons.search),
//                 ),
//               ),
//             ),
//             Expanded(child: SingleChildScrollView(scrollDirection: Axis.vertical, child: buildDataTable())),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// Build DataTable
//   Widget buildDataTable() {
//     return DataTable(
//       columnSpacing: 12,
//       headingRowHeight: 32,
//       dataRowHeight: 38,
//       columns: const [
//         DataColumn(label: Text('Product')),
//         DataColumn(label: Text('Company')),
//         DataColumn(label: Text('Price')),
//         DataColumn(label: Text('Stocked')),
//         DataColumn(label: Text('Sold Out')),
//         DataColumn(label: Text('Available')),
//         DataColumn(label: Text('MFG')),
//         DataColumn(label: Text('EXP')),
//         DataColumn(label: Text('Unit')),
//         DataColumn(label: Text('Actions')),
//       ],
//       rows: filteredMedicines.map((medicine) {
//         final medId = (medicine['id'] as int?) ?? 0;
//         final totalQuantity = (medicine['total_quantity'] as int?) ?? 0;
//         final remainingQuantity = (medicine['remaining_quantity'] as int?) ?? 0;
//         final soldQuantity = totalQuantity - remainingQuantity;
//         final quantity = quantities[medId] ?? 1;
//
//         return DataRow(cells: [
//           DataCell(Text(medicine['name']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis)),
//           DataCell(Text(medicine['company']?.toString() ?? '')),
//           DataCell(Text('TSH ${NumberFormat('#,##0.00', 'en_US').format(medicine['price'] ?? 0)}')),
//           DataCell(Text('$totalQuantity')),
//           DataCell(Text('$soldQuantity')),
//           DataCell(Text(remainingQuantity > 0 ? '$remainingQuantity' : 'Out of Stock', style: TextStyle(color: remainingQuantity > 0 ? Colors.black : Colors.red))),
//           DataCell(Text(medicine['manufacture_date']?.toString() ?? '')),
//           DataCell(Text(medicine['expiry_date']?.toString() ?? '')),
//           DataCell(Text(medicine['unit']?.toString() ?? '')),
//           DataCell(Row(
//             children: [
//               IconButton(icon: const Icon(Icons.remove, color: Colors.red), onPressed: () => _updateQuantity(medId, remainingQuantity, -1)),
//               SizedBox(
//                 width: 30,
//                 height: 28,
//                 child: TextField(
//                   controller: TextEditingController(text: quantity.toString()),
//                   keyboardType: TextInputType.number,
//                   textAlign: TextAlign.center,
//                   onChanged: (value) {
//                     int? newQty = int.tryParse(value);
//                     if (newQty != null && newQty >= 1 && newQty <= remainingQuantity) {
//                       setState(() => quantities[medId] = newQty);
//                     }
//                   },
//                 ),
//               ),
//               IconButton(icon: const Icon(Icons.add, color: Colors.green), onPressed: quantity < remainingQuantity ? () => _updateQuantity(medId, remainingQuantity, 1) : null),
//               if (remainingQuantity > 0)
//                 IconButton(icon: const Icon(Icons.shopping_cart, color: Colors.green), onPressed: () => _addToCart(medicine, quantity)),
//             ],
//           )),
//         ]);
//       }).toList(),
//     );
//   }
//
//   Widget _buildSaleSection(BuildContext context) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         GestureDetector(
//           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SaleOther(user: widget.user))),
//           child: Container(
//             padding: const EdgeInsets.all(15),
//             margin: const EdgeInsets.only(bottom: 15),
//             decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
//             child: Row(
//               children: const [
//                 Icon(Icons.shopping_basket, color: Colors.white),
//                 SizedBox(width: 15),
//                 Text('Go to Other Products Sales', style: TextStyle(fontSize: 24, color: Colors.white)),
//               ],
//             ),
//           ),
//         ),
//         GestureDetector(
//           onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen(user: widget.user))),
//           child: Container(
//             padding: const EdgeInsets.all(15),
//             margin: const EdgeInsets.only(bottom: 15),
//             decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
//             child: Row(
//               children: const [
//                 Icon(Icons.medication, color: Colors.white),
//                 SizedBox(width: 15),
//                 Text('View Pending Bill', style: TextStyle(fontSize: 24, color: Colors.white)),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// /// QR Scanner Screen
// class QRScanScreen extends StatefulWidget {
//   final Function(String) onScanned;
//   const QRScanScreen({super.key, required this.onScanned});
//
//   @override
//   _QRScanScreenState createState() => _QRScanScreenState();
// }
//
// class _QRScanScreenState extends State<QRScanScreen> {
//   final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
//   QRViewController  controller;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Scan QR Code')),
//       body: QRView(key: qrKey, onQRViewCreated: _onQRViewCreated),
//     );
//   }
//
//   void _onQRViewCreated(QRViewController ctrl) {
//     controller = ctrl;
//     controller!.scannedDataStream.listen((scanData) {
//       widget.onScanned(scanData.code ?? '');
//       Navigator.pop(context);
//     });
//   }
//
//   @override
//   void dispose() {
//     controller?.dispose();
//     super.dispose();
//   }
// }
//
// class QRView {
// }
//
// class QRViewController {
// }
