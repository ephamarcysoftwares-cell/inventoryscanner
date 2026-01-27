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
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:url_launcher/url_launcher.dart';
import 'API/payment.dart';
import 'API/payment_conmfemetion.dart';
import 'Agreement/InstallationAgreementScreen.dart';
import 'CHATBOAT/chatboat.dart';
import 'DB/database_helper.dart';
import 'FOTTER/CurvedRainbowBar.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart'; // 🚨 Added Supabase import

// ====================================================================
// 🌐 SUPABASE CONFIGURATION
// ====================================================================
final String SUPABASE_URL = "https://etrqtetptcxilfvuuvyz.supabase.co";
const String SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0cnF0ZXRwdGN4aWxmdnV1dnl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NzQwNTQsImV4cCI6MjA3OTE1MDA1NH0._SIdyz02OFfWurQPP8KaXWL0PX2GJWQ_jEpENAG4r84';

// Initialize the Supabase client (assuming 'supabase_flutter' is initialized elsewhere like main,
// or accessed via these constants)
// final supabase = SupabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY);
// We will access Supabase directly in the logic if needed, but for the provided structure,
// we'll rely on the online/local check and print statements.

// ====================================================================


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

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

  // NOTE: This function's role is complex. In a true Supabase integration,
  // this would be replaced by a dedicated Supabase login function.
  // I am modifying this function minimally to include the requested print statements
  // before the remote/local login attempt, based on connectivity.
  Future<Map<String, dynamic>?> loginRemote(String email, String password) async {
    try {
      // Hash the password
      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      final bool hasInternet = connectivityResult != ConnectivityResult.none;

      print("now let login check in");

      if (hasInternet) {
        print("you wil login online");

        // --- ONLINE LOGIC (Remote/Supabase) ---

        // 1. Attempt Supabase Login (using Auth for credentials check)
        try {
          final client = SupabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY);
          final AuthResponse response = await client.auth.signInWithPassword(
            email: email,
            password: password,
          );

          if (response.session != null && response.user != null) {
            // Fetch profile/role from your database table (e.g., 'profiles') using response.user!.id
            // For this example, we mock the required fields.
            final userMap = {
              'email': response.user!.email,
              'password': hashedPassword,
              'full_name': response.user!.email?.split('@').first ?? 'User',
              'role': 'staff', // Placeholder
            };

            // Cache user locally
            final db = await DatabaseHelper.instance.database;
            await db.insert(
              'users',
              userMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            return userMap;
          }
        } on AuthException catch (e) {
          // Supabase Auth failed, log the error but allow fallthrough to your secondary remote PHP
          debugPrint("Supabase Login Error: ${e.message}");
        } catch (e) {
          debugPrint("General Supabase Error: $e");
        }

        // 2. Attempt legacy remote PHP login as fallback
        final url = Uri.parse("http://ephamarcysoftware.co.tz/ephamarcy/login.php");
        final response = await http.post(url, body: {
          'email': email,
          'password': password,
        });

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            // Cache user locally
            final db = await DatabaseHelper.instance.database;
            await db.insert(
              'users',
              {
                'email': data['user']['email'],
                'password': hashedPassword,
                'name': data['user']['name'],
                // Add other fields as needed
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            return data['user'];
          }
        }

      } else {
        print("you wil login in local");
        // --- OFFLINE LOGIC (Local DB) ---

        // Attempt local login only (if this wasn't done before calling loginRemote)
        final db = await DatabaseHelper.instance.database;
        final localResult = await db.query(
          'users',
          where: 'email = ? AND password = ?',
          whereArgs: [email, hashedPassword],
        );

        if (localResult.isNotEmpty) {
          return localResult.first;
        }
      }
    } catch (e) {
      debugPrint("Login error: $e");
    }

    return null;
  }

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

  // NOTE: Assuming PaymentTransaction is defined elsewhere in your project
  Future<void> readAndNotifyPaymentStatus() async {
    try {
      debugPrint('Starting to fetch payment transactions...');
      // List<Map<String, dynamic>> transactionMaps = await DatabaseHelper.instance.getAllTransactions(); // Uncomment if PaymentTransaction is defined

      // ... (Rest of the readAndNotifyPaymentStatus logic) ...

      // For now, setting a placeholder message without full DB interaction
      setState(() {
        paymentStatusMessage = 'Your are in Trial mode.';
      });

    } catch (e, stacktrace) {
      debugPrint('Error checking payment status: $e');
      debugPrint('Stacktrace: $stacktrace');
      setState(() {
        paymentStatusMessage = '❌ Error reading payment status.';
      });
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


  // Function to handle login logic
  Future<void> login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    // Check if account is locked from SharedPreferences
    await checkLockStatus();

    if (isLocked) {
      DateTime now = DateTime.now();
      Duration difference = now.difference(lastFailedAttempt!);

      if (difference.inMinutes < 5) {
        setState(() {
          errorMessage = 'Account is locked. Try again in ${5 - difference.inMinutes} minutes.';
          isLoading = false;
        });
        return;
      } else {
        // Unlock after 5 minutes
        setState(() {
          isLocked = false;
          failedAttempts = 0;
          // WidgetsBinding.instance.addPostFrameCallback((_) {
          //   DatabaseHelper.instance.checkSubscriptionStatusAndLogoutIfNeeded(context);
          // });

          // Reset failed attempts
        });

        // Update SharedPreferences to reflect that the account is unlocked
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLocked', false);
        await prefs.setInt('failedAttempts', 0);
      }
    }

    try {
      // Hash the password before passing it to the login function
      String hashedPassword = hashPassword(password);

      // Attempt local login first
      var user = await DatabaseHelper.instance.loginUser(email, hashedPassword);

      // ✅ Remote fallback using the updated loginRemote (which now contains the Supabase/online/local logic & prints)
      if (user == null) {
        user = await loginRemote(email, password);
        // NOTE: loginRemote handles its own caching, so the check below is redundant but kept for robustness.
        if (user != null) {
          // This ensures any successful remote login (Supabase or legacy PHP) is inserted/updated locally.
          await DatabaseHelper.instance.insertUserIfNotExists(user);
        }
      }

      if (user != null) {
        FocusScope.of(context).unfocus(); // Hide keyboard

        // Ensure user has 'full_name' key if coming from local DB or remote API
        String fullName = user['full_name'] ?? user['name'] ?? 'User';

        // Show success message using Toast
        Fluttertoast.showToast(
          msg: "Welcome $fullName!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.lightBlueAccent,  // Pharmacy green color
          textColor: Colors.white,
          fontSize: 16.0,
        );

        // Use 'if' logic to determine user role and navigate accordingly
        if (user['role'] == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminDashboard(user: user!)),
          );
        } else if (user['role'] == 'staff') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => PharmacyDashboard(user: user!)),
          );
        } else {
          setState(() {
            errorMessage = 'Role not recognized';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Invalid email or password';
          isLoading = false;
          failedAttempts++;
        });

        if (failedAttempts >= 5) {
          setState(() {
            isLocked = true;
            lastFailedAttempt = DateTime.now();
          });

          // Save lockout info in SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLocked', true);
          await prefs.setInt('failedAttempts', failedAttempts);
          await prefs.setString('lastFailedAttempt', lastFailedAttempt!.toIso8601String());

          Fluttertoast.showToast(
            msg: "Too many failed attempts. Account locked for 5 minutes.",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }

        // Show failure message using Toast
        Fluttertoast.showToast(
          msg: "Invalid email or password",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.blueAccent,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'An error occurred: $e';
        isLoading = false;
      });

      // Show error message using Toast
      Fluttertoast.showToast(
        msg: "An error occurred: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.blueAccent,
        textColor: Colors.white,
        fontSize: 16.0,
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
    readAndNotifyPaymentStatus();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'STOCK&INVENTORY SOFTWARE',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black,
            letterSpacing: 2,
            shadows: [
              Shadow(
                offset: Offset(1.5, 1.5),
                blurRadius: 3.0,
                color: Colors.white,
              ),
            ],
            fontFamily: 'Roboto',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),


      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[500]!, Colors.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top button row — always visible, never scrolls
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 10, bottom: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          margin: EdgeInsets.symmetric(horizontal: 40),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => InfoPage()));
                            },
                            child: Icon(
                              Icons.info,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(width: 50),
                        InkWell(
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ContactPage()));
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.contact_mail,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        InkWell(
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => Payment()));
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.paypal,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => InstallationAgreementScreen())); // replace with your target page
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.menu_book, // or Icons.info, Icons.description
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        SizedBox(width: 50),
                        InkWell(
                          onTap: (_hasInternet && !_isCheckingConnectivity)
                              ? () async {
                            setState(() => _isCheckingConnectivity = true);

                            try {
                              final result = await InternetAddress.lookup('google.com');
                              if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => WeatherScreen()),
                                );
                              } else {
                                throw SocketException('No internet');
                              }
                            } on SocketException catch (_) {
                              setState(() => _hasInternet = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('No internet connection. Please connect to internet to view weather.'),
                                ),
                              );
                            }

                            setState(() => _isCheckingConnectivity = false);
                          }
                              : null,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: _hasInternet ? Colors.blue : Colors.grey,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.sunny,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                        SizedBox(width: 50),
                        InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => TutorialPage()));
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 40),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),


                        SizedBox(width: 50),
                      ],
                    ),
                  ),
                ),

                // Scrollable login form area fills remaining space
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(30),
                    child: AnimatedContainer(
                      duration: Duration(seconds: 1),
                      curve: Curves.easeOut,
                      width: MediaQuery.of(context).size.width * 0.85,
                      // height removed to allow scrolling naturally
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.2),
                            blurRadius: 15,
                            offset: Offset(5, 5),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Information and Help Section
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      paymentStatusMessage,
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Login to Your Account',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                    shadows: [
                                      Shadow(
                                        offset: Offset(2, 2),
                                        blurRadius: 6,
                                        color: Colors.black.withOpacity(0.3),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Enter your registered email and password to access your account.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Form(
                            key: _formKey,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                TextFormField(
                                  controller: emailController,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.green[50],
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email, color: Colors.green[700]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your email';
                                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 16),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: !showPassword, // Toggle visibility
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.green[50],
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock, color: Colors.green[700]),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        showPassword ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.green[700],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          showPassword = !showPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 20),
                                if (isLoading)
                                  CircularProgressIndicator()
                                else
                                  ElevatedButton(
                                    onPressed: login,
                                    child: Text('Login'),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                      backgroundColor: Colors.green[700],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      textStyle: TextStyle(fontSize: 18),
                                    ),
                                  ),
                                if (errorMessage.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10.0),
                                    child: Text(
                                      errorMessage,
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),

                                // Reset Password and Register Links
                                Padding(
                                  padding: const EdgeInsets.only(top: 15.0),
                                  child: Column(
                                    children: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => ResetPasswordScreen()),
                                          );
                                        },
                                        child: Text(
                                          'Forgot Password?',
                                          style: TextStyle(fontSize: 16, color: Colors.green[700]),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => NotRegisteredPage()),
                                          );
                                        },
                                        child: Text(
                                          'Don\'t have an account? Sign up',
                                          style: TextStyle(fontSize: 16, color: Colors.green[700]),
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          FloatingActionButton(
                                            mini: true,
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ChatbotScreen(
                                                    ollamaApiUrl: 'http://localhost:11434/v1/chat/completions',
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Open Chatbot Assistance',
                                            child: Icon(
                                              Icons.chat_bubble_outline,
                                              size: 60, // Increase the icon size (default is 24)
                                            ),
                                          ),
                                        ],
                                      ),


                                      Padding(
                                        padding: const EdgeInsets.only(top: 30.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              'Version: $_appVersion',
                                              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                            ),
                                            SizedBox(height: 5),
                                            Text(
                                              '© ${DateTime.now().year} E-PHAMARCY SOFTWARE - All Rights Reserved',
                                              style: TextStyle(fontSize: 14, color: Colors.black),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
    );
  }

} class ContactPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Icon(Icons.contact_mail, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/backgroud.jpg', // Add this image to assets
                fit: BoxFit.cover,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Contact Info",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(Icons.email, color: Colors.blue),
                    title: Text("support@ephamarcysoftware.co.tz"),
                  ),
                ),
                SizedBox(height: 10),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(Icons.phone, color: Colors.green),
                    title: Text("+255 742448965"),
                  ),
                ),
                SizedBox(height: 10),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: Icon(Icons.location_on, color: Colors.red),
                    title: Text("ARUSHA CBD-LEVOLOSI STREET-MAKAO MAPYA-NEAR NAIROBI ROAD TANZANIA"),
                  ),
                ),
                SizedBox(height: 30),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.arrow_back),
                    label: Text("Back to Login"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      backgroundColor: Colors.blueAccent,
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
}

class InfoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Icon(Icons.info, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/backgroud.jpg', // Add this image to assets
                fit: BoxFit.cover,
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "STOCK & INVENTORY SOFTWARE",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                SizedBox(height: 10),
                Text(
                  '''Stock&Inventory Software is an advanced platform designed to support a wide range of businesses, including pharmacies, clinics, hospitals, cosmetics shops, supermarkets, minimarts, electronic stores, stationery shops, hardware stores, gas and oil distributors, restaurants, food and beverage suppliers, agricultural product sellers, retail stores, wholesale shops, and general merchandise businesses.''',
                  style: TextStyle(fontSize: 16),
                ),
                Divider(height: 30),
                SizedBox(height: 10),
                Text(
                  "It features barcode/QR code stock tracking, automated sales via CCTV, invoicing, email/SMS alerts, financial tracking, user role management, and much more — all in one dashboard.",
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 10),
                Text(
                  "🌟 Key Features:",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                SizedBox(height: 8),
                bullet("Barcode & QR code-based stock management."),
                bullet("Automated sales system with CCTV detection."),
                bullet("Instant invoicing, receipts, and email delivery."),
                bullet("User role access control (Admin, Seller, Pharmacist, Accountant)."),
                bullet("Multi-business & branch dashboard."),
                bullet("Customer & supplier notifications via email/SMS."),
                bullet("Profit/loss analysis and payroll support."),
                bullet("Expiry and out-of-stock alerts."),
                bullet("Advanced sales, stock, and performance reports."),
                bullet("PDF generation and email integration."),
                SizedBox(height: 15),
                Text(
                  "🎯 Who Can Use This?",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal),
                ),
                SizedBox(height: 8),
                SizedBox(height: 8),
                bullet("Pharmacies"),
                bullet("Clinics"),
                bullet("Hospitals"),
                bullet("Cosmetics shops"),
                bullet("Supermarkets"),
                bullet("Minimarts"),
                bullet("Electronic stores"),
                bullet("Stationery shops"),
                bullet("Hardware stores"),
                bullet("Gas and oil distributors"),
                bullet("Restaurants"),
                bullet("Food and beverage suppliers"),
                bullet("Agricultural product sellers"),
                bullet("Retail stores"),
                bullet("Wholesale shops"),
                bullet("General merchandise businesses"),
                bullet("Wholesale and distribution businesses"),
                SizedBox(height: 20),
                Text(
                  "It also uses Artificial Intelligence (AI) to enhance security by detecting theft and to improve customer service by counting and analyzing customer visits.",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  "Stock&Inventory Software is more than just a tool — it's your complete digital business partner, built to empower, protect, and accelerate every part of your operations.",
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
                SizedBox(height: 30),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.arrow_back),
                    label: Text("Back to Login"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      padding:
                      EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                      textStyle: TextStyle(fontSize: 16),
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
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Payment Screen",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            SizedBox(height: 20),
            Text(
              'Choose Your Payment Method',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            SizedBox(height: 20),
            // Wrap widget for horizontal alignment of payment buttons
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10, // Horizontal space between buttons
                  runSpacing: 10, // Vertical space between rows of buttons
                  children: [
                    PaymentButton(
                      label: 'M-Pesa',
                      icon: Icons.phone_android,
                      color: Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
                    ),
                    PaymentButton(
                      label: 'Mix by Yas',
                      icon: Icons.account_balance_wallet,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
                    ),
                    PaymentButton(
                      label: 'Airtel Money',
                      icon: Icons.phone,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
                    ),
                    PaymentButton(
                      label: 'Visa Card',
                      icon: Icons.credit_card,
                      color: Colors.blueGrey,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
                    ),
                    PaymentButton(
                      label: 'Halo Pesa',
                      icon: Icons.monetization_on,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
                    ),
                    PaymentButton(
                      label: 'PayPal',
                      icon: Icons.payment,
                      color: Colors.lightBlue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                        );
                      },
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
}
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Payment Screen",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              'DEAR USER MONTHLY PAMENT HAVE BEEN REACHED YOU CANT ACCESS THE SYSTEM UNTIL YOU PAY ',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const Text(
              'Choose Your Payment Method',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            PaymentButton(
              label: 'M-Pesa',
              icon: Icons.phone_android,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
            PaymentButton(
              label: 'Mix by Yas',
              icon: Icons.account_balance_wallet,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
            PaymentButton(
              label: 'Airtel Money',
              icon: Icons.phone,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
            PaymentButton(
              label: 'Visa Card',
              icon: Icons.credit_card,
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
            PaymentButton(
              label: 'Halo Pesa',
              icon: Icons.monetization_on,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
            PaymentButton(
              label: 'PayPal',
              icon: Icons.payment,
              color: Colors.lightBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PesapalPaymentScreen()),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
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
