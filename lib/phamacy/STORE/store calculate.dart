import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StoreTotalsScreen extends StatefulWidget {
  const StoreTotalsScreen({Key? key}) : super(key: key);

  @override
  _StoreTotalsScreenState createState() => _StoreTotalsScreenState();
}

class _StoreTotalsScreenState extends State<StoreTotalsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _medicines = [];
  bool _isLoading = true;
  String businessName = '';
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadFilteredData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _loadFilteredData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final businessData = await supabase
          .from('businesses')
          .select('business_name')
          .eq('email', user.email!)
          .maybeSingle();

      if (businessData != null) {
        businessName = businessData['business_name'] ?? 'Unknown';

        final response = await supabase
            .from('store')
            .select()
            .eq('business_name', businessName)
            .order('name', ascending: true);

        final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

        final List<Map<String, dynamic>> updated = data.map((medicine) {
          final int quantity = medicine['quantity'] ?? 0;
          final double buy = (medicine['buy_price'] as num?)?.toDouble() ?? 0.0;
          final double price = (medicine['price'] as num?)?.toDouble() ?? 0.0;

          return {
            ...medicine,
            'total_buy_value': buy * quantity,
            'total_sell_value': price * quantity,
          };
        }).toList();

        setState(() {
          _medicines = updated;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Theme Colors ---
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    // Aggregating Totals for Header
    double totalInvested = 0.0;
    double totalProductValue = 0.0;

    for (var medicine in _medicines) {
      totalInvested += (medicine['total_buy_value'] as double? ?? 0.0);
      totalProductValue += (medicine['total_sell_value'] as double? ?? 0.0);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          businessName.isEmpty ? 'LOADING...' : '📦 ${businessName.toUpperCase()} STORE',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
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
          IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadFilteredData
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(25)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: deepPurple))
          : Column(
        children: [
          _buildSummaryHeader(totalInvested, totalProductValue, deepPurple, cardColor, isDark),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10)
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: _buildDataTable(deepPurple, textCol, isDark),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER METHODS ---

  Widget _buildSummaryHeader(double invested, double value, Color accentColor, Color cardColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : accentColor.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(child: _totalColumn("TOTAL INVESTMENT", invested, isDark ? Colors.redAccent.shade100 : Colors.redAccent, isDark)),
            Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.2)),
            Expanded(child: _totalColumn("EXPECTED SALES", value, isDark ? Colors.greenAccent : Colors.green.shade600, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _totalColumn(String title, double amount, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.grey.shade600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "TSH ${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.w900,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(Color deepPurple, Color textCol, bool isDark) {
    return DataTable(
      columnSpacing: 20.0,
      horizontalMargin: 20,
      headingRowHeight: 50,
      headingRowColor: WidgetStateProperty.all(deepPurple.withOpacity(isDark ? 0.2 : 0.05)),
      columns: [
        _headCell('SN', isDark),
        _headCell('Product Name', isDark),
        _headCell('Qty', isDark),
        _headCell('Buy (EA)', isDark),
        _headCell('Sell (EA)', isDark),
        _headCell('Total Buy', isDark),
        _headCell('Total Sell', isDark),
      ],
      rows: _medicines.asMap().entries.map((entry) {
        int idx = entry.key;
        var medicine = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${idx + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textCol))),
            DataCell(Text('${medicine['name']}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textCol))),
            DataCell(Text('${medicine['quantity']}', style: TextStyle(fontWeight: FontWeight.bold, color: textCol))),
            DataCell(Text('${medicine['buy_price']}', style: TextStyle(color: textCol))),
            DataCell(Text('${medicine['price']}', style: TextStyle(color: textCol))),
            DataCell(Text(
              '${medicine['total_buy_value'].toStringAsFixed(1)}',
              style: TextStyle(color: isDark ? Colors.redAccent.shade100 : Colors.redAccent, fontWeight: FontWeight.bold),
            )),
            DataCell(Text(
              '${medicine['total_sell_value'].toStringAsFixed(1)}',
              style: TextStyle(color: isDark ? Colors.greenAccent : Colors.green, fontWeight: FontWeight.bold),
            )),
          ],
        );
      }).toList(),
    );
  }

  DataColumn _headCell(String label, bool isDark) {
    return DataColumn(
      label: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: isDark ? const Color(0xFFB39DDB) : const Color(0xFF311B92),
        ),
      ),
    );
  }
}