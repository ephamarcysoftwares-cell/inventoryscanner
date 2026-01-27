import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Nimetumia Supabase kulingana na code zako za mwanzo
import '../FOTTER/CurvedRainbowBar.dart';

class ViewExensesUsageScreen extends StatefulWidget {
  final String userId; // Ibadilishe kuwa String kama unatumia Supabase UUID

  ViewExensesUsageScreen({required this.userId});

  @override
  _ViewExensesUsageScreenState createState() => _ViewExensesUsageScreenState();
}

class _ViewExensesUsageScreenState extends State<ViewExensesUsageScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _usageList = [];
  List<Map<String, dynamic>> _filteredUsageList = [];
  DateTime? _startDate;
  DateTime? _endDate;
  TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  // Light Blue Theme Colors
  final Color primaryBlue = const Color(0xFF0288D1);
  final Color bgBlue = const Color(0xFFF1F9FF);

  @override
  void initState() {
    super.initState();
    _fetchUsageData();
    _searchController.addListener(_filterSearchResults);
  }

  Future<void> _fetchUsageData() async {
    setState(() => _isLoading = true);
    try {
      // Kama unatumia SQLite (DatabaseHelper), rudisha code yako ya mwanzo hapa
      // Hapa nimetumia Supabase kama mfano wa kuendeleza mtiririko wako wa sasa
      final result = await supabase
          .from('normal_usage')
          .select()
          .eq('user_id', widget.userId)
          .order('usage_date', ascending: false);

      setState(() {
        _usageList = List<Map<String, dynamic>>.from(result);
        _filteredUsageList = _usageList;
      });
    } catch (e) {
      debugPrint("Error fetching expenses: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterByDateRange() {
    if (_startDate != null && _endDate != null) {
      setState(() {
        _filteredUsageList = _usageList.where((usage) {
          final usageDate = DateTime.parse(usage['usage_date']);
          return usageDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
              usageDate.isBefore(_endDate!.add(Duration(days: 1)));
        }).toList();
      });
    }
  }

  void _filterSearchResults() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsageList = _usageList.where((usage) {
        final category = usage['category']?.toLowerCase() ?? '';
        final description = usage['description']?.toLowerCase() ?? '';
        return category.contains(query) || description.contains(query);
      }).toList();
    });
  }

  double _getTotalAmount() {
    return _filteredUsageList.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgBlue,
      appBar: AppBar(
        title: const Text("EXPENSES RECORD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. Total Summary Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const Text("Total Expenses", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 5),
                Text(
                  "TSH ${NumberFormat('#,##0').format(_getTotalAmount())}",
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                // 2. Date Pickers
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: _startDate == null ? 'From Date' : DateFormat('dd MMM').format(_startDate!),
                        icon: Icons.calendar_today,
                        onTap: () async {
                          final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                          if (p != null) { setState(() => _startDate = p); _filterByDateRange(); }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateButton(
                        label: _endDate == null ? 'To Date' : DateFormat('dd MMM').format(_endDate!),
                        icon: Icons.event,
                        onTap: () async {
                          final p = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
                          if (p != null) { setState(() => _endDate = p); _filterByDateRange(); }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                // 3. Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search expenses...',
                      prefixIcon: Icon(Icons.search, color: primaryBlue),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Expenses List (Mobile View)
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primaryBlue))
                : _filteredUsageList.isEmpty
                ? const Center(child: Text("Hakuna kumbukumbu zilizopatikana"))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: _filteredUsageList.length,
              itemBuilder: (context, index) {
                final item = _filteredUsageList[index];
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor: bgBlue,
                      child: Icon(Icons.money_off, color: primaryBlue),
                    ),
                    title: Text(item['category'] ?? 'General', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Text(DateFormat('dd-MM-yyyy • hh:mm a').format(DateTime.parse(item['usage_date'])), style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                    trailing: Text(
                      "TSH ${NumberFormat('#,##0').format(item['amount'])}",
                      style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _dateButton({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: primaryBlue),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: primaryBlue, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}