import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../SMS/sms_gateway.dart'; // Ensure this file and its functions exist
import 'package:supabase_flutter/supabase_flutter.dart';
class StaffToLendReportScreen extends StatefulWidget {
  final String staffId;    // Logged-in staff user_id
  final String userName;   // Logged-in user's name

  const StaffToLendReportScreen({
    super.key,
    required this.staffId,
    required this.userName,
  });

  @override
  _StaffToLendReportScreenState createState() => _StaffToLendReportScreenState();
}

class _StaffToLendReportScreenState extends State<StaffToLendReportScreen> {
  late Future<List<Map<String, dynamic>>> lendData;
  late Future<double> lendTotal;

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;

  String business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';

  // Only message controller remains (used for the reminder message input)
  Map<String, TextEditingController> messageControllers = {};

  // Status tracking
  Map<String, bool> sendingStatus = {};
  Map<String, String> emailStatus = {};

  String get staffId => widget.staffId;
  String get userName => widget.userName;

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
    _applyFilters();
  }

  @override
  void dispose() {
    searchController.dispose();
    messageControllers.values.forEach((c) => c.dispose());
    // Removed disposal of phoneControllers and emailControllers
    super.dispose();
  }

  // --- BUSINESS & DATABASE HELPERS ---

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      // 🛑 CHECK 1: After fetching userProfile
      if (!mounted) return;

      final String? myBusiness = userProfile?['business_name'];
      if (myBusiness == null) return;

      final data = await supabase
          .from('businesses')
          .select()
          .eq('business_name', myBusiness)
          .maybeSingle();

      // 🛑 CHECK 2: After fetching business data
      if (!mounted) return;

      if (data != null) {
        setState(() {
          business_name = data['business_name']?.toString() ?? '';
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
          businessWhatsapp = data['whatsapp']?.toString() ?? '';
          businessLipaNumber = data['lipa_number']?.toString() ?? '';
        });
      }
    } catch (e) {
      if (mounted) debugPrint('❌ Supabase Fetch Error: $e');
    }
  }

  // NOTE: _updateToLendContact has been REMOVED as contacts are no longer editable.

  // Fallback SMS send function (if sms_gateway.dart is not fully implemented)
  Future<bool> _sendSms(String phoneNumber, String message) async {
    final apiKey = 'c675459f5f54525139aa4ce184322393a1a7b83f'; // Placeholder Key

    final url = Uri.parse(
      'https://app.sms-gateway.app/api.php'
          '?apikey=$apiKey'
          '&number=${Uri.encodeComponent(phoneNumber)}'
          '&message=${Uri.encodeComponent(message)}',
    );

    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        try {
          final jsonResponse = json.decode(response.body);
          return jsonResponse['success'] == true;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllPayedLogs(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    try {
      debugPrint("🛰️ Supabase Only: Fetching verified logs for Receipt: $receiptNumber");

      // 1. Get verified User Context (Strict Mode)
      final userRes = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return []; // Lifecycle safety check for mobile

      final String? myBusiness = userRes?['business_name'];
      if (myBusiness == null) throw "Business context missing";

      // 2. Build the Query with Dual-Key Lock
      // We filter by BOTH receipt number AND business name for total isolation
      final response = await supabase
          .from('To_lent_payedlogs')
          .select()
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness) // <--- STRICT MULTI-TENANT FILTER
          .order('created_at', ascending: false);

      // 🛑 Final Lifecycle Check
      if (!mounted) return [];

      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      debugPrint("‼️ Supabase Log Fetch Error: $e");
      return []; // Return empty list to keep UI stable
    }
  }

  /// Fetches the total amount paid by summing 'total_price'
  /// from the To_lent_payedLogs table for a given receipt.
  // 1. Method to calculate how much has been paid so far
  Future<double> _fetchTotalPaid(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    try {
      // Get business context for strict multi-tenancy
      final userRes = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();
      final String? myBusiness = userRes?['business_name'];
      if (myBusiness == null) return 0.0;

      // Fetch all partial payment records for this specific receipt and business
      final response = await supabase
          .from('To_lent_payedlogs')
          .select('total_price')
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness);

      double totalPaid = 0.0;
      if (response != null && response is List) {
        for (var row in response) {
          totalPaid += (double.tryParse(row['total_price'].toString()) ?? 0.0);
        }
      }
      return totalPaid;
    } catch (e) {
      debugPrint("Error fetching total paid: $e");
      return 0.0;
    }
  }

