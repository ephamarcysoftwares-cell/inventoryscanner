import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Switched to Supabase
import '../FOTTER/CurvedRainbowBar.dart';

class EditInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  EditInvoiceScreen({required this.invoice});

  @override
  _EditInvoiceScreenState createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  late TextEditingController customerController;
  List<Map<String, dynamic>> items = [];
  final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    customerController = TextEditingController(text: widget.invoice['customer_name']);
    // Clone the items so we don't modify the original list directly
    items = List<Map<String, dynamic>>.from(
        (widget.invoice['items'] as List).map((item) => Map<String, dynamic>.from(item))
    );

    if (items.isEmpty) {
      addItem();
    }
  }

  void recalculateTotals() {
    setState(() {
      for (var item in items) {
        double qty = double.tryParse(item['quantity'].toString()) ?? 0.0;
        double price = double.tryParse(item['price'].toString()) ?? 0.0;
        item['total'] = qty * price;
      }
    });
  }

  double get grandTotal => items.fold(0.0, (sum, e) => sum + (e['total'] as double));

  /// ☁️ SAVE TO SUPABASE
  Future<void> saveInvoice() async {
    final customerName = customerController.text.trim();
    final String invNo = widget.invoice['invoice_no'];
    final String bizName = widget.invoice['business_name'] ?? "";

    if (customerName.isEmpty) {
      _showSnack('Customer name cannot be empty', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Delete all existing items linked to this Invoice Number
      await supabase
          .from('invoices')
          .delete()
          .eq('invoice_no', invNo);

      // 2. Prepare the updated batch
      final List<Map<String, dynamic>> updatedItems = items.where((item) =>
      item['item_name'].toString().trim().isNotEmpty
      ).map((item) => {
        'invoice_no': invNo,
        'customer_name': customerName,
        'business_name': bizName,
        'item_name': item['item_name'],
        'quantity': item['quantity'],
        'unit': item['unit'],
        'price': item['price'],
        'total': item['total'],
        'added_time': widget.invoice['added_time'], // Keep original timestamp
      }).toList();

      // 3. Insert the new items
      if (updatedItems.isNotEmpty) {
        await supabase.from('invoices').insert(updatedItems);
      }

      _showSnack('Invoice $invNo updated successfully!', Colors.green);
      Navigator.of(context).pop(true); // Return true to refresh the previous list
    } catch (e) {
      debugPrint('Error: $e');
      _showSnack('Failed to update invoice: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void addItem() {
    setState(() {
      items.add({
        'item_name': '',
        'quantity': 1,
        'unit': 'Pcs',
        'price': 0.0,
        'total': 0.0
      });
    });
  }

  void removeItem(int index) {
    if (items.length > 1) {
      setState(() => items.removeAt(index));
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("✏️ Edit: ${widget.invoice['invoice_no']}", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        actions: [
          _isSaving
              ? Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : IconButton(icon: Icon(Icons.check_circle, size: 30), onPressed: saveInvoice),
        ],
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: customerController,
              decoration: InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person, color: Colors.teal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return _buildItemCard(index);
                },
              ),
            ),
            _buildSummaryBar(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addItem,
        backgroundColor: Colors.teal,
        child: Icon(Icons.add_shopping_cart),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildItemCard(int index) {
    final item = items[index];
    return Card(
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(labelText: 'Product/Item Name', border: InputBorder.none),
                    controller: TextEditingController(text: item['item_name'])..selection = TextSelection.collapsed(offset: item['item_name'].length),
                    onChanged: (val) => item['item_name'] = val,
                  ),
                ),
                IconButton(icon: Icon(Icons.cancel, color: Colors.red), onPressed: () => removeItem(index)),
              ],
            ),
            Divider(),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _itemInput(
                    label: 'Qty',
                    initialValue: item['quantity'].toString(),
                    onChanged: (val) {
                      item['quantity'] = double.tryParse(val) ?? 0;
                      recalculateTotals();
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _itemInput(
                    label: 'Price (TSH)',
                    initialValue: item['price'].toString(),
                    onChanged: (val) {
                      item['price'] = double.tryParse(val) ?? 0.0;
                      recalculateTotals();
                    },
                  ),
                ),
                SizedBox(width: 15),
                Text(currencyFormatter.format(item['total']),
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemInput({required String label, required String initialValue, required Function(String) onChanged}) {
    return TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label, isDense: true),
      controller: TextEditingController(text: initialValue)..selection = TextSelection.collapsed(offset: initialValue.length),
      onChanged: onChanged,
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Grand Total:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text("TSH ${currencyFormatter.format(grandTotal)}",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
        ],
      ),
    );
  }
}