import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as businessName;
import 'package:intl/intl.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class StaffPaidLendLogsScreen extends StatefulWidget {
  final String staffId;    // user_id from database
  final String userName;   // staff name

  const StaffPaidLendLogsScreen({
    super.key,
    required this.staffId,
    required this.userName,
  });

  @override
  _StaffPaidLendLogsScreenState createState() => _StaffPaidLendLogsScreenState();
}

class _StaffPaidLendLogsScreenState extends State<StaffPaidLendLogsScreen> {
  late Future<List<Map<String, dynamic>>> paidLendData;
  late Future<double> paidLendTotal;

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;

  String get staffId => widget.staffId;
  String get userName => widget.userName;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }



  Future<List<Map<String, dynamic>>> _fetchPaidLendData() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    try {
      debugPrint("🛰️ Supabase Only: Fetching logs using user_role logic...");

      // 1. Get verified User Context (Business, Name, and Role)
      final userRes = await supabase
          .from('users')
          .select('business_name, full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return [];

      final String? myBusiness = userRes?['business_name'];
      final String currentStaffName = userRes?['full_name'] ?? user.email ?? 'Unknown';

      // FETCH THE ROLE: Default to 'staff' if not found
      final String userRole = userRes?['role']?.toString().toLowerCase() ?? 'staff';

      if (myBusiness == null) return [];

      // 2. Build the Base Query with Multi-Tenant Lock
      var query = supabase
          .from('To_lent_payedlogs')
          .select()
          .eq('business_name', myBusiness); // Main security barrier

      // 3. APPLY ROLE-BASED FILTERING
      // Logic: If the user is NOT an admin, only show logs they confirmed.
      if (userRole != 'admin') {
        query = query.eq('confirmed_by', currentStaffName);
      }

      // 4. Date Range Filtering
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!);
        query = query.gte('confirmed_time', '$start 00:00:00')
            .lte('confirmed_time', '$end 23:59:59');
      }

      // 5. Search Filtering
      if (searchController.text.trim().isNotEmpty) {
        String k = '%${searchController.text.trim()}%';
        query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k,medicine_name.ilike.$k');
      }

      // 6. Execute and Sort by your schema's created_at column
      final response = await query.order('created_at', ascending: false);

      if (!mounted) return [];

      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      debugPrint("‼️ Supabase Fetch Error: $e");
      return [];
    }
  }

  // Add this variable at the top of your State class if it's missing
  double _totalCollected = 0.0;

  void _applyFilters() {
    setState(() => isLoading = true);

    _fetchPaidLendData().then((data) {
      if (mounted) {
        // Calculate total from the list of results
        double total = 0.0;
        for (var row in data) {
          // We use double.tryParse because 'total_price' is numeric in your schema
          total += double.tryParse(row['total_price'].toString()) ?? 0.0;
        }

        setState(() {
          // If you are using a FutureBuilder for the list, keep this:
          paidLendData = Future.value(data);
          // Update the total display
          _totalCollected = total;
          isLoading = false;
        });
      }
    }).catchError((e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("Error in filters: $e");
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) startDate = picked; else endDate = picked;
      });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "PAID TO LEND (MKOPO)",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              "BRANCH: ${'businessName'}",
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ],
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Column(
        children: [
          // --- Search Bar with Shadow Fix ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: "Search records...",
                  prefixIcon: const Icon(Icons.search, color: primaryPurple),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
          ),

          // --- Date Selection ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateInput(
                    startDate == null ? "Start Date" : DateFormat('yyyy-MM-dd').format(startDate!),
                        () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateInput(
                    endDate == null ? "End Date" : DateFormat('yyyy-MM-dd').format(endDate!),
                        () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Total Summary Card ---
          isLoading
              ? const LinearProgressIndicator(color: primaryPurple)
              : FutureBuilder<double>(
            future: paidLendTotal,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      const Text("Total Debt Payments Received",
                          style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        "TSH ${NumberFormat('#,##0').format(snapshot.data!)}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // --- Data List (Modern replacement for DataTable) ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                : FutureBuilder<List<Map<String, dynamic>>>(
              future: paidLendData,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                if (snapshot.data!.isEmpty) {
                  return const Center(child: Text("No data found", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final sale = snapshot.data![index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
                      ),
                      child: ExpansionTile(
                        shape: const Border(), // Removes default borders
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                        title: Text(
                          sale['customer_name']?.toString().toUpperCase() ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text("Receipt: ${sale['receipt_number']}", style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          "TSH ${NumberFormat('#,##0').format(sale['total_price'] ?? 0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryPurple),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                const Divider(),
                                _buildDetailRow("Product", sale['medicine_name']),
                                _buildDetailRow("Quantity", sale['remaining_quantity'].toString()),
                                _buildDetailRow("Payment", sale['payment_method']),
                                _buildDetailRow("Phone", sale['customer_phone']),
                                _buildDetailRow("Date", DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(sale['confirmed_time']))),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- Helper UI Components ---

  Widget _buildDateInput(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF673AB7)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value ?? 'N/A',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
