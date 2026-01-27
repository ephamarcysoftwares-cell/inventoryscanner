import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Import to read the file
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; // Make sure you add intl to pubspec.yaml
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:stock_and_inventory_software/phamacy/pharmacyDashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';
import 'API/clickpesa_payment_screen.dart';
import 'API/clickpesa_service.dart';
import 'API/payment.dart';
import 'API/payment_conmfemetion.dart';
import 'Agreement/InstallationAgreementScreen.dart';
import 'CHATBOAT/chatboat.dart';
import 'DB/database_helper.dart';
import 'FOTTER/CurvedRainbowBar.dart';

import 'SUBADMIN/ACCOUNTANT/AccountantDasboard.dart';
import 'SUBADMIN/HR/HrDasboard.dart';
import 'SUBADMIN/IT/ItDasboard.dart';

import 'SUBADMIN/RECEPTINIST/ReceptionistDashbaord.dart';
import 'SUBADMIN/STATIONARYSERVICES/SecretaryDashboard.dart';
import 'SUBADMIN/STOCTKEEPER/StorekeeperDasboard.dart';
import 'SUBADMIN/SUBADMIN_DASH/SubBranchDasboard.dart';
import 'SUBADMIN/SUPPLAR/SuppDashboard.dart';
import 'SUBADMIN/SubAdmin.dart';
import 'TOUTOLIAL PAGE/toutorial_page.dart';
import 'no registration.dart';
import 'register_screen.dart';
import 'reset_password_screen.dart';
import 'admin/AdminDashboard.dart'; // Admin Dashboard
import 'package:crypto/crypto.dart';
import 'dart:convert'; // For utf8 encoding
import 'package:shared_preferences/shared_preferences.dart'; // Add shared_preferences package
import 'dart:io'; // For file operations
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool isLoading = false;
  String errorMessage = '';
  bool showPassword = false; // Track password visibility

  int failedAttempts = 0; // Track failed attempts
  DateTime? lastFailedAttempt; // Track time of last failed attempt
  bool isLocked = false; // Flag to check if account is locked
  String _appVersion = '';
  bool _isCheckingConnectivity = false;
  bool _hasInternet = true;


  // Hashing the password using SHA-256
  String hashPassword(String password) {
    var bytes = utf8.encode(password); // Convert password to bytes
    var digest = sha256.convert(bytes); // Hash the password using SHA-256
    return digest.toString(); // Return the hash as a string
  }

  String paymentStatusMessage = ''; // Store payment status message
  // IMPORTANT: This replaces your existing loginRemote function.




  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = result != ConnectivityResult.none;
    });
  }
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      // Load Instance ID and Access Token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
      final accessToken = prefs.getString('whatsapp_access_token') ?? '';

      if (instanceId.isEmpty || accessToken.isEmpty) {
        return "❌ WhatsApp error conduct +255742448965!";
      }

      // Clean phone number (Tanzania example)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('255')) {
        // Assuming a standard local number that needs the country code
        cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
      }
      final chatId = '$cleanPhone@c.us';

      Future<http.Response> post(String url, Map<String, String> payload) async {
        return await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: payload,
        );
      }

      // Start typing (optional, for better UX)
      await post('https://wawp.net/wp-json/awp/v1/startTyping', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': chatId,
      });

      // Send message (direct API call)
      final sendRes = await post('https://wawp.net/wp-json/awp/v1/send', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': cleanPhone, // The API might expect only the phone number here
        'message': messageText,
      });

      // Stop typing (optional)
      await post('https://wawp.net/wp-json/awp/v1/stopTyping', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': chatId,
      });

      if (sendRes.statusCode >= 200 && sendRes.statusCode < 300) {
        return "✅ Direct WhatsApp notification sent successfully!";
      } else {
        return "❌ fail";
      }
    } catch (e) {
      return "❌ error";
    }
  }








  Future<void> sendAdminNotification(int daysLeft, String dueDate) async {
    // 1️⃣ Fetch admin users with email, full_name, and phone
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email', 'full_name', 'phone'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    if (result.isEmpty) {
      print("❌ No admin users found to notify.");
      return;
    }

    // 2️⃣ SMTP Server Configuration
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    // 3️⃣ Message templates
    final String emailSubject = '⚠️ Payment Reminder: $daysLeft day(s) left';
    final String emailBody = '''
We hope you're having a productive day.

Just a friendly heads-up — your subscription is nearing its renewal date. You have **$daysLeft day(s)** left, and your next payment is due on **$dueDate**.

Please make the payment before the due date to keep enjoying our platform.
''';

    final String emailSignature = '''
Warm regards,  
STOCK&INVENTORY SOFTWARE Team  
📧 support@ephamarcysoftware.co.tz  
📞 +255742448965  
📍 Arusha - Nairobi Road, Near Makao Mapya
''';

    final String whatsappBodyTemplate =
        "Your STOCK&INVENTORY subscription has $daysLeft day(s) left, due on $dueDate. Please renew to avoid interruption! Contact +255742448965.";

    for (final admin in result) {
      final String adminEmail = admin['email'] as String;
      final String fullName = admin['full_name']?.toString() ?? 'Admin';
      final String? adminPhone = admin['phone'] as String?;

      // -----------------------------------
      // 📧 SEND EMAIL
      // -----------------------------------
      final fullEmailText = 'Dear $fullName,\n\n$emailBody\n\n$emailSignature';

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE REMINDER')
        ..recipients.add(adminEmail)
        ..subject = emailSubject
        ..text = fullEmailText;

      try {
        final sendReport = await send(message, smtpServer);
        print('📧 Email sent to $adminEmail: $sendReport');
      } catch (e) {
        print('❌ Failed to send email to $adminEmail: $e');
      }

      // -----------------------------------
      // 💬 SEND WHATSAPP
      // -----------------------------------
      if (adminPhone != null && adminPhone.isNotEmpty) {
        final String formattedPhone =
        adminPhone.startsWith('+') ? adminPhone : '+$adminPhone';
        final String waMessage = "Dear $fullName, $whatsappBodyTemplate";

        try {
          final waResponse = await sendWhatsApp(formattedPhone, waMessage);
          print('💬 WhatsApp sent to $formattedPhone: $waResponse');
        } catch (e) {
          print('❌ Failed to send WhatsApp to $formattedPhone: $e');
        }
      } else {
        print('⚠️ Skipped WhatsApp for $fullName: Phone not available.');
      }
    }
  }

