import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_and_inventory_software/SUBADMIN/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- ALL YOUR SAVED IMPORTS ---
import 'package:stock_and_inventory_software/admin/restock_checker.dart';
import 'package:stock_and_inventory_software/admin/view_expired_screen.dart';
import 'package:stock_and_inventory_software/admin/view_other_product.dart';
import 'package:stock_and_inventory_software/admin/view_users.dart';
import '../API/PaymentTrack.dart';
import '../API/Paystaff.dart';
import '../API/SetPaymentIpa.dart';
import '../API/admin_subscription_page.dart';
import '../API/payout.dart';
import '../BRACH/BranchesManagementScreen.dart';
import '../BRACH/CreateBranch.dart';
import '../Businesrepots/business_reports_page.dart';
import '../BusinessConfiguration/configure.dart';
import '../CCTV CAMERA/CCTVVideoAnalyzer.dart';
import '../CCTV CAMERA/camera_screen.dart';
import '../CCTV CAMERA/cctv_connection.dart';
import '../CCTV CAMERA/suspected_video.dart';
import '../CHATBOAT/chatboat.dart';
import '../Chat room/chat.dart';
import '../DATA_PROCCESSING/Insert_data.dart';
import '../DATA_PROCCESSING/View_ncd_data.dart';
import '../DB/database_helper.dart';
import '../DESIGN/design.dart';
import '../Diary/Upcoming.dart';
import '../Diary/ViewDiaryPage.dart';
import '../Diary/ViewEventPage.dart';
import '../Diary/adddiary.dart';
import '../Dispensing/CartView.dart';
import '../Dispensing/cart.dart';
import '../Dispensing/sale.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../IA integration/VlcPlayer.dart';
import '../IA integration/cv.dart';
import '../INVOICE/Delivernote.dart';
import '../INVOICE/INVOICE.dart';
import '../LOGS/medical_stock logs.dart';
import '../LOGS/migrate_logs.dart';
import '../LOGS/view deleted medicine.dart';
import '../MKATABA/mkataba_form.dart';
import '../Notification/nofity user.dart';
import '../PERMISSION/AssignPermissionsScreen.dart';
import '../QR Code generator/ProductScannerPage.dart';
import '../QR Code generator/qrcode.dart';
import '../QR Code generator/view_qrcode.dart';
import '../Receipt   Reprint/reprint receipt.dart';
import '../Reviser_trasaction/Revirse_transaction.dart';
import '../STORE/edit_store.dart';
import '../STORE/view_bussines details.dart';
import '../STORE/view_company.dart';
import '../SalesReportScreen.dart';
import '../TO lend/view_lend.dart';
import '../TO lend/view_lendlogs.dart';
import '../Theft detected/theftdetected_counting.dart';
import '../USAGE/excel_company_import.dart';
import '../USAGE/pay_salary_screen.dart';
import '../USAGE/usage_normal.dart';
import '../USAGE/view salary.dart';
import '../USAGE/view_userg.dart';
import '../add_business_screen.dart';
import '../add_company.dart';
import '../admin/REPORT/ViewMedicineStockDeleted.dart';
import '../admin/REPORT/view_history_logs.dart';
import '../analysismedicine/analisty_complite.dart';
import '../analysismedicine/analysis.dart';
import '../analysismedicine/finished_medicines_profit_screen.dart';
import '../login.dart';
import '../phamacy/STORE/store calculate.dart';
import '../phamacy/STORE/view_store.dart';
import '../stock/closing_stock.dart';
import '../INVOICE/view_invoice.dart';
import '../whatsapp/reply.dart';
import '../whatsapp/whatsap.dart';
import 'NonexpiredProduct.dart';

import 'financialsummary.dart';
import '../payment/payment.dart';
import '../admin/view_medicine_screen.dart';
import '../phamacy/medicine_details_screen.dart';
import '../phamacy/view_expired_screen.dart';
import '../profile/ProfileUpdateScreen.dart';
import '../register_screen.dart';
import '../store/add_store_medicine.dart';
import 'add_medicine_screen.dart';
import 'import.dart';
import 'medical.dart';
import 'otherproduct.dart';

