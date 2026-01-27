import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../SalesReportScreen.dart';

class CartView extends StatefulWidget {
  final Map<String, dynamic> user;

  const CartView({super.key, required this.user});

  @override
  _CartViewState createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  late Future<List<Map<String, dynamic>>> cartItems;
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  String paymentMethod = "Cash";
  double grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  void _loadCartItems() {
    setState(() {
      cartItems = _fetchCartItems();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchCartItems() async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> items = await db.query(
      'cart',
      where: 'user_id = ?',
      whereArgs: [widget.user['id']],
    );

    double total = items.fold(0.0, (sum, item) => sum + ((item['price'] as num) * (item['quantity'] as num)));
    setState(() {
      grandTotal = total;
    });

    return items;
  }

  Future<void> _removeItemFromCart(int itemId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('cart', where: 'id = ?', whereArgs: [itemId]);
    _loadCartItems();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Item removed from cart")));
  }

  Future<void> _confirmSale() async {
    final db = await DatabaseHelper.instance.database;
    List<Map<String, dynamic>> items = await _fetchCartItems();

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cart is empty!")));
      return;
    }

    String customerName = nameController.text.trim();
    String customerPhone = phoneController.text.trim();

    if (customerName.isEmpty || customerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Enter customer details!")));
      return;
    }

    List<Map<String, dynamic>> userResult = await db.query(
      'users',
      columns: ['full_name'],
      where: 'id = ?',
      whereArgs: [widget.user['id']],
    );

    String confirmedBy = userResult.isNotEmpty ? userResult.first['full_name'] : 'Unknown';

    String receiptNumber = "REC${(1000 + DateTime.now().millisecondsSinceEpoch % 9000)}";
    String confirmedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    int totalQuantity = items.fold(0, (sum, item) => sum + (item['quantity'] as num).toInt());

    int saleId = await db.insert('sales', {
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'total_quantity': totalQuantity,
      'total_price': grandTotal,
      'receipt_number': receiptNumber,
      'payment_method': paymentMethod,
      'confirmed_time': confirmedTime,
      'user_id': widget.user['id'],
      'confirmed_by': confirmedBy,
    });

    for (var item in items) {
      await db.insert('sale_items', {
        'sale_id': saleId,
        'medicine_id': item['medicine_id'],
        'quantity': item['quantity'],
        'price': item['price'],
      });

      await db.rawUpdate(
        "UPDATE medicines SET quantity = quantity - ? WHERE id = ?",
        [(item['quantity'] as num).toInt(), item['medicine_id']],
      );
    }

    await db.delete('cart', where: 'user_id = ?', whereArgs: [widget.user['id']]);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => SalesReportScreen(  userRole: 'admin', // Or 'staff'
      userName: 'staff_name', )),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sale confirmed successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Cart",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: "Customer Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Customer Phone",
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: cartItems,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                if (snapshot.data!.isEmpty) return Center(child: Text("Cart is empty"));

                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    return ListTile(
                      title: Text(item['medicine_name']),
                      subtitle: Text("Price: TSH ${item['price']} x ${item['quantity']} = TSH ${(item['price'] * item['quantity']).toStringAsFixed(2)}"),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeItemFromCart(item['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  "Grand Total: TSH ${grandTotal.toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _confirmSale,
                  child: Text("Confirm Sale", style: TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
