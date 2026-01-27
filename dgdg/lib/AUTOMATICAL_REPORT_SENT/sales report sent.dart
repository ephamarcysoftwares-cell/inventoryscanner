import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../DB/database_helper.dart';
import '../SMS/sms_gateway.dart'; // Assumed to contain sendSingleMessage

// -----------------------------------------------------------------------------
// 💾 NEW AND SAVED CONSTANTS
// -----------------------------------------------------------------------------
// The Admin's Internal IP (For reference only - not used in WhatsApp logic)
final String _pcIP = '10.216.127.201';

// 100 Unique Daily Business Growth Tips for the Admin Report (via WhatsApp)
const List<String> BUSINESS_GROWTH_TIPS = [
  "🚀 Tip #1: **Review your top 5 selling items.** Ensure you have at least 3 months of stock on hand to prevent running out during peak demand.",
  "💡 Tip #2: **Check today's payment methods.** Is cash significantly higher than mobile payments? Consider improving your mobile payment setup.",
  "📱 Tip #3: **List three unique selling points** of your business that customers mention frequently. Start using them in all staff conversations.",
  "✨ Tip #4: **Recognize one staff member today** for providing exceptional service. Public praise drives performance.",
  "🗓️ Tip #5: **Review the 'customer phone' column** in your recent sales. Are phone numbers missing? Remind staff to capture this data for follow-up.",
  "🎯 Tip #6: **Compare your prices on 5 key items** with local competitors. Adjust any outliers to remain competitive while protecting profit.",
  "🤝 Tip #7: **Identify the longest step** in your daily sales process. Can you simplify it or use technology to cut the time in half?",
  "⭐️ Tip #8: **Audit your 'To_lend' report.** Contact any customers with balances overdue by more than 30 days.",
  "🛒 Tip #9: **Check your business's Google Maps listing.** Is the phone number and opening hours correct? Encourage customers to leave reviews.",
  "🎁 Tip #10: **Inspect the cleanest and dirtiest spots** in your store. A spotless environment builds immediate customer confidence.",
  "📈 Tip #11: **Negotiate a small discount** with your main supplier this week. Even 1% savings directly improves your bottom line.",
  "🚨 Tip #12: **Verify the last time your CCTV footage was checked.** Ensure security systems are fully functional.",
  "📚 Tip #13: **Spend 15 minutes training staff** on how to upsell or cross-sell related products.",
  "🌍 Tip #14: **Identify a local charity or event** your business can support. Community involvement boosts reputation.",
  "💰 Tip #15: **Set a daily sales target** slightly higher than your average for today. Communicate the goal clearly to the team.",
  "🌐 Tip #16: **If you have a website, check it on a mobile phone.** Is it fast and easy to navigate?",
  "📉 Tip #17: **Review dead stock (items not sold in 6 months).** Mark them down for a quick sale to free up capital.",
  "👂 Tip #18: **Analyze a customer complaint** from the past week. Ensure the root cause has been addressed, not just the symptom.",
  "📜 Tip #19: **Check that all required licenses or permits** displayed in the store are current and clearly visible.",
  "✂️ Tip #20: **Look for one small recurring expense** you can reduce by 10% this month (e.g., printing paper, water).",
  "💸 Tip #21: **Review your outstanding invoices.** Send polite reminders for any large payments due within the next 7 days.",
  "🔖 Tip #22: **Ensure all outgoing materials** (receipts, bags, flyers) have a consistent logo and contact details.",
  "🏆 Tip #23: **Implement a small sales contest** for the next 3 days, rewarding the employee with the highest sales value.",
  "👁️ Tip #24: **Highlight a seasonal or high-margin product** at the counter. Visibility drives impulse buys.",
  "🆚 Tip #25: **Ask three staff members** what they think your biggest competitor does better than you. Use the feedback.",
  "🧪 Tip #26: **Test one staff member** on the features and benefits of a new product.",
  "⛑️ Tip #27: **Check fire exits and first aid kit.** Ensure your workplace is safe and compliant for staff and customers.",
  "💎 Tip #28: **Identify your top 5 loyal customers.** Brainstorm a small, personalized thank you action for each.",
  "🤖 Tip #29: **Can one manual task** (like data entry or receipt filing) be automated or done digitally?",
  "🧘 Tip #30: **Block out 30 minutes today** dedicated *only* to strategic thinking, not daily operations.",
  "💬 Tip #31: **Plan your next 5 social media posts** to focus on customer education, not just sales.",
  "📞 Tip #32: **Call a secondary supplier** to check their prices and availability as a backup for core stock.",
  "🗑️ Tip #33: **Find one area where waste is common** (packaging, spoiled goods) and set a target to cut it by 50%.",
  "🔄 Tip #34: **Is your POS/Inventory software fully updated?** Outdated software is a security risk.",
  "🤝 Tip #35: **Partner with a non-competing business** (e.g., a local bakery/cafe) for a joint flyer distribution.",
  "🗣️ Tip #36: **Establish a clear internal channel** for staff to submit improvement ideas anonymously.",
  "🧮 Tip #37: **Verify that yesterday's closing cash balance** matches the system report exactly.",
  "🎓 Tip #38: **Research one free online business course** related to sales or management for yourself or a staff member.",
  "↩️ Tip #39: **Review your refund/exchange policy.** Ensure staff can clearly explain it to customers.",
  "🔮 Tip #40: **Write down one major business goal** for the next quarter (e.g., expand a product line).",
  "💡 Tip #41: **Check all store lighting.** A bright, well-lit store feels safer and more professional.",
  "🏦 Tip #42: **If you have business loans,** review the payment schedule and ensure funds are allocated.",
  "🛵 Tip #43: **If you offer delivery,** track the average delivery time. Aim to reduce it by 5 minutes.",
  "🍎 Tip #44: **Ensure all staff** are taking their full breaks. Rested staff are productive staff.",
  "🌈 Tip #45: **Check for gaps in your product range.** Is there a high-demand item you don't carry?",
  "🆘 Tip #46: **Keep a list of emergency contacts** (plumber, electrician, security) readily available.",
  "🖼️ Tip #47: **Rearrange one shelf** in the store to create a more appealing visual flow for customers.",
  "🔒 Tip #48: **Change your business Wi-Fi password** every three months for better security.",
  "➕ Tip #49: **Review the pricing of complementary items** to encourage bundling.",
  "⏱️ Tip #50: **Hold a 5-minute stand-up meeting** with staff to align on the focus for the day.",
  "👍 Tip #51: **Reply to all customer reviews** (positive and negative) left online in the last week.",
  "📏 Tip #52: **Spot-check the stock count** of 5 random high-value items against the system quantity.",
  "📊 Tip #53: **Categorize all small expenses** from yesterday. Look for potential overspending trends.",
  "♿ Tip #54: **Ensure your store entrance** is clear and accessible for everyone.",
  "💻 Tip #55: **Research one piece of new retail technology** that could benefit your business.",
  "👔 Tip #56: **Ensure all staff uniforms** are clean, presentable, and consistent.",
  "📣 Tip #57: **Review your internal messaging** system to ensure staff communication is efficient.",
  "📉 Tip #58: **Identify the sales channel** that had the lowest revenue last month and brainstorm improvements.",
  "⚖️ Tip #59: **Review your data privacy policy** regarding the customer phone numbers you collect.",
  "⚡ Tip #60: **Turn off any non-essential lighting** or equipment during slow hours to save on electricity.",
  "🗣️ Tip #61: **Practice dealing with a difficult customer** scenario with your top staff member.",
  "🗞️ Tip #62: **Buy a small classified ad** in a local newsletter or community notice board.",
  "🎯 Tip #63: **Define the specific market niche** you want to dominate in the next 6 months.",
  "🗓️ Tip #64: **Break down your monthly profit goal** into a daily revenue target for the team.",
  "🛍️ Tip #65: **Evaluate your customer bags/packaging.** Is it professional and sturdy?",
  "❓ Tip #66: **Start compiling an internal FAQ** for staff on common customer questions.",
  "❤️ Tip #67: **Engage with 5 local followers** on social media (like, comment, share their post).",
  "🛑 Tip #68: **Review all monthly business subscriptions.** Cancel any services you don't actively use.",
  "🏷️ Tip #69: **Check that all price tags** and display signs are clear, correct, and professional-looking.",
  "💧 Tip #70: **Provide fresh water or tea/coffee** for staff to keep them energized throughout the day.",
  "💾 Tip #71: **Ensure all critical business data** was successfully backed up last night.",
  "🧊 Tip #72: **Review your FIFO (First-In, First-Out) method.** Ensure old stock is being sold before new stock.",
  "📈 Tip #73: **Calculate your Customer Lifetime Value (CLV)** for the last year. Focus on increasing this metric.",
  "💸 Tip #74: **Place a low-cost, high-impulse item** near the checkout to boost average transaction value.",
  "⏰ Tip #75: **Ensure the staff schedule** matches peak hours based on last month's sales data.",
  "✅ Tip #76: **Update your business hours** on all platforms (Google, Facebook, Website) for consistency.",
  "🚛 Tip #77: **Audit your transportation/delivery costs.** Can you negotiate a better rate with your current provider?",
  "🛡️ Tip #78: **Test your alarm system** and ensure all staff know the opening/closing security procedures.",
  "🚶 Tip #79: **Walk through your store** as if you were a first-time customer. Identify points of confusion.",
  "🧑‍💻 Tip #80: **Delegate one recurring task** you currently handle to a trusted staff member for the next month.",
  "📋 Tip #81: **Create a short checklist** for staff to use when handling a large or complex order.",
  "🎄 Tip #82: **Plan for the next major holiday/season.** Order stock and plan promotions now.",
  "⚙️ Tip #83: **Utilize a feature in your inventory software** (like reporting or reorder points) you haven't used before.",
  "P&L Tip #84: **Generate a Profit & Loss statement** for the last month to gauge overall business health.",
  "🔗 Tip #85: **Identify a new potential supplier** for a core product to reduce reliance on a single source.",
  "🧡 Tip #86: **Send a small, personalized offer** to customers who haven't shopped in 60-90 days.",
  "💰 Tip #87: **Review your marketing spend.** Is your money going to channels that generate the most sales?",
  "🙋 Tip #88: **Ask one staff member** what single change would make their job easier or more productive.",
  "🧼 Tip #89: **Wipe down all glass surfaces** and windows. Clean glass makes the store look brighter.",
  "📑 Tip #90: **Review your business insurance policy.** Ensure it covers your current stock value and risks.",
  "👤 Tip #91: **Define your ideal customer profile** clearly. Focus marketing efforts only on them.",
  "🤝 Tip #92: **Review your 'To Lend' limits** and enforcement policy. Strict limits reduce risk.",
  "🛒 Tip #93: **If you sell online,** check the checkout process for speed and efficiency.",
  "📝 Tip #94: **If you plan to hire,** start drafting the job description now, focusing on attitude and skills.",
  "🧮 Tip #95: **Calculate the gross profit margin** on your three biggest-selling items.",
  "networking Tip #96: **Plan to attend one local business networking event** this month to build contacts.",
  "🚦 Tip #97: **Ensure the store's exterior sign** is clean, visible, and well-lit at night.",
  "🧑‍🎓 Tip #98: **Train staff on a shortcut or feature** in the POS/Inventory system they don't know yet.",
  "🕵️ Tip #99: **Have a staff member visit a competitor's store** (as a mystery shopper) and report back.",
  "🛠️ Tip #100: **Review your capital investment plan.** What piece of equipment or improvement will you fund next?",
];
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// 📞 The provided sendWhatsApp function (RETAINED)
// -----------------------------------------------------------------------------
Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
  try {
    // Load Instance ID and Access Token from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
    final accessToken = prefs.getString('whatsapp_access_token') ?? '';

    if (instanceId.isEmpty || accessToken.isEmpty) {
      return "❌ WhatsApp error conduct +255742448965!";
    }

    // Clean phone number (Tanzania example)
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (!cleanPhone.startsWith('255')) {
      // Assuming a standard local number that needs the country code
      cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
    }
    final chatId = '$cleanPhone@c.us';

    Future<http.Response> post(String url, Map<String, String> payload) async {
      return await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: payload,
      );
    }

    // Start typing (optional, for better UX)
    await post('https://wawp.net/wp-json/awp/v1/startTyping', {
      'instance_id': instanceId,
      'access_token': accessToken,
      'chatId': chatId,
    });

    // Send message (direct API call)
    final sendRes = await post('https://wawp.net/wp-json/awp/v1/send', {
      'instance_id': instanceId,
      'access_token': accessToken,
      'chatId': cleanPhone, // The API might expect only the phone number here
      'message': messageText,
    });

    // Stop typing (optional)
    await post('https://wawp.net/wp-json/awp/v1/stopTyping', {
      'instance_id': instanceId,
      'access_token': accessToken,
      'chatId': chatId,
    });

    if (sendRes.statusCode >= 200 && sendRes.statusCode < 300) {
      return "✅ Direct WhatsApp notification sent successfully!";
    } else {
      return "❌ fail";
    }
  } catch (e) {
    return "❌ error";
  }
}
// -----------------------------------------------------------------------------


