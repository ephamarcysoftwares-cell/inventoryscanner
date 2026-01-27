import 'package:flutter/material.dart';
import 'package:cron/cron.dart'; // For scheduling tasks
import 'dart:io'; // For checking platform (Android/Desktop)
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:async'; // For Timer on desktop
import 'package:timezone/standalone.dart' as tz;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Check for Android platform to use FlutterBackgroundService
  if (Platform.isAndroid) {
    // Android background service logic (If you still want to use flutter_background_service for Android)
    configureAndroidBackgroundService();
  } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    // Desktop background task using Timer
    startDesktopBackgroundTask();
  }

  runApp(MyApp());
}

// For Android (flutter_background_service) - Remove this if you are not using Android-specific background tasks
void configureAndroidBackgroundService() {
  // Android specific configuration (if you plan to use FlutterBackgroundService for Android)
  // FlutterBackgroundService().configure(
  //   androidConfiguration: AndroidConfiguration(
  //     onStart: backgroundTask,
  //     autoStart: true,
  //     isForegroundMode: true, // Keep the service running in the foreground
  //   ),
  // );
  // FlutterBackgroundService().start();
}

// For Desktop (using Timer)
void startDesktopBackgroundTask() {
  final cron = Cron();

  // Schedule the task to run every day at 11:00 PM (23:00)
  cron.schedule(Schedule.parse('0 23 * * *'), () async {
    await generateAndSendSalesReport();
  });
}

void backgroundTask() {
  final cron = Cron();

  // Schedule the task to run every day at 11:00 PM
  cron.schedule(Schedule.parse('0 23 * * *'), () async {
    await generateAndSendSalesReport();
  });
}


// Listen for events to trigger the report generation manually
  // FlutterBackgroundService().onDataReceived.listen((event) {
  //   if (event != null && event.containsKey("action") && event["action"] == "send_sales_report") {
  //     generateAndSendSalesReport();
  //   }
  // });


Future<void> generateAndSendSalesReport() async {
  // Fetch the sales data (dummy data for now)
  List<Map<String, dynamic>> salesData = await fetchSalesData();

  // Generate the PDF
  SalesReportPdfGenerator pdfGenerator = SalesReportPdfGenerator();
  File pdfFile = await pdfGenerator.generatePdf(salesData);

  // Get the admin's email dynamically
  String adminEmail = await getAdminEmail();

  // Send the email with PDF attachment (use mailer for desktop)
  EmailService emailService = EmailService();
  await emailService.sendEmailWithAttachment(pdfFile, adminEmail);
}

Future<List<Map<String, dynamic>>> fetchSalesData() async {
  // Replace with actual data fetching logic
  return [
    {"medicine": "Medicine A", "quantity": 10, "amount": 100.0},
    {"medicine": "Medicine B", "quantity": 5, "amount": 50.0},
  ];
}

Future<String> getAdminEmail() async {
  // This could be a query to your database or some global variable
  // For now, just return a placeholder
  return 'admin@example.com'; // Replace with actual logic to get the admin email
}

class SalesReportPdfGenerator {
  Future<File> generatePdf(List<Map<String, dynamic>> salesData) async {
    final pdf = pw.Document();

    pdf.addPage(pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Sales Report', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Product', 'Quantity', 'Amount'],
              data: salesData.map((e) => [e['medicine'], e['remaining_quantity'], e['amount']]).toList(),
            ),
          ],
        );
      },
    ));

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/sales_report.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}

class EmailService {
  Future<void> sendEmailWithAttachment(File pdfFile, String adminEmail) async {
    // Use mailer for sending email (for Desktop support)
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE NOTIFICATION')// Replace with the sender email
      ..recipients.add(adminEmail)
      ..subject = 'Daily Sales Report'
      ..text = 'Please find the attached sales report.'
      ..attachments.add(FileAttachment(pdfFile));

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');
    } catch (e) {
      print('Error sending email: $e');
    }
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Sales Report Scheduler")),
        body: Center(
          child: Text("Sales Report is being sent daily automatically!"),
        ),
      ),
    );
  }
}