// ----------------------
// 🌐 WhatsApp sender
// ----------------------


// NOTE: The 'sendWhatsApp' function must be defined and accessible for this code to compile.

  void _showBlockingDialog(String title, String message, String businessName, dynamic businessId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            title,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "TAWI: $businessName",
                style: const TextStyle(fontWeight: FontWeight.bold)
            ),
            Text(
                "ID YA DUKA: $businessId",
                style: const TextStyle(fontSize: 13, color: Colors.blueGrey)
            ),
            const SizedBox(height: 12),
            Text(message),
            const Divider(height: 30),
            const Text(
                "Tafadhali lipia Sasa au wasiliana na +255742448965",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
              onPressed: () {
                Navigator.pop(context); // Funga dialog

                // HAPA NDIPO TUNAPOTUMA TAARIFA KWENYE PAGE YA MALIPO
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubscriptionPaymentScreen(
                      businessName: businessName,
                      businessId: businessId,
                    ),
                  ),
                );
              },
              child: const Text("SAWA / LIPIA SASA", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
  // Function to handle login logic
  // IMPORTANT: This replaces your existing login() function in _LoginScreenState.
  Future<bool> hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        _showError('Tafadhali jaza email na password');
        return;
      }

      if (!await hasInternet()) {
        _showError('Hakuna internet. Tafadhali washa mtandao wako.');
        return;
      }

      final supabase = Supabase.instance.client;

      // 1. AUTH LOGIN (Imefichwa ili isitoe Auth Error kwa user)
      AuthResponse? response;
      try {
        response = await supabase.auth.signInWithPassword(email: email, password: password);
      } catch (authError) {
        // Hapa tunazuia Auth Error isionekane kwa mtumiaji
        _showError('Email au password sio sahihi');
        return;
      }

      final user = response.user;
      if (user == null) {
        _showError('Email au password sio sahihi');
        return;
      }

      // 2. FETCH USER DATA
      final userData = await supabase.from('users').select('*').eq('id', user.id).maybeSingle();
      if (userData == null) {
        _showError('Profile yako haijakamilika, wasiliana na Admin.');
        return;
      }

      // --- 🛑 CHEKI KAMA AKAUNTI IMEFUNGWA (LOCKED) ---
      if (userData['is_disabled'] == true) {
        String sababu = userData['block_reason'] ?? "Akaunti yako imesimamishwa kwa muda. Wasiliana na uongozi.";

        // Logout mara moja ili asibaki ndani ya mfumo
        await supabase.auth.signOut();

        _showLockedDialog(sababu);
        return;
      }

      final businessId = userData['business_id'];
      final businessName = userData['business_name'] ?? 'Biashara';
      DateTime leo = DateTime.now();

      // 3. GRACE PERIOD (Siku 5)
      bool yupoNdaniYaSiku5 = false;
      if (userData['last_seen'] != null) {
        DateTime lastSeen = DateTime.parse(userData['last_seen']);
        if (leo.difference(lastSeen).inDays < 5) {
          yupoNdaniYaSiku5 = true;
        }
      }

      // 4. VALIDATE PAYMENT (Kama siku 5 zimeisha)
      if (!yupoNdaniYaSiku5) {
        final paymentData = await supabase
            .from('payments')
            .select('expiry_date, status, amount, collected_amount')
            .eq('business_id', businessId)
            .or('status.eq.SUCCESS,status.eq.SETTLED,status.eq.success,status.eq.settled')
            .order('expiry_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (paymentData == null) {
          _showBlockingDialog("JARIBIO LIMEISHA", "Muda wa majaribio umeisha. Lipia ili uendelee.", businessName, businessId);
          return;
        }

        double amountDue = double.parse(paymentData['amount'].toString());
        double collected = double.parse((paymentData['collected_amount'] ?? 0).toString());

        if (collected < amountDue) {
          _showBlockingDialog("MALIPO HAYAJATOSHA", "Kiasi ulicholipa hakijatosheleza gharama ya huduma.", businessName, businessId);
          return;
        }

        DateTime expiryDate = DateTime.parse(paymentData['expiry_date']);
        if (leo.isAfter(expiryDate)) {
          _showBlockingDialog("HUDUMA IMEISHA", "Muda wa huduma umeisha tarehe ${DateFormat('dd/MM/yyyy').format(expiryDate)}.", businessName, businessId);
          return;
        }
      }

      // 5. UPDATE LAST SEEN & PROCEED
      await supabase.from('users').update({
        'last_seen': leo.toIso8601String(),
      }).eq('id', user.id);

      _proceedToDashboard(user.id, user.email!, userData, businessName, businessId, userData['role'] ?? 'user');

    } catch (e) {
      // Hapa tunazuia makosa ya code (Exceptions) yasimtishe mtumiaji
      _showError('Imeshindikana kuingia, jaribu tena baadaye.');
      debugPrint("Login Error Detail: $e"); // Inabaki kwa developer tu
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// -----------------------------------------------------------------------------
// DIALOG YA KUFUNGWA KWA AKAUNTI (LOCKED)
// -----------------------------------------------------------------------------
  void _showLockedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_clock_rounded, color: Colors.red, size: 50),
        title: const Text("AKAUNTI IMEFUNGWA",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("SAWA, NIMEFAHAMU", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }




// Hii ndiyo njia ya kuingia ndani ya App (Navigating)
  void _proceedToDashboard(String userId, String email, dynamic userData, String bName, dynamic bId, String role) {
    final userMap = {
      'id': userId,
      'email': email,
      'full_name': userData['full_name'],
      'role': role,
      'business_name': bName,
      'business_id': bId,
    };

    String lowerRole = role.toLowerCase();

    if (lowerRole == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard(user: userMap)));
    }
    else if (lowerRole == 'sub_admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SubBranchDasboard(user: userMap)));
    }
    // REKEBISHO: Receptionist na Staff sasa wanaenda PharmacyDashboard
    else if (lowerRole == 'staff' || lowerRole == 'receptionist') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PharmacyDashboard(user: userMap)));
    }
    else if (lowerRole == 'accountant') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AccountantDasboard(user: userMap)));
    }
    else if (lowerRole == 'storekeeper') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => StoKeeperDashbord(user: userMap)));
    }
    else if (lowerRole == 'hr') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HrDasboard(user: userMap)));
    }
    else if (lowerRole == 'it') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ItDasboard(user: userMap)));
    }
    else if (lowerRole == 'supplier') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SuppDashboard(user: userMap)));
    }
    else if (lowerRole == 'secretary') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SecretaryDashboard(user: userMap)));
    }
    else {
      print("Role haijatambulika: $lowerRole");
    }
  }

  void _navigateToPayment(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 5),
    ));
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SubscriptionPaymentScreen()),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }






  Future<void> handleFailedAttempt() async {
    failedAttempts++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('failedAttempts', failedAttempts);

    if (failedAttempts >= 5) {
      isLocked = true;
      lastFailedAttempt = DateTime.now();

      await prefs.setBool('isLocked', true);
      await prefs.setString(
          'lastFailedAttempt', lastFailedAttempt!.toIso8601String());

      Fluttertoast.showToast(
        msg: "Too many attempts. Account locked for 5 minutes.",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } else {
      Fluttertoast.showToast(
        msg: "Invalid email or password",
        backgroundColor: Colors.orange,
        textColor: Colors.white,
      );
    }
  }




  Future<void> checkAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();

    setState(() {
      _appVersion = 'v${packageInfo.version} (Build ${packageInfo.buildNumber})';
    });
  }

  // Check if the account is locked by reading SharedPreferences
  Future<void> checkLockStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLockedFromStorage = prefs.getBool('isLocked') ?? false;
    int failedAttemptsFromStorage = prefs.getInt('failedAttempts') ?? 0;
    String? lastFailedAttemptString = prefs.getString('lastFailedAttempt');

    if (isLockedFromStorage && lastFailedAttemptString != null) {
      setState(() {
        isLocked = true;
        failedAttempts = failedAttemptsFromStorage;
        lastFailedAttempt = DateTime.parse(lastFailedAttemptString);
      });
    } else {
      setState(() {
        isLocked = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    checkLockStatus();
    checkAppVersion();

    checkInternet(); // Check internet on startup
  }

  void checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(() {
        _hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      });
    } on SocketException catch (_) {
      setState(() {
        _hasInternet = false;
      });
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
        toolbarHeight: 100,
        title: const Text(
          'STOCK & INVENTORY',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 2,
          ),
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
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
        ),
      ),
      body: Stack(
        children: [
          // Subtle Background Branding
          Positioned(
            top: 20,
            right: -50,
            child: Icon(Icons.inventory_2_outlined,
                size: 250, color: deepPurple.withOpacity(0.03)),
          ),

          SafeArea(
            child: Column(
              children: [
                // --- Optimized Action Bar (Horizontal Scrollable to prevent overflow) ---
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
                  child: Row(
                    children: [
                      _buildTopAction(Icons.info_outline, Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => InfoPage()))),
                      _buildTopAction(Icons.contact_support_outlined, Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContactPage()))),
                      _buildTopAction(
                        Icons.payments_outlined,
                        Colors.green,
                            () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionPaymentScreen()), // Changed from Service to Screen
                        ),
                      ),
                      _buildTopAction(Icons.gavel_outlined, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (_) => InstallationAgreementScreen()))),
                      // _buildTopAction(
                      //     Icons.cloud_outlined,
                      //     _hasInternet ? Colors.cyan : Colors.grey,
                      //
                      // ),
                      _buildTopAction(Icons.play_circle_outline, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => TutorialPage()))),
                    ],
                  ),
                ),

                // --- Main Login Card ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: deepPurple.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        children: [
                          Text(
                            paymentStatusMessage,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Welcome Back',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: deepPurple,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to manage your inventory',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                          ),
                          const SizedBox(height: 35),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Email Field
                                _buildTextField(
                                  controller: emailController,
                                  label: 'Email Address',
                                  icon: Icons.alternate_email,
                                  type: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 20),

                                // Password Field
                                _buildTextField(
                                  controller: passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscure: !showPassword,
                                  suffix: IconButton(
                                    icon: Icon(
                                      showPassword ? Icons.visibility : Icons.visibility_off,
                                      color: primaryPurple,
                                    ),
                                    onPressed: () => setState(() => showPassword = !showPassword),
                                  ),
                                ),

                                const SizedBox(height: 30),

                                if (isLoading)
                                  const CircularProgressIndicator(color: primaryPurple)
                                else
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: ElevatedButton(
                                      // Disable the button while loading to prevent multiple taps
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: deepPurple,
                                        disabledBackgroundColor: deepPurple.withOpacity(0.6), // Slightly faded when loading
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                        elevation: 5,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                        height: 30,
                                        width: 30,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2, // Thinner line to fit inside the button
                                        ),
                                      )
                                          : const Text(
                                        'LOGIN TO DASHBOARD',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ),
                                  ),

                                if (errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 15),
                                    child: Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                                  ),

                                const SizedBox(height: 25),

                                // Reset/Sign up links
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen())),
                                  child: const Text('Forgot Password?', style: TextStyle(color: primaryPurple, fontWeight: FontWeight.w600)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotRegisteredPage())),
                                  child: const Text("Don't have an account? Sign up", style: TextStyle(color: Colors.blueGrey)),
                                ),

                                const SizedBox(height: 20),

                                // Version & Footer
                                Text('Version: $_appVersion', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  '© ${DateTime.now().year} E-PHAMARCY SOFTWARE',
                                  style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // Styled Chatbot FAB
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryPurple,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatbotScreen(ollamaApiUrl: '...'))),
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

