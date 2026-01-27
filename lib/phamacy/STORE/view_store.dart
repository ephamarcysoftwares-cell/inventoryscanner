import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../DB/database_helper.dart';
// Ensure this path matches your project structure exactly
import '../../FOTTER/CurvedRainbowBar.dart';

class FinaViewStoreProducts extends StatefulWidget {
  const FinaViewStoreProducts({super.key});

  @override
  _FinaViewStoreProductsState createState() => _FinaViewStoreProductsState();
}

class _FinaViewStoreProductsState extends State<FinaViewStoreProducts> {
  final supabase = Supabase.instance.client;

  late Future<List<Map<String, dynamic>>> storeProducts = Future.value([]);
  String businessName = 'Loading...';
  String searchQuery = "";
  bool _isDarkMode = false;
  String userRole = '';
  String subBranch = '';
  // Selection and Discount/Quantity tracking
  Map<int, bool> isSelected = {};
  Map<int, double> selectedDiscounts = {};

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> _initializeData() async {
    await _getBusinessInfo();
    _refreshData();
  }

  void _refreshData() {
    if (mounted) {
      setState(() {
        storeProducts = _fetchStoreData();
      });
    }
  }

  /// 1. Get Business Info from Supabase
 // Hii itatusaidia kujua tawi la mtumiaji

  /// 1. Get Business Info from Supabase
  Future<void> _getBusinessInfo() async {
    print('🚀 [DEBUG] _getBusinessInfo started');
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('❌ [DEBUG] No user logged in');
        return;
      }
      print('👤 [DEBUG] User ID: ${user.id}');

