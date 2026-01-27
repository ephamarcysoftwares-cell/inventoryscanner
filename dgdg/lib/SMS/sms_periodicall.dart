import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../DB/database_helper.dart';
import '../SMS/sms_gateway.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class PeriodicReminderScheduler {
  /// Check if WhatsApp contact exists using WAWP API
  Future<String> checkWhatsappContact(String phoneNumber) async {
    final prefs = await SharedPreferences.getInstance();
    final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
    final accessToken = prefs.getString('whatsapp_access_token') ?? '';

    if (instanceId.isEmpty || accessToken.isEmpty) {
      print("WA_DEBUG: Config Missing for Check");
      return "Config Missing";
    }

    // Clean number
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    print("WA_DEBUG: Checking phone format: $cleanPhone");

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
        print("WA_DEBUG: HTTP Error ${response.statusCode}");
        return "HTTP Error ${response.statusCode}";
      }
    } catch (e) {
      print("WA_DEBUG: Exception: $e");
      return "Exception";
    }
  }

  /// Send WhatsApp message via WAWP API
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
      final accessToken = prefs.getString('whatsapp_access_token') ?? '';

      if (instanceId.isEmpty || accessToken.isEmpty) {
        return "❌ WA Config Error";
      }

      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('255') && cleanPhone.length >= 9) {
        cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
      } else if (cleanPhone.isEmpty) {
        return "❌ WA No Number";
      }

      print("WA_DEBUG: Sending message to $cleanPhone");

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

  /// Start scheduler
  void start() {
    _sendDailyReminders();
    _scheduleDailyReminders();
  }

  /// Schedule reminders at 7:00 AM, 12:00 PM, 8:00 PM
  void _scheduleDailyReminders() {
    const List<List<int>> reminderTimes = [
      [7, 0],
      [12, 0],
      [20, 0],
    ];

    final now = DateTime.now();
    final List<DateTime> nextOccurrences = [];

    for (final time in reminderTimes) {
      final nextTime = DateTime(now.year, now.month, now.day, time[0], time[1]);
      nextOccurrences.add(nextTime);
    }

    final upcomingTimesToday = nextOccurrences.where((dt) => dt.isAfter(now)).toList();
    DateTime scheduledTime;

    if (upcomingTimesToday.isNotEmpty) {
      upcomingTimesToday.sort();
      scheduledTime = upcomingTimesToday.first;
    } else {
      final tomorrow = now.add(const Duration(days: 1));
      scheduledTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, reminderTimes[0][0], reminderTimes[0][1]);
    }

    final durationUntilScheduledTime = scheduledTime.difference(now);
    print("⏳ Next reminder scheduled at: $scheduledTime (${durationUntilScheduledTime.inMinutes} min)");

    Future.delayed(durationUntilScheduledTime, () async {
      await _sendDailyReminders();
      _scheduleDailyReminders();
    });
  }

  /// Send reminders (Email + WhatsApp + SMS)
  Future<void> _sendDailyReminders() async {
    try {
      print("▶️ Running reminders at ${DateTime.now()}");

      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> toLendList = await db.query('To_lend');

      print("📊 Found ${toLendList.length} records in To_lend");
      if (toLendList.isEmpty) return;

      final businessInfo = await getBusinessInfo();
      final businessName = businessInfo['name'] ?? '';
      final businessPhone = businessInfo['phone'] ?? '';

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
          customers[key] = {'name': name, 'email': email, 'phone': phone, 'total': total};
        }
      }

      final sortedCustomers = customers.values.toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

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

      // --- Send to each customer ---
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

        // ✅ Email Validation
        bool isValidEmail(String? email) {
          if (email == null) return false;
          final trimmed = email.trim().toLowerCase();
          if (trimmed.isEmpty) return false;

          final parts = trimmed.split('@');
          if (parts.length != 2) return false;

          final localPart = parts[0];
          final domainPart = parts[1];

          if (localPart.length < 3) return false;
          if (!domainPart.contains('.')) return false;

          final invalidPatterns = ['example', 'demo', 'test', 'fake', 'mailinator', 'placeholder'];
          if (invalidPatterns.any((word) => trimmed.contains(word))) return false;

          final allowedDomain = RegExp(
              r'^[a-zA-Z0-9._%+-]+@(gmail\.com|yahoo\.com|hotmail\.com|outlook\.com|icloud\.com|live\.com|protonmail\.com|aol\.com|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})$');
          return allowedDomain.hasMatch(trimmed);
        }

        // ✅ 1. Email send
        if (isValidEmail(email)) {
          final message = Message()
            ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
            ..recipients.add(email!.trim())
            ..subject = 'Kumbusho la Malipo ya Deni'
            ..html = "<p>${msg.replaceAll('\n', '<br>')}</p>";
          await sendWithRetryEmail(message);
        } else {
          print("⚠️ Skipping invalid email: $email");
        }

        // ✅ 2. WhatsApp first, then SMS fallback
        if (phone != null && phone.isNotEmpty) {
          String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
          if (!cleanPhone.startsWith('255') && cleanPhone.length >= 9) {
            cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
          }

          print("📞 Prepared WhatsApp number: $cleanPhone");
          final waExists = await checkWhatsappContact(cleanPhone);
          print("📲 WA Check Result for $cleanPhone: $waExists");

          if (waExists == "Exists") {
            bool sent = false;
            const int maxAttempts = 3;
            for (int attempt = 1; attempt <= maxAttempts; attempt++) {
              final result = await sendWhatsApp(cleanPhone, msg);
              print("🟩 WhatsApp send attempt $attempt → $result");
              if (result.startsWith("✅")) {
                sent = true;
                break;
              }
              await Future.delayed(const Duration(seconds: 3));
            }

            if (!sent) {
              print("⚠️ WhatsApp failed after retries, fallback to SMS.");
              await sendWithRetrySMS(cleanPhone, msg);
            }
          } else {
            print("ℹ️ WhatsApp not exists for $cleanPhone, sending SMS.");
            await sendWithRetrySMS(cleanPhone, msg);
          }
        } else {
          print("⚠️ No phone number found for $name");
        }
      }
    } catch (e) {
      print("⚠️ Error in PeriodicReminderScheduler: $e");
    }
  }

  /// Get business info
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
