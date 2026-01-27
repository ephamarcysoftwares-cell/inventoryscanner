import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

import '../DB/database_helper.dart';

// ===================== SMS CONFIG =====================
const String SERVER = "https://app.sms-gateway.app";
const String API_KEY = "c675459f5f54525139aa4ce184322393a1a7b83f";

// ===================== SMS FUNCTIONS =====================
Future<Map<String, dynamic>> sendSingleMessage(
    String number,
    String message, {
      int device = 0,
      int? schedule,
      bool isMMS = false,
      String? attachments,
      bool prioritize = false,
    }) async {
  String url = "$SERVER/services/send.php";
  var postData = {
    'number': number,
    'message': message,
    'schedule': schedule,
    'key': API_KEY,
    'devices': device,
    'type': isMMS ? "mms" : "sms",
    'attachments': attachments,
    'prioritize': prioritize ? 1 : 0,
  };
  var response = await sendRequest(url, postData);
  return response["messages"][0];
}

Future<Map<String, dynamic>> sendRequest(
    String url, Map<String, dynamic> postData) async {
  postData.removeWhere((key, value) => value == null);
  var res = await http.post(
    Uri.parse(url),
    body: postData.map((key, value) => MapEntry(key, value.toString())),
  );
  if (res.statusCode == 200) {
    var jsonResponse = json.decode(res.body);
    if (jsonResponse == false || jsonResponse == null) {
      throw Exception(res.body.isEmpty ? "Missing required data" : res.body.toString());
    } else {
      if (jsonResponse["success"] == true) {
        return jsonResponse["data"];
      } else {
        throw Exception(jsonResponse["error"]["message"]);
      }
    }
  } else {
    throw Exception("HTTP Error Code: ${res.statusCode}");
  }
}

// ===================== DAILY REPORT SCHEDULER =====================
class DailySummaryReportScheduler {
  void start() {
    print("DailySummaryReportScheduler started (sends at 23:00 and 23:30)");

    void scheduleNextReport() {
      final now = DateTime.now();
      final today23 = DateTime(now.year, now.month, now.day, 23, 0);
      final today2330 = DateTime(now.year, now.month, now.day, 23, 30);
      final tomorrow2330 = today2330.add(Duration(days: 1));

      DateTime nextReportTime;
      if (now.isBefore(today23)) {
        nextReportTime = today23;
      } else if (now.isBefore(today2330)) {
        nextReportTime = today2330;
      } else {
        nextReportTime = tomorrow2330;
      }

      Duration timeToNextReport = nextReportTime.difference(now);

      Timer(timeToNextReport, () async {
        try {
          final now = DateTime.now();
          print('Triggering daily summary report at: ${now.hour}:${now.minute}');
          await _sendDailyReport();
          scheduleNextReport(); // schedule next
        } catch (e) {
          print("Error in scheduler: $e");
        }
      });
    }

    scheduleNextReport();
  }

  Future<bool> _sendDailyReport() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Fetch business info
      final businessResult = await db.query('businesses', limit: 1);
      String businessName = businessResult.isNotEmpty
          ? businessResult[0]['business_name']?.toString() ?? 'STOCK&INVENTORY SOFTWARE'
          : 'STOCK&INVENTORY SOFTWARE';

      // Fetch today's and yesterday's summary
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterday = now.subtract(Duration(days: 1));
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

      double salesToday = await _getTotalSales(todayStr);
      double salesYesterday = await _getTotalSales(yesterdayStr);

      double debtPaidToday = await _getTotalDebtPaid(todayStr);
      double debtPaidYesterday = await _getTotalDebtPaid(yesterdayStr);

      double diff = (salesToday + debtPaidToday) - (salesYesterday + debtPaidYesterday);
      double diffAbs = diff.abs();
      String change = diff > 0 ? "kuongezeka" : (diff < 0 ? "kupungua" : "kutosha tofauti");