String _buildSalesComparisonMessage({
  required String businessName,
  required String dateCurrent,
  required String datePrevious,
  required double salesCurrent,
  required double salesPrevious,
  required double lentPaidCurrent,
  required double lentPaidPrevious,
}) {
  final NumberFormat currencyFormat = NumberFormat('#,##0.00');

  final totalCurrent = salesCurrent + lentPaidCurrent;
  final totalPrevious = salesPrevious + lentPaidPrevious;
  final diff = totalCurrent - totalPrevious;
  final diffAbs = diff.abs();

  String change = diff > 0 ? "kuongezeka" : (diff < 0 ? "kupungua" : "kutosha tofauti");

  // Ujumbe maalum kulingana na hali
  String extraMessage;
  if (diff > 0) {
    extraMessage = "Hongera sana! Endelea kufanya vizuri zaidi 💪😊.";
  } else if (diff < 0) {
    extraMessage = "Yamepungua kidogo 😟. Jaribu kujali wateja zaidi na tafuta mbinu mpya za kuwavutia kurudi.";
  } else {
    extraMessage = "Hakuna tofauti kubwa, endelea kudumisha huduma bora 💯.";
  }

  return "Habari kutoka $businessName 😊,\n"
      "Mauzo yako ya $dateCurrent ni shilingi TZS ${currencyFormat.format(salesCurrent)}, "
      "Madeni (Debt) yaliyolipwa ni TZS ${currencyFormat.format(lentPaidCurrent)},\n"
      "ukilinganisha na $datePrevious ambapo mauzo yalikuwa TZS ${currencyFormat.format(salesPrevious)} "
      "na Madeni (Debt) yaliyolipwa ni TZS ${currencyFormat.format(lentPaidPrevious)}.\n"
      "Jumla yame$change kwa kiasi cha TZS ${currencyFormat.format(diffAbs)}.\n"
      "$extraMessage\n"
      "Ahsante kwa kuchagua STOCK&INVENTORY SOFTWARE.";
}

