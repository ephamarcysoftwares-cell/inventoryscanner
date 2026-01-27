import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sqflite/sqflite.dart';

// Import your existing screens
import '../CCTV CAMERA/camera_screen.dart';
import '../CCTV CAMERA/suspected_video.dart';
import '../DB/database_helper.dart';
import '../Dispensing/CartView.dart';
import '../Dispensing/cart.dart';
import '../Dispensing/sale.dart';
import '../INVOICE/INVOICE.dart';
import '../LOGS/medical_stock logs.dart';
import '../LOGS/migrate_logs.dart';
import '../LOGS/view deleted medicine.dart';
import '../Notification/nofity user.dart' hide DatabaseHelper;
import '../QR Code generator/ProductScannerPage.dart';
import '../QR Code generator/qrcode.dart';
import '../QR Code generator/view_qrcode.dart';
import '../Receipt   Reprint/reprint receipt.dart';
import '../STORE/add_store_medicine.dart';
import '../STORE/view_bussines details.dart';
import '../STORE/view_company.dart';

import '../SalesReportScreen.dart';
import '../TO lend/staff_paid_lend_logs_screen.dart';
import '../TO lend/staff_to_lend_report_screen.dart';
import '../TO lend/view_lend.dart';
import '../TO lend/view_lendlogs.dart';
import '../USAGE/pay_salary_screen.dart';
import '../USAGE/usage_normal.dart';
import '../USAGE/view salary.dart';
import '../USAGE/view_userg.dart';
import '../add_business_screen.dart';
import '../add_company.dart';
import '../admin/StaffRestockOtherProduct.dart';
import '../admin/add_medicine_screen.dart';
import '../admin/financialsummary.dart';
import '../admin/import.dart';
import '../admin/medical.dart';
import '../admin/otherproduct.dart';
import '../admin/restock_checker.dart';
import '../admin/staff_restock_normal_poduct.dart';
import '../admin/view_expired_screen.dart';
import '../admin/view_medicine_screen.dart';
import '../admin/view_users.dart';
import '../analysismedicine/analisty_complite.dart';
import '../login.dart';
import '../profile/ProfileUpdateScreen.dart';
import '../register_screen.dart';
import 'AssignPermissionsScreen.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboard({super.key, required this.user});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? imagePath = prefs.getString('profile_image');
    if (imagePath != null) {
      setState(() {
        _profileImage = File(imagePath);
      });
    }
  }

  Future<void> _pickProfileImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      File file = File(result.files.single.path!);
      String savedPath = await _saveImage(file);
      setState(() => _profileImage = file);
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', savedPath);
    }
  }

  Future<String> _saveImage(File file) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String filePath = '${appDir.path}/profile_image.png';
    await file.copy(filePath);
    return filePath;
  }

  // UPDATED: Dynamic Permission Fetcher for Current User/Business
  Future<List<String>> getUserPermissions(dynamic userId, String businessName) async {
    List<String> permissions = [];
    final String uid = userId.toString();

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult != ConnectivityResult.none) {
        final response = await Supabase.instance.client
            .from('user_permissions')
            .select('permission')
            .eq('user_id', uid)
            .eq('business_name', businessName);

        if (response is List && response.isNotEmpty) {
          permissions = response.map((e) => e['permission'].toString()).toList();

          final db = await DatabaseHelper.instance.database;
          await db!.transaction((txn) async {
            await txn.delete('user_permissions',
                where: 'user_id = ? AND business_name = ?',
                whereArgs: [uid, businessName]);
            for (var p in permissions) {
              await txn.insert('user_permissions', {
                'user_id': uid,
                'business_name': businessName,
                'permission': p
              });
            }
          });
          debugPrint("✅ Permissions Synced from Supabase");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Permission Fetch Error: $e");
    }

    if (permissions.isEmpty) {
      final db = await DatabaseHelper.instance.database;
      final results = await db!.query(
        'user_permissions',
        where: 'user_id = ? AND business_name = ?',
        whereArgs: [uid, businessName],
      );
      permissions = results.map((e) => e['permission'].toString()).toList();
    }
    return permissions;
  }

  Future<bool> _showConfirmationDialog(BuildContext context, String option) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text('Do you want to open "$option"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Yes')),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ADMIN DASHBOARD"), backgroundColor: Colors.teal[800]),
      drawer: _buildDrawer(context),
      body: Homepage(
          user: widget.user,
          getUserPermissions: getUserPermissions,
          showConfirmationDialog: _showConfirmationDialog
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(widget.user['full_name'] ?? 'Admin'),
            accountEmail: Text(widget.user['email'] ?? ''),
            currentAccountPicture: GestureDetector(
              onTap: _pickProfileImage,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                child: _profileImage == null ? Text(widget.user['full_name'][0], style: const TextStyle(fontSize: 40.0)) : null,
              ),
            ),
            decoration: BoxDecoration(color: Colors.teal[800]),
          ),
          ListTile(
            leading: Icon(Icons.dashboard, color: Colors.teal[700]),
            title: const Text("Dashboard"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout"),
            onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false),
          ),
        ],
      ),
    );
  }
}