// --- Helper UI Components ---

  Widget _buildTopAction(IconData icon, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF673AB7), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF5F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        floatingLabelStyle: const TextStyle(color: Color(0xFF311B92), fontWeight: FontWeight.bold),
      ),
    );
  }

} class ContactPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Icon(Icons.contact_mail, color: Colors.white),
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
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.1, // Reduced for better readability
              child: Image.asset(
                'assets/backgroud.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Contact Info",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: deepPurple,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 25),

                // Email Card
                _buildContactCard(
                  icon: Icons.email,
                  iconColor: Colors.blue,
                  text: "support@ephamarcysoftware.co.tz",
                ),

                const SizedBox(height: 12),

                // Phone Card
                _buildContactCard(
                  icon: Icons.phone,
                  iconColor: Colors.green,
                  text: "+255 742 448 965",
                ),

                const SizedBox(height: 12),

                // Location Card
                _buildContactCard(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  text: "ARUSHA CBD-LEVOLOSI STREET-MAKAO MAPYA-NEAR NAIROBI ROAD TANZANIA",
                ),

                const SizedBox(height: 40),

                Center(
                  child: SizedBox(
                    width: 200,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text(
                          "Back to Login",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPurple,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// Helper method for uniform cards
  Widget _buildContactCard({required IconData icon, required Color iconColor, required String text}) {
    return Container(
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: iconColor, size: 28),
        title: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class InfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Icon(Icons.info_outline, color: Colors.white),
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
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/backgroud.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "STOCK & INVENTORY SOFTWARE",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: deepPurple,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 15),
                const Text(
                  '''Stock&Inventory Software is an advanced platform designed to support a wide range of businesses, including pharmacies, clinics, hospitals, cosmetics shops, supermarkets, minimarts, electronic stores, stationery shops, hardware stores, gas and oil distributors, restaurants, food and beverage suppliers, agricultural product sellers, retail stores, wholesale shops, and general merchandise businesses.''',
                  style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                ),
                const Divider(height: 40, thickness: 1),
                const Text(
                  "It features barcode/QR code stock tracking, automated sales via CCTV, invoicing, email/SMS alerts, financial tracking, user role management, and much more — all in one dashboard.",
                  style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.5),
                ),
                const SizedBox(height: 25),

                const Text(
                  "🌟 Key Features:",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryPurple),
                ),
                const SizedBox(height: 12),
                _customBullet("Barcode & QR code-based stock management."),
                _customBullet("Automated sales system with CCTV detection."),
                _customBullet("Instant invoicing, receipts, and email delivery."),
                _customBullet("User role access control (Admin, Seller, Pharmacist, Accountant)."),
                _customBullet("Multi-business & branch dashboard."),
                _customBullet("Customer & supplier notifications via email/SMS."),
                _customBullet("Profit/loss analysis and payroll support."),
                _customBullet("Expiry and out-of-stock alerts."),
                _customBullet("Advanced sales, stock, and performance reports."),
                _customBullet("PDF generation and email integration."),

                const SizedBox(height: 30),
                const Text(
                  "🎯 Who Can Use This?",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryPurple),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip("Pharmacies"), _buildChip("Clinics"), _buildChip("Hospitals"),
                    _buildChip("Cosmetics shops"), _buildChip("Supermarkets"), _buildChip("Minimarts"),
                    _buildChip("Electronic stores"), _buildChip("Stationery shops"), _buildChip("Hardware stores"),
                    _buildChip("Gas & Oil"), _buildChip("Restaurants"), _buildChip("Retailers"),
                    _buildChip("Wholesale"), _buildChip("Agri-Business"),
                  ],
                ),

                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: primaryPurple.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: const [
                      Text(
                        "It also uses Artificial Intelligence (AI) to enhance security by detecting theft and to improve customer service by counting and analyzing customer visits.",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: deepPurple),
                      ),
                      SizedBox(height: 12),
                      Text(
                        "Stock&Inventory Software is more than just a tool — it's your complete digital business partner, built to empower, protect, and accelerate every part of your operations.",
                        style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.black54),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Center(
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text("BACK TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: deepPurple,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- Custom Helper Widgets ---

  Widget _customBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF673AB7).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF673AB7).withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF311B92)),
      ),
    );
  }
}
Widget bullet(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("• ", style: TextStyle(fontSize: 18, color: Colors.teal)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ],
    ),
  );
}