class ReportScheduler {

  // ------------------- NEW DAILY TIP LOGIC -------------------

  /// Gets the Admin's phone number. PLACEHOLDER: Must be configured.
  Future<String> _getAdminPhoneNumber() async {
    // NOTE: Replace this with the actual way to fetch the Admin's WhatsApp number.
    // The IP address _pcIP = '10.216.127.201' is the source computer IP.
    return '2557XXXXXXXX'; // <<<--- SET ADMIN WHATSAPP NUMBER HERE
  }

  /// Selects a unique daily tip from the list by cycling through the 100 tips
  /// based on the current day of the year.
  String _selectDailyGrowthTip() {
    final now = DateTime.now();
    // Get the day number (1-365/366).
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays + 1;

    // Use modulo operator to cycle through the 100 tips (0 to 99)
    final tipIndex = (dayOfYear - 1) % BUSINESS_GROWTH_TIPS.length;

    return BUSINESS_GROWTH_TIPS[tipIndex];
  }

  /// Sends the selected business growth tip to the Admin via WhatsApp.
  Future<bool> _sendDailyGrowthTip() async {
    final adminPhone = await _getAdminPhoneNumber();
    if (adminPhone.length < 10 || adminPhone.contains('X')) {
      print("❌ Admin phone number not properly configured for Daily Tip. Skipping.");
      return false;
    }

    if (!await _checkInternetConnectivity()) {
      print("🚫 Cannot send Daily Tip: No internet connection.");
      return false;
    }

    final tip = _selectDailyGrowthTip();

    final message = "Daily Business Growth Tip:\n\n$tip";

    final result = await sendWhatsApp(adminPhone, message);

    if (result.startsWith("✅")) {
      print("✅ Daily Business Growth Tip sent successfully to Admin.");
      return true;
    } else {
      print("❌ Failed to send Daily Business Growth Tip to Admin. Result: $result");
      return false;
    }
  }

