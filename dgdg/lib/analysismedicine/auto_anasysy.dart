import 'dart:io';
import 'package:cron/cron.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

// Replace with your actual DatabaseHelper class
class DatabaseHelper {
  static final instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  Future<Database> get database async {
    if (_database != null) return _database!;
    try {
      _database = await openDatabase(r'C:\Users\Public\epharmacy\epharmacy.db');
      print('Database opened successfully');
    } catch (e) {
      print('Error opening database: $e');
    }
    return _database!;
  }

}

class EmailScheduler {
  final cron = Cron();

  // Fetch admin email from SQLite database
  Future<String?> getAdminEmail() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    if (result.isNotEmpty) {
      return result.first['email'] as String?;
    }
    return null;
  }

  // Generate a dummy financial summary PDF and return file path
  Future<String> generateFinancialSummaryPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text('Financial Summary Report\n\n(Replace with your actual report)'),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final formattedDate = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filePath = '${dir.path}/financial_summary_$formattedDate.pdf';

    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    print('PDF generated at $filePath');
    return filePath;
  }

  // Send email with PDF attachment
  Future<void> sendFinancialSummaryEmail({
    required String adminEmail,
    required String pdfFilePath,
  }) async {
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE')
      ..recipients.add(adminEmail)
      ..subject = 'Business Financial Summary Report'
      ..text =
          'Dear Admin,\n\nPlease find attached the latest business financial summary report.\n\nRegards,\nYour Software'
      ..attachments = [FileAttachment(File(pdfFilePath))];

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: ' + sendReport.toString());
    } catch (e) {
      print('Email sending failed: $e');
    }
  }

  // // Schedule to send email every 3 days at 8:00 AM
  // void scheduleEmailEvery3Days() {
  //   cron.schedule(Schedule.parse('0 8 */3 * *'), () async {
  //     print('Scheduled task triggered at ${DateTime.now()}');
  //
  //     final adminEmail = await getAdminEmail();
  //     if (adminEmail == null) {
  //       print("No admin email found.");
  //       return;
  //     }
  //
  //     final pdfFilePath = await generateFinancialSummaryPDF();
  //     await sendFinancialSummaryEmail(adminEmail: adminEmail, pdfFilePath: pdfFilePath);
  //   });
  // }
// Schedule to send email every minute for testing
  void scheduleEmailEveryMinute() {
    cron.schedule(Schedule.parse('* * * * *'), () async {
      print('Scheduled task triggered at ${DateTime.now()}');

      final adminEmail = await getAdminEmail();
      if (adminEmail == null) {
        print("No admin email found.");
        return;
      }

      final pdfFilePath = await generateFinancialSummaryPDF();
      await sendFinancialSummaryEmail(adminEmail: adminEmail, pdfFilePath: pdfFilePath);
    });
  }

  // To stop cron if needed
  void stopScheduler() {
    cron.close();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final emailScheduler = EmailScheduler();

  // Start the scheduler
  // emailScheduler.scheduleEmailEvery3Days();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Email Scheduler Demo',
      home: Scaffold(

        appBar: AppBar(
          title: Text(
            "Email Scheduler Demo",
            style: TextStyle(color: Colors.white), // ✅ correct place
          ),
          centerTitle: true,
          backgroundColor: Colors.teal,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
          ),
        ),
        body: const Center(
          child: Text('Financial summary email will be sent every 3 days at 8:00 AM.'),
        ),
      ),
    );
  }
}
