import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import '../DB/database_helper.dart';

class OutOfStockOtherProductNotifier {
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';
  Timer? _timer;

  void start() {
    print("📅 OutOfStockNotifier scheduler started (11:00 PM daily)");
    getBusinessInfo();

    void scheduleNextCheck() {
      final now = DateTime.now();

      // Schedule only for 11:00 PM
      DateTime nextTime = DateTime(now.year, now.month, now.day, 23, 0);
      if (nextTime.isBefore(now)) {
        // If 11:00 PM today already passed, schedule for tomorrow
        nextTime = nextTime.add(Duration(days: 1));
      }

      Duration delay = nextTime.difference(now);
      _timer = Timer(delay, () async {
        await sendAllReports();
        scheduleNextCheck(); // Schedule for the next day
      });
    }

    scheduleNextCheck();
  }


  void stop() {
    _timer?.cancel();
    print("🛑 OutOfStockNotifier scheduler stopped.");
  }

  Future<void> getBusinessInfo() async {
    try {
      Database db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        businessName = result[0]['business_name']?.toString() ?? '';
        businessEmail = result[0]['email']?.toString() ?? '';
        businessPhone = result[0]['phone']?.toString() ?? '';
        businessLocation = result[0]['location']?.toString() ?? '';
        businessLogoPath = result[0]['logo']?.toString() ?? '';
        address = result[0]['address']?.toString() ?? '';
        whatsapp = result[0]['whatsapp']?.toString() ?? '';
        lipaNumber = result[0]['lipa_number']?.toString() ?? '';
      }
    } catch (e) {
      print('❌ Error loading business info: $e');
    }
  }

  Future<void> sendAllReports() async {
    print("📤 Sending all stock reports...");
    await getBusinessInfo();

    final outOfStockSent = await checkAndSendOutOfStock();
    if (outOfStockSent) print("✅ Out-of-stock report sent.");

    final nearOutOfStockSent = await checkAndSendNearOutOfStock();
    if (nearOutOfStockSent) print("✅ Near out-of-stock report sent.");

    final availableStockSent = await checkAndSendAvailableStock();
    if (availableStockSent) print("✅ Available stock report sent.");
  }

  Future<bool> checkAndSendOutOfStock() async {
    final outOfStock = await getOutOfStockMedicines();
    if (outOfStock.isEmpty) {
      print("No out-of-stock medicines found.");
      return false;
    }

    final pdfFile = await generateOutOfStockReport(outOfStock);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: 'Out of Stock Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the out-of-stock medicine report.',
      attachment: pdfFile,
    );
  }

  Future<bool> checkAndSendAvailableStock() async {
    final availableStock = await getAvailableMedicines();
    if (availableStock.isEmpty) {
      print("No available medicines found.");
      return false;
    }

    final pdfFile = await generateAvailableStockReport(availableStock);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: 'Available Stock Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the available stock prduct .',
      attachment: pdfFile,
    );
  }

  Future<bool> checkAndSendNearOutOfStock() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT * FROM medicines 
      WHERE total_quantity > 0 
        AND remaining_quantity <= (0.10 * total_quantity)
        AND remaining_quantity > 0
    ''');

    if (result.isEmpty) {
      print("No near out-of-stock medicines found.");
      return false;
    }

    final pdfFile = await _generateStockReport(result, "Near Out of Stock Report", PdfColors.orangeAccent);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: '⚠️ Near Out of Stock Report - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the near out-of-stock product.',
      attachment: pdfFile,
    );
  }

  Future<bool> _sendEmail({
    required String subject,
    required String text,
    required File attachment,
  }) async {
    final senderName = businessName.isNotEmpty ? businessName : 'STOCK&INVENTORY SOFTWARE NOTIFICATION';

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', senderName)
      ..recipients.addAll(adminEmails)
      ..subject = subject
      ..text = text
      ..attachments = [FileAttachment(attachment)];

    try {
      await send(message, smtpServer);
      print("📧 Email sent: $subject");
      return true;
    } catch (e) {
      print("❌ Error sending email: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getOutOfStockMedicines() async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('SELECT * FROM other_product WHERE remaining_quantity <= 0');
    } catch (e) {
      print("❌ Error fetching out-of-stock procduct");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableMedicines() async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('SELECT * FROM  other_product WHERE remaining_quantity > 0');
    } catch (e) {
      print("❌ Error fetching available medicines: $e");
      return [];
    }
  }

  Future<List<String>> getAdminEmails() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query('users', columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
      return result.map((row) => row['email'].toString()).toList();
    } catch (e) {
      print("❌ Error fetching admin emails: $e");
      return [];
    }
  }

  Future<File> generateOutOfStockReport(List<Map<String, dynamic>> data) async {
    return await _generateStockReport(data, "Out of Stock Report", PdfColors.red900);
  }

  Future<File> generateAvailableStockReport(List<Map<String, dynamic>> data) async {
    return await _generateStockReport(data, "Available Stock Report", PdfColors.teal800);
  }

  Future<File> _generateStockReport(List<Map<String, dynamic>> data, String title, PdfColor color) async {
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

    const int rowsPerPage = 40;
    final headers = [
      'ID', 'Name', 'Company', 'Qty', 'Buy Price', 'Sell Price',
      'Batch Number', 'Unit', 'Manufacture Date', 'Expire Date',
      'Added By', 'Added Time'
    ];

    for (int i = 0; i < data.length; i += rowsPerPage) {
      final pageData = data.skip(i).take(rowsPerPage).toList();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (context) => [
            if (i == 0)
              pw.Center(
                child: pw.Column(
                  children: [
                    logoWidget,
                    pw.SizedBox(height: 10),
                    pw.Text(business['business_name'] ?? '', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Email: ${business['email'] ?? ''}"),
                    pw.Text("Phone: ${business['phone'] ?? ''}"),
                    pw.Text("Location: ${business['location'] ?? ''}"),
                    pw.Text("Address: ${business['address'] ?? ''}"),
                    pw.SizedBox(height: 30),
                    pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated on: $formattedDate"),
                    pw.SizedBox(height: 15),
                  ],
                ),
              ),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey700),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: color),
              cellAlignment: pw.Alignment.center,
              headerHeight: 30,
              cellHeight: 30,
              cellStyle: pw.TextStyle(fontSize: 10),
              headers: headers,
              data: pageData.map((item) {
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
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename = '${title.replaceAll(" ", "_").toLowerCase()}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    print("✅ $title PDF generated at ${file.path}");
    return file;
  }

  /// Manual test method
  Future<void> testSendAllReports() async {
    print("📤 Testing all reports manually...");
    await sendAllReports();
  }
}