  /// Utility function to check for internet connectivity.
  Future<bool> _checkInternetConnectivity() async {
    try {
      // Use a low-level check for connectivity. Pinging a reliable server.
      final result = await InternetAddress.lookup('google.com')
          .timeout(Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print("🌐 Internet connectivity confirmed.");
        return true;
      }
      return false;
    } on SocketException catch (_) {
      print("🚫 No internet connection detected.");
      return false;
    } catch (e) {
      print("🚫 Error checking internet: $e");
      return false;
    }
  }

  // ------------------- SCHEDULER CORE FUNCTIONS -------------------

  void start() {
    print("📅 ReportScheduler started (Daily: Summary & Top Ten at 22:00; Full Report, Top Ten, & Daily Tip at 23:00) (Weekly: Sunday 12:00, 22:00, 23:00)");

    // 1. Attempt to send yesterday's FULL report immediately on startup (catch-up)
    sendYesterdayReport();

    // 2. Schedule the 22:00 Summary, 23:00 Full Report, AND the new Sunday Weekly Report tasks
    void scheduleNextTasks() {
      final now = DateTime.now();
      final ReportScheduler scheduler = ReportScheduler();

      // --- DAILY: 22:00 Summary & Top Ten Task ---
      DateTime nextSummaryTime = DateTime(now.year, now.month, now.day, 22, 0);
      if (!nextSummaryTime.isAfter(now)) {
        nextSummaryTime = nextSummaryTime.add(Duration(days: 1)); // Schedule for tomorrow
      }
      Duration timeToNextSummary = nextSummaryTime.difference(now);

      // Schedule the 22:00 Summary & Top Ten Report (DAILY)
      Timer(timeToNextSummary, () async {
        print('⏰ Triggering sales summary and Top Ten Report at 22:00.');

        await _sendDailySummary();
        await scheduler.sendTopTenSoldReport();

        scheduleNextTasks();
      });

      // --- DAILY: 23:00 Full Report, Top Ten, AND Daily Tip Task ---
      DateTime nextReportTime = DateTime(now.year, now.month, now.day, 23, 0);
      if (!nextReportTime.isAfter(now)) {
        nextReportTime = nextReportTime.add(Duration(days: 1)); // Schedule for tomorrow
      }
      Duration timeToNextReport = nextReportTime.difference(now);

      // Schedule the 23:00 Full Report, Top Ten Report, and Daily Tip (DAILY)
      Timer(timeToNextReport, () async {
        print('⏰ Triggering full daily report, Top Ten Report, and Daily Tip at 23:00.');

        bool sent = await _sendDailyReport();
        print(sent
            ? "✅ Full Report sent successfully."
            : "❌ Full Report failed.");

        // NEW: Send the Daily Business Growth Tip
        await _sendDailyGrowthTip();

        await scheduler.sendTopTenSoldReport();

        scheduleNextTasks();
      });

      // --- WEEKLY: Sunday 12:00 PM, 22:00, and 23:00 Tasks ---

      // Helper function to find the next Sunday at a specific hour
      DateTime findNextSunday(int hour) {
        DateTime targetTime = DateTime(now.year, now.month, now.day, hour, 0);
        // Add days until we hit Sunday (where DateTime.weekday == 7)
        while (targetTime.weekday != DateTime.sunday || !targetTime.isAfter(now)) {
          targetTime = targetTime.add(Duration(days: 1));
          // Reset to the target hour if we jumped to the next day
          if (targetTime.weekday == DateTime.sunday) {
            targetTime = DateTime(targetTime.year, targetTime.month, targetTime.day, hour, 0);
          }
          if (targetTime.isBefore(now) || targetTime.isAtSameMomentAs(now)) {
            targetTime = targetTime.add(Duration(days: 7)); // Ensure we skip to next Sunday
          }
        }
        return targetTime;
      }

      void scheduleWeeklyReport(int hour) {
        DateTime nextWeeklyTime = findNextSunday(hour);
        Duration timeToNextWeekly = nextWeeklyTime.difference(now);

        // Schedule the Weekly Report
        Timer(timeToNextWeekly, () async {
          print('⏰ Triggering Weekly Report on Sunday at ${hour.toString().padLeft(2, '0')}:00.');
          await scheduler.sendWeeklyReport();

          // Reschedule this specific weekly task (recursively call the function)
          scheduleWeeklyReport(hour);
        });
      }

      // Schedule the three Sunday tasks
      scheduleWeeklyReport(12); // 12:00 PM (Noon)
      scheduleWeeklyReport(22); // 10:00 PM (Night)
      scheduleWeeklyReport(23); // 11:00 PM (Night)

      // Daily task print outs
      print("Next 22:00 Daily Reports scheduled for: $nextSummaryTime");
      print("Next 23:00 Daily Reports scheduled for: $nextReportTime");
    }

    scheduleNextTasks();
  }

