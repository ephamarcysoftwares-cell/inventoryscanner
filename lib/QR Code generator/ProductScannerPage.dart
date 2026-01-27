// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
//
//
// class ProductScannerPage extends StatefulWidget {
//   const ProductScannerPage({super.key});
//
//   @override
//   State<ProductScannerPage> createState() => _ProductScannerPageState();
// }
//
// class _ProductScannerPageState extends State<ProductScannerPage> {
//   String? scannedUrl;
//   Map<String, dynamic>? productData;
//   bool isLoading = false;
//   bool hasScanned = false;
//
//   void fetchProductData(String url) async {
//     setState(() {
//       isLoading = true;
//       scannedUrl = url;
//     });
//
//     try {
//       final response = await http.get(Uri.parse(url));
//       if (response.statusCode == 200) {
//         setState(() {
//           productData = jsonDecode(response.body);
//         });
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//           content: Text("Server returned ${response.statusCode}"),
//         ));
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text("Error: $e"),
//       ));
//     } finally {
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }
//
//   void onDetect(BarcodeCapture barcode) {
//     if (hasScanned) return;
//     hasScanned = true;
//
//     final code = barcode.barcodes.first.rawValue;
//     if (code != null && code.startsWith("https://ephamarcysoftware.co.tz")) {
//       fetchProductData(code);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text("Invalid QR or Barcode scanned."),
//       ));
//       hasScanned = false; // allow retry
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Scan Product QR/Barcode"),
//         backgroundColor: Colors.green,
//       ),
//       body: Column(
//         children: [
//           if (!hasScanned)
//             SizedBox(
//               height: 300,
//               child: MobileScanner(
//                 onDetect: onDetect,
//               ),
//             )
//
//           else if (isLoading)
//             const Padding(
//               padding: EdgeInsets.all(20),
//               child: CircularProgressIndicator(),
//             )
//           else if (productData != null)
//               Expanded(
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Card(
//                     elevation: 4,
//                     child: ListView(
//                       padding: const EdgeInsets.all(16),
//                       children: [
//                         const Text("Product Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                         const SizedBox(height: 10),
//                         Text("ID: ${productData!['id']}"),
//                         Text("Name: ${productData!['name']}"),
//                         Text("Price: ${productData!['price']}"),
//                         Text("Quantity: ${productData!['quantity']}"),
//                         Text("Expiry: ${productData!['expiry']}"),
//                         const SizedBox(height: 20),
//                         ElevatedButton.icon(
//                           icon: const Icon(Icons.refresh),
//                           label: const Text("Scan Again"),
//                           onPressed: () {
//                             setState(() {
//                               productData = null;
//                               hasScanned = false;
//                             });
//                           },
//                         )
//                       ],
//                     ),
//                   ),
//                 ),
//               )
//             else
//               const Text("No data yet..."),
//         ],
//       ),
//     );
//   }
// }