class Homepage extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<List<String>> Function(dynamic, String) getUserPermissions;
  final Future<bool> Function(BuildContext, String) showConfirmationDialog;

  Homepage({
    super.key,
    required this.user,
    required this.getUserPermissions,
    required this.showConfirmationDialog,
  });

  final List<String> cartName = [
    "MANAGE PRODUCT", "SALES WINDOW", "REPORT", "MANAGE USER",
    "SALARY MANAGEMENT", "MANAGE BUSINESS", "MY STORE", "AUTO SALES SETTING"
  ];

  final List<Icon> cartIcons = [
    const Icon(Icons.production_quantity_limits_sharp, color: Colors.white, size: 30),
    const Icon(Icons.business, color: Colors.white, size: 30),
    const Icon(Icons.point_of_sale_sharp, color: Colors.white, size: 30),
    const Icon(Icons.supervised_user_circle, color: Colors.white, size: 30),
    const Icon(Icons.people, color: Colors.white, size: 30),
    const Icon(Icons.business_sharp, color: Colors.white, size: 30),
    const Icon(Icons.store, color: Colors.white, size: 30),
    const Icon(Icons.camera, color: Colors.white, size: 30),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.teal[800]!, Colors.teal[600]!]),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: const Text("STOCK & INVENTORY SOFTWARE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          GridView.builder(
            itemCount: cartName.length,
            shrinkWrap: true,
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openCategoryOptions(context, index, user),
                child: Container(
                  decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(15)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      cartIcons[index],
                      const SizedBox(height: 10),
                      Text(cartName[index], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _openCategoryOptions(BuildContext context, int index, Map<String, dynamic> user) async {
    String bizName = user['businessName'] ?? user['business_name'] ?? '';
    List<String> userHas = await getUserPermissions(user['id'], bizName);

    if (userHas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No permissions assigned.")));
      return;
    }

    // Filter permissions based on the specific dashboard button clicked
    List<String> categoryPermissions = _getPermissionsForCategory(cartName[index], userHas);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(cartName[index], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: categoryPermissions.length,
                itemBuilder: (context, idx) {
                  final option = categoryPermissions[idx];
                  return InkWell(
                    onTap: () async {
                      bool confirmed = await showConfirmationDialog(context, option);
                      if (confirmed) {
                        final page = _getPageForPermission(option, user);
                        if (page != null) Navigator.push(context, MaterialPageRoute(builder: (_) => page));
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(color: Colors.blue[300], borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_getIconForPermission(option), color: Colors.white),
                          Text(option, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getPermissionsForCategory(String category, List<String> userPerms) {
    Map<String, List<String>> mapping = {
      "MANAGE PRODUCT": ["Add Stock", "View All Product", "View Expired Product", "import product", "Re -Stock", "deleted product history", "add other product"],
      "SALES WINDOW": ["Sales windows", "view pending bill", "print receipt", "Generate Invoice", "Dispency Product"],
      "REPORT": ["sales report", "Stock report", "view financial summary", "Sales Analysis", "view stock logs", "view store migrated report"],
      "MANAGE USER": ["Manage users", "add user", "Notify customer"],
      "SALARY MANAGEMENT": ["Salary payment", "View salary history", "Add Expenses", "view expenses"],
      "MANAGE BUSINESS": ["Business Name", "add company", "Manage company", "Manage Business Details"],
      "MY STORE": ["add to store", "view my store", "qr code manage", "view generate qrcode&barcode", "ProductScannerPage"],
      "AUTO SALES SETTING": ["CCTV CONNECTION", "SET AUTOMATICAL SELL", "VIEW SUSPECTED VIDEO"],
    };
    return userPerms.where((p) => mapping[category]?.contains(p) ?? false).toList();
  }

  IconData _getIconForPermission(String p) {
    // Icons provided in your switch statement
    switch (p) {
      case "Add Stock": return Icons.add_box;
      case "View All Product": return Icons.view_list;
      case "View Expired Product": return Icons.warning;
      case "Manage users": return Icons.group;
      case "sales report": return Icons.bar_chart;
      case "Sales windows": return Icons.point_of_sale;
      default: return Icons.apps;
    }
  }

  Widget? _getPageForPermission(String p, Map<String, dynamic> user) {
    // Pages provided in your switch statement
    switch (p) {
      case "Add Stock": return AddMedicineScreen(user: user);
      case "View All Product": return ViewMedicineScreen();
      case "Manage users": return const SuperViewUsersScreen(user: {},);
      case "Sales windows": return SaleScreen(user: user);
      case "sales report": return SalesReportScreen(userRole: 'admin', userName: 'staff_name');
      case "View To Lend(MKOPO)": return StaffToLendReportScreen(staffId: user['id'].toString(), userName: user['full_name']);
      default: return null;
    }
  }
}