class SubAdminDashboard extends StatefulWidget {
  final Map<String, dynamic> user;
  const SubAdminDashboard({super.key, required this.user});

  @override
  _SubAdminDashboardState createState() => _SubAdminDashboardState();
}

class _SubAdminDashboardState extends State<SubAdminDashboard> {
  // Global States
  File? _profileImage;
  bool _isDarkMode = false;
  String _searchQuery = "";
  final String _pcIP = '10.216.127.201';

  // Slider States
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;
  Timer? _timer;
  final List<String> _sliderImages = [
    'assets/images/track1.png',
    'assets/images/tracak2.png',
    'assets/images/track1.png',
  ];


  @override
  void initState() {
    super.initState();
    _loadSettings();
    _startSlider();
    _checkTempPasswordFromDB();

    // --- 🛡️ SECURITY CHECK FOR TEMPORARY PASSWORD ---
    if (widget.user['is_temp_password'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showForceChangePasswordDialog();
        }
      });
    }
  }


  // --- 🔒 MANDATORY PASSWORD RESET DIALOG ---
  void _showForceChangePasswordDialog() {
    final TextEditingController newPassController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();

    bool isSaving = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.security, color: Colors.orange),
              SizedBox(width: 10),
              Text("Security Required"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "You are using a temporary password. Please set a new permanent password to continue.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: newPassController,
                obscureText: obscureNew,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmPassController,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673AB7),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                  String p1 = newPassController.text.trim();
                  String p2 = confirmPassController.text.trim();

                  if (p1.length < 6) {
                    _showToast(context, "Zitakiwe herufi zisizopungua 6", Colors.red);
                    return;
                  }

                  if (p1 != p2) {
                    _showToast(context, "Password hazilingani!", Colors.red);
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  try {
                    // Jaribu ku-update password
                    await Supabase.instance.client.auth.updateUser(
                      UserAttributes(password: p1),
                    );

                    // Update database flag
                    await Supabase.instance.client
                        .from('users')
                        .update({'is_temp_password': false})
                        .eq('id', widget.user['id']);

                    setState(() {
                      widget.user['is_temp_password'] = false;
                    });

                    Navigator.pop(dialogContext);
                    _showToast(context, "Imefanikiwa kubadilishwa!", Colors.green);

                  } catch (e) {
                    setDialogState(() => isSaving = false);

                    // 🟢 HAPA NDIPO MABADILIKO MAKUBWA YALIPO
                    String errorStr = e.toString().toLowerCase();
                    String ujumbeWako;

                    // Tunachuja kosa hapa
                    if (errorStr.contains("same_password") || errorStr.contains("different from the old")) {
                      ujumbeWako = "Usitumie password ambayo ulikwisha kutumia. Weka mpya tofauti.";
                    } else {
                      ujumbeWako = "Kuna tatizo limetokea. Jaribu tena baadae.";
                    }

                    // MUHIMU: Tunatumia 'ujumbeWako' badala ya 'e.toString()'
                    _showToast(context, ujumbeWako, Colors.redAccent);
                  }
                },
                child: isSaving
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : const Text(
                  "UPDATE & CONTINUE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper function ya SnackBar
  void _showToast(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

// Helper function ya SnackBar



  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startSlider() {
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (_currentPage < _sliderImages.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutQuint,
        );
      }
    });
  }
  Future<void> _checkTempPasswordFromDB() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final response = await Supabase.instance.client
        .from('users')
        .select('is_temp_password')
        .eq('id', userId)
        .single();

    if (response['is_temp_password'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showForceChangePasswordDialog();
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      String? path = prefs.getString('profile_image');
      if (path != null) _profileImage = File(path);
    });
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_image', picked.path);
      setState(() => _profileImage = File(picked.path));
    }
  }

  void _toggleTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('darkMode', _isDarkMode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color nmbBlue = const Color(0xFF005696);
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color cardColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;

    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        drawer: _buildDrawer(context, textColor),
        backgroundColor: bgColor,
        body: LayoutBuilder(builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;
          return Row(
            children: [
              if (isWide) _buildDesktopSidebar(cardColor, nmbBlue, textColor),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    _buildNMBAppBar(nmbBlue),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchHeader(cardColor, textColor),
                            const SizedBox(height: 20),
                            _buildImageSlider(cardColor),
                            const SizedBox(height: 25),
                            _buildInventoryChart(cardColor, nmbBlue, textColor),
                            const SizedBox(height: 30),
                            _buildSectionLabel("Operational Modules", nmbBlue),
                            const SizedBox(height: 15),
                            _buildResponsiveGrid(constraints.maxWidth, cardColor, nmbBlue, textColor),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
        bottomNavigationBar: MediaQuery.of(context).size.width <= 900
            ? _buildNMBFloatingDock(nmbBlue) : null,
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, Color textColor) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  accountName: Text(widget.user['full_name'] ?? "Admin"),
                  accountEmail: Text(widget.user['email'] ?? ""),
                  currentAccountPicture: GestureDetector(
                    onTap: _pickProfileImage,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? Text(widget.user['full_name'][0], style: const TextStyle(fontSize: 40.0, color: Colors.teal))
                          : null,
                    ),
                  ),
                  decoration: const BoxDecoration(color: Color(0xFF005696)),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.teal),
                  title: Text("Dashboard", style: TextStyle(color: textColor)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.teal),
                  title: Text("Update Profile", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(user: widget.user)));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: Text("Logout", style: TextStyle(color: textColor)),
                  onTap: () {
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => LoginScreen()), (route) => false);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30.0, left: 10, right: 10),
            child: Text(
              '© ${DateTime.now().year} E-PHAMARCY SOFTWARE - All Rights Reserved',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNMBAppBar(Color nmbBlue) {
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return SliverAppBar(
      expandedHeight: 120, pinned: true, backgroundColor: primaryPurple, elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: const Text("STOCK & INVENTORY SOFTWARE", style: TextStyle(fontWeight: FontWeight.w200, letterSpacing: 4, fontSize: 14, color: Colors.white)),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [deepPurple, primaryPurple, lightViolet]),
          ),
        ),
      ),
      actions: [
        IconButton(icon: Icon(_isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round_sharp, color: Colors.white), onPressed: _toggleTheme),
        _buildProfileAvatar(35), const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildImageSlider(Color cardColor) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _sliderImages.length,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemBuilder: (context, index) =>Image.asset(_sliderImages[index], fit: BoxFit.cover, width: double.infinity),
            ),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.6)]))),
            Positioned(bottom: 15, left: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_currentPage == 0 ? "Inventory Tracking" : (_currentPage == 1 ? "Analysis" : "Sales"), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const Text("STOCK&INVENTORY SOFTWARE", style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader(Color cardColor, Color textColor) {
    return TextField(
      onChanged: (val) => setState(() => _searchQuery = val),
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: "Search stock, users, or reports...",
        prefixIcon: const Icon(Icons.search, color: Color(0xFF005696)),
        filled: true, fillColor: cardColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildInventoryChart(Color cardColor, Color nmbBlue, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Inventory Performance", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), Icon(Icons.query_stats, color: nmbBlue)]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, crossAxisAlignment: CrossAxisAlignment.end, children: [_bar(0.4, "Mon", nmbBlue, textColor), _bar(0.8, "Tue", nmbBlue, textColor), _bar(0.6, "Wed", nmbBlue, textColor), _bar(0.9, "Thu", nmbBlue, textColor), _bar(0.5, "Fri", nmbBlue, textColor)]),
        ],
      ),
    );
  }

  Widget _bar(double heightFactor, String day, Color color, Color textColor) {
    return Column(children: [
      Container(width: 20, height: 80 * heightFactor, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
      const SizedBox(height: 5),
      Text(day, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
    ]);
  }

  Widget _buildResponsiveGrid(double width, Color cardColor, Color nmbBlue, Color textColor) {
    final Map<String, IconData> modules = {
      "STOCK": Icons.inventory_2_rounded,
      "SALES": Icons.point_of_sale_rounded,
      "DEBIT": Icons.payment,// Better for POS/Sales
      "REPORTS": Icons.assessment_rounded,
      "ONLINE PAYMENT": Icons.payment,
      "BUSINESS": Icons.business_center_rounded,
      "BRANCH": Icons.account_tree_rounded, // Represents branches/sub-locations branching out
      "EXPENSES": Icons.account_balance_wallet_rounded,
      "STORE": Icons.storefront_rounded,     // Specific to a shop/store
      "BARCODE&QRCODE": Icons.qr_code_scanner_rounded,
      "PERFORMANCE": Icons.speed_rounded,
      "USERS": Icons.people_alt_rounded,
      "NOTIFICATION": Icons.mark_chat_unread_rounded,
      "SHARE IDEA": Icons.tips_and_updates_rounded,
      "CCTV": Icons.videocam_rounded,        // More intuitive for CCTV
      "DIARY": Icons.event_note_rounded,      // Differentiates from CCTV/Calendar
      "INVOICE": Icons.receipt_long_rounded, // Standard for invoices
      "AI/DETECTION": Icons.psychology_rounded, // Great for AI context
      "GRAPHICS": Icons.brush_rounded,       // Clearer for design/graphics
      "CONFIGURATION": Icons.settings_suggest_rounded,
       "SUBSCRIPTION": Icons.payment,

    };
    final filtered = modules.keys.where((k) => k.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    int cols = width > 900 ? 5 : (width > 600 ? 3 : 2);
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filtered.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 15, mainAxisSpacing: 15),
      itemBuilder: (context, index) => InkWell(
        onTap: () => _openServiceMenu(filtered[index]),
        child: Container(decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(modules[filtered[index]], color: nmbBlue), Text(filtered[index], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 10))])),
      ),
    );
  }

  void _handleNavigation(String option) {
    final user = widget.user;

    if (option == "Add Normal Stock") {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => SubAddMedicineScreen(user: user)));
    } else if (option == "View Normal Stock") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewMedicineScreen()));
    } else if (option == "Sales windows") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => SaleScreen(user: user)));
    } else if (option == "view pending bill") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => CartScreen(user: user)));
    } else if (option == "request") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => CartView(user: user)));
    } else if (option == "Manage Staff" || option == "MANAGE STORE") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => SuperViewUsersScreen(user: {},)));
    } else if (option == "Register staff") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => SubAdminRegisterScreenSfaff()));
    } else if (option == "Notify customer" || option == "Manage Customer") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => CustomerListScreen()));
    } else if (option == "sales report") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          SalesReportScreen(
              userRole: 'admin', userName: user['full_name'] ?? 'Admin')));
    } else if (option == "Normal product Stock report") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewMedicineStock()));
    } else if (option == "other product Stock report") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ProductLogsPage()));
    } else if (option == "view financial summary") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => FinancialSummaryScreen()));
    } else if (option == "Business Name") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => AddBusinessScreen()));
    } else if (option == "add company") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => AddCompanyScreen()));
    } else if (option == "add to store") {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => AddMedicineStore(user: user)));
    } else if (option == "view my store") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => FinaViewStoreProducts()));
    } else if (option == "qr code manage") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => QrcodeGenerator()));
    } else
    if (option == "CCTV CONNECTION" || option == "VIEW SUSPECTED VIDEO") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => FFMPEGPlayerScreen()));
    } else if (option == "SET AUTOMATICAL SELL") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => CameraScreen(user: user)));
    } else if (option == "Manage Business Details") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewBusinessesScreen()));
    } else if (option == "Manage company") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewCompaniesScreen()));
    } else if (option == "view store migrated report") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => MigrationLogsScreen()));
    } else if (option == "view stock logs") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => MedicalLogsScreen()));
    } else if (option == "Sales Analysis") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => BusinessSummaryScreen()));
    } else if (option == "Add Expenses") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          NormalUsageForm(userId: user['id'], addedBy: user['full_name'])));
    } else if (option == "import product") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ExcelReaderScreen()));
    } else if (option == "import company") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ExcelCompanyImport()));
    } else if (option == "view expenses") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewNormalUsageScreen()));
    } else if (option == "Salary payment") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => PaySalaryScreen()));
    } else if (option == "View salary history") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => SalaryTableScreen()));
    } else if (option == "deleted product history") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => DeletedMedicinesScreen()));
    } else if (option == "Generate Invoice") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceForm()));
    } else if (option == "print receipt") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          AllReceiptsScreen()));
    } else if (option == "Re -Stock") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          RestockCheckerScreenUser(user: user)));
    } else if (option == "Permission") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          AssignPermissionsScreen(userId: user['id'],
              businessName: user['businessName'],
              userName: user['full_name'])));
    } else if (option == "Add Diary") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddDiaryPage()),
      );
    } else if (option == "Add Event") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => AddEventPage()));
    } else if (option == "view upcoming Event") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => ViewEventPage()));
    } else if (option == "View my Diary") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewDiaryPage()),
      );
    } else if (option == "Store value") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => StoreTotalsScreen()));
    } else if (option == "stock analyse") {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => FinishedMedicinesProfitScreen()));
    } else if (option == "View To Lend(MKOPO)") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          ToLendReportScreen(userRole: user['role'] ?? '',
              userName: user['username'] ?? user['full_name'] ?? '')));
    } else if (option == "To Lend History") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          PaidLendLogsScreen(userRole: user['role'] ?? '',
              userName: user['username'] ?? user['full_name'] ?? '')));
    } else if (option == "Closing&opening Stock") {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ClosingstockViewMedicineScreen()));
    } else if (option == "View Invoice") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewInvoiceScreen()));
    } else if (option == "Graphics") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => DesignEditorScreen(designType: '')));
    } else if (option == "Add other product") {
      Navigator.push(context, MaterialPageRoute(builder: (_) =>
          OtherProduct(user: user, staffId: '', userName: null)));
    } else if (option == "View other product") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => AViewOtherProductScreen(user: user)));
    } else if (option == "DATA ACCUMULATION") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => Data()));
    } else if (option == "View ncd Data") {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DataViewApp()));
    } else if (option == "generate contract") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ContractFormPage()));
    } // Hakikisha ume-import file hapa juu (badilisha jina la file kulingana na unavyolihifadhi)