  // --- 22:00 Summary Sender ---
  Future<bool> _sendDailySummary() async {
    final isConnected = await _checkInternetConnectivity();
    if (!isConnected) {
      print("🚫 Summary skipped. No internet connection.");
      return false;
    }

    try {
      final businessName = await getBusinessName();
      final summary = await getTodaySalesSummary();
      final NumberFormat currencyFormat = NumberFormat('#,##0.00');

      final message = "Daily Summary from **$businessName** (${DateFormat('yyyy-MM-dd').format(DateTime.now())}):\n"
          "💰 Total Sales: TZS ${currencyFormat.format(summary['total_sales'])}\n"
          "📥 Debt Paid: TZS ${currencyFormat.format(summary['total_lent_paid'])}\n"
          "📈 **Grand Total:** TZS ${currencyFormat.format(summary['grand_total'])}\n\n"
          "The full detailed report and a daily tip will be sent at **23:00**.\n" // Updated note
          "Ahsante kwa kuchagua STOCK&INVENTORY SOFTWARE.";

      final adminPhones = await getAdminPhones();

      // Send SMS and WhatsApp
      for (var phone in adminPhones) {
        // Send SMS
        try {
          // Note: SMS may not support bold text (**)
          final smsResponse = await sendSingleMessage(phone, message.replaceAll('**', '').replaceAll('*', ''));
          print("📱 SMS Summary sent to $phone: $smsResponse");
        } catch (e) {
          print("❌ SMS Summary failed to $phone: $e");
        }

        // Send WhatsApp
        try {
          final waResponse = await sendWhatsApp(phone, message);
          print("💬 WhatsApp Summary sent to $phone: $waResponse");
        } catch (e) {
          print("❌ WhatsApp Summary failed to $phone: $e");
        }
      }
      return true;
    } catch (e) {
      print("❌ Error sending daily summary: $e");
      return false;
    }
  }


  /// Internal method to send Today's Report (compared to Yesterday)
  Future<bool> _sendDailyReport() async {
    return await _sendReportForDate(DateTime.now(), DateTime.now().subtract(Duration(days: 1)));
  }

  /// Core logic for sending a full daily report (Email, SMS, WhatsApp)
  Future<bool> _sendReportForDate(DateTime currentDate, DateTime previousDate) async {
    final isConnected = await _checkInternetConnectivity();
    if (!isConnected) {
      print("🚫 Full Report skipped for ${DateFormat('yyyy-MM-dd').format(currentDate)}. No internet connection.");
      return false;
    }

    try {
      final businessName = await getBusinessName();

      // Fetch sales & lent paid
      final salesCurrentList = await getSalesByDate(currentDate);
      final salesPreviousList = await getSalesByDate(previousDate);
      final lentCurrentList = await getLentPaidByDate(currentDate);
      final lentPreviousList = await getLentPaidByDate(previousDate);

      final totalSalesCurrent = salesCurrentList.fold(
          0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());
      final totalSalesPrevious = salesPreviousList.fold(
          0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());

      final totalLentCurrent = lentCurrentList.fold(
          0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());
      final totalLentPrevious = lentPreviousList.fold(
          0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());

      final salesComparisonMessage = _buildSalesComparisonMessage(
        businessName: businessName,
        dateCurrent: DateFormat('yyyy-MM-dd').format(currentDate),
        datePrevious: DateFormat('yyyy-MM-dd').format(previousDate),
        salesCurrent: totalSalesCurrent,
        salesPrevious: totalSalesPrevious,
        lentPaidCurrent: totalLentCurrent,
        lentPaidPrevious: totalLentPrevious,
      );

      // Get the Daily Tip to include in the Email and WhatsApp
      final dailyTip = _selectDailyGrowthTip();

      // Combine messages for final Email/WhatsApp body
      final fullMessageBody =
          "$salesComparisonMessage\n\n"
          "--- 💡 DAILY BUSINESS TIP ---\n"
          "$dailyTip\n"
          "-----------------------------";


      // Generate PDF
      final pdfFile = await generateSalesReport(
        [...salesCurrentList, ...lentCurrentList],
        totalPrevious: totalSalesPrevious + totalLentPrevious,
        dateCurrent: DateFormat('yyyy-MM-dd').format(currentDate),
        datePrevious: DateFormat('yyyy-MM-dd').format(previousDate),
      );

      // --- 📧 Send Email ---
      final adminEmails = await getAdminEmails();
      if (adminEmails.isNotEmpty) {
        final smtpServer = SmtpServer(
          'mail.ephamarcysoftware.co.tz',
          username: 'suport@ephamarcysoftware.co.tz',
          password: 'Matundu@2050',
          port: 465,
          ssl: true,
        );

        final emailMessage = Message()
          ..from = Address('suport@ephamarcysoftware.co.tz', '$businessName NOTIFICATION')
          ..recipients.addAll(adminEmails)
          ..subject =
              'Sales & Lent Paid Report - ${DateFormat('yyyy-MM-dd').format(currentDate)}'
          ..text = fullMessageBody
          ..attachments = [FileAttachment(pdfFile)];

        try {
          await send(emailMessage, smtpServer);
          print("📧 Email report sent to ${adminEmails.length} admin(s) with Daily Tip.");
        } catch (e) {
          print("❌ Email failed: $e");
        }
      }

      final adminPhones = await getAdminPhones();

      // --- 📱 Send SMS and WhatsApp ---
      for (var phone in adminPhones) {
        // Send SMS (SMS is short, so send the sales comparison only)
        try {
          final smsResponse = await sendSingleMessage(phone, salesComparisonMessage);
          print("📱 SMS sent to $phone: $smsResponse");
        } catch (e) {
          print("❌ SMS failed to $phone: $e");
        }

        // Send WhatsApp (Includes full comparison, tip, and PDF note)
        try {
          final whatsappMessage = "$fullMessageBody\n\n📌 **FULL REPORT PDF attachment has been sent via Email** to the registered admin emails. Please check your inbox.";
          final waResponse = await sendWhatsApp(phone, whatsappMessage);
          print("💬 WhatsApp sent to $phone: $waResponse (with Tip)");
        } catch (e) {
          print("❌ WhatsApp failed to $phone: $e");
        }
      }

      return true;
    } catch (e) {
      print("❌ Error sending report: $e");
      return false;
    }
  }