      final data = await supabase
          .from('users')
          .select('business_name, sub_business_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          businessName = data['business_name'] ?? 'Unknown';
          subBranch = data['sub_business_name'] ?? '';
          userRole = (data['role'] ?? '').toString().toLowerCase();
        });
        print('✅ [DEBUG] Info Loaded: Biz=$businessName, Branch=$subBranch, Role=$userRole');
      } else {
        print('⚠️ [DEBUG] No user data found in Supabase users table');
      }
    } catch (e) {
      print('❌ [DEBUG] Auth Error Trace: $e');
      debugPrint('Auth Error: $e');
    }
  }

  /// 2. Fetch from public.store
  Future<List<Map<String, dynamic>>> _fetchStoreData() async {
    print('📦 [DEBUG] _fetchStoreData started');
    try {
      var query = supabase.from('store').select();

      // Filter by Business Name
      if (businessName.isNotEmpty && businessName != 'Loading...') {
        print('🔍 [DEBUG] Filtering by business_name: $businessName');
        query = query.eq('business_name', businessName);
      }

      // Branch Logic
      if (userRole != 'storekeeper' && subBranch.isNotEmpty) {
        print('🔍 [DEBUG] Not a storekeeper, filtering by branch: $subBranch');
        query = query.eq('sub_business_name', subBranch);
      }

      if (searchQuery.isNotEmpty) {
        print('🔍 [DEBUG] Searching for: $searchQuery');
        query = query.or('name.ilike.%$searchQuery%,company.ilike.%$searchQuery%');
      }

      final response = await query.order('added_time', ascending: false);

      print('📊 [DEBUG] Supabase returned ${response.length} items');
      if (response.isNotEmpty) {
        print('📝 [DEBUG] First item sample: ${response.first}');
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ [DEBUG] Fetch Data Error: $e');
      return [];
    }
  }

  /// 2. Fetch from public.store


  /// 3. Quantity Input Dialog
  Future<int?> _showQtyDialog(int maxAvailable) async {
    TextEditingController qtyController = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Amount to Migrate"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("In Store: $maxAvailable"),
            const SizedBox(height: 10),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: "Enter Quantity",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(qtyController.text);
              if (val != null && val > 0 && val <= maxAvailable) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid amount")));
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  /// 4. Migration Engine (Partial or Full)
  Future<void> _migrateProcess() async {
    if (isSelected.entries.where((e) => e.value).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select items first")),
      );
      return;
    }

    // Tunahitaji business_id ya huyu mtumiaji
    final userResponse = await supabase
        .from('users')
        .select('business_id')
        .eq('id', supabase.auth.currentUser!.id)
        .single();

    final int myBizId = userResponse['business_id'];
    final products = await storeProducts;

    for (var id in isSelected.keys) {
      if (isSelected[id] == true) {
        final item = products.firstWhere((p) => p['id'] == id);
        int maxQty = item['quantity'] ?? 0;

        int? qtyToMove = await _showQtyDialog(maxQty);

        if (qtyToMove != null) {
          try {
            // 1. Insert into medicines
            final medicineResponse = await supabase.from('medicines').insert({
              'name': item['name'],
              'company': item['company'] ?? 'N/A',
              'total_quantity': qtyToMove,
              'remaining_quantity': qtyToMove,
              'buy': item['buy_price'] ?? 0,
              'price': item['price'] ?? 0,
              'batch_number': item['batch_number'] ?? 'N/A',
              'manufacture_date': item['manufacture_date'],
              'expiry_date': item['expiry_date'],
              'added_by': item['added_by'] ?? 'System',
              'discount': selectedDiscounts[id] ?? 0,
              'unit': item['unit'],
              'business_name': item['business_name'],
              'business_id': myBizId, // Tumeongeza hapa
              'sub_business_name': subBranch,
              'synced': true,
              'added_time': DateTime.now().toIso8601String(),
            }).select().single();

            // 2. SAVE KWENYE MIGRATION_LOGS (Pamoja na Business ID)
            await supabase.from('migration_logs').insert({
              'business_id': myBizId, // <--- MPYA: Hapa ndipo siri ilipo
              'medicine_id': medicineResponse['id'],
              'medicine_name': item['name'],
              'quantity_migrated': qtyToMove,
              'quantity': maxQty,
              'discount': selectedDiscounts[id] ?? 0,
              'status': 'SUCCESS',
              'business_name': item['business_name'],
              'sub_business_name': subBranch, // Log tawi lililopokea mzigo
              'added_by': item['added_by'] ?? 'System',
              'manufacture_date': item['manufacture_date'],
              'expiry_date': item['expiry_date'],
              'batch_number': item['batch_number'] ?? 'N/A',
              'company': item['company'] ?? 'N/A',
              'price': item['price'] ?? 0,
              'buy': item['buy_price'] ?? 0,
              'unit': item['unit'],
              'migration_date': DateTime.now().toIso8601String(),
            });

            // 3. Update au Delete kutoka store
            if (qtyToMove == maxQty) {
              await supabase.from('store').delete().eq('id', id);
            } else {
              await supabase
                  .from('store')
                  .update({'quantity': maxQty - qtyToMove})
                  .eq('id', id);
            }
          } catch (e) {
            debugPrint("Migration Error: $e");
            // Log kosa na business_id pia
            await supabase.from('migration_logs').insert({
              'business_id': myBizId,
              'medicine_name': item['name'],
              'status': 'FAILED: $e',
              'business_name': item['business_name'],
            });
          }
        }
      }
    }

    setState(() {
      isSelected.clear();
      selectedDiscounts.clear();
    });
    _refreshData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Migration Logged with Business ID")),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    // Kutumia rangi zako za awali (Deep Purple)
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(businessName.toUpperCase(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
            Text("STORE INVENTORY", style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7))),
          ],
        ),
        centerTitle: true,
        elevation: 4,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Kitufe cha kuhamisha kwenda Counter
          IconButton(
              tooltip: "Migrate to Counter",
              icon: const Icon(Icons.local_shipping_outlined, color: Colors.white),
              onPressed: _migrateProcess
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _refreshData),
        ],
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
      ),
      body: Column(
        children: [
          _buildSearch(primaryPurple, cardColor, textCol),

          // --- SUMMARY BAR (Optional but looks great on Mobile) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallStat("Items", "Loading...", isDark),
                _buildSmallStat("Selected", "${isSelected.values.where((v) => v).length}", isDark),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 10, left: 8, right: 8),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 15, offset: const Offset(0, -5))
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: _buildTable(primaryPurple, deepPurple, textCol, isDark),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- Widget ya Takwimu ndogo juu ya Table ---
  Widget _buildSmallStat(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.indigo)),
        ],
      ),
    );
  }

  Widget _buildSearch(Color accentColor, Color cardColor, Color textCol) {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: TextField(
          style: TextStyle(color: textCol),
          decoration: InputDecoration(
            hintText: "Search name, batch, or company...",
            hintStyle: TextStyle(fontSize: 14, color: textCol.withOpacity(0.5)),
            prefixIcon: Icon(Icons.search_rounded, color: accentColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onChanged: (v) {
            searchQuery = v;
            _refreshData();
          },
        ),
      ),
    );
  }

  Widget _buildTable(Color primaryPurple, Color deepPurple, Color textCol, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: storeProducts,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: primaryPurple));
        final data = snapshot.data!;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: DataTable(
              columnSpacing: 25,
              horizontalMargin: 20,
              headingRowHeight: 50,
              headingRowColor: WidgetStateProperty.all(deepPurple.withOpacity(isDark ? 0.2 : 0.05)),
              columns: [
                _headerColumn('Select', isDark),
                _headerColumn('Product Details', isDark),
                _headerColumn('Batch', isDark),
                _headerColumn('Stock', isDark),
                _headerColumn('Unit', isDark),
                _headerColumn('Buying', isDark),
                _headerColumn('Selling', isDark),
                _headerColumn('Expiry', isDark),
                _headerColumn('User', isDark),
                _headerColumn('Disc%', isDark),
              ],
              rows: data.map((item) {
                final id = item['id'];

                DateTime? expiry;
                bool isNearExpiry = false;
                if (item['expiry_date'] != null) {
                  expiry = DateTime.parse(item['expiry_date']);
                  isNearExpiry = expiry.isBefore(DateTime.now().add(const Duration(days: 90)));
                }

                return DataRow(
                  selected: isSelected[id] ?? false,
                  color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) return primaryPurple.withOpacity(0.15);
                    return null;
                  }),
                  cells: [
                    DataCell(Checkbox(
                      activeColor: primaryPurple,
                      side: BorderSide(color: textCol.withOpacity(0.5)),
                      value: isSelected[id] ?? false,
                      onChanged: (v) => setState(() {
                        isSelected[id] = v!;
                        if (v) selectedDiscounts[id] = 0.0;
                      }),
                    )),
                    DataCell(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textCol)),
                          Text(item['company'] ?? 'N/A', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF9575CD) : primaryPurple.withOpacity(0.7), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )),
                    DataCell(Text(item['batch_number'] ?? '-', style: TextStyle(fontSize: 12, color: textCol))),
                    DataCell(Text("${item['quantity'] ?? 0}", style: TextStyle(fontWeight: FontWeight.bold, color: textCol))),
                    DataCell(Text(item['unit'] ?? '', style: TextStyle(fontSize: 12, color: textCol))),
                    DataCell(Text("${item['buy_price'] ?? 0}", style: TextStyle(color: textCol.withOpacity(0.6), fontSize: 12))),
                    DataCell(Text("${item['price'] ?? 0}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isNearExpiry ? Colors.red.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        item['expiry_date'] ?? '-',
                        style: TextStyle(
                          color: isNearExpiry ? Colors.redAccent : textCol,
                          fontWeight: isNearExpiry ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    )),
                    DataCell(Text(item['added_by'] ?? '', style: TextStyle(fontSize: 11, color: textCol.withOpacity(0.5)))),
                    DataCell(SizedBox(
                      width: 40,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textCol),
                        decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(color: textCol.withOpacity(0.3)), border: InputBorder.none),
                        onChanged: (v) => selectedDiscounts[id] = double.tryParse(v) ?? 0.0,
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  DataColumn _headerColumn(String label, bool isDark) {
    return DataColumn(
      label: Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF311B92),
            letterSpacing: 0.5
        ),
      ),
    );
  }
}