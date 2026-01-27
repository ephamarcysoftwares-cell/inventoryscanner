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

class MonthlyReportScheduler {
  void start() {
    print("🕐 MonthlyReportScheduler running every hour to check if it's the last day of the month at 21:00");

    Timer.periodic(Duration(hours: 1), (timer) async {
      final now = DateTime.now();
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;

      if (now.day == lastDayOfMonth && now.hour == 21 && now.minute < 5) {
        print("📤 Triggering monthly report...");
        final success = await _sendMonthlyReport();
        print(success ? "✅ Monthly report sent successfully" : "❌ Failed to send monthly report");
      }
    });
  }

  Future<bool> _sendMonthlyReport() async {
    try {
      final sales = await getMonthlySales();
      if (sales.isEmpty) {
        print("⚠️ No sales found for this month.");
        return false;
      }

      final pdfFile = await generateMonthlyReport(sales);
      final adminEmails = await getAllAdminEmails();

      if (adminEmails.isEmpty) {
        print("❌ No admin emails found");
        return false;
      }

      // Fetch business name for email sender
      final db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
      final businessResult = await db.rawQuery('SELECT business_name FROM businesses LIMIT 1');
      final businessName = (businessResult.isNotEmpty &&
          (businessResult[0]['business_name']?.toString().trim().isNotEmpty ?? false))
          ? businessResult[0]['business_name'].toString().trim()
          : 'STOCK&INVENTORY SOFTWARE NOTIFICATION';

      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465,
        ssl: true,
      );

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.addAll(adminEmails)
        ..subject = '📊 Monthly Sales Summary Report - ${DateFormat('MMMM yyyy').format(DateTime.now())}'
        ..text = 'Attached is the monthly sales summary report.'
        ..attachments = [FileAttachment(pdfFile)];

      await send(message, smtpServer);
      print("📧 Monthly report sent to: $adminEmails");
      return true;
    } catch (e) {
      print("❌ Error sending monthly report: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getMonthlySales() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);

      final result = await db.rawQuery('''
        SELECT confirmed_by, SUM(total_price) AS total_sales
        FROM sales
        WHERE DATE(confirmed_time) BETWEEN ? AND ?
        GROUP BY confirmed_by
      ''', [
        DateFormat('yyyy-MM-dd').format(firstDay),
        DateFormat('yyyy-MM-dd').format(lastDay),
      ]);

      return result;
    } catch (e) {
      print("❌ Error fetching monthly sales: $e");
      return [];
    }
  }

  Future<List<String>> getAllAdminEmails() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'users',
        columns: ['email'],
        where: 'role = ?',
        whereArgs: ['admin'],
      );

      return result.map((row) => row['email'].toString()).toList();
    } catch (e) {
      print("❌ Error fetching admin emails: $e");
      return [];
    }
  }

  Future<File> generateMonthlyReport(List<Map<String, dynamic>> sales) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);
    final monthLabel = DateFormat('MMMM yyyy').format(now);

    final db = await openDatabase('C:\\Users\\Public\\epharmacy\\epharmacy.db');
    final result = await db.rawQuery('SELECT * FROM businesses');
    final business = result.isNotEmpty ? result[0] : {};

    final logoPath = business['logo']?.toString() ?? '';
    pw.Widget logoWidget = pw.Container();

    if (logoPath.isNotEmpty && File(logoPath).existsSync()) {
      final image = pw.MemoryImage(File(logoPath).readAsBytesSync());
      logoWidget = pw.Image(image, width: 100, height: 100);
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              logoWidget,
              pw.SizedBox(height: 10),
              pw.Text(business['business_name'] ?? '',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text("Email: ${business['email'] ?? ''}"),
              pw.Text("Phone: ${business['phone'] ?? ''}"),
              pw.Text("Location: ${business['location'] ?? ''}"),
              pw.Text("Address: ${business['address'] ?? ''}"),
              pw.SizedBox(height: 20),
              pw.Text("MONTHLY SALES SUMMARY REPORT",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Month: $monthLabel"),
              pw.Text("Generated on: $formattedDate"),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey),
                cellAlignment: pw.Alignment.center,
                headerHeight: 30,
                cellHeight: 30,
                cellStyle: pw.TextStyle(fontSize: 10),
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
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/monthly_sales_report.pdf');
    await file.writeAsBytes(await pdf.save());

    print("📄 Monthly PDF generated at: ${file.path}");
    return file;
  }
}