  /// Public method to send Yesterday's Report (Catch-up)
  Future<void> sendYesterdayReport() async {
    final isConnected = await _checkInternetConnectivity();
    if (isConnected) {
      print("🔄 Attempting to send yesterday's report (catch-up).");
      // Sends a report for Yesterday compared to the day before Yesterday
      await _sendReportForDate(DateTime.now().subtract(Duration(days: 1)),
          DateTime.now().subtract(Duration(days: 2)));
    } else {
      print("⚠️ Cannot send catch-up report. No internet connection.");
    }
  }

  // ------------------- Top Ten Sold Report Sender -------------------
  /// Fetches the top 10 products by quantity sold and sends a report.
  Future<bool> sendTopTenSoldReport() async {
    final isConnected = await _checkInternetConnectivity();
    if (!isConnected) {
      print("🚫 Top 10 Report skipped. No internet connection.");
      return false;
    }

    try {
      final businessName = await getBusinessName();
      final topProducts = await getTopTenSoldProducts();
      final NumberFormat currencyFormat = NumberFormat('#,##0.00');

      if (topProducts.isEmpty) {
        print("⚠️ No sales data found for the Top 10 report.");
        return false;
      }

      // Build the report message
      String message = "🏆 Top 10 Best-Selling Products for **$businessName** 🏆\n\n";

      for (int i = 0; i < topProducts.length; i++) {
        final product = topProducts[i];
        final rank = i + 1;
        final productName = product['medicine_name'];
        final quantity = product['TotalQuantity'] ?? 0;
        final revenue = product['TotalRevenue'] ?? 0.0;

        message +=
        "$rank. **$productName**\n"
            "   - Quantity Sold: ${quantity.toString()}\n"
            "   - Total Revenue: TZS ${currencyFormat.format(revenue)}\n";
      }

      message += "\nReport Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}\n"
          "Ahsante kwa kuchagua STOCK&INVENTORY SOFTWARE.";

      final adminPhones = await getAdminPhones();

      // Send SMS and WhatsApp
      for (var phone in adminPhones) {
        // 1. Send SMS (no bold formatting)
        try {
          final smsResponse = await sendSingleMessage(phone, message.replaceAll('**', '').replaceAll('*', ''));
          print("📱 SMS Top 10 Report sent to $phone: $smsResponse");
        } catch (e) {
          print("❌ SMS Top 10 Report failed to $phone: $e");
        }

        // 2. Send WhatsApp (with bold formatting)
        try {
          final waResponse = await sendWhatsApp(phone, message);
          print("💬 WhatsApp Top 10 Report sent to $phone: $waResponse");
        } catch (e) {
          print("❌ WhatsApp Top 10 Report failed to $phone: $e");
        }
      }

      return true;
    } catch (e) {
      print("❌ Error sending Top 10 report: $e");
      return false;
    }
  }


  // ------------------- Weekly Report Sender -------------------
  /// Fetches weekly performance data and sends an analysis via SMS and WhatsApp.
  Future<bool> sendWeeklyReport() async {
    final isConnected = await _checkInternetConnectivity();
    if (!isConnected) {
      print("🚫 Weekly Report skipped. No internet connection.");
      return false;
    }

    try {
      final businessName = await getBusinessName();
      final analysis = await analyzeWeeklyPerformance();

      final message = "Weekly Performance Analysis from **$businessName**:\n\n$analysis\n\n"
          "Ahsante kwa kuchagua STOCK&INVENTORY SOFTWARE.";

      final adminPhones = await getAdminPhones();

      // Send SMS and WhatsApp
      for (var phone in adminPhones) {
        // Send SMS (no bold formatting)
        try {
          final smsResponse = await sendSingleMessage(phone, message.replaceAll('**', '').replaceAll('*', ''));
          print("📱 SMS Weekly Analysis sent to $phone: $smsResponse");
        } catch (e) {
          print("❌ SMS Weekly Analysis failed to $phone: $e");
        }

        // Send WhatsApp (with bold formatting)
        try {
          final waResponse = await sendWhatsApp(phone, message);
          print("💬 WhatsApp Weekly Analysis sent to $phone: $waResponse");
        } catch (e) {
          print("❌ WhatsApp Weekly Analysis failed to $phone: $e");
        }
      }

      print("✅ Weekly Analysis Report sent successfully.");
      return true;

    } catch (e) {
      print("❌ Error sending weekly analysis: $e");
      return false;
    }
  }

  // ------------------- Monthly Report Sender -------------------
  /// Fetches monthly performance data and sends an analysis via SMS and WhatsApp.
  Future<bool> sendMonthlyReport() async {
    final isConnected = await _checkInternetConnectivity();
    if (!isConnected) {
      print("🚫 Monthly Report skipped. No internet connection.");
      return false;
    }

    try {
      final businessName = await getBusinessName();
      final analysis = await analyzeMonthlyPerformance();

      final message = "Monthly Performance Analysis from **$businessName**:\n\n$analysis\n\n"
          "Ahsante kwa kuchagua STOCK&INVENTORY SOFTWARE.";

      final adminPhones = await getAdminPhones();

      // Send SMS and WhatsApp
      for (var phone in adminPhones) {
        // Send SMS (no bold formatting)
        try {
          final smsResponse = await sendSingleMessage(phone, message.replaceAll('**', '').replaceAll('*', ''));
          print("📱 SMS Monthly Analysis sent to $phone: $smsResponse");
        } catch (e) {
          print("❌ SMS Monthly Analysis failed to $phone: $e");
        }

        // Send WhatsApp (with bold formatting)
        try {
          final waResponse = await sendWhatsApp(phone, message);
          print("💬 WhatsApp Monthly Analysis sent to $phone: $waResponse");
        } catch (e) {
          print("❌ WhatsApp Monthly Analysis failed to $phone: $e");
        }
      }

      print("✅ Monthly Analysis Report sent successfully.");
      return true;

    } catch (e) {
      print("❌ Error sending monthly analysis: $e");
      return false;
    }
  }