// import 'pages/reverse_transaction_page.dart';

    else if (option == "Reverse Transaction") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReverseTransaction( // Hakikisha spelling ni ReverseTransaction
            userRole: user['role'] ?? '',
            userName: user['username'] ?? user['full_name'] ?? '',
          ),
        ),
      );
    } else if (option == "View Customer counting and Theft detection") {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => CustomerAnalyticsScreen()));
    } else if (option == "View Delivery Note") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewDeliveryNoteScreen()));
    } else if (option == "commonication setting") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => WhatsAppConfigScreen()));
    } else if (option == "Communication Message") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => LiveWebhookMessages()));
    } else if (option == "View Edited product") {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ViewEditHistory()));
    } else if (option == "Share what you have") {
      Navigator.push(context, MaterialPageRoute(
          builder: (_) => AdvancedChatScreen(currentUserName: '',)));
    } else if (option == "View my Diary") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ViewDiaryPage()),
      );
    } else if (option == "Set payment") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AdminSubscriptionPage()),
      );
    } else if (option == "Control number setting") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BusinessConfigTable()),
      );
    } else if (option == "conline payment") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
      );
    } else if (option == "configure communication") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WhatsAppSetupPage(user: {},)),
      );
    }else if (option == "View all report") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BusinessReportsPage()),
      );
    }else if (option == "Oline account") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  ClickPesaStatementScreen()),
      );
    }else if (option == "Add Non Expired Product") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  AddNonExpiredProduct(user:  user)),
      );
    }else if (option == "Check out") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  MobileMoneyPayoutScreen()),
      );
    }else if (option == "Create New Branch") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>  CreateSubBusinessScreen()),
      );
    }else if (option == "Manage All Branch") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) =>   BranchesManagementScreen()),
      );
    }else if (option == "View Subsription history") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BusinessConfigTable()),
      );
    }


  }

  void _openServiceMenu(String module) {
    List<String> opts = [];
    switch (module.toUpperCase()) {
      case "STOCK":
        opts = ["Add Normal Stock", "Add other product","Add Non Expired Product", "View other product", "View Normal Stock", "View Expired Product", "import product", ];
        break;
      case "SALES":
        opts = ["Sales windows", "view pending bill", "print receipt"];
        break;
      case "DEBIT":
        opts = ["View To Lend(MKOPO)","To Lend History","Reverse Transaction"];
        break;
      case "REPORTS":
        opts = ["sales report", "Normal product Stock report",'View Edited product', 'other product Stock report', "view financial summary", "view store migrated report", "view stock logs", 'Sales Analysis', 'view expenses', 'deleted product history', "stock analyses", "To Lend History", "Reverse Transaction", "Closing&opening Stock",'View salary history'];
        break;
      case "PERFORMANCE":
        opts = ["View all report"];
        break;
      case "USERS":
        opts = ["Manage Staff", "Register staff","Permission"];
        break;
      case "BUSINESS":
        opts = [ "Business Name", "Manage Business Details"];
        break;
      case "STORE":
        opts = ["add to store", "view my store",  "Store value"];
        break;
      case "CCTV":
        opts = ["CCTV CONNECTION", "SET AUTOMATICAL SELL", "VIEW SUSPECTED VIDEO AND CUSTOMER COTING"];
        break;
      case "DIARY":
        opts = ["Add Diary", "View my Diary", 'Add Event', "view upcoming Event"];
        break;
      case "INVOICE":
        opts = ["Generate Invoice", "View Invoice", "View Delivery Note"];
        break;
      case "BARCODE&QRCODE":
        opts = ["qr code manage", "View Invoice", "View Delivery Note"];
        break;
      case "EXPENSES":
        opts = ['Add Expenses', 'view expenses','Salary payment','View salary history'];
        break;
      case "BRANCH":
        opts = ["Create New Branch","Manage All Branch","Manage company", "add company","import company"];
        break;
      case "NOTIFICATION":
        opts = ["Notify customer",];
        break;
      case "SHARE IDEA":
        opts = ["Share what you have"];
        break;
      case "GRAPHICS":
        opts = ["Graphics"];
        break;
      case "AI/DETECTION":
        opts = ["View Customer counting and Theft detection"];
        break;
      case "CONFIGURATION":
        opts = ["commonication setting", "Communication Message",'Control number setting','configure communication'];
        break;
      case "SUBSCRIPTION":
        opts = ["View Subsription history", "Set payment"];
        break;case "ONLINE PAYMENT":
      opts = ["conline payment", "Track payment",'Oline account','Check out'];
      break;
      default:
        opts = [];
    }

    if (opts.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF16213E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        children: opts.map((o) => ListTile(
          title: Text(o, style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87)),
          trailing: Icon(Icons.chevron_right, color: _isDarkMode ? Colors.white70 : Colors.black54),
          onTap: () {
            Navigator.pop(context);
            _handleNavigation(o);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildProfileAvatar(double size) => GestureDetector(
      onTap: () => Scaffold.of(context).openDrawer(),
      child: CircleAvatar(
          radius: size / 2,
          backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
          child: _profileImage == null ? Text(widget.user['full_name'][0]) : null
      )
  );

  Widget _buildNMBFloatingDock(Color nmbBlue) => Container(
      height: 60, margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: nmbBlue, borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        const Icon(Icons.home, color: Colors.white),
        IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedChatScreen (currentUserName: widget.user['username'] ?? 'Admin')))),
        FloatingActionButton(mini: true, onPressed: () {}, child: const Icon(Icons.add)),
        _buildProfileAvatar(30)
      ])
  );

  Widget _buildDesktopSidebar(Color cardColor, Color nmbBlue, Color textColor) =>
      Container(
        width: 250,
        color: cardColor,
        child: Column(
          children: [
            const SizedBox(height: 50),
            _buildProfileAvatar(80),
            const SizedBox(height: 30),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: Text("DASHBOARD", style: TextStyle(color: textColor)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: Colors.teal),
              title: Text("LIVE CHAT", style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => AdvancedChatScreen (currentUserName: widget.user['username'] ?? 'Admin')));
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("LOGOUT"),
              onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false),
            ),
            const SizedBox(height: 20)
          ],
        ),
      );

  Widget _buildSectionLabel(String t, Color c) => Text(t, style: TextStyle(color: c, fontWeight: FontWeight.bold));
}