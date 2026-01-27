import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../DB/database_helper.dart';

class OtherProductNotifier {
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  Timer? _timer;

  void start() {
    print("📅 OtherProductNotifier scheduler started (11:00 PM daily)");
    getBusinessInfo();

    void scheduleNextCheck() {
      final now = DateTime.now();
      DateTime nextTime = DateTime(now.year, now.month, now.day, 23, 0);
      if (nextTime.isBefore(now)) nextTime = nextTime.add(Duration(days: 1));

      Duration delay = nextTime.difference(now);
      _timer = Timer(delay, () async {
        await sendAllReports();
        scheduleNextCheck();
      });
    }

    scheduleNextCheck();
  }

  void stop() {
    _timer?.cancel();
    print("🛑 OtherProductNotifier scheduler stopped.");
  }

  Future<void> getBusinessInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        businessName = result[0]['business_name']?.toString() ?? '';
        businessEmail = result[0]['email']?.toString() ?? '';
        businessPhone = result[0]['phone']?.toString() ?? '';
        businessLocation = result[0]['location']?.toString() ?? '';
        businessLogoPath = result[0]['logo']?.toString() ?? '';
      }
    } catch (e) {
      print('❌ Error loading business info: $e');
    }
  }

  Future<void> sendAllReports() async {
    print("📤 Sending all other product reports...");
    await getBusinessInfo();

    final outOfStockSent = await checkAndSendOutOfStock();
    if (outOfStockSent) print("✅ Other product out-of-stock report sent.");

    final nearOutOfStockSent = await checkAndSendNearOutOfStock();
    if (nearOutOfStockSent) print("✅ Other product near out-of-stock report sent.");

    final availableStockSent = await checkAndSendAvailableStock();
    if (availableStockSent) print("✅ Other product available stock report sent.");
  }

  Future<bool> checkAndSendOutOfStock() async {
    final outOfStock = await getOutOfStockProducts();
    if (outOfStock.isEmpty) return false;

    final pdfFile = await generateReport(outOfStock, "Other Product Out of Stock Report", PdfColors.red900);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: 'Other Product Out of Stock - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the out-of-stock other product report.',
      attachment: pdfFile,
    );
  }

  Future<bool> checkAndSendAvailableStock() async {
    final available = await getAvailableProducts();
    if (available.isEmpty) return false;

    final pdfFile = await generateReport(available, "Other Product Available Stock Report", PdfColors.teal800);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: 'Other Product Available Stock - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the available other product report.',
      attachment: pdfFile,
    );
  }

  Future<bool> checkAndSendNearOutOfStock() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT * FROM other_product
      WHERE total_quantity > 0
        AND remaining_quantity <= (0.10 * total_quantity)
        AND remaining_quantity > 0
    ''');
    if (result.isEmpty) return false;

    final pdfFile = await generateReport(result, "Other Product Near Out of Stock Report", PdfColors.orangeAccent);
    final adminEmails = await getAdminEmails();
    if (adminEmails.isEmpty) return false;

    return await _sendEmail(
      subject: '⚠️ Other Product Near Out of Stock - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      text: 'Attached is the near out-of-stock other product report.',
      attachment: pdfFile,
    );
  }

  Future<List<Map<String, dynamic>>> getOutOfStockProducts() async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('SELECT * FROM other_product WHERE remaining_quantity <= 0');
  }

  Future<List<Map<String, dynamic>>> getAvailableProducts() async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('SELECT * FROM other_product WHERE remaining_quantity > 0');
  }

  Future<List<String>> getAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
    return result.map((row) => row['email'].toString()).toList();
  }

  Future<File> generateReport(List<Map<String, dynamic>> data, String title, PdfColor color) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);

    pw.Widget logoWidget = pw.Container();
    if (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync()) {
      final image = pw.MemoryImage(File(businessLogoPath).readAsBytesSync());
      logoWidget = pw.Image(image, width: 100, height: 100);
    }

    const headers = [
      'ID', 'Name', 'Company', 'Qty', 'Buy Price', 'Selling Price',
      'Batch', 'Unit', 'Manufacture Date', 'Expiry Date', 'Added By', 'Date Added'
    ];

    const int rowsPerPage = 40;
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
                    pw.Text(businessName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Email: $businessEmail"),
                    pw.Text("Phone: $businessPhone"),
                    pw.Text("Location: $businessLocation"),
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
                  item['buy_price'].toString(),
                  item['selling_price'].toString(),
                  item['batch_number'] ?? '',
                  item['unit'] ?? '',
                  item['manufacture_date'] ?? '',
                  item['expiry_date'] ?? '',
                  item['added_by'] ?? '',
                  item['date_added'] ?? '',
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
}
