import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/services.dart' show rootBundle, Uint8List;
import 'package:sqflite/sqflite.dart';
import 'package:dropdown_search/dropdown_search.dart';

import '../../DB/database_helper.dart';
import '../../FOTTER/CurvedRainbowBar.dart';


class StaffRestockOtherProduct extends StatefulWidget {
  const StaffRestockOtherProduct({super.key, required Map<String, dynamic> user, required String staffId, required userName});

  @override
  _StaffRestockOtherProductState createState() => _StaffRestockOtherProductState();
}

class _StaffRestockOtherProductState extends State<StaffRestockOtherProduct> {
  late Future<List<Map<String, dynamic>>> products;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";
  String businessName = "";
  String businessEmail = "";
  String businessPhone = "";
  String businessLocation = "";
  String businessLogoPath = "";
  String address = "";
  String whatsapp = "";
  String lipaNumber = "";

  List<String> uniqueCompanies = [];
  String _selectedCompany = '';

  @override
  void initState() {
    super.initState();
    initializeData();
  }

  Future<void> initializeData() async {
    await getBusinessInfo();
    await fetchUniqueCompanies();
    loadProducts();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchUniqueCompanies() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('SELECT DISTINCT company FROM other_product WHERE company IS NOT NULL AND company != "" ORDER BY company ASC');
      setState(() {
        uniqueCompanies = result.map((row) => row['company'] as String).toList();
      });
    } catch (e) {
      print('❌ Error fetching unique companies: $e');
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      Database db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        businessName = result[0]['business_name']?.toString() ?? '';
        businessEmail = result[0]['email']?.toString() ?? '';
        businessPhone = result[0]['phone']?.toString() ?? '';
        businessLocation = result[0]['location']?.toString() ?? '';
        businessLogoPath = result[0]['logo']?.toString() ?? '';
        address = result[0]['address']?.toString() ?? '';
        whatsapp = result[0]['whatsapp']?.toString() ?? '';
        lipaNumber = result[0]['lipa_number']?.toString() ?? '';
        setState(() {});
      }
    } catch (e) {
      print('❌ Error loading business info: $e');
    }
  }

  void loadProducts() {
    setState(() {
      products = fetchProducts(searchQuery: searchQuery);
    });
    fetchUniqueCompanies();
  }

  bool isExpired(String? expiryDateStr) {
    if (expiryDateStr == null || expiryDateStr.isEmpty) return false;
    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      final today = DateTime.now();
      return expiryDate.isBefore(today);
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts({String searchQuery = ''}) async {
    final db = await DatabaseHelper.instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery.trim().isNotEmpty) {
      whereClause = '''
      (name LIKE ? OR 
       company LIKE ? OR 
       expiry_date LIKE ? OR 
       batch_number LIKE ? OR 
       manufacture_date LIKE ? OR 
       added_by LIKE ? OR 
       unit LIKE ? OR
       selling_price LIKE ? OR
       buy_price LIKE ? OR
       total_quantity LIKE ? OR
       remaining_quantity LIKE ? OR
       discount LIKE ?)
    ''';
      whereArgs.addAll(List.generate(12, (_) => '%$searchQuery%'));
    }

    final result = await db.query(
      'other_product',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result.map((product) {
      final mutable = Map<String, dynamic>.from(product);

      final qty = double.tryParse(mutable['remaining_quantity']?.toString() ?? '0') ?? 0.0;
      mutable['remaining_quantity'] = qty < 0 ? 0 : qty.toInt();
      mutable['status'] = qty < 1 ? 'OUT OF STOCK' : 'Available';

      final totalQty = int.tryParse(mutable['total_quantity']?.toString() ?? '0') ?? 0;
      mutable['sold_quantity'] = totalQty - (mutable['remaining_quantity'] as int);

      mutable['expired'] = isExpired(mutable['expiry_date']?.toString()) ? 'EXPIRED' : '';

      return mutable;
    }).toList();
  }

  Future<void> deleteProduct(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('other_product', where: 'id = ?', whereArgs: [id]);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted!'))
    );
    loadProducts();
  }

  Future<List<String>> getAllAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
    return result.map((row) => row['email'].toString()).toList();
  }

  Future<void> sendAdminNotification({
    required String name,
    required String company,
    required int quantity,
    required double price,
    required double buy,
    required String batchNumber,
    required String addedBy,
    required double discount,
    required String unit,
  }) async {
    try {
      final emails = await getAllAdminEmails();
      if (emails.isEmpty) return;

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final htmlContent = '''
<html>
<body>
<h2>🆕 New Product Added</h2>
<table border="1" cellpadding="5">
<tr><td>Name</td><td>$name</td></tr>
<tr><td>Company</td><td>$company</td></tr>
<tr><td>Quantity</td><td>$quantity</td></tr>
<tr><td>Buy Price</td><td>$buy</td></tr>
<tr><td>Selling Price</td><td>$price</td></tr>
<tr><td>Batch</td><td>$batchNumber</td></tr>
<tr><td>Unit</td><td>$unit</td></tr>
<tr><td>Discount</td><td>$discount%</td></tr>
<tr><td>Added By</td><td>$addedBy</td></tr>
</table>
</body>
</html>
''';

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName.isNotEmpty ? businessName : 'STOCK & INVENTORY SOFTWARE')
        ..recipients.addAll(emails)
        ..subject = '🆕 New Product Added: $name'
        ..text = 'New product "$name" added.'
        ..html = htmlContent;

       send(message, smtpServer);
      print("Email sent successfully to all admins");
    } catch (e) {
      print('Failed to send admin email: $e');
    }
  }

  // UPDATED: Now accepts newCompany, newMfgDate, and newExpDate
  Future<void> addOrReAddProduct(
      Map<String, dynamic> product,
      int quantityToAdd,
      String batchNumber,
      String newCompany,
      String newMfgDate, // NEW
      String newExpDate, // NEW
      ) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    int remainingQty = product['remaining_quantity'] ?? 0;
    int totalQty = product['total_quantity'] ?? 0;

    if (remainingQty < 1) {
      // Delete old product if no stock
      await db.delete('other_product', where: 'id = ?', whereArgs: [product['id']]);

      // New product data
      final newProduct = {
        'name': product['name'] ?? '',
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': quantityToAdd,
        'remaining_quantity': quantityToAdd,
        'buy_price': product['buy_price'] ?? 0,
        'selling_price': product['selling_price'] ?? 0,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': product['added_by'] ?? '',
        'discount': product['discount'] ?? 0,
        'unit': product['unit'] ?? '',
        'business_name': businessName,
        'date_added': now,
        'product_type': 'Other Product',
        'product_category': 'General',
      };

      await db.insert('other_product', newProduct);

      // Log insertion in product_logs
      await db.insert('product_logs', {
        'product_name': newProduct['name'],
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': newProduct['total_quantity'],
        'remaining_quantity': newProduct['remaining_quantity'],
        'buy_price': newProduct['buy_price'],
        'selling_price': newProduct['selling_price'],
        'batch_number': newProduct['batch_number'],
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': newProduct['added_by'],
        'discount': newProduct['discount'],
        'unit': newProduct['unit'],
        'business_name': newProduct['business_name'],
        'date_added': now,
        'product_type': 'Other Product',
        'product_category': 'General',
        'action': 'Re-added product',
        'synced': 0,
      });
    } else {
      int updatedTotal = totalQty + quantityToAdd;
      int updatedRemaining = remainingQty + quantityToAdd;

      await db.update(
        'other_product',
        {
          'total_quantity': updatedTotal,
          'remaining_quantity': updatedRemaining,
          'batch_number': batchNumber,
          'company': newCompany, // UPDATE COMPANY
          'manufacture_date': newMfgDate, // UPDATE MFG DATE
          'expiry_date': newExpDate, // UPDATE EXP DATE
          'date_added': now,
        },
        where: 'id = ?',
        whereArgs: [product['id']],
      );

      await db.insert('product_logs', {
        'product_name': product['name'],
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': updatedTotal,
        'remaining_quantity': updatedRemaining,
        'buy_price': product['buy_price'] ?? 0,
        'selling_price': product['selling_price'] ?? 0,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': product['added_by'] ?? '',
        'discount': product['discount'] ?? 0,
        'unit': product['unit'] ?? '',
        'business_name': businessName,
        'date_added': now,
        'product_type': 'Other Product',
        'product_category': 'General',
        'action': 'Added more units',
        'synced': 0,
      });
      // UPDATED: Now accepts newCompany, newMfgDate, and newExpDate
      Future<void> addOrReAddProduct(
          Map<String, dynamic> product,
          int quantityToAdd,
          String batchNumber,
          String newCompany,
          String newMfgDate, // NEW
          String newExpDate, // NEW
          ) async {
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().toIso8601String();

        int remainingQty = product['remaining_quantity'] ?? 0;
        int totalQty = product['total_quantity'] ?? 0;

        final businessName = product['business_name'] ?? '';
        final productName = product['name'] ?? '';
        final sellingPrice = product['selling_price'] ?? 0;
        final buyPrice = product['buy_price'] ?? 0;
        final addedBy = product['added_by'] ?? '';
        final discount = product['discount'] ?? 0;
        final unit = product['unit'] ?? '';

        if (remainingQty < 1) {
          // Delete old product if no stock
          await db.delete('other_product', where: 'id = ?', whereArgs: [product['id']]);

          // New product data
          final newProduct = {
            'name': product['name'] ?? '',
            'company': newCompany, // USE NEW COMPANY
            'total_quantity': quantityToAdd,
            'remaining_quantity': quantityToAdd,
            'buy_price': product['buy_price'] ?? 0,
            'selling_price': product['selling_price'] ?? 0,
            'batch_number': batchNumber,
            'manufacture_date': newMfgDate, // USE NEW MFG DATE
            'expiry_date': newExpDate, // USE NEW EXP DATE
            'added_by': product['added_by'] ?? '',
            'discount': product['discount'] ?? 0,
            'unit': product['unit'] ?? '',
            'business_name': businessName,
            'date_added': now,
            'product_type': 'Other Product',
            'product_category': 'General',
          };

          await db.insert('other_product', newProduct);

          // Log insertion in product_logs
          await db.insert('product_logs', {
            'product_name': newProduct['name'],
            'company': newCompany, // USE NEW COMPANY
            'total_quantity': newProduct['total_quantity'],
            'remaining_quantity': newProduct['remaining_quantity'],
            'buy_price': newProduct['buy_price'],
            'selling_price': newProduct['selling_price'],
            'batch_number': newProduct['batch_number'],
            'manufacture_date': newMfgDate, // USE NEW MFG DATE
            'expiry_date': newExpDate, // USE NEW EXP DATE
            'added_by': newProduct['added_by'],
            'discount': newProduct['discount'],
            'unit': newProduct['unit'],
            'business_name': newProduct['business_name'],
            'date_added': now,
            'product_type': 'Other Product',
            'product_category': 'General',
            'action': 'Re-added product',
            'synced': 0,
          });

          // ➡️ CALL ADMIN NOTIFICATION HERE FOR RE-ADDED PRODUCT
          sendAdminNotification(
            name: productName,
            company: newCompany,
            quantity: quantityToAdd,
            price: sellingPrice,
            buy: buyPrice,
            batchNumber: batchNumber,
            addedBy: addedBy,
            discount: discount,
            unit: unit,
          );
        } else {
          int updatedTotal = totalQty + quantityToAdd;
          int updatedRemaining = remainingQty + quantityToAdd;

          await db.update(
            'other_product',
            {
              'total_quantity': updatedTotal,
              'remaining_quantity': updatedRemaining,
              'batch_number': batchNumber,
              'company': newCompany, // UPDATE COMPANY
              'manufacture_date': newMfgDate, // UPDATE MFG DATE
              'expiry_date': newExpDate, // UPDATE EXP DATE
              'date_added': now,
            },
            where: 'id = ?',
            whereArgs: [product['id']],
          );

          // ➡️ CALL ADMIN NOTIFICATION HERE FOR UPDATED PRODUCT
           sendAdminNotification(
            name: productName,
            company: newCompany,
            quantity: quantityToAdd,
            price: sellingPrice,
            buy: buyPrice,
            batchNumber: batchNumber,
            addedBy: addedBy,
            discount: discount,
            unit: unit,
          );
        }
      }

    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product['name']} updated with $quantityToAdd units')),
    );

    loadProducts();
  }

  // ================== PDF Export ==================
  Future<Uint8List> generatePdf(
      List<Map<String, dynamic>> productsList, {
        bool returnBytes = false,
      }) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    final user = prefs.getString('user') ?? '.........................';
    final timestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pw.ImageProvider? logoImage;
    if (businessLogoPath.isNotEmpty) {
      final file = File(businessLogoPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        logoImage = pw.MemoryImage(bytes);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          // Business Header
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    businessName.isNotEmpty ? businessName : 'STOCK & INVENTORY SOFTWARE',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  if (businessLocation.isNotEmpty)
                    pw.Text('Location: $businessLocation', style: const pw.TextStyle(fontSize: 10)),
                  if (businessPhone.isNotEmpty)
                    pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 10)),
                  if (businessEmail.isNotEmpty)
                    pw.Text('Email: $businessEmail', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Generated by $user on $timestamp', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              if (logoImage != null)
                pw.Container(height: 50, width: 50, child: pw.Image(logoImage)),
            ],
          ),

          pw.SizedBox(height: 15),
          pw.Text(
            'OTHER PRODUCT STOCK LIST',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          // Table
          pw.TableHelper.fromTextArray(
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            rowDecoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey, width: 0.5)),
            ),
            data: [
              [
                'Name', 'Batch', 'Company', 'Buy', 'Price', 'Total Qty',
                'Sold Qty', 'Remaining', 'Status', 'Expired', 'Unit',
                'Mfg', 'Expiry', 'Staff', 'Added'
              ],
              ...productsList.map((m) => [
                m['name']?.toString() ?? '',
                m['batch_number']?.toString() ?? '',
                m['company']?.toString() ?? '',
                'TSH ${NumberFormat('#,##0.00').format(double.tryParse(m['buy_price']?.toString() ?? '0') ?? 0)}',
                'TSH ${NumberFormat('#,##0.00').format(double.tryParse(m['selling_price']?.toString() ?? '0') ?? 0)}',
                m['total_quantity']?.toString() ?? '0',
                m['sold_quantity']?.toString() ?? '0',
                m['remaining_quantity']?.toString() ?? '0',
                m['status']?.toString() ?? '',
                m['expired']?.toString() ?? '',
                m['unit']?.toString() ?? '',
                m['manufacture_date']?.toString() ?? '',
                m['expiry_date']?.toString() ?? '',
                m['added_by']?.toString() ?? '',
                m['date_added']?.toString() ?? '',
              ])
            ],
          ),
        ],
      ),
    );

    if (returnBytes) {
      return pdf.save();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Other_Products_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.readAsBytes();
    }
  }


  // ================== Build UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: const Text(
          "OTHER PRODUCT WINDOWS",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: $businessName', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) {
                setState(() {
                  searchQuery = v;
                  products = fetchProducts(searchQuery: v);
                });
              },
            ),
            const SizedBox(height: 10),

            // ===== Header Row =====
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Stocked Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Sold Out', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Remaining Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Expired', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Buy', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Batch No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Mfg Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Exp Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Added Time', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),

            const SizedBox(height: 4),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: products,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No products found.'));
                  }

                  final productList = snapshot.data!;
                  return ListView.builder(
                    itemCount: productList.length,
                    itemBuilder: (context, index) {
                      final p = productList[index];
                      final statusText = p['status'] ?? '';
                      final expiredText = p['expired'] ?? '';
                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(flex: 3, child: Text(p['name'] ?? '')),
                              Expanded(flex: 1, child: Text('${p['total_quantity'] ?? 0}')),
                              Expanded(flex: 1, child: Text('${p['sold_quantity'] ?? 0}')),
                              Expanded(flex: 1, child: Text('${p['remaining_quantity'] ?? 0}')),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusText == 'OUT OF STOCK' ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  expiredText,
                                  style: TextStyle(
                                    color: expiredText == 'EXPIRED' ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(flex: 2, child: Text('${p['buy_price'] ?? 0}')),
                              Expanded(flex: 2, child: Text('${p['selling_price'] ?? 0}')),
                              Expanded(flex: 2, child: Text(p['batch_number'] ?? '')),
                              Expanded(flex: 2, child: Text(p['manufacture_date'] ?? '')),
                              Expanded(flex: 2, child: Text(p['expiry_date'] ?? '')),
                              Expanded(flex: 2, child: Text(p['date_added'] ?? '')),
                              Expanded(flex: 2, child: Text(p['unit'] ?? '')),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blue),
                                onPressed: () async {
                                  // Set initial values for controllers and dropdown
                                  _selectedCompany = p['company']?.toString() ?? '';
                                  if (_selectedCompany.isEmpty) _selectedCompany = uniqueCompanies.firstOrNull ?? '';

                                  final qtyController = TextEditingController();
                                  final batchController = TextEditingController(text: p['batch_number'] ?? '');
                                  final mfgDateController = TextEditingController(text: p['manufacture_date'] ?? ''); // NEW
                                  final expDateController = TextEditingController(text: p['expiry_date'] ?? ''); // NEW
                                  final formKey = GlobalKey<FormState>();

                                  final result = await showDialog<Map<String, String>?>(
                                    context: context,
                                    builder: (context) => StatefulBuilder(
                                      builder: (BuildContext context, StateSetter setStateInDialog) {
                                        return AlertDialog(
                                          title: const Text('Add / Re-add Product Stock'),
                                          content: Form(
                                            key: formKey,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    'Product: ${p['name']}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const Divider(),

                                                  // Company DropdownSearch
                                                  DropdownSearch<String>(
                                                    items: uniqueCompanies,
                                                    selectedItem: _selectedCompany,
                                                    onChanged: (newValue) {
                                                      setStateInDialog(() {
                                                        _selectedCompany = newValue!;
                                                      });
                                                    },
                                                    dropdownDecoratorProps: const DropDownDecoratorProps(
                                                      dropdownSearchDecoration: InputDecoration(
                                                        labelText: 'Select Company',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    popupProps: PopupProps.menu(
                                                      showSearchBox: true,
                                                      showSelectedItems: true,
                                                      searchFieldProps: const TextFieldProps(
                                                        decoration: InputDecoration(
                                                          hintText: 'Search or type new company...',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                      ),
                                                      // onBeforeChange: (prev, next) async {
                                                      //   if (next != null && !uniqueCompanies.contains(next)) {
                                                      //     setStateInDialog(() {
                                                      //       uniqueCompanies.add(next);
                                                      //       _selectedCompany = next;
                                                      //     });
                                                      //   }
                                                      //   return true;
                                                      // },
                                                    ),
                                                    validator: (val) => val == null || val.isEmpty ? 'Please select or enter a company' : null,
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Quantity Field
                                                  TextFormField(
                                                    controller: qtyController,
                                                    keyboardType: TextInputType.number,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Quantity to Add',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    validator: (val) {
                                                      if (val == null || int.tryParse(val) == null || int.parse(val) <= 0) {
                                                        return 'Enter a valid quantity';
                                                      }
                                                      return null;
                                                    },
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Batch Number Field
                                                  TextFormField(
                                                    controller: batchController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Batch Number',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    validator: (val) => val == null || val.isEmpty ? 'Enter a batch number' : null,
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Manufacture Date Field (NEW)
                                                  TextFormField(
                                                    controller: mfgDateController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Manufacture Date (YYYY-MM-DD)',
                                                      border: OutlineInputBorder(),
                                                      suffixIcon: Icon(Icons.calendar_today),
                                                    ),
                                                    readOnly: true,
                                                    onTap: () async {
                                                      DateTime? pickedDate = await showDatePicker(
                                                        context: context,
                                                        initialDate: DateTime.tryParse(mfgDateController.text) ?? DateTime.now(),
                                                        firstDate: DateTime(2000),
                                                        lastDate: DateTime(2101),
                                                      );
                                                      if (pickedDate != null) {
                                                        mfgDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                                      }
                                                    },
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Expiry Date Field (NEW)
                                                  TextFormField(
                                                    controller: expDateController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Expiry Date (YYYY-MM-DD)',
                                                      border: OutlineInputBorder(),
                                                      suffixIcon: Icon(Icons.calendar_today),
                                                    ),
                                                    readOnly: true,
                                                    onTap: () async {
                                                      DateTime? pickedDate = await showDatePicker(
                                                        context: context,
                                                        initialDate: DateTime.tryParse(expDateController.text) ?? DateTime.now().add(const Duration(days: 365)),
                                                        firstDate: DateTime.now(),
                                                        lastDate: DateTime(2101),
                                                      );
                                                      if (pickedDate != null) {
                                                        expDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, null),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                if (formKey.currentState!.validate()) {
                                                  Navigator.pop(context, {
                                                    'quantity': qtyController.text,
                                                    'batchNumber': batchController.text,
                                                    'company': _selectedCompany,
                                                    'manufacture_date': mfgDateController.text, // RETURN NEW MFG DATE
                                                    'expiry_date': expDateController.text, // RETURN NEW EXP DATE
                                                  });
                                                }
                                              },
                                              child: const Text('Add'),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  );

                                  if (result != null) {
                                    final newQty = int.tryParse(result['quantity']!) ?? 0;
                                    final batchNo = result['batchNumber']!;
                                    final newCompany = result['company']!;
                                    final newMfgDate = result['manufacture_date']!; // EXTRACT NEW MFG DATE
                                    final newExpDate = result['expiry_date']!; // EXTRACT NEW EXP DATE

                                    if (newQty > 0 && batchNo.isNotEmpty && newCompany.isNotEmpty) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(child: CircularProgressIndicator()),
                                      );
                                      try {
                                        // PASS ALL NEW VALUES
                                        await addOrReAddProduct(p, newQty, batchNo, newCompany, newMfgDate, newExpDate);
                                      } finally {
                                        Navigator.pop(context);
                                      }
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Quantity, Batch, and Company are required.')),
                                      );
                                    }
                                  }
                                },
                              ),
                              // IconButton(
                              //   icon: const Icon(Icons.edit, color: Colors.green),
                              //   onPressed: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (_) => EditOtherProductScreen(
                              //           id: p['id'],
                              //           name: p['name'] ?? '',
                              //           company: p['company'] ?? '',
                              //           total_quantity: p['total_quantity'] ?? 0,
                              //           remaining_quantity: p['remaining_quantity'] ?? 0,
                              //           buy_price: (p['buy_price'] ?? 0).toDouble(),
                              //           selling_price: (p['selling_price'] ?? 0).toDouble(),
                              //           batch_number: p['batch_number'] ?? '',
                              //           manufacture_date: p['manufacture_date'] ?? '',
                              //           expiry_date: p['expiry_date'] ?? '',
                              //           added_by: p['added_by'] ?? '',
                              //           discount: (p['discount'] ?? 0).toDouble(),
                              //           date_added: p['date_added'] ?? '',
                              //           unit: p['unit'] ?? '',
                              //           businessName: p['business_name'] ?? '',
                              //           synced: p['synced'] ?? 0,
                              //         ),
                              //       ),
                              //     ).then((_) => loadProducts());
                              //   },
                              // ),
                              // IconButton(
                              //   icon: const Icon(Icons.delete, color: Colors.red),
                              //   onPressed: () async {
                              //     final confirm = await showDialog<bool>(
                              //       context: context,
                              //       builder: (context) => AlertDialog(
                              //         title: const Text('Delete product'),
                              //         content: const Text('Are you sure you want to delete this product?'),
                              //         actions: [
                              //           TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                              //           TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
                              //         ],
                              //       ),
                              //     );
                              //     if (confirm == true) await deleteProduct(p['id']);
                              //   },
                              // ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
      // floatingActionButton: FloatingActionButton.extended(
      //   icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
      //   label: const Text("Export PDF", style: TextStyle(color: Colors.white)),
      //   backgroundColor: Colors.blue,
      //   onPressed: () async {
      //     final list = await products;
      //
      //     if (list.isEmpty) {
      //       ScaffoldMessenger.of(context).showSnackBar(
      //         const SnackBar(content: Text('Sorry, no product to export!')),
      //       );
      //       return;
      //     }
      //
      //     String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
      //     if (selectedDirectory == null) return;
      //
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       const SnackBar(content: Text('Generating PDF...')),
      //     );
      //
      //     final filePath = "$selectedDirectory/Other_Product_${DateTime.now().millisecondsSinceEpoch}.pdf";
      //     final pdfFile = File(filePath);
      //     await pdfFile.writeAsBytes(await generatePdf(list));
      //
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(content: Text('PDF saved to: $filePath')),
      //     );
      //   },
      // ),
    );
  }
}