  /// ------------------- Today's Sales Summary -------------------
  Future<Map<String, double>> getTodaySalesSummary() async {
    final currentDate = DateTime.now();
    final salesList = await getSalesByDate(currentDate);
    final lentList = await getLentPaidByDate(currentDate);

    final totalSales = salesList.fold(
        0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());
    final totalLentPaid = lentList.fold(
        0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());

    return {
      'total_sales': totalSales,
      'total_lent_paid': totalLentPaid,
      'grand_total': totalSales + totalLentPaid,
    };
  }

  /// ------------------- Get Top Ten Sold Products -------------------
  Future<List<Map<String, dynamic>>> getTopTenSoldProducts() async {
    final db = await DatabaseHelper.instance.database;

    // SQL to group sales by product name, sum the quantities,
    // order by the sum (TotalQuantity) in descending order, and limit to 10.
    final List<Map<String, dynamic>> result = await db.rawQuery("""
      SELECT 
        medicine_name, 
        SUM(total_quantity) AS TotalQuantity,
        SUM(total_price) AS TotalRevenue
      FROM 
        sales
      GROUP BY 
        medicine_name
      ORDER BY 
        TotalQuantity DESC
      LIMIT 10;
    """);

    return result;
  }

  /// ------------------- Get Weekly Report Total -------------------
  Future<double> getWeeklyTotal(DateTime endDate) async {
    final startDate = endDate.subtract(Duration(days: 6)); // 7 days total
    final db = await DatabaseHelper.instance.database;
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    final salesQuery = await db.rawQuery("""
      SELECT SUM(total_price) as weekly_total
      FROM sales
      WHERE DATE(confirmed_time) BETWEEN ? AND ?
    """, [startStr, endStr]);

    final lentPaidQuery = await db.rawQuery("""
      SELECT SUM(total_price) as weekly_total
      FROM To_lent_payedLogs
      WHERE DATE(confirmed_time) BETWEEN ? AND ?
    """, [startStr, endStr]);

    final salesTotal = (salesQuery.first['weekly_total'] as num?)?.toDouble() ?? 0.0;
    final lentPaidTotal = (lentPaidQuery.first['weekly_total'] as num?)?.toDouble() ?? 0.0;

    return salesTotal + lentPaidTotal;
  }

  /// ------------------- Analyze Weekly Report -------------------
  Future<String> analyzeWeeklyPerformance() async {
    final now = DateTime.now();
    // This week (Last 7 days, including today)
    final thisWeekEnd = now;
    final thisWeekStart = now.subtract(Duration(days: 6));
    final thisWeekTotal = await getWeeklyTotal(thisWeekEnd);

    // Previous week (7 days before this week's start)
    final lastWeekEnd = thisWeekStart.subtract(Duration(days: 1));
    final lastWeekTotal = await getWeeklyTotal(lastWeekEnd);

    final diff = thisWeekTotal - lastWeekTotal;
    final diffAbs = diff.abs();
    final NumberFormat currencyFormat = NumberFormat('#,##0.00');

    final dateRangeThis = "${DateFormat('MMM d').format(thisWeekStart)} - ${DateFormat('MMM d').format(thisWeekEnd)}";
    final dateRangeLast = "${DateFormat('MMM d').format(lastWeekEnd.subtract(Duration(days: 6)))} - ${DateFormat('MMM d').format(lastWeekEnd)}";

    String analysis;
    if (diff > 0) {
      analysis = "🚀 MAUZO VIZURI! Mauzo ya wiki ya sasa ($dateRangeThis) yameongezeka kwa TZS ${currencyFormat.format(diff)} "
          "ukilinganisha na wiki iliyopita ($dateRangeLast).\n"
          "Jumla wiki hii: TZS ${currencyFormat.format(thisWeekTotal)}. "
          "Jumla wiki iliyopita: TZS ${currencyFormat.format(lastWeekTotal)}. Endelea na jitihada! 💪";
    } else if (diff < 0) {
      analysis = "📉 MAUZO YANAHITAJI UPINZANI! Mauzo ya wiki ya sasa ($dateRangeThis) yamepungua kwa TZS ${currencyFormat.format(diffAbs)} "
          "ukilinganisha na wiki iliyopita ($dateRangeLast).\n"
          "Jumla wiki hii: TZS ${currencyFormat.format(thisWeekTotal)}. "
          "Jumla wiki iliyopita: TZS ${currencyFormat.format(lastWeekTotal)}. Tafuta mbinu mpya za kibiashara.";
    } else {
      analysis = "⚖️ MAUZO SAWA! Mauzo ya wiki ya sasa ($dateRangeThis) na wiki iliyopita ($dateRangeLast) yanafanana.\n"
          "Jumla wiki hii: TZS ${currencyFormat.format(thisWeekTotal)}. Endelea kuboresha huduma.";
    }

    return analysis;
  }

