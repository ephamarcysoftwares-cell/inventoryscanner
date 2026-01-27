import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart';
import '../DB/database_helper.dart'; // Adjust path as needed
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class BackupService {
  // Upload backup file to live server with detailed debug info
  static Future<void> uploadBackupToServer(String filePath, String fileName) async {
    try {
      final uri = Uri.parse('https://ephamarcysoftware.co.tz/ephamarcy/upload_backup/'); // Replace with your API URL
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('backup_file', filePath, filename: fileName));

      print('[BackupService] Starting upload to server: $uri');
      print('[BackupService] Uploading file: $fileName, path: $filePath');

      final response = await request.send();

      // Read response body for better debugging
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        print('[BackupService] Backup uploaded to server successfully.');
        print('[BackupService] Server response body: $responseBody');
      } else {
        print('[BackupService] Failed to upload backup to server. Status code: ${response.statusCode}');
        print('[BackupService] Server response body: $responseBody');
      }
    } catch (e, stack) {
      print('[BackupService] Error uploading backup to server: $e');
      print('[BackupService] Stacktrace:\n$stack');
    }
  }

  // Send backup email with renamed DB attachment based on business name + time
  static Future<void> sendBackupEmail() async {
    try {
      print('[BackupService] Starting backup email process...');

      final db = await DatabaseHelper.instance.database;
      print('[BackupService] Got database instance');
      final dbPath = db.path;
      print('[BackupService] DB path: $dbPath');

      // Get business names using helper method
      final names = await DatabaseHelper.instance.getBusinessNames();
      if (names.isEmpty) {
        print('[BackupService] No business found in DB.');
        return;
      }

      String businessName = names.first.replaceAll(' ', '_');
      print('[BackupService] Business name: $businessName');

      // Format current date & time, e.g., 2025-07-01_22-30
      final now = DateTime.now();
      final formattedDateTime = DateFormat('yyyy-MM-dd_HH-mm').format(now);

      // Add date/time to filename and subject
      String newFileName = '${businessName}_backup_$formattedDateTime.db';

      // Copy DB file to temp directory with new name
      final tempDir = Directory.systemTemp;
      final tempFilePath = join(tempDir.path, newFileName);
      await File(dbPath).copy(tempFilePath);
      print('[BackupService] Copied DB to temp: $tempFilePath');

      // SMTP server config
      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );
      print('[BackupService] SMTP server configured');

      // Compose email
      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', 'Epharmacy Backup')
        ..recipients.add('mlyukakenedy@gmail.com')
        ..subject = 'Daily Backup - $businessName - $formattedDateTime'
        ..text = 'Attached is your backup database.'
        ..attachments = [
          FileAttachment(File(tempFilePath))..fileName = newFileName
        ];

      print('[BackupService] Sending email...');
      final sendReport = await send(message, smtpServer);
      print('[BackupService] Backup email sent successfully! Report: $sendReport');

      // --- Upload to live server simultaneously ---
      print('[BackupService] Uploading backup to live server...');
      await uploadBackupToServer(tempFilePath, newFileName);

    } catch (e, stack) {
      print('[BackupService] Error sending backup: $e');
      print('[BackupService] Stacktrace:\n$stack');
    }
  }

  // Check if backup was sent today; if not, send it and record date
  static Future<void> sendBackupIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final lastBackupDate = prefs.getString('last_backup_date');
    if (lastBackupDate != today) {
      print('[BackupService] Sending daily backup...');
      await sendBackupEmail();
      await prefs.setString('last_backup_date', today);
    } else {
      print('[BackupService] Backup already sent today.');
    }
  }
}

// Scheduler function to run backup every 24 hours
Future<void> startDailyBackupScheduler() async {
  // Run initial check and backup if needed
  await BackupService.sendBackupIfNeeded();

  // Schedule periodic backups every 24 hours
  Timer.periodic(Duration(hours: 24), (timer) async {
    await BackupService.sendBackupIfNeeded();
  });
}
