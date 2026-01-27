import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';

import '../DB/database_helper.dart';

class YearlyReportScheduler {
  void start() {
    print("YearlyReportScheduler started (runs on December 31st at 21:00)");

    Timer.periodic(Duration(hours: 1), (timer) async {
      final now = DateTime.now();

      // Check if it's December 31st at 21:00 (within first 5 minutes)
      if (now.month == 12 && now.day == 31 && now.hour == 21 && now.minute < 5) {
        print("Triggering yearly report...");
        final success = await _sendYearlyReport();
        print(success ? "Yearly report sent successfully" : "Failed to send yearly report");
      }
    });
  }

  Future<bool> _sendYearlyReport() async {
    try {
      final sales = await getYearlySales();
      final pdfFile = await generateYearlyReport(sales);
      final adminEmails = await getAdminEmails();

      if (adminEmails.isEmpty) {
        print("No admin emails found");
        return false;
      }

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', 'STOCK&INVENTORY SOFTWARE NOTIFICATION')
        ..recipients.addAll(adminEmails)
        ..subject = 'Yearly Sales Summary Report'
        ..text = 'Please find attached the yearly sales summary report.'
        ..attachments = [FileAttachment(pdfFile)];

      await send(message, smtpServer);
      return true;
    } catch (e) {
      print("Error sending yearly report: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getYearlySales() async {
    final db = await DatabaseHelper.instance.database;
    final year = DateTime.now().year;

    final startStr = '$year-01-01';
    final endStr = '$year-12-31';

    try {
      final result = await db.rawQuery('''
        SELECT confirmed_by, SUM(total_price) AS total_sales
        FROM sales
        WHERE DATE(confirmed_time) BETWEEN ? AND ?
        GROUP BY confirmed_by
      ''', [startStr, endStr]);

      return result;
    } catch (e) {
      print("Error fetching yearly sales data: $e");
      return [];
    }
  }

  Future<List<String>> getAdminEmails() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query(
      'users',
      columns: ['email'],
      where: 'role = ?',
      whereArgs: ['admin'],
    );

    return result
        .map((row) => row['email']?.toString() ?? '')
        .where((email) => email.isNotEmpty)
        .toList();
  }

  Future<File> generateYearlyReport(List<Map<String, dynamic>> sales) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final yearLabel = DateFormat('yyyy').format(now);

    final db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
    final businessData = await db.rawQuery('SELECT * FROM businesses');

    String businessName = '', businessEmail = '', businessPhone = '', businessLocation = '', businessLogoPath = '', address = '';

    if (businessData.isNotEmpty) {
      final b = businessData[0];
      businessName = b['business_name']?.toString() ?? '';
      businessEmail = b['email']?.toString() ?? '';
      businessPhone = b['phone']?.toString() ?? '';
      businessLocation = b['location']?.toString() ?? '';
      businessLogoPath = b['logo']?.toString() ?? '';
      address = b['address']?.toString() ?? '';
    }

    pw.Widget logoWidget = pw.Container();
    if (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync()) {
      final image = pw.MemoryImage(File(businessLogoPath).readAsBytesSync());
      logoWidget = pw.Image(image, width: 100, height: 100);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            logoWidget,
            pw.SizedBox(height: 10),
            pw.Text(businessName,
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text("Email: $businessEmail"),
            pw.Text("Phone: $businessPhone"),
            pw.Text("Location: $businessLocation"),
            pw.Text("Address: $address"),
            pw.SizedBox(height: 20),
            pw.Text("YEARLY SALES SUMMARY REPORT",
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.Text("Year: $yearLabel"),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headers: ["Staff Name", "Total Sales (TZS)"],
              data: sales.map((sale) {
                return [
                  sale['confirmed_by'] ?? 'Unknown',
                  "TZS ${NumberFormat('#,##0.00', 'en_US').format(sale['total_sales'] ?? 0)}"
                ];
              }).toList(),
            ),

          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/yearly_sales_report_$yearLabel.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }
}
