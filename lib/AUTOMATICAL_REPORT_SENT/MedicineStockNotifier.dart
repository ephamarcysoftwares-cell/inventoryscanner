import 'dart:async';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../DB/database_helper.dart';

class MedicineStockNotifier {
  void start() {
    print("📦 Product StockNotifier started: check on app start and at 11:00 PM daily");

    // Run immediately on app start
    checkAndSendMedicineStock().then((sent) {
      final now = DateTime.now();
      if (sent) {
        print("✅ Stock report sent on app start at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
      } else {
        print("ℹ️ No new products found on app start at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
      }
    });

    // Timer to check every minute for 11:00 PM
    Timer.periodic(Duration(minutes: 1), (Timer timer) async {
      final now = DateTime.now();
      if (now.hour == 23 && now.minute == 0) {  // 23:00 = 11:00 PM
        final sent = await checkAndSendMedicineStock();
        if (sent) {
          print("✅ Stock report sent at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
        } else {
          print("ℹ️ No new products found at ${DateFormat('yyyy-MM-dd HH:mm').format(now)}");
        }
      }
    });
  }



  Future<bool> checkAndSendMedicineStock() async {
    final stockedMedicines = await getNewlyStockedMedicines();
    if (stockedMedicines.isEmpty) {
      return false;
    }

    final business = await getBusinessInfo();
    final adminEmails = await getAllAdminEmails();

    if (adminEmails.isEmpty) {
      print("❌ No admin emails found.");
      return false;
    }

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(now);
    final emailBody = _buildEmailBody(stockedMedicines, business, formattedDate);

    final senderName = (business['business_name']?.toString().isNotEmpty ?? false)
        ? business['business_name'].toString()
        : 'STOCK & INVENTORY NOTIFICATION STOCK';

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', senderName)
      ..recipients.addAll(adminEmails)
      ..subject = '📦 New Product Stock Report - $formattedDate'
      ..html = emailBody;

    try {
      await send(message, smtpServer);
      print("✅ Stock report sent to admins: $adminEmails");
      return true;
    } catch (e) {
      print("❌ Error sending stock report: $e");
      return false;
    }
  }



  String _buildEmailBody(List<Map<String, dynamic>> medicines, Map<String, dynamic> business, String date) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln("<h2>${business['business_name'] ?? 'Pharmacy Business'}</h2>");
    buffer.writeln("<p>Email: ${business['email'] ?? ''} | Phone: ${business['phone'] ?? ''}</p>");
    buffer.writeln("<p>Location: ${business['location'] ?? ''} | Address: ${business['address'] ?? ''}</p>");
    buffer.writeln("<hr>");
    buffer.writeln("<h3>📄 New Product Stock Report - $date</h3>");
    buffer.writeln("<table border='1' cellspacing='0' cellpadding='5'>");
    buffer.writeln("<tr style='background-color: #4CAF50; color: white;'>"
        "<th>ID</th><th>Name</th><th>Company</th><th>Qty</th><th>Buy Price</th><th>Sell Price</th>"
        "<th>Batch No</th><th>Unit</th><th>Manufacture Date</th><th>Expiry Date</th>"
        "<th>Added By</th><th>Added Time</th></tr>");

    for (var item in medicines) {
      buffer.writeln("<tr>"
          "<td>${item['id']}</td>"
          "<td>${item['name']}</td>"
          "<td>${item['company']}</td>"
          "<td>${item['remaining_quantity']}</td>"
          "<td>${item['buy']}</td>"
          "<td>${item['price']}</td>"
          "<td>${item['batchNumber']}</td>"
          "<td>${item['unit']}</td>"
          "<td>${item['manufacture_date']}</td>"
          "<td>${item['expiry_date']}</td>"
          "<td>${item['added_by']}</td>"
          "<td>${item['added_time']}</td>"
          "</tr>");
    }

    buffer.writeln("</table>");
    return buffer.toString();
  }

  Future<List<Map<String, dynamic>>> getNewlyStockedMedicines() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final twoMinutesAgo = DateTime.now().subtract(Duration(minutes: 2));
      final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(twoMinutesAgo);

      final result = await db.rawQuery('''
        SELECT * FROM medicines 
        WHERE added_time >= ?
      ''', [formattedTime]);

      return result;
    } catch (e) {
      print("❌ Error fetching medicines: $e");
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

      if (result.isNotEmpty) {
        return result.map((row) => row['email'].toString()).toList();
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching admin emails: $e");
      return [];
    }
  }


  Future<Map<String, dynamic>> getBusinessInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.rawQuery('SELECT * FROM businesses LIMIT 1');
      return result.isNotEmpty ? result.first : {};
    } catch (e) {
      print("❌ Error fetching business info: $e");
      return {};
    }
  }
}
