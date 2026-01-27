import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:http/http.dart' as http;

import '../QR Code generator/daily summary.dart' hide sendSingleMessage;
import '../SMS/sms_gateway.dart' show sendSingleMessage, SERVER, API_KEY;
import '../login.dart';

// ===== Database Helper =====
class DatabaseHelper {
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    return openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
  }

  Future<bool> checkUserExists() async {
    final db = await database;
    List<Map<String, dynamic>> users = await db.query('users', limit: 1);
    return users.isNotEmpty;
  }
}

// ===== Payment Transaction Service =====
class PaymentTransactionService {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  Future<int> insertPaymentTransaction(Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    return await db.insert('payment_transactions', data);
  }
}

// ===== Payment Confirmation Screen =====
class PaymentConfirmationCode extends StatefulWidget {
  @override
  _PaymentConfirmationCodeState createState() =>
      _PaymentConfirmationCodeState();
}

class _PaymentConfirmationCodeState extends State<PaymentConfirmationCode> {
  final TextEditingController codeController = TextEditingController();

  String generatedCode = "";
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String firstName = '';
  String lastName = '';

  bool isCodeSent = false;
  bool isVerified = false;
  bool isLoading = false;
  bool isButtonEnabled = true;
  int cooldownSeconds = 0;
  Timer? _timer;

  // ===== Send Reset Code =====
  Future<void> sendResetCode() async {
    if (!isButtonEnabled) return;

    setState(() {
      isLoading = true; // show spinner
    });

    try {
      // ===== Check network connectivity =====
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        showMessage("❌ No internet connection. Please check your network and try again.");
        return;
      }

      // ===== Check if user exists =====
      bool userExists = await DatabaseHelper.instance.checkUserExists();
      if (!userExists) {
        showMessage("User not found in system.");
        return;
      }

      // ===== Get business info =====
      await getBusinessInfo();

      if (businessName.isEmpty) {
        showMessage("Business info not found. Cannot proceed.");
        return;
      }

      // ===== Check live payment =====
      bool paymentExists = await checkLivePayment(businessName);
      if (!paymentExists) {
        showMessage(
          "No completed payment found for $businessName.\n"
              "If your payment was successful, please contact: +255 742448965 or Email: support@ephamarcysoftware.co.tz",
        );
        return;
      }

      // ===== Generate 6-digit code =====
      generatedCode =
          (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();

      // ===== Send email & SMS =====
      bool emailSent = await sendEmail(generatedCode);
      bool smsSent = await sendSmsCode(businessPhone, generatedCode);

      if (emailSent || smsSent) {
        setState(() {
          isCodeSent = true;
          isVerified = false;
          codeController.clear();
          isButtonEnabled = false;
          cooldownSeconds = 120; // 2 minutes cooldown
        });

        // Start cooldown timer
        _startCooldownTimer();

        showMessage(
          "Payment is on review. Check your email or SMS for the code.",
        );
      } else {
        showMessage("❌ Failed to send email/SMS. Please check your network connection and try again.");
      }
    } catch (e) {
      showMessage("❌ Error occurred: $e");
    } finally {
      setState(() {
        isLoading = false; // hide spinner
      });
    }
  }

