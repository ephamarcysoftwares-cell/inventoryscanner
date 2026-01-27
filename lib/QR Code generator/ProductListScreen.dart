// import 'package:flutter/material.dart';
// import 'package:untitled3/QR%20Code%20generator/product.dart';
// // Import the SQLite library
//
// class ProductListScreen extends StatefulWidget {
//   @override
//   _ProductListScreenState createState() => _ProductListScreenState();
// }
//
// class _ProductListScreenState extends State<ProductListScreen> {
//   late Future<List<Product>> _productList;
//
//   @override
//   void initState() {
//     super.initState();
//     _productList = fetchAllProducts(); // Fetch products when the screen initializes
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('All Products'),
//       ),
//       body: FutureBuilder<List<Product>>(
//         future: _productList,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No products found.'));
//           }
//
//           final products = snapshot.data!;
//
//           return ListView.builder(
//             itemCount: products.length,
//             itemBuilder: (context, index) {
//               final product = products[index];
//
//               return ListTile(
//                 title: Text(product.productName),
//                 subtitle: Text('Kg: ${product.kg}, Price: ${product.lipaNumber}'),
//                 trailing: ElevatedButton.icon(
//                   icon: Icon(Icons.delete, size: 20),
//                   label: Text("Delete Product", style: TextStyle(fontSize: 16)),
//                   style: ElevatedButton.styleFrom(
//                     padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
//                     backgroundColor: Colors.red,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                   ),
//                   onPressed: () async {
//                     bool confirmDelete = await showDialog(
//                       context: context,
//                       builder: (context) {
//                         return AlertDialog(
//                           title: Text("Delete Product"),
//                           content: Text("Are you sure you want to delete this product?"),
//                           actions: [
//                             TextButton(
//                               onPressed: () {
//                                 Navigator.of(context).pop(false);
//                               },
//                               child: Text("Cancel"),
//                             ),
//                             TextButton(
//                               onPressed: () {
//                                 Navigator.of(context).pop(true);
//                               },
//                               child: Text("Delete", style: TextStyle(color: Colors.red)),
//                             ),
//                           ],
//                         );
//                       },
//                     );
//
//                     if (confirmDelete) {
//                       bool deleted = await deleteProduct(product.id);
//
//                       if (deleted) {
//                         setState(() {
//                           _productList = fetchAllProducts(); // Refresh the list
//                         });
//                       } else {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(content: Text("Failed to delete the product.")),
//                         );
//                       }
//                     }
//                   },
//                 ),
//                 onTap: () {
//                   // Optional: Add functionality to view more details about the product
//                 },
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