// 2. Method to reconstruct the Original Debt (Paid + Remaining)
  Future<double> _fetchOriginalTotal(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    try {
      final userRes = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();
      final String? myBusiness = userRes?['business_name'];
      if (myBusiness == null) return 0.0;

      // A. Get sum of partial payments
      final double paidSoFar = await _fetchTotalPaid(receiptNumber);

      // B. Get current balance from the debt table
      final debtRes = await supabase
          .from('To_lend')
          .select('total_price')
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness)
          .maybeSingle();

      double remainingDebt = 0.0;
      if (debtRes != null && debtRes['total_price'] != null) {
        remainingDebt = (double.tryParse(debtRes['total_price'].toString()) ?? 0.0);
      }

      // Original = What they paid + What they still owe
      return paidSoFar + remainingDebt;
    } catch (e) {
      debugPrint("Error fetching original total: $e");
      return 0.0;
    }
  }

  /// Calculates the original total debt amount
  /// (Total Paid + Remaining Balance).


  // --- NOTIFICATION HANDLERS ---

  Future<void> _sendEmailAndSmsToCustomer(
      String email,
      String phoneNumber,
      String messageText,
      String receiptNumber,
      ) async {
    setState(() {
      sendingStatus[receiptNumber] = true;
      emailStatus[receiptNumber] = '';
    });

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = Message()
      ..from = Address(
        'suport@ephamarcysoftware.co.tz',
        business_name .isNotEmpty ? business_name  : 'STOCK&INVENTORY SOFTWARE',
      )
      ..recipients.add(email)
      ..subject = 'Notification from ${business_name .isNotEmpty ? business_name  : 'STOCK&INVENTORY SOFTWARE'}'
      ..html = """
      <p>${messageText.replaceAll('\n', '<br>')}</p>
      <small>This email was sent automatically. Please do not reply.</small>
    """;

    bool emailSent = false;
    bool smsSent = false;

    try {
      // 1. Send Email (only if email is provided)
      if (email.isNotEmpty) {
        await send(message, smtpServer);
        emailSent = true;
      }

      // 2. Send SMS
      if (phoneNumber.isNotEmpty) {
        try {
          final smsResponse =  sendSingleMessage(phoneNumber, messageText);
          smsSent = (smsResponse != null && smsResponse.toString().isNotEmpty);
        } catch (_) {
          smsSent = await _sendSms(phoneNumber, messageText);
        }
      }

      setState(() {
        String emailPart = email.isNotEmpty ? (emailSent ? '✅ Email sent!' : '❌ Email failed') : '❗ No email';
        String smsPart = phoneNumber.isNotEmpty ? (smsSent ? '✅ SMS sent!' : '❌ SMS failed') : '❗ No phone';
        emailStatus[receiptNumber] = '$emailPart $smsPart';
      });
    } catch (e) {
      setState(() {
        emailStatus[receiptNumber] = '❌ Failed: $e';
      });
    } finally {
      setState(() {
        sendingStatus[receiptNumber] = false;
      });
    }
  }


  // --- MAIN LOGIC & FILTERS ---

  Future<List<Map<String, dynamic>>> _fetchLendData() async {
    final db = await DatabaseHelper.instance.database;
    final supabase = Supabase.instance.client;

    // 1. Check Connectivity
    var connectivity = await (Connectivity().checkConnectivity());
    bool isOnline = connectivity != ConnectivityResult.none;

    // 2. Try Fetching from Supabase if Online
    if (isOnline) {
      try {
        debugPrint("🛰️ Fetching Active Debts from Supabase...");

        var query = supabase.from('To_lend').select();

        // Apply Date Filters
        if (startDate != null && endDate != null) {
          String start = DateFormat('yyyy-MM-dd').format(startDate!);
          String end = DateFormat('yyyy-MM-dd').format(endDate!);
          query = query.gte('confirmed_time', '$start 00:00:00')
              .lte('confirmed_time', '$end 23:59:59');
        }

        // Apply Search Filter
        if (searchController.text.isNotEmpty) {
          String k = '%${searchController.text}%';
          query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k,medicine_name.ilike.$k,customer_phone.ilike.$k');
        }

        final response = await query.order('confirmed_time', ascending: false);
        return List<Map<String, dynamic>>.from(response);

      } catch (e) {
        debugPrint("⚠️ Supabase Fetch Error (To_lend): $e");
        // If cloud fails, proceed to local fetch
      }
    }

    // 3. Fallback to Local SQLite (Offline or Cloud Failure)
    debugPrint("💾 Fetching Active Debts from Local SQLite...");

    String sql = "SELECT * FROM To_lend";
    bool hasDateFilter = startDate != null && endDate != null;
    bool hasSearch = searchController.text.isNotEmpty;

    List<String> conditions = [];

    if (hasDateFilter) {
      String start = DateFormat('yyyy-MM-dd').format(startDate!);
      String end = DateFormat('yyyy-MM-dd').format(endDate!);
      conditions.add("DATE(confirmed_time) BETWEEN '$start' AND '$end'");
    }

    if (hasSearch) {
      String keyword = searchController.text;
      conditions.add("""
      (receipt_number LIKE '%$keyword%' 
       OR customer_name LIKE '%$keyword%' 
       OR customer_phone LIKE '%$keyword%' 
       OR medicine_name LIKE '%$keyword%')
    """);
    }

    if (conditions.isNotEmpty) {
      sql += " WHERE " + conditions.join(" AND ");
    }

    sql += " ORDER BY confirmed_time DESC";

    return await db!.rawQuery(sql);
  }

  Future<double> _fetchLendTotal() async {
    final db = await DatabaseHelper.instance.database;
    final supabase = Supabase.instance.client;

    // 1. Check Connectivity
    var connectivity = await (Connectivity().checkConnectivity());
    bool isOnline = connectivity != ConnectivityResult.none;

    // 2. Try Supabase Sum if Online
    if (isOnline) {
      try {
        debugPrint("🛰️ Calculating Lend Total from Supabase...");

        // We select only the 'total_price' column to minimize data usage
        var query = supabase.from('To_lend').select('total_price');

        // Apply Date Filters
        if (startDate != null && endDate != null) {
          String start = DateFormat('yyyy-MM-dd').format(startDate!);
          String end = DateFormat('yyyy-MM-dd').format(endDate!);
          query = query.gte('confirmed_time', '$start 00:00:00')
              .lte('confirmed_time', '$end 23:59:59');
        }

        // Apply Search Filter
        if (searchController.text.isNotEmpty) {
          String k = '%${searchController.text}%';
          query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k,medicine_name.ilike.$k');
        }

        final response = await query;

        double cloudTotal = 0.0;
        for (var row in response) {
          cloudTotal += (double.tryParse(row['total_price'].toString()) ?? 0.0);
        }
        return cloudTotal;

      } catch (e) {
        debugPrint("⚠️ Supabase Total Error: $e");
        // Fallback to local if request fails
      }
    }

    // 3. Fallback to SQLite (Offline or Supabase error)
    debugPrint("💾 Calculating Lend Total from Local SQLite...");

    String sql = "SELECT SUM(total_price) AS total_sum FROM To_lend";
    bool hasDateFilter = startDate != null && endDate != null;
    bool hasSearch = searchController.text.isNotEmpty;

    if (hasDateFilter) {
      String start = DateFormat('yyyy-MM-dd').format(startDate!);
      String end = DateFormat('yyyy-MM-dd').format(endDate!);
      sql += " WHERE DATE(confirmed_time) BETWEEN '$start' AND '$end'";
    }

    if (hasSearch) {
      String keyword = searchController.text;
      String searchCondition = """
      (receipt_number LIKE '%$keyword%' OR customer_name LIKE '%$keyword%' OR medicine_name LIKE '%$keyword%')
    """;
      sql += hasDateFilter ? " AND $searchCondition" : " WHERE $searchCondition";
    }

    final result = await db!.rawQuery(sql);
    if (result.isNotEmpty && result.first['total_sum'] != null) {
      return (result.first['total_sum'] as num).toDouble();
    }
    return 0.0;
  }

  void _applyFilters() {
    setState(() => isLoading = true);
    lendData = _fetchLendData();
    lendTotal = _fetchLendTotal();
    Future.wait([lendData, lendTotal]).then((_) {
      setState(() => isLoading = false);
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
        if (isStart) startDate = picked;
        else endDate = picked;
      });
      _applyFilters();
    }
  }

  // --- PAYMENT ACTIONS ---

  void _showPaymentLogsDialog(String receiptNumber) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Payment History - Receipt: $receiptNumber"),
          content: FutureBuilder<List<Map<String, dynamic>>>(
            future: fetchAllPayedLogs(receiptNumber),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text("No payment history found for this receipt.");
              }

              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final log = snapshot.data![index];
                    final amount = (log['total_price'] as num?)?.toDouble() ?? 0.0;
                    final date = log['created_at'] != null
                        ? DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(log['created_at']))
                        : 'N/A';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      elevation: 1,
                      child: ListTile(
                        title: Text("TSH ${NumberFormat('#,##0').format(amount)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        subtitle: Text("Type: ${log['payment_method'] ?? 'Full'} - Date: $date"),
                        trailing: Text("By: ${log['full_name'] ?? 'System'}"),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAsPartiallyPaid(Map<String, dynamic> lendRecord) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal during cloud sync
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Malipo ya Sehemu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Deni lililobaki: TSH ${NumberFormat('#,##0').format(double.tryParse(lendRecord['total_price'].toString()) ?? 0)}"),
                const SizedBox(height: 10),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    hintText: 'Ingiza kiasi ulicholipwa',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  enabled: !isSubmitting,
                ),
                if (isSubmitting) const Padding(padding: EdgeInsets.only(top: 15), child: LinearProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Ghairi'),
              ),
              TextButton(
                child: const Text('Thibitisha', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: isSubmitting ? null : () async {
                  double paid = double.tryParse(amountController.text) ?? 0.0;
                  double total = double.tryParse(lendRecord['total_price'].toString()) ?? 0.0;

                  if (paid <= 0 || paid > total) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiasi si halali')));
                    return;
                  }

                  setDialogState(() => isSubmitting = true);

                  try {
                    // 1. Fetch Verified Identity (Strict Mode)
                    final userRes = await supabase
                        .from('users')
                        .select('business_name, full_name, role')
                        .eq('id', user.id)
                        .maybeSingle();

                    if (!mounted) return;

                    final String? myBusiness = userRes?['business_name'];
                    final String currentStaffName = userRes?['full_name'] ?? user.email ?? 'Unknown';
                    final String currentUserRole = userRes?['role'] ?? 'staff';

                    if (myBusiness == null) throw "Business name not found";

                    double remaining = total - paid;
                    String receiptNumber = lendRecord['receipt_number'];

                    // 2. Prepare Data for Logs & Sales
                    Map<String, dynamic> partialLog = Map.from(lendRecord);
                    partialLog.remove('id'); // ID is auto-gen
                    partialLog['total_price'] = paid;
                    partialLog['payment_method'] = 'Partial';
                    partialLog['business_name'] = myBusiness;
                    partialLog['confirmed_by'] = currentStaffName;
                    partialLog['user_role'] = currentUserRole;
                    partialLog['confirmed_time'] = DateTime.now().toIso8601String();
                    partialLog['created_at'] = DateTime.now().toIso8601String();

                    // 3. CLOUD OPERATIONS
                    // A. Log payment in 'To_lent_payedlogs'
                    await supabase.from('To_lent_payedlogs').insert(partialLog);

                    // B. Add to General 'sales'
                    await supabase.from('sales').insert(partialLog);

                    // C. Update or Delete the Debt Record
                    if (remaining <= 0) {
                      await supabase.from('To_lend')
                          .delete()
                          .eq('receipt_number', receiptNumber)
                          .eq('business_name', myBusiness);
                    } else {
                      await supabase.from('To_lend').update({
                        'total_price': remaining,
                        'created_at': DateTime.now().toIso8601String(),
                      })
                          .eq('receipt_number', receiptNumber)
                          .eq('business_name', myBusiness);
                    }

                    // 4. Success and Communication
                    if (!mounted) return;
                    Navigator.pop(context); // Close dialog
                    _applyFilters();

                    // SMS/Email Logic...
                    String email = (lendRecord['customer_email'] ?? '').trim();
                    String phone = (lendRecord['customer_phone'] ?? '').trim();
                    String msg = "Mpendwa ${lendRecord['customer_name']}, tumepokea malipo ya TSH ${NumberFormat('#,##0').format(paid)} kutoka $myBusiness. Baki: TSH ${NumberFormat('#,##0').format(remaining)}.";

                    _sendEmailAndSmsToCustomer(email, phone, msg, receiptNumber);

                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Malipo ya sehemu yamehifadhiwa!'))
                    );

                  } catch (e) {
                    debugPrint("❌ Supabase Error: $e");
                    if (mounted) {
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: $e')));
                    }
                  }
                },
              ),
            ],
          );
        });
      },
    );
  }


  Future<void> _markAsPaid(Map<String, dynamic> lendRecord) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final String receiptNumber = lendRecord['receipt_number'] ?? 'N/A';
    final String customerName = lendRecord['customer_name'] ?? 'Mteja';
    final double remainingAmount = double.tryParse(lendRecord['total_price'].toString()) ?? 0.0;
    final String formattedAmount = NumberFormat('#,##0').format(remainingAmount);

    // Safety check to prevent processing $0 debts
    if (remainingAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Huu mkopo tayari umeshalipwa.')),
      );
      return;
    }

    // Show a loading indicator while syncing with cloud
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Get Verified Identity & Business Context (Strict Mode)
      final userRes = await supabase
          .from('users')
          .select('business_name, full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final String? myBusiness = userRes?['business_name'];
      final String currentStaffName = userRes?['full_name'] ?? user.email ?? 'Unknown';
      final String currentUserRole = userRes?['role'] ?? 'staff';

      if (myBusiness == null) throw "Business context not found. Please log in again.";

      // 2. Prepare the payment record
      Map<String, dynamic> paymentData = Map.from(lendRecord);
      paymentData.remove('id'); // ID is auto-generated by Postgres
      paymentData['total_price'] = remainingAmount;
      paymentData['payment_method'] = 'Cash';
      paymentData['business_name'] = myBusiness; // Mandatory lock
      paymentData['confirmed_by'] = currentStaffName; // Verified Cloud Name
      paymentData['user_role'] = currentUserRole; // Verified Cloud Role
      paymentData['confirmed_time'] = DateTime.now().toIso8601String();
      paymentData['created_at'] = DateTime.now().toIso8601String();

      // 3. Execute Cloud Operations (Sequential Order)
      // Step A: Record in payment logs
      await supabase.from('To_lent_payedlogs').insert(paymentData);

      // Step B: Record in general sales
      await supabase.from('sales').insert(paymentData);

      // Step C: Remove the debt record entirely
      // We filter by BOTH receipt AND business_name for strict isolation
      await supabase.from('To_lend')
          .delete()
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness);

      // 4. Cleanup and UI Update
      Navigator.pop(context); // Close loading dialog
      _applyFilters(); // Trigger list refresh

      // 5. Notifications
      String email = (lendRecord['customer_email'] ?? '').trim();
      String phoneNumber = (lendRecord['customer_phone'] ?? '').trim();
      String msg = "Mpendwa $customerName, tumepokea malipo yako kamili ya TSH $formattedAmount kutoka $myBusiness. Asante!";

      _sendEmailAndSmsToCustomer(email, phoneNumber, msg, receiptNumber);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Malipo yamekamilika na kuhifadhiwa wingu (Cloud)!')),
      );

    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      debugPrint("❌ Supabase Transaction Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hitilafu: Imeshindwa kuhifadhi malipo ($e)')),
        );
      }
    }
  }


  // --- WIDGET BUILDER ---

  @override
  Widget build(BuildContext context) {
    // Theme Colors consistent with your Admin software
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
              "TO LEND (MIKOPO) REPORT",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              "BRANCH: ${business_name.trim().toUpperCase()}",
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
          // --- Modern Search Bar with Shadow ---
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
          ),

          // --- Date Selection Row ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterDateBtn(
                    context,
                    startDate == null ? "Start Date" : DateFormat('yyyy-MM-dd').format(startDate!),
                        () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterDateBtn(
                    context,
                    endDate == null ? "End Date" : DateFormat('yyyy-MM-dd').format(endDate!),
                        () => _selectDate(context, false),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Outstanding Debt Summary Card ---
          isLoading
              ? const SizedBox(height: 2, child: LinearProgressIndicator(color: primaryPurple))
              : FutureBuilder<double>(
            future: lendTotal,
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    const Text("Total Outstanding Debt", style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      "TSH ${NumberFormat('#,##0', 'en_US').format(snapshot.data ?? 0)}",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // --- List of Debt Records ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                : FutureBuilder<List<Map<String, dynamic>>>(
              future: lendData,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                if (snapshot.data!.isEmpty) return const Center(child: Text("No data available"));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final sale = snapshot.data![index];
                    String receipt = sale['receipt_number'] ?? '';
                    String customerPhone = sale['customer_phone'] ?? 'N/A';
                    String customerEmail = sale['customer_email'] ?? 'N/A';
                    messageControllers.putIfAbsent(receipt, () => TextEditingController());
                    bool isSending = sendingStatus[receipt] == true;
                    String status = emailStatus[receipt] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(receipt, style: const TextStyle(fontWeight: FontWeight.w900, color: primaryPurple)),
                                const Icon(Icons.info_outline, size: 18, color: Colors.grey),
                              ],
                            ),
                            Text(sale['customer_name']?.toString().toUpperCase() ?? "UNKNOWN CUSTOMER",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),

                            const Divider(height: 24),

                            // Contact Info Badges
                            Row(
                              children: [
                                _buildContactBadge(Icons.phone, customerPhone),
                                const SizedBox(width: 10),
                                _buildContactBadge(Icons.email, customerEmail),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Finance Details Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: bgLight, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  _buildFinanceRow("Total Debit", _fetchOriginalTotal(receipt), Colors.teal),
                                  _buildFinanceRow("Total Paid", _fetchTotalPaid(receipt), Colors.purple),
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("REMAINING", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(
                                        "TSH ${NumberFormat('#,##0').format(double.tryParse(sale['total_price'].toString()) ?? 0.0)}",
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            Text("Product: ${sale['medicine_name']}", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                            Text("Staff: ${sale['confirmed_by']} | ${sale['created_at'] ?? ''}", style: const TextStyle(fontSize: 11, color: Colors.grey)),

                            const SizedBox(height: 16),

                            // Reminder Section
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: messageControllers[receipt],
                                    decoration: InputDecoration(
                                      hintText: 'Enter reminder text...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      filled: true,
                                      fillColor: bgLight,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                isSending
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.green),
                                  onPressed: () async {
                                    String msg = messageControllers[receipt]!.text.trim();
                                    if ((customerPhone == 'N/A' && customerEmail == 'N/A') || msg.isEmpty) return;
                                    _sendEmailAndSmsToCustomer(customerEmail != 'N/A' ? customerEmail : '', customerPhone != 'N/A' ? customerPhone : '', msg, receipt);
                                  },
                                ),
                              ],
                            ),
                            if (status.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(status, style: const TextStyle(fontSize: 11, color: Colors.blue)),
                              ),

                            const SizedBox(height: 16),

                            // Action Buttons Row
                            Row(
                              children: [
                                _buildActionBtn(Icons.history, "History", Colors.blueGrey, () => _showPaymentLogsDialog(receipt)),
                                const SizedBox(width: 8),
                                _buildActionBtn(Icons.payment, "Partial", Colors.orange, () => _markAsPartiallyPaid(sale)),
                                const SizedBox(width: 8),
                                _buildActionBtn(Icons.check_circle, "Mark Paid", Colors.green, () {
                                  _confirmFullPayment(context, sale);
                                }),
                              ],
                            ),
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
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

// --- Helper UI Widgets ---

  void _confirmFullPayment(BuildContext context, Map<String, dynamic> sale) {
    final double remaining = double.tryParse(sale['total_price'].toString()) ?? 0.0;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Full Payment"),
        content: Text("Mark TSH ${NumberFormat('#,##0').format(remaining)} for ${sale['customer_name']} as fully PAID?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () { Navigator.pop(context); _markAsPaid(sale); }, child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
        ],
      ),
    );
  }

  Widget _buildFilterDateBtn(BuildContext context, String text, VoidCallback onTap) {
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

  Widget _buildContactBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, Future<double> future, Color color) {
    return FutureBuilder<double>(
      future: future,
      builder: (context, snapshot) {
        String val = snapshot.hasData ? NumberFormat('#,##0').format(snapshot.data) : "...";
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              Text("TSH $val", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 10)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}