  // ===== Cooldown Timer =====
  void _startCooldownTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (cooldownSeconds == 0) {
        setState(() {
          isButtonEnabled = true;
        });
        timer.cancel();
      } else {
        setState(() {
          cooldownSeconds--;
        });
      }
    });
  }

  // ===== Verify Code & Insert Payment =====
  Future<void> verifyCodeAndInsert() async {
    String inputCode = codeController.text.trim();

    if (inputCode == generatedCode) {
      final now = DateTime.now();
      final paymentDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final nextPaymentDate =
      DateFormat('yyyy-MM-dd HH:mm:ss').format(now.add(Duration(days: 30)));

      Map<String, dynamic> paymentData = {
        'status': 'Completed',
        'message': 'Payed',
        'payment_method': 'Tigo',
        'amount': 10500,
        'confirmation_code': generatedCode,
        'order_tracking_id': generatedCode,
        'merchant_reference': generatedCode,
        'currency': 'Tsh',
        'payment_date': paymentDate,
        'next_payment_date': nextPaymentDate,
        'synced': 1,
        'business_name': businessName,
        'first_name': firstName,
        'last_name': lastName,
      };

      int id = await PaymentTransactionService()
          .insertPaymentTransaction(paymentData);

      // ===== Send Thank You Notification =====
       sendThankYouNotification();

      // Show dialog before redirecting
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text("Congratulations!"),
          content: Text(
            "Payment completed and verified successfully.\n\nYou will now be redirected to login.",
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                );
              },
              child: Text("OK"),
            )
          ],
        ),
      );
    } else {
      showMessage("Invalid code. Please try again.");
    }
  }


  // ===== Get Business Info =====
  Future<void> getBusinessInfo() async {
    try {
      Database db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> result =
      await db.rawQuery('SELECT * FROM businesses LIMIT 1');

      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name']?.toString() ?? '';
          businessEmail = result[0]['email']?.toString() ?? '';
          businessPhone = result[0]['phone']?.toString() ?? '';
          firstName = result[0]['first_name']?.toString() ?? '';
          lastName = result[0]['last_name']?.toString() ?? '';
        });
        print(
            'Business Info Loaded: $businessName, $businessPhone, $businessEmail');
      } else {
        print('No business records found in local DB');
      }
    } catch (e) {
      print('Error loading business info: $e');
    }
  }

  // ===== Send Email =====
  Future<bool> sendEmail(String code) async {
    if (businessEmail.isEmpty) return false;

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
        'STOCK & INVENTORY SOFTWARE CODE REQUESTING',
      )
      ..recipients.addAll([businessEmail, 'mlyukakenedy@gmail.com'])
      ..subject = 'Payment Confirmation Code for $businessName'
      ..text =
          'Dear $businessName,\n\nYour confirmation code is: $code\n\nBusiness Email: $businessEmail\n\nThank you for using our service.';

    try {
      await send(message, smtpServer);
      print('Email sent successfully to $businessEmail.');
      return true;
    } on MailerException catch (e) {
      print('Email sending failed: $e');
      return false;
    }
  }

  // ===== Send SMS using sms_gateway.dart =====
  Future<bool> sendSmsCode(String phone, String code) async {
    if (phone.isEmpty) return false;

    try {
      String message =
          "Dear $businessName, your payment confirmation code is: $code";
      await sendSingleMessage(phone, message, device: 0);
      print('SMS sent successfully to $phone.');
      return true;
    } catch (e) {
      print('Failed to send SMS: $e');
      return false;
    }
  }
  Future<void> sendThankYouNotification() async {
    setState(() {
      isVerified = true;
    });

    print("Sending thank you notifications...");

    // ===== Send Email =====
    if (businessEmail.isNotEmpty) {
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
          'STOCK & INVENTORY SOFTWARE',
        )
        ..recipients.add(businessEmail)
        ..subject = 'Payment Verified Successfully'
        ..text =
            'Dear $businessName,\n\nYour payment has been successfully verified.\n'
            'Thank you for using STOCK & INVENTORY SOFTWARE.\n\n'
            'Best regards,\nSTOCK & INVENTORY SOFTWARE Team.\n\n'
            'Talk to Us,\n+255 742448965.\n\n'
            'Email,\nsupport@ephamarcysoftware.co.tz';
      try {
        await send(message, smtpServer);
        print('✅ Thank you email sent successfully to $businessEmail.');
      } on MailerException catch (e) {
        print('❌ MailerException: $e');
        for (var p in e.problems) {
          print('Problem: ${p.code}: ${p.msg}');
        }
      } catch (e) {
        print('❌ Unknown error sending email: $e');
      }
    } else {
      print('⚠️ businessEmail is empty, skipping email.');
    }

    // ===== Send SMS =====
    if (businessPhone.isNotEmpty) {
      try {
        String smsMessage =
            "Dear $businessName, your payment has been successfully verified. Thank you for using STOCK & INVENTORY SOFTWARE.";
        print("Sending SMS to $businessPhone: $smsMessage");
        await sendSingleMessage(businessPhone, smsMessage, device: 0);
        print('✅ Thank you SMS sent successfully to $businessPhone.');
      } catch (e) {
        print('❌ Failed to send thank you SMS: $e');
      }
    } else {
      print('⚠️ businessPhone is empty, skipping SMS.');
    }

    print("Done sending notifications.");
  }




  // ===== Check Live Payment =====
  Future<bool> checkLivePayment(String businessName) async {
    if (businessName.isEmpty) return false;

    final url = Uri.parse(
        'https://ephamarcysoftware.co.tz/payment/payment_check.php?business_name=${Uri.encodeComponent(businessName.trim())}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Live payment check response: $data');
        return data['payment_found'] ?? false;
      } else {
        print('Server error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error checking payment: $e');
      return false;
    }
  }

  // ===== Show SnackBar =====
  void showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text("Payment Confirmation"),
        centerTitle: true,
        elevation: 2,
        backgroundColor: Colors.teal.shade700,
      ),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Card(
            elevation: 6,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.payment, size: 80, color: Colors.teal.shade400),
                  SizedBox(height: 16),
                  Text(
                    "Verify Your Payment",
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Request a payment confirmation code and enter it below to verify your payment.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey.shade700),
                  ),
                  SizedBox(height: 30),

                  // Spinner while sending code
                  if (isLoading) ...[
                    CircularProgressIndicator(color: Colors.teal.shade600),
                    SizedBox(height: 20),
                  ],

        // Request code button
        ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
        minimumSize: Size(double.infinity, 48),
        backgroundColor: isButtonEnabled ? Colors.teal.shade600 : Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: isLoading
          ? SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2,
        ),
      )
          : Icon(Icons.send),
          label: isButtonEnabled
              ? Text(
            isLoading ? "Checking..." : "Request Payment Verification",
            style: TextStyle(color: Colors.white),
          )
              : Text(
            "Wait ${cooldownSeconds}s to Request new Code. Make sure you check phone before requesting new Code",
            style: TextStyle(color: Colors.white),
          ),

          onPressed: isButtonEnabled && !isLoading
          ? () async {
        setState(() {
          isLoading = true; // show spinner
        });

        // ===== Check Network Before Sending Code =====
        try {
          final result = await InternetAddress.lookup('example.com');
          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            // Connected, proceed
            await sendResetCode();
          } else {
            // No connection
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("No internet connection please connect to Internet or make your Internet Stable!!")),
            );
          }
        } on SocketException catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("No internet connection please connect to Internet or make your Internet Stable!")),
          );
        } finally {
          setState(() {
            isLoading = false; // hide spinner
          });
        }
      }
          : null,
    ),



    // Show business info when code is sent
                  if (isCodeSent) ...[
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Code sent to:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade800,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "$businessName",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                          Text(
                            "Phone: $businessPhone",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                          Text(
                            "Email: $businessEmail",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 30),

                    // Enter code field
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: "Enter Confirmation Code",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        prefixIcon: Icon(Icons.confirmation_num),
                        counterText: '',
                      ),
                    ),
                    SizedBox(height: 20),

                    // Verify code button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: Colors.teal.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(Icons.verified),
                      label: Text("Verify Payment Code", style: TextStyle(color: Colors.white),),
                      onPressed: verifyCodeAndInsert,
                    ),
                  ],

                  // Success message
                  if (isVerified) ...[
                    SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 28),
                        SizedBox(width: 8),
                        Text(
                          "Payment Verification Successful!",
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
