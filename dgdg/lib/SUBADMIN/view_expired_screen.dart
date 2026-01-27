import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class AddminViewExpiredMedicineScreen extends StatefulWidget {
  const AddminViewExpiredMedicineScreen({super.key});

  @override
  _AddminViewExpiredMedicineScreenState createState() => _AddminViewExpiredMedicineScreenState();
}

class _AddminViewExpiredMedicineScreenState extends State<AddminViewExpiredMedicineScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _expiredList = [];
  bool _isLoading = true;

  // Business/Branch Details
  String business_name = '';
  String businessLocation = '';
  String businessPhone = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _getBusinessInfo();
    await _fetchExpiredMedicines();

    // Only attempt to email if there are expired products
    if (_expiredList.isNotEmpty) {
      sendExpiredMedicinesToAdmin();
    }
  }

  // 1. Fetch Business/Branch Details based on logged in user
  Future<void> _getBusinessInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get branch name from user profile
      final profile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      final String myBranch = profile?['business_name'] ?? 'ONLINE STORE';

      // Get full branch details (Location, Phone)
      final bizData = await supabase
          .from('businesses')
          .select()
          .eq('business_name', myBranch)
          .maybeSingle();

      if (mounted) {
        setState(() {
          business_name = myBranch;
          businessLocation = bizData?['location'] ?? 'Not Set';
          businessPhone = bizData?['phone'] ?? 'Not Set';
        });
      }
    } catch (e) {
      debugPrint('❌ Header Load Error: $e');
    }
  }

  // 2. Fetch Expired Products from Supabase (Filtered by Business)
  Future<void> _fetchExpiredMedicines() async {
    setState(() => _isLoading = true);
    try {
      final dateNow = DateTime.now().toIso8601String().split('T')[0];

      final response = await supabase
          .from('medicines')
          .select()
          .eq('business_name', business_name)
          .lt('expiry_date', dateNow); // Less than today

      setState(() {
        _expiredList = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Fetch Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // 3. Email Automation
  Future<void> sendExpiredMedicinesToAdmin() async {
    try {
      final adminUser = await supabase
          .from('users')
          .select('email')
          .eq('role', 'admin')
          .eq('business_name', business_name)
          .maybeSingle();

      String? adminEmail = adminUser?['email'];
      if (adminEmail == null) return;

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      String body = 'Expired Products Report for $business_name\n\n';
      for (var med in _expiredList) {
        body += '- ${med['name']} (Qty: ${med['total_quantity']}, Exp: ${med['expiry_date']})\n';
      }

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
        ..recipients.add(adminEmail)
        ..subject = 'EXPIRED PRODUCTS ALERT: $business_name'
        ..text = body;

      await send(message, smtpServer);
    } catch (e) {
      debugPrint('❌ Email failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expired Products", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
        children: [
          // --- BRANCH HEADER ---
          Card(
            margin: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.teal,
                    radius: 25,
                    child: Icon(Icons.store, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "BRANCH: ${business_name.toUpperCase()}",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                        const SizedBox(height: 4),
                        Text("📍 $businessLocation", style: TextStyle(color: Colors.grey.shade700)),
                        Text("📞 $businessPhone", style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- DATA TABLE OR NO RESULT ---
          Expanded(
            child: _expiredList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, size: 80, color: Colors.green.shade200),
                  const SizedBox(height: 10),
                  const Text(
                    "NO EXPIRED PRODUCTS FOUND",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  Text("All items in $business_name are up to date."),
                ],
              ),
            )
                : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.teal.shade100),
                    columns: const [
                      DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('EXP Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _expiredList.map((med) {
                      return DataRow(cells: [
                        DataCell(Text(med['name'] ?? '')),
                        DataCell(Text('TSH ${med['price'] ?? '0'}')),
                        DataCell(Text('${med['total_quantity'] ?? '0'}')),
                        DataCell(Text(med['unit'] ?? '')),
                        DataCell(Text(med['expiry_date'] ?? '', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                        DataCell(
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: () => _confirmDelete(med['id']),
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  void _confirmDelete(dynamic medicineId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Record?"),
        content: const Text("This will permanently delete this expired product from the cloud database."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFromSupabase(medicineId);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFromSupabase(dynamic medicineId) async {
    try {
      await supabase.from('medicines').delete().eq('id', medicineId);
      _fetchExpiredMedicines(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product removed successfully.')));
    } catch (e) {
      debugPrint('❌ Delete Error: $e');
    }
  }
}