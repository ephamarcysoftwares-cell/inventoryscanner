import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';

class EventNotifier {
  static Future<void> notifyUpcomingEvents() async {
    final db = await DatabaseHelper.instance.database;

    final today = DateTime.now();
    final todayString = DateFormat('yyyy-MM-dd').format(today);

    final events = await db.rawQuery('''
      SELECT * FROM upcoming_event 
      WHERE DATE(event_date) >= ? 
    ''', [todayString]);

    for (final event in events) {
      final eventId = event['id'];
      final userId = event['user_id'];
      final title = event['event_title'];
      final eventDate = DateTime.parse(event['event_date'].toString());
      final lastNotified = event['last_notified'] != null
          ? DateTime.tryParse(event['last_notified'].toString())
          : null;

      final eventDateStr = DateFormat('yyyy-MM-dd').format(eventDate);

      // Only notify once per day
      if (lastNotified != null &&
          DateFormat('yyyy-MM-dd').format(lastNotified) == todayString) {
        continue;
      }

      // Fetch user details (email, name, business)
      final user = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (user.isEmpty) continue;

      final userEmail = user[0]['email'];
      final userName = user[0]['name'];
      final businessName = user[0]['business_name'] ?? 'STOCK&INVENTORY REMAINDER';

      await _sendEmail(
        userEmail: userEmail.toString(),
        userName: userName.toString(),
        eventTitle: title.toString(),
        eventDateStr: eventDateStr,
        businessName: businessName.toString(),
      );

      await db.update(
        'upcoming_event',
        {'last_notified': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [eventId],
      );
    }
  }

  static Future<void> _sendEmail({
    required String userEmail,
    required String userName,
    required String eventTitle,
    required String eventDateStr,
    required String businessName,
  }) async {
    try {
      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final htmlContent = """
      <html>
        <body style="font-family: Arial, sans-serif; background-color: #f3f3f3; padding: 20px;">
          <div style="background-color: white; padding: 20px; border-radius: 12px;">
            <h2 style="color: green;">📅 Upcoming Event Reminder</h2>
            <p>Dear </p>
            <p>This is a friendly reminder about your upcoming event:</p>
            <ul>
              <li><strong>Title:</strong> $eventTitle</li>
              <li><strong>Date:</strong> $eventDateStr</li>
            </ul>
            <p>Make sure you're prepared. Thank you for using <strong>$businessName</strong>.</p>
            <p style="color: #888; font-size: 12px;">You will not receive this reminder again today.</p>
          </div>
        </body>
      </html>
      """;

      final message = mailer.Message()
        ..from = mailer.Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.add(userEmail)
        ..subject = '📌 Reminder: Upcoming Event - $eventTitle'
        ..html = htmlContent;

      await mailer.send(message, smtpServer);
      print('✅ Reminder sent to $userEmail');
    } catch (e) {
      print('❌ Error sending reminder: $e');
    }
  }
}
