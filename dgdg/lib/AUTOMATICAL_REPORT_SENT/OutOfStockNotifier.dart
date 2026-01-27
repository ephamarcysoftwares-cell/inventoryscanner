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

class OutOfStockNotifier {
  String address = '';
  String businessEmail = '';
  String businessLogoPath = '';
  String businessLocation = '';
  String businessName = '';
  String businessPhone = '';
  String lipaNumber = '';
  String whatsapp = '';
  Timer? _timer;

  final Map<String, String> tableDisplayNames = {
    'medicines': 'Normal Product',
    'other_product': 'Other Product',
  };

  void start() {
    print("📅 OutOfStockNotifier scheduler started (11:00 PM daily)");

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
    print("🛑 OutOfStockNotifier scheduler stopped.");
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
      return result.map((row) => row['email'].toString()).toList();
    } catch (e) {
      print("❌ Error fetching admin emails: $e");
      return [];
    }
  }

  Future<void> getBusinessInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('SELECT * FROM businesses LIMIT 1');
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

  int toIntSafe(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<List<Map<String, dynamic>>> getAvailableStock(String tableName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('SELECT * FROM $tableName WHERE remaining_quantity > 0');
    } catch (e) {
      print("❌ Error fetching available products from $tableName: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearExpiry(String tableName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final expiryLimit = now.add(Duration(days: 30)).toIso8601String();
      return await db.rawQuery(
          'SELECT * FROM $tableName WHERE expiry_date IS NOT NULL AND expiry_date <= ?',
          [expiryLimit]);
    } catch (e) {
      print("❌ Error fetching near-expiry products from $tableName: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getNearOutOfStock(String tableName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('''
        SELECT * FROM $tableName 
        WHERE total_quantity > 0 
          AND remaining_quantity <= (0.10 * total_quantity)
          AND remaining_quantity > 0
      ''');
    } catch (e) {
      print("❌ Error fetching near out-of-stock products from $tableName: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getOutOfStock(String tableName) async {
    try {
      final db = await DatabaseHelper.instance.database;
      return await db.rawQuery('SELECT * FROM $tableName WHERE remaining_quantity <= 0');
    } catch (e) {
      print("❌ Error fetching out-of-stock products from $tableName: $e");
      return [];
    }
  }

  Future<bool> _sendEmail({
    required String subject,
    required String text,
    required File attachment,
  }) async {
    if (businessName.isEmpty) await getBusinessInfo();
    final senderName =
    businessName.isNotEmpty ? businessName : '';

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

  Future<File> _generateStockReport(
      List<Map<String, dynamic>> data, String title, PdfColor color) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(now);

    pw.Widget logoWidget = pw.Container();
    if (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync()) {
      final image = pw.MemoryImage(File(businessLogoPath).readAsBytesSync());
      logoWidget = pw.Image(image, width: 100, height: 100);
    }

    const int rowsPerPage = 40;
    final headers = [
      'ID',
      'Name',
      'Company',
      'Qty',
      'Buy Price',
      'Sell Price',
      'Batch Number',
      'Unit',
      'Manufacture Date',
      'Expire Date',
      'Added By',
      'Date Added',
      'Advice'
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
                    pw.Text(businessName,
                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Email: $businessEmail"),
                    pw.Text("Phone: $businessPhone"),
                    pw.Text("Location: $businessLocation"),
                    pw.Text("Address: $address"),
                    pw.SizedBox(height: 30),
                    pw.Text(title,
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Generated on: $formattedDate"),
                    pw.SizedBox(height: 15),
                  ],
                ),
              ),
            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey700),
              headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: color),
              cellAlignment: pw.Alignment.center,
              headerHeight: 30,
              cellHeight: 30,
              cellStyle: pw.TextStyle(fontSize: 10),
              headers: headers,
              data: pageData.map((item) {
                return [
                  item['id']?.toString() ?? '',
                  item['name'] ?? item['medicine_name'] ?? '',
                  item['company'] ?? '',
                  item['remaining_quantity']?.toString() ?? '',
                  item['buy_price']?.toString() ?? '',
                  item['selling_price']?.toString() ?? '',
                  item['batch_number'] ?? '',
                  item['unit'] ?? '',
                  item['manufacture_date'] ?? '',
                  item['expiry_date'] ?? '',
                  item['added_by'] ?? '',
                  item['date_added'] ?? '',
                  item['advice'] ?? '',
                ];
              }).toList(),
            ),
          ],
        ),
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${title.replaceAll(" ", "_").toLowerCase()}_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(await pdf.save());
    print("✅ $title PDF generated at ${file.path}");
    return file;
  }

  // ===================== REPORT CHECK METHODS =====================
  Future<bool> checkAndSendAvailableStock({required String tableName}) async {
    final data = await getAvailableStock(tableName);
    if (data.isEmpty) return false;
    final pdfFile = await _generateStockReport(
        data, "Available Stock Report (${tableDisplayNames[tableName] ?? tableName})", PdfColors.teal800);
    return await _sendEmail(
        subject:
        'Available Stock Report (${tableDisplayNames[tableName] ?? tableName}) - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Attached is the available stock report for ${tableDisplayNames[tableName] ?? tableName}.',
        attachment: pdfFile);
  }

  Future<bool> checkAndSendNearExpiry({required String tableName}) async {
    final data = await getNearExpiry(tableName);
    if (data.isEmpty) return false;
    final pdfFile = await _generateStockReport(
        data, "Near Expiry Report (${tableDisplayNames[tableName] ?? tableName})", PdfColors.orange);
    return await _sendEmail(
        subject:
        '⚠️ Near Expiry Report (${tableDisplayNames[tableName] ?? tableName}) - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Attached is the near-expiry report for ${tableDisplayNames[tableName] ?? tableName}.',
        attachment: pdfFile);
  }

  Future<bool> checkAndSendNearOutOfStock({required String tableName}) async {
    final data = await getNearOutOfStock(tableName);
    if (data.isEmpty) return false;
    final pdfFile = await _generateStockReport(
        data, "Near Out of Stock Report (${tableDisplayNames[tableName] ?? tableName})", PdfColors.orangeAccent);
    return await _sendEmail(
        subject:
        '⚠️ Near Out of Stock Report (${tableDisplayNames[tableName] ?? tableName}) - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Attached is the near out-of-stock report for ${tableDisplayNames[tableName] ?? tableName}.',
        attachment: pdfFile);
  }

  Future<bool> checkAndSendOutOfStock({required String tableName}) async {
    final data = await getOutOfStock(tableName);
    if (data.isEmpty) return false;
    final pdfFile = await _generateStockReport(
        data, "Out of Stock Report (${tableDisplayNames[tableName] ?? tableName})", PdfColors.red900);
    return await _sendEmail(
        subject:
        'Out of Stock Report (${tableDisplayNames[tableName] ?? tableName}) - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Attached is the out-of-stock report for ${tableDisplayNames[tableName] ?? tableName}.',
        attachment: pdfFile);
  }

  Future<bool> checkAndSendMostlySoldProductsFromSales() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final last30Days = now.subtract(Duration(days: 30)).toIso8601String();

      final salesData = await db.rawQuery('''
      SELECT medicine_name, SUM(total_quantity) AS sold_quantity
      FROM sales
      WHERE confirmed_time >= ?
      GROUP BY medicine_name
      ORDER BY sold_quantity DESC
      LIMIT 20
    ''', [last30Days]);

      if (salesData.isEmpty) {
        print("No mostly sold products found in last 30 days.");
        return false;
      }

      List<Map<String, dynamic>> pdfData = [];
      String adviceText = '';

      for (var item in salesData) {
        final medicineName = item['medicine_name']?.toString() ?? '';
        final soldQty = toIntSafe(item['sold_quantity']);

        final medStock = await db.rawQuery(
          'SELECT remaining_quantity FROM medicines WHERE name = ?',
          [medicineName],
        );

        final otherStock = await db.rawQuery(
          'SELECT remaining_quantity FROM other_product WHERE name = ?',
          [medicineName],
        );

        int remaining = 0;
        if (medStock.isNotEmpty) remaining += toIntSafe(medStock[0]['remaining_quantity']);
        if (otherStock.isNotEmpty) remaining += toIntSafe(otherStock[0]['remaining_quantity']);

        String advice = remaining < 0.2 * soldQty ? "Restock Immediately" : "Monitor Stock";

        adviceText += "Product: $medicineName, Sold: $soldQty, Remaining: $remaining → $advice\n";

        pdfData.add({
          'id': 0,
          'name': medicineName,
          'company': '',
          'remaining_quantity': remaining,
          'buy_price': '',
          'selling_price': '',
          'batch_number': '',
          'unit': '',
          'manufacture_date': '',
          'expiry_date': '',
          'added_by': '',
          'date_added': '',
          'advice': advice,
        });
      }

      final pdfFile = await _generateStockReport(pdfData, "Mostly Sold Products Report (Last 30 Days)",
          PdfColors.purple900);

      return await _sendEmail(
          subject: 'Mostly Sold Products Report (Last 30 Days) - ${DateFormat('yyyy-MM-dd').format(now)}',
          text: 'Attached is the mostly sold products report from sales.\n\nAdvice:\n$adviceText',
          attachment: pdfFile);
    } catch (e) {
      print("❌ Error sending mostly sold products report: $e");
      return false;
    }
  }

  Future<void> sendAllReports() async {
    print("📤 Sending all stock reports...");
    await getBusinessInfo();

    for (String table in ['medicines', 'other_product']) {
      await checkAndSendOutOfStock(tableName: table);
      await checkAndSendNearOutOfStock(tableName: table);
      await checkAndSendAvailableStock(tableName: table);
      await checkAndSendNearExpiry(tableName: table);
    }

    await checkAndSendMostlySoldProductsFromSales();
  }

  Future<void> testSendAllReports() async {
    print("📤 Testing all reports manually...");
    await sendAllReports();
  }
}
