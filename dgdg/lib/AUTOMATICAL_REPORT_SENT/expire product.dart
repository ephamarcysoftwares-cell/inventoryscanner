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

class ExpiredMedicineNotifier {
  void start() {
    print("⏰ ExpiredMedicineNotifier started: check on app start and at 11:00 PM daily");

    // Run immediately when the app starts
    checkAndSendExpiredMedicines().then((sent) {
      final now = DateTime.now();
      if (sent) {
        print("✅ Expired report sent on app start at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
      } else {
        print("ℹ️ No expired medicines on app start at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
      }
    });

    // Timer to check every minute for 11:00 PM
    Timer.periodic(Duration(minutes: 1), (Timer timer) async {
      final now = DateTime.now();
      final currentHour = now.hour;
      final currentMinute = now.minute;

      if (currentHour == 23 && currentMinute == 0) { // 23:00 = 11:00 PM
        final sent = await checkAndSendExpiredMedicines();
        if (sent) {
          print("✅ Expired report sent at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
        } else {
          print("ℹ️ No expired medicines at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
        }
      }
    });
  }



  Future<bool> checkAndSendExpiredMedicines() async {
    final expiredMedicines = await getExpiredMedicines();
    if (expiredMedicines.isEmpty) {
      print("ℹ️ No expired medicines found.");
      return false;
    }

    final pdfFile = await generateExpiredMedicineReport(expiredMedicines);

    final adminEmails = await getAllAdminEmails();
    if (adminEmails.isEmpty) {
      print("❌ No admin emails found.");
      return false;
    }

    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('SELECT * FROM businesses');
    final business = result.isNotEmpty ? result[0] : {};

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    final message = Message()
      ..from = Address(
          'suport@ephamarcysoftware.co.tz',
          business['business_name']?.toString().trim().isNotEmpty == true
              ? business['business_name']
              : 'STOCK & INVENTORY NOTIFICATION SYSTEM'
      )
      ..recipients.addAll(adminEmails)
      ..subject = '🛑 Expired Product Report - $formattedDate'
      ..text = 'Attached is the expired product report.'
      ..attachments = [FileAttachment(pdfFile)];

    try {
      await send(message, smtpServer);
      print("✅ Expired Product report email sent to admins.");
      return true;
    } catch (e) {
      print("❌ Error sending expired product report: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getExpiredMedicines() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final result = await db.rawQuery(
        'SELECT * FROM medicines WHERE expiry_date <= ?',
        [today],
      );
      return result;
    } catch (e) {
      print("❌ Error fetching expired medicines: $e");
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

  Future<File> generateExpiredMedicineReport(List<Map<String, dynamic>> expiredMedicines) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);

    final db = await DatabaseHelper.instance.database;
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    logoWidget,
                    pw.SizedBox(height: 10),
                    pw.Text(business['business_name'] ?? '',
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Email: ${business['email'] ?? ''}"),
                    pw.Text("Phone: ${business['phone'] ?? ''}"),
                    pw.Text("Location: ${business['location'] ?? ''}"),
                    pw.Text("Address: ${business['address'] ?? ''}"),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text("🛑 Expired Medicines",
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Generated on: $formattedDate"),
              pw.SizedBox(height: 15),
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey700),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: PdfColors.redAccent),
                cellAlignment: pw.Alignment.center,
                headerHeight: 30,
                cellHeight: 30,
                cellStyle: pw.TextStyle(fontSize: 10),
                headers: [
                  'ID', 'Name', 'Company', 'Qty', 'Buy Price', 'Sell Price',
                  'Batch Number', 'Unit', 'Manufacture Date', 'Expire Date',
                  'Added By', 'Added Time'
                ],
                data: expiredMedicines.map((item) {
                  return [
                    item['id'].toString(),
                    item['name'] ?? '',
                    item['company'] ?? '',
                    item['remaining_quantity'].toString(),
                    item['buy'].toString(),
                    item['price'].toString(),
                    item['batchNumber'] ?? '',
                    item['unit'] ?? '',
                    item['manufacture_date'] ?? '',
                    item['expiry_date'] ?? '',
                    item['added_by'] ?? '',
                    item['added_time'] ?? '',
                  ];
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/expired_product_report.pdf');
    await file.writeAsBytes(await pdf.save());
    print("✅ Expired PDF report generated at ${file.path}");
    return file;
  }
}