class Payment extends StatelessWidget {
  const Payment({super.key});

  // Method to launch URL in the browser
  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
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
        title: const Text(
          "PAYMENT GATEWAY",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 18,
          ),
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
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            const Text(
              'Secure Payment',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: deepPurple,
              ),
            ),
            const Text(
              'Choose your preferred payment method',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 25),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // Two columns for a cleaner grid
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.2,
                  children: [
                    _buildPaymentCard(
                      context,
                      label: 'M-Pesa',
                      icon: Icons.phone_android,
                      color: Colors.redAccent, // M-Pesa Brand Color
                    ),
                    _buildPaymentCard(
                      context,
                      label: 'Mix by Yas',
                      icon: Icons.account_balance_wallet,
                      color: Colors.purple,
                    ),
                    _buildPaymentCard(
                      context,
                      label: 'Airtel Money',
                      icon: Icons.phone,
                      color: Colors.orange,
                    ),
                    _buildPaymentCard(
                      context,
                      label: 'Visa Card',
                      icon: Icons.credit_card,
                      color: Colors.indigo,
                    ),
                    _buildPaymentCard(
                      context,
                      label: 'Halo Pesa',
                      icon: Icons.phonelink_ring,
                      color: Colors.orange.shade700,
                    ),
                    _buildPaymentCard(
                      context,
                      label: 'PayPal',
                      icon: Icons.paypal,
                      color: Colors.blue.shade800,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Security Note
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 5),
                    Text(
                      "Encrypted Secure Checkout",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- Modern Payment Card Widget ---
  Widget _buildPaymentCard(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>LoginScreen()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF311B92),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "SYSTEM ACCESS LOCKED",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
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
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(50)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            // Warning Section
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      'Your monthly payment period has reached. Please pay to continue using the system.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              'Select Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: deepPurple,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 15),

            // Scrollable List of Payment Buttons
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildLockPaymentButton(
                    context,
                    label: 'M-Pesa',
                    icon: Icons.phone_android,
                    color: Colors.redAccent,
                  ),
                  _buildLockPaymentButton(
                    context,
                    label: 'Mix by Yas',
                    icon: Icons.account_balance_wallet,
                    color: Colors.purple,
                  ),
                  _buildLockPaymentButton(
                    context,
                    label: 'Airtel Money',
                    icon: Icons.phone,
                    color: Colors.orange,
                  ),
                  _buildLockPaymentButton(
                    context,
                    label: 'Visa / Mastercard',
                    icon: Icons.credit_card,
                    color: Colors.indigo,
                  ),
                  _buildLockPaymentButton(
                    context,
                    label: 'Halo Pesa',
                    icon: Icons.phonelink_ring,
                    color: Colors.orange.shade800,
                  ),
                  _buildLockPaymentButton(
                    context,
                    label: 'PayPal',
                    icon: Icons.payment,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

// --- Specialized Button for the Lock Screen ---
  Widget _buildLockPaymentButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 20),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF311B92),
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
class PaymentButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap; // <-- Change this

  const PaymentButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap, // <-- And this
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap, // <-- Use onTap instead of launching URL
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
      ),
    );
  }
}
class WeatherScreen extends StatefulWidget {
  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  bool _isLoading = false;
  String _temperature = '';
  String _humidity = '';
  String _weatherCondition = '';
  String _cityName = '';

