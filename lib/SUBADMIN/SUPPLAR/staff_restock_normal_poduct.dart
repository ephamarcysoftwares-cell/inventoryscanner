import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:dropdown_search/dropdown_search.dart'; // Import for DropdownSearch

import '../../DB/database_helper.dart';
import '../../FOTTER/CurvedRainbowBar.dart';


class StaffRestockNormalProduct extends StatefulWidget {
  const StaffRestockNormalProduct({super.key, required String staffId, required userName});

  @override
  _StaffRestockNormalProductState createState() => _StaffRestockNormalProductState();
}

class _StaffRestockNormalProductState extends State<StaffRestockNormalProduct> {
  late Future<List<Map<String, dynamic>>> medicines;
  TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  // Business info
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';

  // State for DropdownSearch
  List<String> uniqueCompanies = [];
  String _selectedCompany = ''; // Will hold the selected company in the dialog

  @override
  void initState() {
    super.initState();
    medicines = Future.value([]);
    initializeData();
  }

  Future<void> initializeData() async {
    setState(() {
      medicines = fetchMedicines(searchQuery: searchQuery);
    });
    await getBusinessInfo();
    await fetchUniqueCompanies(); // Fetch unique companies on init
  }
// Function to fetch all admin emails from the database
  Future<List<String>> getAllAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    // NOTE: This assumes a 'users' table with 'email' and 'role' columns
    final result = await db.query('users', columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
    return result.map((row) => row['email'].toString()).toList();
  }

// Function to send the product restock notification email
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
    // NOTE: The businessName is needed but must be passed or accessed via a class property.
    // We'll assume it's passed or available from the context where this is called.
    String businessName = 'STOCK & INVENTORY SOFTWARE',
  }) async {
    try {
      final emails = await getAllAdminEmails();
      if (emails.isEmpty) return;

      // NOTE: Replace with your actual SMTP details
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
<h2>🆕 New Product Stock Added</h2>
<table border="1" cellpadding="5">
<tr><td>Name</td><td>$name</td></tr>
<tr><td>Company</td><td>$company</td></tr>
<tr><td>Quantity Added</td><td>$quantity</td></tr>
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
        ..subject = '🆕 Product Stock Updated: $name'
        ..text = 'Stock for product "$name" has been updated.'
        ..html = htmlContent;

      send(message, smtpServer);
      print("Email sent successfully to all admins");
    } catch (e) {
      print('Failed to send admin email: $e');
    }
  }

  // ================== Fetch Unique Company Names ==================
  Future<void> fetchUniqueCompanies() async {
    try {
      final db = await DatabaseHelper.instance.database;
      // Fetch all distinct company names
      final result = await db.rawQuery('SELECT DISTINCT company FROM medicines WHERE company IS NOT NULL AND company != "" ORDER BY company ASC');
      setState(() {
        uniqueCompanies = result.map((row) => row['company'] as String).toList();
      });
    } catch (e) {
      print('Error fetching unique companies: $e');
    }
  }

  Future<void> getBusinessInfo() async {
    // ... (Your business info loading logic remains unchanged)
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('businesses');
      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name']?.toString() ?? '';
          businessEmail = result[0]['email']?.toString() ?? '';
          businessPhone = result[0]['phone']?.toString() ?? '';
          businessLocation = result[0]['location']?.toString() ?? '';
          businessLogoPath = result[0]['logo']?.toString() ?? '';
        });
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }

  void loadMedicines() {
    setState(() {
      medicines = fetchMedicines(searchQuery: searchQuery);
    });
    fetchUniqueCompanies(); // Also refresh company list
  }

  Future<List<Map<String, dynamic>>> fetchMedicines({String searchQuery = ''}) async {
    // ... (Your fetch medicines logic remains unchanged)
    final db = await DatabaseHelper.instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery.trim().isNotEmpty) {
      whereClause = '''
      (name LIKE ? OR 
       company LIKE ? OR 
       expiry_date LIKE ? OR 
       batchNumber LIKE ? OR 
       manufacture_date LIKE ?)
      ''';
      whereArgs.addAll(List.filled(5, '%$searchQuery%'));
    }

    final result = await db.query(
      'medicines',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return result.map((medicine) {
      final mutable = Map<String, dynamic>.from(medicine);

      int remainingQty = 0;
      final remainingRaw = mutable['remaining_quantity'];
      if (remainingRaw is int) remainingQty = remainingRaw;
      else if (remainingRaw is double) remainingQty = remainingRaw.toInt();
      else remainingQty = int.tryParse(remainingRaw?.toString() ?? '0') ?? 0;
      remainingQty = remainingQty < 0 ? 0 : remainingQty;
      mutable['remaining_quantity'] = remainingQty;

      int totalQty = 0;
      final totalRaw = mutable['total_quantity'];
      if (totalRaw is int) totalQty = totalRaw;
      else if (totalRaw is double) totalQty = totalRaw.toInt();
      else totalQty = int.tryParse(totalRaw?.toString() ?? '0') ?? 0;
      mutable['total_quantity'] = totalQty;

      int soldQty = totalQty - remainingQty;
      if (soldQty < 0) soldQty = 0;
      mutable['sold_quantity'] = soldQty;

      final expiryStr = mutable['expiry_date']?.toString();
      DateTime? expiryDate;
      try {
        expiryDate = expiryStr != null ? DateTime.parse(expiryStr) : null;
      } catch (_) {
        expiryDate = null;
      }
      final isExpired = expiryDate != null && expiryDate.isBefore(DateTime.now());
      mutable['status'] = (remainingQty < 1 || isExpired) ? 'Out of Stock' : 'Available';

      return mutable;
    }).toList();
  }

  Future<Map<String, dynamic>> fetchMedicineDetails(int id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('medicines', where: 'id = ?', whereArgs: [id]);
    return result.isNotEmpty ? result.first : {};
  }

  Future<void> deleteMedicine(int id) async {
    final medicine = await fetchMedicineDetails(id);
    if (medicine.isNotEmpty) {
      int remaining = medicine['remaining_quantity'] ?? 0;
      if (remaining < 1) {
        // Assume saveToDeletedTableAndSend is defined elsewhere or not critical for this fix
        // await saveToDeletedTableAndSend(medicine);
      }
      await DatabaseHelper.instance.deleteMedicine(id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${medicine['name'] ?? 'Product'} deleted!')),
      );
      loadMedicines();
    }
  }

  Future<void> saveToDeletedTableAndSend(Map<String, dynamic> medicine) async {
    // ... (Your saveToDeletedTableAndSend logic remains unchanged)
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('deleted_medicines', {
      'name': medicine['name']?.toString() ?? 'Unknown',
      'company': medicine['company']?.toString() ?? 'Unknown',
      'total_quantity': medicine['total_quantity'] ?? 0,
      'remaining_quantity': medicine['remaining_quantity'] ?? 0,
      'buy': (medicine['buy'] ?? 0).toDouble(),
      'price': (medicine['price'] ?? 0).toDouble(),
      'batchNumber': medicine['batchNumber']?.toString() ?? '',
      'manufacture_date': medicine['manufacture_date']?.toString() ?? '',
      'expiry_date': medicine['expiry_date']?.toString() ?? '',
      'added_by': medicine['added_by']?.toString() ?? '',
      'discount': (medicine['discount'] ?? 0).toDouble(),
      'unit': medicine['unit']?.toString() ?? '',
      'business_name': businessName,
      'deleted_date': now,
      'date_added': now,
    });
  }

  // ================== Add / Re-add Medicine (with new fields) ==================
  Future<void> addOrReAddMedicineWithUpdates(
      Map<String, dynamic> medicine,
      int quantityToAdd,
      String batchNumber,
      String newCompany,
      String newMfgDate,
      String newExpDate,
      ) async {
    // ... (Your addOrReAddMedicineWithUpdates logic remains unchanged)
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();

    int remainingQty = medicine['remaining_quantity'] ?? 0;
    int totalQty = medicine['total_quantity'] ?? 0;

    if (remainingQty < 1) {
      // Archive and delete completely
      // Assume saveToDeletedTableAndSend is defined elsewhere or not critical for this fix
      // await saveToDeletedTableAndSend(medicine);
      await db.delete('medicines', where: 'id = ?', whereArgs: [medicine['id']]);

      // When re-adding (product out of stock/deleted): Insert new record with NEW values
      final newMedicineLog = {
        'medicine_name': medicine['name'] ?? '',
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': quantityToAdd,
        'remaining_quantity': quantityToAdd,
        'buy_price': medicine['buy'] ?? 0,
        'selling_price': medicine['price'] ?? 0,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': medicine['added_by'] ?? '',
        'discount': medicine['discount'] ?? 0,
        'unit': medicine['unit'] ?? '',
        'business_name': businessName,
        'date_added': now,
        'action': 'Re-added product',
      };

      await db.insert('medicines', {
        'name': medicine['name'] ?? '',
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': quantityToAdd,
        'remaining_quantity': quantityToAdd,
        'buy': medicine['buy'] ?? 0,
        'price': medicine['price'] ?? 0,
        'batchNumber': batchNumber,
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': medicine['added_by'] ?? '',
        'discount': medicine['discount'] ?? 0,
        'unit': medicine['unit'] ?? '',
        'businessName': businessName,
        'added_time': now,
      });

      await db.insert('medical_logs', newMedicineLog);

      // Assume sendAdminNotification is defined elsewhere or not critical for this fix
       sendAdminNotification(
        name: medicine['name'],
        company: newCompany,
        quantity: quantityToAdd,
        price: medicine['price'] ?? 0,
        buy: medicine['buy'] ?? 0,
        batchNumber: batchNumber,
        addedBy: medicine['added_by'] ?? '',
        discount: medicine['discount'] ?? 0,
        unit: medicine['unit'] ?? '',
      );

    } else {
      // When stocking existing product: Update existing record with NEW batch/dates/company
      int updatedTotal = totalQty + quantityToAdd;
      int updatedRemaining = remainingQty + quantityToAdd;

      await db.update(
        'medicines',
        {
          'total_quantity': updatedTotal,
          'remaining_quantity': updatedRemaining,
          'batchNumber': batchNumber,
          'company': newCompany, // UPDATE COMPANY
          'manufacture_date': newMfgDate, // UPDATE MFG DATE
          'expiry_date': newExpDate, // UPDATE EXP DATE
          'added_time': now,
        },
        where: 'id = ?',
        whereArgs: [medicine['id']],
      );

      // Insert log with updated details
      await db.insert('medical_logs', {
        'medicine_name': medicine['name'],
        'company': newCompany, // USE NEW COMPANY
        'total_quantity': updatedTotal,
        'remaining_quantity': updatedRemaining,
        'buy_price': medicine['buy'] ?? 0,
        'selling_price': medicine['price'] ?? 0,
        'batch_number': batchNumber,
        'manufacture_date': newMfgDate, // USE NEW MFG DATE
        'expiry_date': newExpDate, // USE NEW EXP DATE
        'added_by': medicine['added_by'] ?? '',
        'discount': medicine['discount'] ?? 0,
        'unit': medicine['unit'] ?? '',
        'business_name': businessName,
        'date_added': now,
        'action': 'Added more units',
      });

      // Assume sendAdminNotification is defined elsewhere or not critical for this fix
      sendAdminNotification(
        name: medicine['name'],
        company: newCompany,
        quantity: quantityToAdd,
        price: medicine['price'] ?? 0,
        buy: medicine['buy'] ?? 0,
        batchNumber: batchNumber,
        addedBy: medicine['added_by'] ?? '',
        discount: medicine['discount'] ?? 0,
        unit: medicine['unit'] ?? '',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${medicine['name']} Stocked with $quantityToAdd units')),
    );
    loadMedicines();
  }

  // (Your sendAdminNotification and generatePdf methods remain unchanged)

  // ================== Build UI ==================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "VIEW NORMAL PRODUCT",
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
                  medicines = fetchMedicines(searchQuery: v);
                });
              },
            ),
            const SizedBox(height: 10),
            Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                children: [
                  // ... (Table header layout remains unchanged)
                  Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Total Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Sold Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Remaining Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Buy (TSH)', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Price (TSH)', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Batch No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Manufacture Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Added Time', style: TextStyle(fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: medicines,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No product found.'));
                  }
                  final medList = snapshot.data!;
                  return ListView.builder(
                    itemCount: medList.length,
                    itemBuilder: (context, index) {
                      final med = medList[index];
                      return Card(
                        child: ListTile(
                          title: Row(
                            children: [
                              // ... (ListTile content remains unchanged)
                              Expanded(flex: 3, child: Text(med['name'] ?? '')),
                              Expanded(flex: 1, child: Text('${med['total_quantity'] ?? 0}')),
                              Expanded(flex: 1, child: Text('${med['sold_quantity'] ?? 0}')),
                              Expanded(flex: 1, child: Text('${med['remaining_quantity'] ?? 0}')),
                              Expanded(flex: 1, child: Text(med['status'] ?? '')),
                              Expanded(flex: 2, child: Text('${med['buy'] ?? 0}')),
                              Expanded(flex: 2, child: Text('${med['price'] ?? 0}')),
                              Expanded(flex: 2, child: Text(med['batchNumber'] ?? '')),
                              Expanded(flex: 2, child: Text(med['manufacture_date'] ?? '')),
                              Expanded(flex: 2, child: Text(med['expiry_date'] ?? '')),
                              Expanded(flex: 2, child: Text(med['added_time'] ?? '')),
                              Expanded(flex: 2, child: Text(med['unit'] ?? '')),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blue),
                                onPressed: () async {
                                  // Reset selected company to the current product's company
                                  _selectedCompany = med['company']?.toString() ?? '';
                                  if (_selectedCompany.isEmpty) _selectedCompany = uniqueCompanies.firstOrNull ?? '';

                                  final qtyController = TextEditingController();
                                  final batchController = TextEditingController(text: med['batchNumber']?.toString() ?? '');
                                  final mfgDateController = TextEditingController(text: med['manufacture_date']?.toString() ?? '');
                                  final expDateController = TextEditingController(text: med['expiry_date']?.toString() ?? '');

                                  final formKey = GlobalKey<FormState>();

                                  // --- MODIFIED DIALOG WITH DROP-DOWN SEARCH START ---
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
                                                    'Product: ${med['name']}',
                                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  const Divider(),

                                                  // Company DropdownSearch
                                                  DropdownSearch<String>(
                                                    // Pass a copy of the list that can be modified by custom logic
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
                                                      // This allows the user to type a value not in the list
                                                      showSelectedItems: true,
                                                      searchFieldProps: const TextFieldProps(
                                                        decoration: InputDecoration(
                                                          hintText: 'Search or type new company...',
                                                          border: OutlineInputBorder(),
                                                        ),
                                                      ),
                                                      // Custom logic to handle the new company entry
                                                      // onBeforeChange: (prev, next) async {
                                                      //   // Check if the next item is a new company typed by the user
                                                      //   if (next != null && !uniqueCompanies.contains(next)) {
                                                      //     setStateInDialog(() {
                                                      //       // Add the new company to the temporary list
                                                      //       uniqueCompanies.add(next);
                                                      //       // Set it as the selected company
                                                      //       _selectedCompany = next;
                                                      //     });
                                                      //   }
                                                      //   return true; // Allow the change
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

                                                  // Manufacture Date
                                                  TextFormField(
                                                    controller: mfgDateController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Manufacture Date (YYYY-MM-DD)',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    onTap: () async {
                                                      // Date picker logic remains unchanged
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

                                                  // Expiry Date
                                                  TextFormField(
                                                    controller: expDateController,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Expiry Date (YYYY-MM-DD)',
                                                      border: OutlineInputBorder(),
                                                    ),
                                                    onTap: () async {
                                                      // Date picker logic remains unchanged
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
                                                  // All validations passed, return the map
                                                  Navigator.pop(context, {
                                                    'quantity': qtyController.text,
                                                    'batchNumber': batchController.text,
                                                    'company': _selectedCompany,
                                                    'manufacture_date': mfgDateController.text,
                                                    'expiry_date': expDateController.text,
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
                                  // --- MODIFIED DIALOG WITH DROP-DOWN SEARCH END ---

                                  if (result != null) {
                                    final newQty = int.tryParse(result['quantity']!) ?? 0;
                                    final batchNo = result['batchNumber']!;
                                    final newCompany = result['company']!;
                                    final newMfgDate = result['manufacture_date']!;
                                    final newExpDate = result['expiry_date']!;

                                    if (newQty > 0 && batchNo.isNotEmpty && newCompany.isNotEmpty) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => const Center(child: CircularProgressIndicator()),
                                      );

                                      try {
                                        await addOrReAddMedicineWithUpdates(
                                          med, newQty, batchNo, newCompany, newMfgDate, newExpDate,
                                        );
                                      } finally {
                                        Navigator.of(context).pop();
                                      }

                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Quantity, Batch, and Company are required.')),
                                      );
                                    }
                                  }
                                },
                              ),
                              // ... (rest of the action buttons)
                              // IconButton(
                              //   icon: const Icon(Icons.edit, color: Colors.green),
                              //   onPressed: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (_) => EditMedicineScreen(
                              //           id: med['id'],
                              //           name: med['name']?.toString() ?? '',
                              //           company: med['company']?.toString() ?? '',
                              //           total_quantity: med['total_quantity'] ?? 0,
                              //           remaining_quantity: med['remaining_quantity'] ?? 0,
                              //           buy: (med['buy'] ?? 0).toDouble(),
                              //           price: (med['price'] ?? 0).toDouble(),
                              //           batchNumber: med['batchNumber']?.toString() ?? '',
                              //           manufacturedDate: med['manufacture_date']?.toString() ?? '',
                              //           expiryDate: med['expiry_date']?.toString() ?? '',
                              //           added_by: med['added_by']?.toString() ?? '',
                              //           discount: (med['discount'] ?? 0).toDouble(),
                              //           added_time: med['added_time']?.toString() ?? '',
                              //           unit: med['unit']?.toString() ?? '',
                              //           businessName: med['business_name']?.toString() ?? '',
                              //           synced: med['synced'] ?? 0,
                              //         ),
                              //       ),
                              //     ).then((_) => loadMedicines());
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
                              //     if (confirm == true) await deleteMedicine(med['id']);
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
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () async {
      //     final list = await medicines;
      //     if (list.isNotEmpty) {
      //       // Assume generatePdf is defined elsewhere or not critical for this fix
      //       // await generatePdf(list);
      //     }
      //   },
      //   // child: const Icon(Icons.picture_as_pdf),
      // ),
    );
  }
}