import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../DB/database_helper.dart';
import '../SMS/sms_gateway.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class PeriodicReminderScheduler {
  /// Placeholder for checking WhatsApp contact existence using WAWP API.
  Future<String> checkWhatsappContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
    final accessToken = prefs.getString('whatsapp_access_token') ?? '';

    if (instanceId.isEmpty || accessToken.isEmpty) {
      return "Config Missing";
    }

    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

    var uri = Uri.parse('https://wawp.net/wp-json/awp/v1/contacts/check-exists');

    var request = http.Request(
      'GET',
      uri.replace(queryParameters: {
        'instance_id': instanceId,
        'access_token': accessToken,
        'phone': cleanPhone,
      }),
    );

    try {
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body);
        return json['status'] == 'exists' ? "Exists" : "Not Exists";
      } else {
        return "HTTP Error ${response.statusCode}";
      }
    } catch (e) {
      return "Exception";
    }
  }

  /// Send WhatsApp message using WAWP API
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
      final accessToken = prefs.getString('whatsapp_access_token') ?? '';

      if (instanceId.isEmpty || accessToken.isEmpty) {
        return "❌ WA Config Error";
      }

      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      // Example of formatting for Tanzanian numbers if necessary
      if (!cleanPhone.startsWith('255') && cleanPhone.length >= 9) {
        cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
      } else if (cleanPhone.isEmpty) {
        return "❌ WA No Number";
      }

      final sendRes = await http.post(
        Uri.parse('https://wawp.net/wp-json/awp/v1/send'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'instance_id': instanceId,
          'access_token': accessToken,
          'chatId': cleanPhone,
          'message': messageText,
        },
      );

      if (sendRes.statusCode >= 200 && sendRes.statusCode < 300) {
        return "✅ WA Sent";
      } else {
        return "❌ WA Failed: ${sendRes.statusCode}";
      }
    } catch (e) {
      return "❌ WA Exception";
    }
  }

  /// Start the scheduler
  void start() {
    // Send reminders immediately (non-blocking)
    _sendDailyReminders();

    // Schedule next reminder
    _scheduleDailyReminders();
  }

  // --------------------------------------------------------------------------

  /// --- PRODUCTION MODE: Runs daily at three scheduled times ---
  void _scheduleDailyReminders() {
    // Define the three daily reminder times as hours and minutes
    const List<List<int>> reminderTimes = [
      [7, 0],  // 7:00 AM
      [12, 0], // 12:00 PM (Noon)
      [20, 0], // 8:00 PM
    ];

    final now = DateTime.now();
    final List<DateTime> nextOccurrences = [];

    // 1. Calculate the next occurrence for TODAY for each time
    for (final time in reminderTimes) {
      final nextTime = DateTime(now.year, now.month, now.day, time[0], time[1]);
      nextOccurrences.add(nextTime);
    }

    // 2. Find the *very next* time slot that hasn't passed yet
    // Filter out the times that are in the past
    final upcomingTimesToday = nextOccurrences.where((dt) => dt.isAfter(now)).toList();

    DateTime scheduledTime;

    if (upcomingTimesToday.isNotEmpty) {
      // If there are times left today, the next one is the earliest of those
      upcomingTimesToday.sort();
      scheduledTime = upcomingTimesToday.first;
    } else {
      // If all times for today have passed, schedule for the first time tomorrow (7:00 AM)
      final tomorrow = now.add(const Duration(days: 1));
      scheduledTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, reminderTimes[0][0], reminderTimes[0][1]);
    }

    final durationUntilScheduledTime = scheduledTime.difference(now);

    print("⏳ [PRODUCTION] Next reminder scheduled at: "
        "$scheduledTime (${durationUntilScheduledTime.inMinutes} minutes from now)");

    // Schedule the function call and recursive rescheduling
    Future.delayed(durationUntilScheduledTime, () async {
      await _sendDailyReminders(); // The action to perform
      _scheduleDailyReminders();    // Schedule the next occurrence
    });
  }

  // --------------------------------------------------------------------------

  /// Send reminders (Email + SMS + WhatsApp)
  Future<void> _sendDailyReminders() async {
    try {
      print("▶️ Running _sendDailyReminders at ${DateTime.now()}");

      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> toLendList = await db.query('To_lend');

      print("📊 Found ${toLendList.length} records in To_lend");

      if (toLendList.isEmpty) {
        print('ℹ️ No reminders to send today.');
        return;
      }

      // Get business info
      final businessInfo = await getBusinessInfo();
      final businessName = businessInfo['name'] ?? '';
      final businessPhone = businessInfo['phone'] ?? '';

      // Group by customer phone/email and sum total_price
      final Map<String, Map<String, dynamic>> customers = {};

      for (var lend in toLendList) {
        final phone = lend['customer_phone'] ?? '';
        final email = lend['customer_email'] ?? '';
        final name = lend['customer_name'] ?? 'Mteja';
        final total = double.tryParse(lend['total_price'].toString()) ?? 0.0;

        final key = phone.isNotEmpty ? phone : email;
        if (key.isEmpty) continue;

        if (customers.containsKey(key)) {
          customers[key]!['total'] += total;
        } else {
          customers[key] = {
            'name': name,
            'email': email,
            'phone': phone,
            'total': total,
          };
        }
      }

      // Convert to list and sort by total descending
      final sortedCustomers = customers.values.toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      // SMTP config
      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      // --- Helper Functions for Retries ---

      Future<void> sendWithRetryEmail(Message message) async {
        const int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await send(message, smtpServer);
            print('✅ Email sent to ${message.recipients}');
            break;
          } catch (e) {
            print("❌ Email attempt $attempt failed for ${message.recipients}: $e");
            if (attempt < maxAttempts) await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      Future<void> sendWithRetrySMS(String phone, String msg) async {
        const int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await sendSingleMessage(phone, msg);
            print('✅ SMS sent to $phone');
            break;
          } catch (e) {
            print("❌ SMS attempt $attempt failed for $phone: $e");
            if (attempt < maxAttempts) await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      Future<void> sendWithRetryWA(String phone, String msg) async {
        const int maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          final result = await sendWhatsApp(phone, msg);
          if (result.startsWith('✅')) {
            print('$result to $phone');
            break;
          } else {
            print("$result (Attempt $attempt) for $phone");
            if (attempt < maxAttempts) await Future.delayed(const Duration(seconds: 5));
          }
        }
      }

      // --- Send Message Logic ---

      for (var customer in sortedCustomers) {
        final email = customer['email'] as String?;
        final phone = customer['phone'] as String?;
        final name = customer['name'] as String?;
        final total = customer['total'] as double;

        final msg =
            "Mpendwa Mteja wetu $name, tunapenda kutumia fursa hii kukukumbusha "
            "${businessName.isNotEmpty ? 'kutoka $businessName ' : ''}"
            "kwamba bado una deni la TSH ${NumberFormat('#,##0').format(total)}. "
            "Tafadhali lipa deni lako unapopata nafasi ili tuendelee kutoa huduma bora kwako. "
            "Tunakupenda na Kukudhamini sana mteja wetu. "
            "Usijibu ujumbe huu au kupiga simu kama unachangamoto wasiliana kupitia ${businessPhone.isNotEmpty ? businessPhone : '24HRS'} "
            "Imetumwa kutoka STOCK & INVENTORY SOFTWARE. Ahsante!";

        // 1. Send Email Reminder
        if (email != null && email.isNotEmpty) {
          final message = Message()
            ..from = Address(
                'suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
            ..recipients.add(email)
            ..subject = 'Kumbusho la Malipo ya Deni'
            ..html = "<p>${msg.replaceAll('\n', '<br>')}</p>";

          await sendWithRetryEmail(message);
        }

        // 2. Send WhatsApp Reminder (to customer_phone, with SMS fallback)
        if (phone != null && phone.isNotEmpty) {
          final waExists = await checkWhatsappContact(phone);
          if (waExists == "Exists") {
            await sendWithRetryWA(phone, msg); // Primary: WhatsApp
          } else {
            print("ℹ️ WhatsApp not exists for $phone, attempting SMS.");
            await sendWithRetrySMS(phone, msg); // Fallback: SMS
          }
        }
      }
    } catch (e) {
      print("⚠️ Error in PeriodicReminderScheduler: $e");
    }
  }

  // --------------------------------------------------------------------------

  /// Fetch business info (first row from businesses)
  Future<Map<String, String?>> getBusinessInfo() async {
    final db = await DatabaseHelper.instance.database;

    final businessResult = await db.query(
      'businesses',
      columns: ['business_name', 'phone'],
      orderBy: 'id ASC',
      limit: 1,
    );

    if (businessResult.isEmpty) return {};

    return {
      'name': businessResult.first['business_name'] as String?,
      'phone': businessResult.first['phone'] as String?,
    };
  }
}