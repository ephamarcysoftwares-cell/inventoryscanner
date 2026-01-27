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

class WeeklyReportScheduler {
  void start() {
    print("🕐 WeeklyReportScheduler started (runs every minute to check Friday 22:00)");

    Timer.periodic(Duration(minutes: 1), (timer) async {
      final now = DateTime.now();

      if (now.weekday == DateTime.friday && now.hour == 22 && now.minute < 5) {
        print("📤 Triggering weekly report...");
        final success = await _sendWeeklyReport();
        print(success ? "✅ Weekly report sent" : "❌ Failed to send weekly report");
      }
    });
  }

  Future<bool> _sendWeeklyReport() async {
    try {
      final sales = await getWeeklySales();
      if (sales.isEmpty) {
        print("⚠️ No weekly sales data found.");
        return false;
      }

      final pdfFile = await generateWeeklyReport(sales);
      final adminEmails = await getAdminEmails();
      final adminPhones = await getAdminPhones(); // 📱 Now fetching normalized phone numbers

      if (adminEmails.isEmpty) {
        print("❌ No admin emails found.");
        return false;
      }

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

      final weekRange = getWeekRange(DateTime.now());

      final message = Message()
        ..from = Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.addAll(adminEmails)
        ..subject = '📊 Weekly Sales Summary Report ($weekRange)'
        ..text = 'Attached is the weekly sales summary report.'
        ..attachments = [FileAttachment(pdfFile)];

      await send(message, smtpServer);

      print("📧 Weekly report sent to: $adminEmails");
      print("📱 Admin phones for SMS notification: $adminPhones");

      // Here you could call your SMS sending function using adminPhones

      return true;
    } catch (e) {
      print("❌ Error sending weekly report: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getWeeklySales() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
      final endOfWeek = startOfWeek.add(Duration(days: 4)); // Friday

      final startStr = DateFormat('yyyy-MM-dd').format(startOfWeek);
      final endStr = DateFormat('yyyy-MM-dd').format(endOfWeek);

      final result = await db.rawQuery('''
        SELECT confirmed_by, SUM(total_price) AS total_sales
        FROM sales
        WHERE DATE(confirmed_time) BETWEEN ? AND ?
        GROUP BY confirmed_by
      ''', [startStr, endStr]);

      return result;
    } catch (e) {
      print("❌ Error fetching weekly sales data: $e");
      return [];
    }
  }

  Future<List<String>> getAdminEmails() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'users',
        columns: ['email'],
        where: 'role = ?',
        whereArgs: ['admin'],
      );

      return result
          .map((row) => row['email']?.toString().trim() ?? '')
          .where((email) => email.isNotEmpty)
          .toList();
    } catch (e) {
      print("❌ Error fetching admin emails: $e");
      return [];
    }
  }

  /// 📱 New function to get admin phones and normalize to +255 format
  Future<List<String>> getAdminPhones() async {
    try {
      final db = await DatabaseHelper.instance.database;

      final result = await db.query(
        'users',
        columns: ['phone'],
        where: 'role = ?',
        whereArgs: ['admin'],
      );

      return result
          .map((row) {
        String phone = row['phone']?.toString().trim() ?? '';
        if (phone.isEmpty) return '';
        if (!phone.startsWith('+255')) {
          phone = phone.replaceFirst(RegExp(r'^0+'), '');
          phone = '+255$phone';
        }
        return phone;
      })
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (e) {
      print("❌ Error fetching admin phones: $e");
      return [];
    }
  }

  Future<File> generateWeeklyReport(List<Map<String, dynamic>> sales) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final weekRange = getWeekRange(now);

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
              pw.Text("WEEKLY SALES SUMMARY REPORT",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Week: $weekRange"),
              pw.Text("Generated on: ${DateFormat('yyyy-MM-dd – HH:mm').format(now)}"),
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
    final file = File('${dir.path}/weekly_sales_report.pdf');
    await file.writeAsBytes(await pdf.save());

    print("📄 Weekly PDF generated at: ${file.path}");
    return file;
  }

  String getWeekRange(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1)); // Monday
    final end = start.add(Duration(days: 4)); // Friday
    final formatter = DateFormat('dd MMM yyyy');
    return "${formatter.format(start)} - ${formatter.format(end)}";
  }
}
