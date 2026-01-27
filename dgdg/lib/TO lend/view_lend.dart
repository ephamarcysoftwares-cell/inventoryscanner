import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../SMS/sms_gateway.dart'; // Ensure this file and its functions exist
import 'package:supabase_flutter/supabase_flutter.dart';
class ToLendReportScreen extends StatefulWidget {
  final String userRole; // 'admin' or 'staff'
  final String userName; // Logged-in user's name

  const ToLendReportScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  _ToLendReportScreenState createState() => _ToLendReportScreenState();
}

class _ToLendReportScreenState extends State<ToLendReportScreen> {
  Future<List<Map<String, dynamic>>>? lendData; // Ongeza ?
  Future<double>? lendTotal; // Ongeza ?

  TextEditingController searchController = TextEditingController();
  DateTime? startDate;
  DateTime? endDate;
  bool isLoading = false;
  bool _isDarkMode = false;
  String business_name = '';
  // Unaweza kutumia int kama ID yako ni namba, au String kama ni UUID
  dynamic currentBusinessId;
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String smsApiKey = '';
  String smsGatewayServer = '';
  String waInstanceId = '';
  String waAccessToken = '';
  // message controllers per receipt
  Map<String, TextEditingController> messageControllers = {};
  Map<String, bool> sendingStatus = {}; // to track which row is sending
  Map<String, String> emailStatus = {}; // success / error messages

  // NEW: editable phone & email controllers per receipt
  final Map<String, TextEditingController> phoneControllers = {};
  final Map<String, TextEditingController> emailControllers = {};

  String get userRole => widget.userRole;
  String get userName => widget.userName;

