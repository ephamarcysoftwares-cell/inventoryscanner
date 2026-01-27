import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../db/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssignPermissionsScreen extends StatefulWidget {
  final dynamic userId;
  final String businessName;
  final String userName;

  const AssignPermissionsScreen({
    super.key,
    required this.userId,
    required this.businessName,
    required this.userName,
  });

  @override
  State<AssignPermissionsScreen> createState() => _AssignPermissionsScreenState();
}

class _AssignPermissionsScreenState extends State<AssignPermissionsScreen> {
  late String _safeUserId;

  final List<String> allPermissions = [
    "Add Stock", "View All Product", "View Expired Product", "import product", "Add Expenses", "view expenses", "Re -Stock",
    "Sales windows", "view pending bill", "print receipt", "View To Lend(MKOPO)",
    "sales report", "Stock report", "view financial summary", "view store migrated report", "My Lend History",
    "view stock logs", "Sales Analysis", "deleted product history", "Manage users", "add user",
    "Notify customer", "Salary payment", "View salary history", "Generate Invoice", "Business Name",
    "add company", "Manage company", "Manage Business Details", "login activiews", "add to store",
    "view my store", "qr code manage", "view generate qrcode&barcode", "ProductScannerPage", "Store value",
    "CCTV CONNECTION", "SET AUTOMATICAL SELL", "VIEW SUSPECTED VIDEO", "ARAM SETTING",
    "Add Diary", "View my Diary", "Add Event", "view upcoming Event", "View product normal product&Restock",
    "View product other product&Restock", "add other product",
  ];

  Set<String> selectedPermissions = {};
  List<String> filteredPermissions = [];
  TextEditingController searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _safeUserId = widget.userId.toString();
    filteredPermissions = allPermissions;
    loadExistingPermissions();
    searchController.addListener(_filterPermissions);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _filterPermissions() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredPermissions = allPermissions
          .where((perm) => perm.toLowerCase().contains(query))
          .toList();
    });
  }

  // --- 1. FETCH PERMISSIONS (SUPABASE PRIMARY, SQLITE FALLBACK) ---
  Future<void> loadExistingPermissions() async {
    try {
      var connectivity = await (Connectivity().checkConnectivity());
      if (connectivity != ConnectivityResult.none) {
        final response = await Supabase.instance.client
            .from('user_permissions')
            .select('permission')
            .eq('user_id', _safeUserId)
            .eq('business_name', widget.businessName);

        if (response is List) {
          final fetched = response.map((e) => e['permission'].toString()).toSet();

          if (mounted) {
            setState(() {
              selectedPermissions = fetched;
              isLoading = false;
            });
          }

          final db = await DatabaseHelper.instance.database;
          await db!.transaction((txn) async {
            await txn.delete('user_permissions',
                where: 'user_id = ? AND business_name = ?',
                whereArgs: [_safeUserId, widget.businessName]);
            for (var p in fetched) {
              await txn.insert('user_permissions', {
                'user_id': _safeUserId,
                'business_name': widget.businessName,
                'permission': p
              });
            }
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Supabase Fetch Error: $e");
    }

    final db = await DatabaseHelper.instance.database;
    final results = await db!.query(
      'user_permissions',
      where: 'user_id = ? AND business_name = ?',
      whereArgs: [_safeUserId, widget.businessName],
    );

    if (mounted) {
      setState(() {
        selectedPermissions = results.map((e) => e['permission'].toString()).toSet();
        isLoading = false;
      });
    }
  }

  // --- 2. SAVE PERMISSIONS ---
  Future<void> savePermissions() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    bool cloudSuccess = false;

    try {
      var connectivity = await (Connectivity().checkConnectivity());
      if (connectivity != ConnectivityResult.none) {
        final supabase = Supabase.instance.client;

        await supabase.from('user_permissions')
            .delete()
            .eq('user_id', _safeUserId)
            .eq('business_name', widget.businessName);

        if (selectedPermissions.isNotEmpty) {
          final List<Map<String, dynamic>> dataToInsert = selectedPermissions.map((p) => {
            'user_id': _safeUserId,
            'business_name': widget.businessName,
            'permission': p,
          }).toList();

          await supabase.from('user_permissions').insert(dataToInsert);
        }
        cloudSuccess = true;
      }
    } catch (e) {
      debugPrint("❌ Cloud Save Error: $e");
    }

    final db = await DatabaseHelper.instance.database;
    await db!.transaction((txn) async {
      await txn.delete('user_permissions',
          where: 'user_id = ? AND business_name = ?',
          whereArgs: [_safeUserId, widget.businessName]);
      for (final p in selectedPermissions) {
        await txn.insert('user_permissions', {
          'user_id': _safeUserId,
          'business_name': widget.businessName,
          'permission': p
        });
      }
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cloudSuccess ? "Ruhusa zimesawazishwa Cloud ✅" : "Zimehifadhiwa Offline (Simuni) 📶"),
          backgroundColor: cloudSuccess ? Colors.teal : Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${widget.userName} - Access", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all, color: Colors.white),
            onPressed: () => setState(() => selectedPermissions = allPermissions.toSet()),
            tooltip: "Chagua zote",
          ),
          IconButton(
            icon: const Icon(Icons.deselect, color: Colors.white),
            onPressed: () => setState(() => selectedPermissions.clear()),
            tooltip: "Futa zote",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Tafuta kipengele...',
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.teal.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Vipengele Vilivyochaguliwa: ${selectedPermissions.length}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ),
          const Divider(),

          Expanded(
            child: ListView.builder(
              itemCount: filteredPermissions.length,
              itemBuilder: (context, index) {
                final perm = filteredPermissions[index];
                final isSelected = selectedPermissions.contains(perm);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                      color: isSelected ? Colors.teal.withOpacity(0.05) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)
                  ),
                  child: CheckboxListTile(
                    title: Text(perm, style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.teal : Colors.black87
                    )),
                    value: isSelected,
                    activeColor: Colors.teal,
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setState(() {
                        val == true ? selectedPermissions.add(perm) : selectedPermissions.remove(perm);
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 10),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: savePermissions,
        label: const Text("HIFADHI CLOUD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.cloud_upload, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
    );
  }
}