      String extraMessage;
      if (diff > 0) {
        extraMessage = "Hongera sana! Endelea kufanya vizuri zaidi 💪😊.";
      } else if (diff < 0) {
        extraMessage = "Yamepungua kidogo 😟. Jaribu kujali wateja zaidi na tafuta mbinu mpya za kuwavutia kurudi.";
      } else {
        extraMessage = "Hakuna tofauti kubwa, endelea kudumisha huduma bora 💯.";
      }

      final currencyFormat = NumberFormat('#,##0.00', 'en_US');
      String message = "Habari kutoka $businessName 😊,\n"
          "Mauzo yako ya $todayStr ni TZS ${currencyFormat.format(salesToday)}, "
          "Madeni yaliyolipwa ni TZS ${currencyFormat.format(debtPaidToday)},\n"
          "ukilinganisha na $yesterdayStr ambapo mauzo yalikuwa TZS ${currencyFormat.format(salesYesterday)} "
          "na Madeni yaliyolipwa TZS ${currencyFormat.format(debtPaidYesterday)}.\n"
          "Jumla yame$change kwa TZS ${currencyFormat.format(diffAbs)}.\n"
          "$extraMessage\n"
          "Ahsante kwa kuchagua $businessName.";

      // Send SMS
      final adminPhones = await getAdminPhones();
      for (var phone in adminPhones) {
        try {
          await sendSingleMessage(phone, message);
          print("📱 SMS sent to $phone");
        } catch (e) {
          print("❌ SMS failed to $phone: $e");
        }
      }

      // Generate PDF
      final pdfFile = await generateSummaryReport(salesToday, debtPaidToday, todayStr, businessName);

      // Send Email
      final adminEmail = await getAdminEmail();
      if (adminEmail != null) {
        final smtpServer = SmtpServer(
          'mail.ephamarcysoftware.co.tz',
          username: 'suport@ephamarcysoftware.co.tz',
          password: 'Matundu@2050',
          port: 465,
          ssl: true,
        );

        final emailMessage = Message()
          ..from = Address('suport@ephamarcysoftware.co.tz', businessName)
          ..recipients.add(adminEmail)
          ..subject = 'Daily Sales Summary - $todayStr'
          ..text = message
          ..attachments = [FileAttachment(pdfFile)];

        await send(emailMessage, smtpServer);
        print('📧 Email sent successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error sending daily report: $e');
      return false;
    }
  }

  Future<double> _getTotalSales(String date) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery("SELECT SUM(total_price) as total FROM sales WHERE DATE(confirmed_time)=?", [date]);
    return result.isNotEmpty ? (result[0]['total'] ?? 0.0) as double : 0.0;
  }

  Future<double> _getTotalDebtPaid(String date) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery("SELECT SUM(lent_paid) as total FROM sales WHERE DATE(confirmed_time)=?", [date]);
    return result.isNotEmpty ? (result[0]['total'] ?? 0.0) as double : 0.0;
  }

  Future<File> generateSummaryReport(double sales, double debtPaid, String date, String businessName) async {
    final pdf = pw.Document();
    final currencyFormat = NumberFormat('#,##0.00', 'en_US');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(businessName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text("Daily Summary Report - $date", style: pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 20),
              pw.Text("Total Sales: TZS ${currencyFormat.format(sales)}"),
              pw.Text("Debt Paid: TZS ${currencyFormat.format(debtPaid)}"),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/daily_summary_report_$date.pdf');
    await file.writeAsBytes(await pdf.save());
    print("✅ PDF generated at: ${file.path}");
    return file;
  }

  // Placeholder functions - implement as per your DB
  Future<List<String>> getAdminPhones() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', columns: ['phone'], where: 'role=?', whereArgs: ['admin']);
    return result.map((e) => e['phone'].toString()).toList();
  }

  Future<String?> getAdminEmail() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users', columns: ['email'], where: 'role=?', whereArgs: ['admin']);
    return result.isNotEmpty ? result.first['email'].toString() : null;
  }
}