  /// ------------------- Get Monthly Report Total -------------------
  Future<double> getMonthlyTotal(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final dateFilter = DateFormat('yyyy-MM').format(date); // e.g., '2025-10'

    final salesQuery = await db.rawQuery("""
      SELECT SUM(total_price) as monthly_total
      FROM sales
      WHERE strftime('%Y-%m', confirmed_time) = ?
    """, [dateFilter]);

    final lentPaidQuery = await db.rawQuery("""
      SELECT SUM(total_price) as monthly_total
      FROM To_lent_payedLogs
      WHERE strftime('%Y-%m', confirmed_time) = ?
    """, [dateFilter]);

    final salesTotal = (salesQuery.first['monthly_total'] as num?)?.toDouble() ?? 0.0;
    final lentPaidTotal = (lentPaidQuery.first['monthly_total'] as num?)?.toDouble() ?? 0.0;

    return salesTotal + lentPaidTotal;
  }

  /// ------------------- Analyze Monthly Report -------------------
  Future<String> analyzeMonthlyPerformance() async {
    final now = DateTime.now();
    // This month
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthTotal = await getMonthlyTotal(now);

    // Last month
    final lastMonth = now.subtract(Duration(days: 30));
    final lastMonthTotal = await getMonthlyTotal(lastMonth);

    final diff = thisMonthTotal - lastMonthTotal;
    final diffAbs = diff.abs();
    final NumberFormat currencyFormat = NumberFormat('#,##0.00');

    final dateRangeThis = DateFormat('MMMM yyyy').format(now);
    final dateRangeLast = DateFormat('MMMM yyyy').format(lastMonth);

    String analysis;
    if (diff > 0) {
      analysis = "🚀 MAUZO YA MWEZI HUU VIZURI! Mauzo ya **$dateRangeThis** yameongezeka kwa TZS ${currencyFormat.format(diff)} "
          "ukilinganisha na **$dateRangeLast**.\n"
          "Jumla mwezi huu: TZS ${currencyFormat.format(thisMonthTotal)}. "
          "Jumla mwezi uliopita: TZS ${currencyFormat.format(lastMonthTotal)}. Endelea na kasi! 📈";
    } else if (diff < 0) {
      analysis = "📉 MAUZO YA MWEZI HUU YANAHITAJI MIKAKATI! Mauzo ya **$dateRangeThis** yamepungua kwa TZS ${currencyFormat.format(diffAbs)} "
          "ukilinganishwa na **$dateRangeLast**.\n"
          "Jumla mwezi huu: TZS ${currencyFormat.format(thisMonthTotal)}. "
          "Jumla mwezi uliopita: TZS ${currencyFormat.format(lastMonthTotal)}. Fanya tathmini ya kina.";
    } else {
      analysis = "⚖️ MAUZO SAWA! Mauzo ya **$dateRangeThis** na **$dateRangeLast** yanafanana.\n"
          "Jumla mwezi huu: TZS ${currencyFormat.format(thisMonthTotal)}. Zingatia ubunifu. 💡";
    }

    return analysis;
  }

  /// ------------------- DATABASE UTILITY FUNCTIONS (RETAINED) -------------------
  Future<List<Map<String, dynamic>>> getSalesByDate(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return await db.rawQuery(
        "SELECT * FROM sales WHERE DATE(confirmed_time) = ?", [dateStr]);
  }

  Future<List<Map<String, dynamic>>> getLentPaidByDate(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return await db.rawQuery(
        "SELECT * FROM To_lent_payedLogs WHERE DATE(confirmed_time) = ?", [dateStr]);
  }

  Future<List<String>> getAdminEmails() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users',
        columns: ['email'], where: 'role = ?', whereArgs: ['admin']);
    return result.map((row) => row['email'].toString()).toList();
  }

  Future<List<String>> getAdminPhones() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('users',
        columns: ['phone'], where: 'role = ?', whereArgs: ['admin']);
    return result.map((row) {
      String phone = row['phone']?.toString().trim() ?? '';
      // Normalization logic: prepend +255 if needed
      if (phone.isNotEmpty) {
        if (phone.startsWith('0')) {
          phone = '+255' + phone.substring(1);
        } else if (!phone.startsWith('+')) {
          phone = '+255' + phone;
        }
      }
      return phone;
    }).toList().where((p) => p.length > 5).toList(); // Filter out very short/invalid numbers
  }

  Future<String> getBusinessName() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('businesses', limit: 1);
    if (result.isNotEmpty) return result[0]['business_name']?.toString() ?? 'My Business';
    return 'My Business';
  }

  /// ------------------- PDF GENERATION (RETAINED) -------------------
  // NOTE: This section was incomplete in the provided code, but retained for context.
  Future<File> generateSalesReport(
      List<Map<String, dynamic>> sales, {
        double totalPrevious = 0.0,
        String dateCurrent = '',
        String datePrevious = '',
      }) async {
    final pdf = pw.Document();
    double totalSales = sales.fold(
        0.0, (sum, s) => sum + ((s['total_price'] ?? 0) as num).toDouble());

    final diff = totalSales - totalPrevious;
    final formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(DateTime.now());

    // Fetch business details
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('businesses', limit: 1);
    String businessName = '';
    String businessEmail = '';
    String businessPhone = '';
    String businessLocation = '';
    String businessLogoPath = '';
    String address = '';

    if (result.isNotEmpty) {
      final b = result[0];
      businessName = b['business_name']?.toString() ?? '';
      businessEmail = b['email']?.toString() ?? '';
      businessPhone = b['phone']?.toString() ?? '';
      businessLocation = b['location']?.toString() ?? '';
      businessLogoPath = b['logo']?.toString() ?? '';
      address = b['address']?.toString() ?? '';
    }

    // ... [PDF generation logic would continue here] ...

    // Placeholder for directory and file creation
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sales_report_$dateCurrent.pdf');

    // Save the PDF
    await file.writeAsBytes(await pdf.save());

    return file; // Return the temporary file
  }
}