  @override
  void initState() {
    super.initState();
    _loadTheme();

    // Kila mtu anaweza kuona (Admin, Sub-Admin, Staff)
    // Lakini mfumo utachuja data kulingana na business_id yao
    _loadBusinessInfo().then((_) {
      _applyFilters();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    // dispose message controllers
    messageControllers.values.forEach((c) => c.dispose());
    phoneControllers.values.forEach((c) => c.dispose());
    emailControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }

  void _showAccessDeniedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Access Denied"),
        content: const Text("You do not have permission to view this report."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  // Helper: update To_lend contact info (phone & email) for a receipt
  Future<void> _updateToLendContact(String receiptNumber, String phone, String email) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      // 1. Get the current user's business context (Strict Mode)
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      // 🛑 Lifecycle Check: Stop if the screen was closed during the fetch
      if (!mounted) return;

      final String? myBusiness = userProfile?['business_name'];
      if (myBusiness == null) throw "Business context not found";

      // 2. Perform the Update strictly filtered by Business and Receipt
      await supabase
          .from('To_lend') // Ensure case-sensitive table name matches
          .update({
        'customer_phone': phone,
        'customer_email': email,
      })
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness); // <--- STRICT MULTI-TENANT LOCK

      debugPrint('✅ Updated Supabase To_lend contact for $receiptNumber => phone: $phone');

      // 3. UI Feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mawasiliano yamesasishwa!')),
        );
      }

    } catch (e) {
      debugPrint('❌ Failed to update Supabase contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Fallback SMS send function (if sms_gateway.dart is not fully implemented)


  Future<void> _loadBusinessInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Pata business_id NA business_name kutoka kwa user profile
      final userProfile = await supabase
          .from('users')
          .select('business_id, business_name') // ✅ Ongeza business_id hapa
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null) {
        final String myBusiness = userProfile['business_name']?.toString().trim() ?? '';

        // Hifadhi business_id mapema ili functions zingine ziweze kuitumia
        if (mounted) {
          setState(() {
            currentBusinessId = userProfile['business_id'];
          });
        }

        // 2. Vuta taarifa zingine za biashara (Logo, Simu, nk)
        final List<dynamic> response = await supabase
            .from('businesses')
            .select()
            .eq('business_name', myBusiness)
            .limit(1);

        if (mounted && response.isNotEmpty) {
          var data = response.first;

          setState(() {
            business_name = data['business_name']?.toString().trim() ?? '';
            businessPhone = data['phone']?.toString() ?? '';
            businessEmail = data['email']?.toString() ?? '';
            businessLogoPath = data['logo']?.toString() ?? '';

            smsApiKey = data['sms_api_key'] ?? '';
            smsGatewayServer = data['sms_gateway_server'] ?? '';
            waInstanceId = data['whatsapp_instance_id'] ?? '';
            waAccessToken = data['whatsapp_access_token'] ?? '';

            // Kama business_id haikuwepo kwenye users lakini ipo kwenye businesses table:
            if (currentBusinessId == null) {
              currentBusinessId = data['id'];
            }
          });

          debugPrint("✅ Business Info Loaded: $business_name (ID: $currentBusinessId)");

          // Sasa vuta data za madeni kwa kutumia ID iliyopatikana
          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading business fixed: $e');
    }
  }
  Future<void> _sendPaymentNotifications({
    required String customerName,
    required String customerPhone,
    required String amountPaid,
    required String balanceRemaining,
    required String receipt,
  }) async {
    // 1. Tengeneza Ujumbe kwa Lugha ya Heshima
    // Nimetumia herufi za kwanza tu kuwa kubwa kwa mvuto zaidi (Title Case)
    String message = "SHUKRANI KWA MALIPO\n\n"
        "Habari MPENDWA MTEJA WETU WA THAMANI, ${customerName.toUpperCase()},\n\n"
        "Tunafurahi kukutaarifu kuwa tumepokea malipo yako kikamilifu. Kwa Muhtasari wa muamala:\n\n"
        "KUTOKA: ${business_name.trim()}\n"
        "NAMBA YA RISITI: #$receipt\n"
        "TAREHE: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}\n"
        "-------------------------------------------\n"
        "KIASI ULICHOLIPA: TSH $amountPaid\n"
        "DENI LILILOBAKI: TSH $balanceRemaining\n"
        "-------------------------------------------\n\n"
        " Asante kwa uaminifu wako. Ni fahari yetu kukuhudumia!\n\n"
        "Kama Unaswali ua Changamoto tufikie kupitia : $businessPhone\n\n"
        "Tunafurahi sana kuja kupa Huma Hapa Kwetu,\n"
        "${business_name.trim()}";

    // 2. Safisha namba ya mteja ianze na +255 (Kama ulivyoelekeza)
    String cleanPhone = customerPhone.replaceAll(RegExp(r'\D'), ''); // Ondoa kila kitu kisicho namba
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '+255${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('255')) {
      cleanPhone = '+$cleanPhone';
    } else if (!cleanPhone.startsWith('+255')) {
      cleanPhone = '+255$cleanPhone';
    }

    try {
      // 3. TUMA WHATSAPP
      if (waInstanceId.trim().isNotEmpty && waAccessToken.trim().isNotEmpty) {
        final waUrl = Uri.parse('https://wawp.net/wp-json/awp/v1/send');

        // Baadhi ya API za WhatsApp hazipendi alama ya '+'
        // Kama haitaenda, tumia: String waPhone = cleanPhone.replaceAll('+', '');
        String waPhone = cleanPhone;

        final waResponse = await http.post(waUrl, body: {
          'instance_id': waInstanceId.trim(),
          'access_token': waAccessToken.trim(),
          'number': waPhone,
          'message': message,
          'type': 'text'
        });

        debugPrint("WhatsApp Status: ${waResponse.statusCode} - Body: ${waResponse.body}");
      }

      // 4. TUMA SMS
      if (smsApiKey.trim().isNotEmpty && smsGatewayServer.trim().isNotEmpty) {
        final smsUrl = Uri.parse("${smsGatewayServer.trim()}/services/send.php");

        final smsResponse = await http.post(smsUrl, body: {
          'number': cleanPhone, // SMS API nyingi zinakubali +255
          'message': message,
          'key': smsApiKey.trim()
        });

        debugPrint("SMS Status: ${smsResponse.statusCode}");
      }

    } catch (e) {
      debugPrint("❌ Notification Error: $e");
    }
  }
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

    // NOTE: Replace these with your actual SMTP credentials
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
        business_name.isNotEmpty ? business_name : 'STOCK&INVENTORY SOFTWARE',
      )
      ..recipients.add(email)
      ..subject = 'Notification from ${business_name.isNotEmpty ? business_name : 'STOCK&INVENTORY SOFTWARE'}'
      ..html = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; background-color: #f8f8f8; margin: 0; padding: 0; }
    .container { background-color: #ffffff; border-radius: 8px; padding: 20px; max-width: 600px; margin: 40px auto; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    h2 { color: #2e7d32; margin-top: 0; }
    p { font-size: 15px; line-height: 1.6; color: #333333; }
    .footer { margin-top: 20px; font-size: 12px; color: #999999; text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <h2>Reminder Message from ${business_name.isNotEmpty ? business_name : 'STOCK&INVENTORY SOFTWARE'}</h2>
    <p>${messageText.replaceAll('\n', '<br>')}</p>
    <div class="footer">This email was sent automatically. Please do not reply.</div>
  </div>
</body>
</html>
""";

    try {
      // Send email (only if email provided)
      if (email.isNotEmpty) {
        await send(message, smtpServer);
      }

      // Send SMS using your SMS Gateway client function (or fallback)
      bool smsSent = false;
      if (phoneNumber.isNotEmpty) {
        // try to use sendSingleMessage from sms_gateway.dart if it exists
        try {
          // Assuming sendSingleMessage is a defined function in sms_gateway.dart
          final smsResponse =  sendSingleMessage(phoneNumber, messageText);
          // Check if the response indicates success (adjust based on your sms_gateway logic)
          smsSent = (smsResponse != null && smsResponse.toString().isNotEmpty);
        } catch (_) {
          // Fallback to local _sendSms if sendSingleMessage fails or is not found
          // smsSent = await _sendSms(phoneNumber, messageText);
        }
      }

      setState(() {
        emailStatus[receiptNumber] =
        '${email.isNotEmpty ? "✅ Email sent successfully!" : "❗ No email"} ${smsSent ? "✅ SMS sent successfully!" : (phoneNumber.isNotEmpty ? "❌ SMS failed" : "❗ No phone") }';
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
  Future<void> debugCheckColumns() async {
    final supabase = Supabase.instance.client;
    try {
      // Jaribu kuvuta row moja tu kutoka To_lend
      final response = await supabase.from('To_lend').select().limit(1);

      if (response.isNotEmpty) {
        debugPrint("🔍 DEBUG: Column zilizopo kwenye To_lend ni: ${response.first.keys.toList()}");

        if (response.first.containsKey('business_id')) {
          debugPrint("✅ SUCCESS: Column 'business_id' ipo tayari!");
        } else {
          debugPrint("❌ ERROR: Column 'business_id' HAIPO. Table inatumia: ${response.first.keys.toList()}");
        }
      } else {
        debugPrint("⚠️ Table ya To_lend haina data yoyote kwa sasa.");
      }
    } catch (e) {
      debugPrint("‼️ Debug Error: $e");
    }
  }
  Future<List<Map<String, dynamic>>> fetchLendData() async {
    try {
      // 1. Hakikisha business_id ipo
      if (currentBusinessId == null) {
        debugPrint("⚠️ currentBusinessId ni NULL");
        return [];
      }

      final supabase = Supabase.instance.client;

      // 2. BADILISHA HAPA: Tumia jina la table lenye data za mikopo
      // Kulingana na schema yako, table inaitwa "To_lend"
      var query = supabase
          .from('To_lend') // Kama uliandika "To_lend" kwenye SQL, tumia hivi hivi
          .select()
          .eq('business_id', currentBusinessId);

      // 3. Filter ya kutafuta (Search)
      String search = searchController.text.trim();
      if (search.isNotEmpty) {
        query = query.or('customer_name.ilike.%$search%,receipt_number.ilike.%$search%,medicine_name.ilike.%$search%');
      }

      // 4. Filter ya Tarehe
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!.add(const Duration(days: 1)));
        query = query.gte('created_at', start).lt('created_at', end);
      }

      // 5. Kupanga matokeo
      final response = await query.order('created_at', ascending: false);

      debugPrint("✅ Zimepatikana safu ${response.length} kutoka To_lend");
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("❌ Error fetching lend data: $e");
      return [];
    }
  }

  Future<double> _fetchLendTotal() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return 0.0;

    try {
      // 1. Tumia ID tuliyoipata tayari kwenye _loadBusinessInfo ili kuokoa muda
      // Lakini kama bado haijapatikana, tunatumia ile ya kwenye profile
      final dynamic myId = currentBusinessId;

      if (myId == null) {
        debugPrint("⚠️ Business ID haijapatikana bado...");
        return 0.0;
      }

      debugPrint("🔍 DEBUG: Calculating Total for Business ID: $myId");

      // 2. Build Query
      var query = supabase
          .from('To_lend')
          .select('total_price')
          .eq('business_id', myId);

      // Filter kwa Role (Staff aone tu alizothibitisha yeye)
      if (userRole != 'admin' && userRole != 'sub_admin') {
        query = query.eq('confirmed_by', userName);
      }

      // Filter kwa Tarehe
      if (startDate != null && endDate != null) {
        query = query.gte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(startDate!)} 00:00:00')
            .lte('confirmed_time', '${DateFormat('yyyy-MM-dd').format(endDate!)} 23:59:59');
      }

      // 3. 🆕 ONGEZA HII: Filter kwa Search (Ili jumla iendane na kile unachokiona kwenye list)
      if (searchController.text.trim().isNotEmpty) {
        String k = '%${searchController.text.trim()}%';
        query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k,medicine_name.ilike.$k');
      }

      final response = await query;

      if (!mounted) return 0.0;

      // 4. Piga Jumla
      double cloudTotal = 0.0;
      if (response is List) {
        for (var row in response) {
          // Hakikisha total_price inasomwa vizuri hata kama ni namba au string
          cloudTotal += (double.tryParse(row['total_price'].toString()) ?? 0.0);
        }
      }

      debugPrint("💰 DEBUG: Total Debt calculated: TSH $cloudTotal");
      return cloudTotal;

    } catch (e) {
      debugPrint("‼️ Sum Error: $e");
      return 0.0;
    }
  }

  void _applyFilters() {
    setState(() {
      lendData = fetchLendData(); // Hakikisha hii inarudisha Future<List>
      lendTotal = calculateLendTotal(); // Hakikisha hii inarudisha Future<double>
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

  /// ✅ Fetches the total amount paid by summing 'total_price'
  /// from the To_lent_payedLogs table for a given receipt.
  Future<double> _fetchTotalPaid(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return 0.0;

    try {
      // 1. Get user's business context (Strict Mode)
      final userProfile = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();
      if (!mounted) return 0.0;

      final String? myBusiness = userProfile?['business_name'];

      // 2. Query the Payed Logs table
      final response = await supabase
          .from('To_lent_payedlogs') // Matches your case-sensitive table
          .select('total_price')
          .eq('receipt_number', receiptNumber)
          .eq('business_name', myBusiness ?? ''); // STRICT FILTER

      if (!mounted) return 0.0;

      // 3. Sum the payments
      double totalPaid = 0.0;
      for (var row in response) {
        totalPaid += (double.tryParse(row['total_price'].toString()) ?? 0.0);
      }
      return totalPaid;
    } catch (e) {
      debugPrint("⚠️ Error fetching total paid: $e");
      return 0.0;
    }
  }
  Future<double> calculateLendTotal() async {
    try {
      if (currentBusinessId == null) return 0.0;

      final supabase = Supabase.instance.client;

      // Tunasoma kutoka "To_lend" kwa sababu huku ndiko deni lililopo (Debit)
      var query = supabase
          .from('To_lend')
          .select('total_price')
          .eq('business_id', currentBusinessId);

      // Filter kwa Search
      String searchTerm = searchController.text.trim();
      if (searchTerm.isNotEmpty) {
        query = query.or('customer_name.ilike.%$searchTerm%,receipt_number.ilike.%$searchTerm%');
      }

      // Filter kwa Tarehe
      if (startDate != null && endDate != null) {
        String start = DateFormat('yyyy-MM-dd').format(startDate!);
        String end = DateFormat('yyyy-MM-dd').format(endDate!.add(const Duration(days: 1)));
        query = query.gte('created_at', start).lt('created_at', end);
      }

      final response = await query;

      double totalDebit = 0.0;
      if (response != null && response is List) {
        for (var row in response) {
          totalDebit += double.tryParse(row['total_price'].toString()) ?? 0.0;
        }
      }

      debugPrint("💰 DEBUG: Total Debit (Deni linalodaiwa): TSH $totalDebit");
      return totalDebit;
    } catch (e) {
      debugPrint("❌ Error calculating total debit: $e");
      return 0.0;
    }
  }
  Future<double> _fetchOriginalTotal(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null || currentBusinessId == null) return 0.0;

    try {
      // 1. Pata jumla ya malipo yote yaliyokwisha fanyika (kutoka logs za malipo)
      final double totalPaid = await _fetchTotalPaid(receiptNumber);
      if (!mounted) return 0.0;

      // 2. Tafuta deni lililobaki kwenye table ya To_lend kwa kutumia business_id
      // Tunatumia .select() pekee bila single() ili kupata items zote za risiti hiyo
      final remainingRes = await supabase
          .from('To_lend')
          .select('total_price')
          .eq('receipt_number', receiptNumber)
          .eq('business_id', currentBusinessId); // ✅ Imebadilishwa kutoka jina kwenda ID

      if (!mounted) return 0.0;

      // 3. Jumlisha madeni yote yaliyosalia kwenye To_lend kwa risiti hii
      double remainingBalance = 0.0;
      if (remainingRes != null && remainingRes is List) {
        for (var row in remainingRes) {
          remainingBalance += (double.tryParse(row['total_price'].toString()) ?? 0.0);
        }
      }

      // 4. Deni la mwanzo = Jumla ya pesa zilizolipwa + Deni lililosalia
      debugPrint("📊 Receipt: $receiptNumber | Paid: $totalPaid | Remaining: $remainingBalance");
      return totalPaid + remainingBalance;

    } catch (e) {
      debugPrint("⚠️ Fixed Error in _fetchOriginalTotal: $e");
      return 0.0;
    }
  }
  // Function to fetch all payment logs for a specific receipt
  Future<List<Map<String, dynamic>>> fetchAllPayedLogs(String receiptNumber) async {
    final supabase = Supabase.instance.client;
    if (currentBusinessId == null) return [];

    try {
      // Fetch logs za malipo kwa kutumia business_id
      final response = await supabase
          .from('To_lent_payedlogs')
          .select('*')
          .eq('receipt_number', receiptNumber)
          .eq('business_id', currentBusinessId) // ✅ Inatumia ID (mfano 34)
          .order('created_at', ascending: false);

      if (response == null) return [];

      debugPrint("✅ Historia ya malipo kwa risiti $receiptNumber: ${response.length} logs.");
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("‼️ Supabase Fetch Error (Logs): $e");
      return [];
    }
  }

  // Function to display the payment logs in a dialog
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

  /// ✅ New: mark as partially paid
  /// ✅ New: mark as partially paid
  Future<void> _markAsPartiallyPaid(Map<String, dynamic> lendRecord) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1. 🛡️ ULINZI WA ROLE: Zuia kama sio Admin au Sub-Admin
    if (userRole != 'admin' && userRole != 'sub_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Huna ruhusa ya kufanya malipo. Wasiliana na Admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    TextEditingController amountController = TextEditingController();
    TextEditingController phoneController = TextEditingController(text: lendRecord['customer_phone'] ?? '');
    String receipt = lendRecord['receipt_number'] ?? 'N/A';
    String cName = lendRecord['customer_name'] ?? 'Mteja Wetu';

    // Hakikisha tunapata business_id kutoka kwenye record ya sasa
    final dynamic bId = lendRecord['business_id'] ?? currentBusinessId;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('MALIPO YA SEHEMU: #$receipt', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Namba ya Simu'), keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                TextField(controller: amountController, decoration: const InputDecoration(hintText: 'Kiasi kinacholipwa (TSH)'), keyboardType: TextInputType.number),
                if (isSubmitting) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Ghairi', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSubmitting ? null : () async {
                  double paid = double.tryParse(amountController.text.trim()) ?? 0.0;
                  double currentDebt = double.tryParse(lendRecord['total_price'].toString()) ?? 0.0;
                  double remaining = currentDebt - paid;

                  if (paid <= 0 || paid > currentDebt) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kiasi si halali')));
                    return;
                  }

                  setDialogState(() => isSubmitting = true);

                  try {
                    final userRes = await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
                    final String staff = userRes?['full_name'] ?? userName;

                    // 2. 🛰️ ANDAA LOG (Pamoja na business_id)
                    Map<String, dynamic> log = Map.from(lendRecord);
                    log.remove('id'); // ID ya To_lend isitumike kwenye log mpya
                    log['synced'] = 1;
                    log['total_price'] = paid; // Kiasi kilicholipwa sasa
                    log['payment_method'] = 'Partial Cash';
                    log['confirmed_by'] = staff;
                    log['full_name'] = staff;
                    log['confirmed_time'] = DateTime.now().toIso8601String();
                    log['paid_time'] = DateTime.now().toIso8601String();
                    log['user_id'] = user.id;
                    log['business_id'] = bId; // ✅ SAVE BUSINESS ID

                    // Insert kwenye Logs na Sales
                    await supabase.from('To_lent_payedlogs').insert(log);
                    await supabase.from('sales').insert(log);

                    // 3. 🔄 UPDATE AU DELETE KWENYE TO_LEND
                    if (remaining <= 0) {
                      await supabase.from('To_lend')
                          .delete()
                          .eq('receipt_number', receipt)
                          .eq('business_id', bId); // ✅ LOCK KWA ID
                    } else {
                      await supabase.from('To_lend').update({
                        'total_price': remaining,
                        'customer_phone': phoneController.text,
                      })
                          .eq('receipt_number', receipt)
                          .eq('business_id', bId); // ✅ LOCK KWA ID
                    }

                    // 🔥 Notification
                    _sendPaymentNotifications(
                      customerName: cName,
                      customerPhone: phoneController.text,
                      amountPaid: NumberFormat('#,##0').format(paid),
                      balanceRemaining: NumberFormat('#,##0').format(remaining),
                      receipt: receipt,
                    );

                    Navigator.pop(dialogContext);
                    _applyFilters(); // Refresh data

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Malipo yamefanikiwa!'), backgroundColor: Colors.green));
                  } catch (e) {
                    debugPrint("‼️ Error updating payment: $e");
                    setDialogState(() => isSubmitting = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kosa: $e')));
                  }
                },
                child: const Text('Thibitisha', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
  }


  // The definition of _markAsPaid is updated:
  // The definition of _markAsPaid is updated:
  Future<void> _markAsPaid(Map<String, dynamic> lendRecord) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 1. 🛡️ Ulinzi wa Role
    if (userRole != 'admin' && userRole != 'sub_admin') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Huna ruhusa ya kuthibitisha malipo. Wasiliana na Admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Hifadhi Messenger mapema kabla ya kuanza async yoyote
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final String receipt = lendRecord['receipt_number'] ?? 'N/A';
    final String cName = lendRecord['customer_name'] ?? 'Mteja Wetu';
    final double amount = double.tryParse(lendRecord['total_price'].toString()) ?? 0.0;
    final String cPhone = lendRecord['customer_phone'] ?? '';
    final dynamic bId = lendRecord['business_id'] ?? currentBusinessId;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Full Payment'),
        content: Text('Uthibitishe kupokea TSH ${NumberFormat('#,##0').format(amount)} kutoka kwa $cName kwa risiti #$receipt?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            child: const Text('Confirm', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            onPressed: () async {
              // Funga Dialog kwanza
              Navigator.pop(dialogContext);

              try {
                final userRes = await supabase.from('users').select('full_name').eq('id', user.id).maybeSingle();
                final String staff = userRes?['full_name'] ?? userName;

                // 2. 🛰️ Andaa Data
                Map<String, dynamic> paymentData = Map.from(lendRecord);
                paymentData.remove('id');
                paymentData['synced'] = 1;
                paymentData['business_id'] = bId;
                paymentData['business_name'] = business_name;
                paymentData['payment_method'] = 'Full Cash';
                paymentData['confirmed_time'] = DateTime.now().toIso8601String();
                paymentData['paid_time'] = DateTime.now().toIso8601String();
                paymentData['confirmed_by'] = staff;
                paymentData['full_name'] = staff;
                paymentData['user_id'] = user.id;

                // Ingiza kwenye Logs na Sales
                await supabase.from('To_lent_payedlogs').insert(paymentData);
                await supabase.from('sales').insert(paymentData);

                // 3. 🗑️ Futa Deni
                await supabase.from('To_lend')
                    .delete()
                    .eq('receipt_number', receipt)
                    .eq('business_id', bId);

                // Tuma Notification (Hii haina haja ya context)
                _sendPaymentNotifications(
                  customerName: cName,
                  customerPhone: cPhone,
                  amountPaid: NumberFormat('#,##0').format(amount),
                  balanceRemaining: "0.00 (UMEKWISHA)",
                  receipt: receipt,
                );

                // 4. MUHIMU: Angalia kama screen bado ipo kabla ya ku-refresh na kuonyesha SnackBar
                if (!mounted) return;

                _applyFilters();

                scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Malipo yamekamilika na deni limefutwa!'), backgroundColor: Colors.green)
                );
              } catch (e) {
                debugPrint("❌ Error confirming full payment: $e");
                // Tumia scaffoldMessenger uliyohifadhi
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Kosa: $e'), backgroundColor: Colors.red));
              }
            },
          ),
        ],
      ),
    );
  }




  @override
  Widget build(BuildContext context) {
    // Theme Logic
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.grey[600]!;
    final Color fieldFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);

    // Constant Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "DEBIT HISTORY REPORT",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "BRANCH: ${business_name.trim().toUpperCase()}",
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w300
              ),
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
          // --- Search Bar ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                style: TextStyle(color: textCol), // typed text turns white in dark mode
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: business_name.isNotEmpty
                      ? "Search ${business_name.trim()} records..."
                      : "Search by any keyword...",
                  hintStyle: TextStyle(color: subTextCol),
                  prefixIcon: const Icon(Icons.search, color: primaryPurple),
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      searchController.clear();
                      _applyFilters();
                    },
                  )
                      : null,
                ),
              ),
            ),
          ),

          // --- Date Selectors ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                      context,
                      startDate == null ? "Start Date" : DateFormat('yyyy-MM-dd').format(startDate!),
                      cardColor, textCol,
                          () => _selectDate(context, true)
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton(
                      context,
                      endDate == null ? "End Date" : DateFormat('yyyy-MM-dd').format(endDate!),
                      cardColor, textCol,
                          () => _selectDate(context, false)
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Grand Total Card ---
          isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryPurple))
              : FutureBuilder<double>(
            future: lendTotal,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryPurple.withOpacity(0.2)),
                    boxShadow: [BoxShadow(color: primaryPurple.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Text("Total Outstanding Debt", style: TextStyle(color: subTextCol, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        "TSH ${NumberFormat('#,##0', 'en_US').format(snapshot.data!)}",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryPurple),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // --- Results List ---
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: primaryPurple))
                : FutureBuilder<List<Map<String, dynamic>>>(
              future: lendData,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                if (snapshot.data!.isEmpty) {
                  return Center(child: Text("No records found", style: TextStyle(color: subTextCol)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final sale = snapshot.data![index];
                    String receipt = sale['receipt_number'] ?? '';

                    messageControllers.putIfAbsent(receipt, () => TextEditingController());
                    phoneControllers.putIfAbsent(receipt, () => TextEditingController(text: sale['customer_phone']?.toString() ?? ''));
                    emailControllers.putIfAbsent(receipt, () => TextEditingController(text: sale['customer_email']?.toString() ?? ''));

                    bool isSending = sendingStatus[receipt] == true;
                    String status = emailStatus[receipt] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10)],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(receipt, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                                Icon(Icons.more_horiz, color: subTextCol),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(sale['customer_name']?.toString().toUpperCase() ?? "N/A",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),

                            Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey[200]),

                            // Contact Inputs
                            _buildInCardField(phoneControllers[receipt]!, "Phone", Icons.phone, TextInputType.phone, textCol, isDark),
                            const SizedBox(height: 8),
                            _buildInCardField(emailControllers[receipt]!, "Email", Icons.email, TextInputType.emailAddress, textCol, isDark),

                            const SizedBox(height: 16),

                            // Finance Details
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: fieldFill, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  _buildFinanceRow("Total Debit", _fetchOriginalTotal(receipt), Colors.teal, subTextCol),
                                  _buildFinanceRow("Total Paid", _fetchTotalPaid(receipt), Colors.orange, subTextCol),
                                  Divider(height: 16, color: isDark ? Colors.white10 : Colors.grey[300]),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text("BALANCE DUE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textCol)),
                                      Text(
                                        "TSH ${NumberFormat('#,##0').format(double.tryParse(sale['total_price'].toString()) ?? 0.0)}",
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            // Sehemu ya Bidhaa
                            Text("Product: ${sale['medicine_name']}", style: TextStyle(fontSize: 13, color: textCol)),

                            // ✅ MPYA: Sehemu ya Kuonyesha Tawi (Branch)
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.storefront, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Text(
                                    "Branch: ${sale['business_name']?.toString().toUpperCase() ?? business_name.toUpperCase()}",
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueAccent)
                                ),
                              ],
                            ),

                            const SizedBox(height: 2),
                            Text("Handled by: ${sale['confirmed_by']}", style: TextStyle(fontSize: 11, color: subTextCol)),

                            const SizedBox(height: 16),

                            // Notification Row
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: messageControllers[receipt],
                                    style: TextStyle(color: textCol, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Reminder text...',
                                      hintStyle: TextStyle(fontSize: 12, color: subTextCol),
                                      filled: true,
                                      fillColor: fieldFill,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                sendingStatus[receipt] == true
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                                    : IconButton(
                                  icon: const Icon(Icons.send_rounded, color: Colors.deepPurple),
                                  onPressed: () async {
                                    // Hapa utaita function yako ya kutuma
                                    await _sendEmailAndSmsToCustomer(
                                      emailControllers[receipt]!.text,
                                      phoneControllers[receipt]!.text,
                                      messageControllers[receipt]!.text,
                                      receipt,
                                    );
                                  },
                                ),
                              ],
                            ),

                            if (emailStatus[receipt] != null && emailStatus[receipt]!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(emailStatus[receipt]!, style: const TextStyle(fontSize: 11, color: Colors.blueAccent)),
                              ),

                            const SizedBox(height: 16),

                            // Action Buttons
                            Row(
                              children: [
                                _buildActionBtn(Icons.history, "Logs", Colors.blueGrey, () => _showPaymentLogsDialog(receipt)),
                                const SizedBox(width: 8),
                                _buildActionBtn(Icons.payment, "Partial", Colors.orange, () => _markAsPartiallyPaid(sale)),
                                const SizedBox(width: 8),
                                _buildActionBtn(Icons.done_all, "Paid", Colors.green, () => _markAsPaid(sale)),
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
      bottomNavigationBar: const CurvedRainbowBar(),
    );
  }

// --- Helper Methods (Stay inside the State class) ---

  Widget _buildDateButton(BuildContext context, String text, Color bg, Color txt, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: _isDarkMode ? Border.all(color: Colors.white10) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 16, color: Color(0xFF673AB7)),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: txt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInCardField(TextEditingController controller, String label, IconData icon, TextInputType type, Color txt, bool isDark) {
    return SizedBox(
      height: 45,
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(fontSize: 13, color: txt), // typing text
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
          prefixIcon: Icon(icon, size: 16, color: isDark ? Colors.white60 : Colors.grey),
          filled: true,
          fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[300]!),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF673AB7), width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildFinanceRow(String label, Future<double> future, Color color, Color subTxt) {
    return FutureBuilder<double>(
      future: future,
      builder: (context, snapshot) {
        String val = snapshot.hasData ? NumberFormat('#,##0').format(snapshot.data) : "...";
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: subTxt)),
              Text("TSH $val", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        );
      },
    );
  }
  }