  @override
  void initState() {
    super.initState();
    _fetchWeatherBasedOnLocation();
  }

  Future<void> _fetchWeatherBasedOnLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception("Location permission denied");
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      double lat = position.latitude;
      double lon = position.longitude;

      final apiKey = 'f2dc560b35878ca88d7a097808889972'; // Replace with your actual key
      final url = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

      final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _temperature = data['main']?['temp']?.toString() ?? 'N/A';
          _humidity = data['main']?['humidity']?.toString() ?? 'N/A';
          _weatherCondition = data['weather']?[0]?['description'] ?? 'N/A';
          _cityName = data['name'] ?? 'Unknown';
        });

        _speakWeather();
      } else {
        _showError("Server error: ${response.statusCode}");
      }
    } on SocketException {
      _showError("No internet connection.");
    } on TimeoutException {
      _showError("Request timed out. Check your connection.");
    } on Exception catch (e) {
      _showError(e.toString());
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showError(String message) {
    setState(() {
      _temperature = 'N/A';
      _humidity = 'N/A';
      _weatherCondition = message;
      _cityName = 'Unknown';
    });
    _speakWeather();
  }

  void _speakWeather() {
    final text = _temperature == 'N/A'
        ? "Weather data is unavailable. $_weatherCondition"
        : "Current weather in $_cityName: Temperature is $_temperature degrees Celsius, Humidity is $_humidity percent, Condition is $_weatherCondition.";
    speakWithPowerShell(text);
  }

  void speakWithPowerShell(String text) async {
    final escapedText = text.replaceAll("'", "''");
    final psCommand = '''
Add-Type -AssemblyName System.speech;
\$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer;
\$synth.Speak('$escapedText');
''';
    try {
      await Process.run('powershell', ['-Command', psCommand]);
    } catch (e) {
      print('Error running PowerShell TTS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "STOCK & INVENTORY SOFTWARE",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchWeatherBasedOnLocation,
        child: Icon(Icons.refresh),
        backgroundColor: Colors.green[700],
        tooltip: "Refresh Weather",
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade200, Colors.blue.shade200],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 100,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(3, 3),
                    blurRadius: 6,
                    color: Colors.black26,
                  ),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'WEATHER INFORMATION',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
              _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : _temperature == 'N/A'
                  ? Column(
                children: [
                  Text(
                    'Unable to load weather data.\n$_weatherCondition',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchWeatherBasedOnLocation,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.green[800], backgroundColor: Colors.white,
                    ),
                    child: Text("Try Again"),
                  ),
                ],
              )
                  : Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    WeatherInfoRow(label: 'City', value: _cityName, icon: Icons.location_city),
                    WeatherInfoRow(label: 'Temperature', value: '$_temperature °C', icon: Icons.thermostat),
                    WeatherInfoRow(label: 'Humidity', value: '$_humidity%', icon: Icons.water_drop),
                    WeatherInfoRow(label: 'Condition', value: _weatherCondition, icon: Icons.cloud_queue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}

class WeatherInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const WeatherInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 18, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
// Uncomment this section to use WebView in the future
// class WebViewPage extends StatelessWidget {
//   final String url;
//   const WebViewPage({Key? key, required this.url}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Payment Page'),
//       ),
//       body: WebView(
//         initialUrl: url,
//         javascriptMode: JavascriptMode.unrestricted,
//       ),
//     );
//   }
// }
