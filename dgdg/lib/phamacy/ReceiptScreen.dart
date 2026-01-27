import 'dart:io';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../API/payment_alternative.dart';
import '../CHATBOAT/chatboat.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ReceiptScreen extends StatefulWidget {
  final String confirmedBy;
  final String confirmedTime;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String paymentMethod;
  final String receiptNumber;
  final List<String> medicineNames;
  final List<int> medicineQuantities;
  final List<double> medicinePrices;
  final List<String> medicineUnits;
  final List<String> medicineSources;
  final double totalPrice;
  final int remaining_quantity;

  const ReceiptScreen({
    super.key,
    required this.confirmedBy,
    required this.confirmedTime,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.paymentMethod,
    required this.receiptNumber,
    required this.medicineNames,
    required this.medicineQuantities,
    required this.medicinePrices,
    required this.medicineUnits,
    required this.medicineSources,
    required this.totalPrice,
    required this.remaining_quantity,
  });

  @override
  _ReceiptScreenState createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';
  String businessAddress = '';

  // API Configs from Database
  String waInstanceId = '';
  String waToken = '';
  String smsKey = '';

  bool _isDarkMode = false;
  bool _hasAutoSent = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    getBusinessInfo();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata Profile na Business ID ya huyu aliyelog-in
      final userData = await supabase
          .from('users')
          .select('business_name, business_id')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null) {
        final bId = userData['business_id'];
        final bName = userData['business_name']?.toString() ?? '';

        // 2. Query ya kutafuta biashara (Kipaumbele ni Business ID)
        var query = supabase.from('businesses').select();

        final response = bId != null
            ? await query.eq('id', bId).limit(1)
            : await query.eq('business_name', bName).limit(1);

        if (response.isNotEmpty) {
          var data = response.first;

          // LOGIC YA TAWI: Kama ni tawi, tumia Logo na Info za Makao Makuu
          if (data['is_main_business'] == false && data['parent_id'] != null) {
            final parent = await supabase.from('businesses').select().eq('id', data['parent_id']).maybeSingle();
            if (parent != null) data = parent;
          }

          if (mounted) {
            setState(() {
              int? _businessId;
              business_name = data['business_name']?.toString() ?? '';
              businessEmail = data['email']?.toString() ?? '';
              businessPhone = data['phone']?.toString() ?? '';
              businessAddress = data['address']?.toString() ?? '';
              businessLocation = data['location']?.toString() ?? '';
              businessLogoPath = data['logo']?.toString() ?? '';
              waInstanceId = data['whatsapp_instance_id']?.toString() ?? '';
              waToken = data['whatsapp_access_token']?.toString() ?? '';
              smsKey = data['sms_api_key']?.toString() ?? '';
            });
            // Tuma ujumbe kiotomatiki mara data zikipatikana
            _triggerAutoNotifications();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error Fetching Business Info: $e');
    }
  }

  // --- WHATSAPP API LOGIC (MOVED INSIDE STATE) ---
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      // Use the variables fetched in getBusinessInfo()
      if (waInstanceId.isEmpty || waToken.isEmpty) {
        debugPrint("❌ WA API Credentials missing in State");
        return "❌ Configuration error!";
      }

      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      // Standardize to 255 format
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '255${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('255')) {
        cleanPhone = '255$cleanPhone';
      }

      final res = await http.post(
        Uri.parse('https://wawp.net/wp-json/awp/v1/send'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'instance_id': waInstanceId,
          'access_token': waToken,
          'chatId': cleanPhone,
          'message': messageText
        },
      );

      debugPrint("WA Response: ${res.body}");
      return (res.statusCode >= 200 && res.statusCode < 300) ? "✅ Message sent!" : "❌ API Error";
    } catch (e) {
      debugPrint("WA Error: $e");
      return "❌ Connection failed";
    }
  }

  // --- AUTOMATIC NOTIFICATION LOGIC ---
  // Mwenye biashara anaweza kubadilisha hii kuwa false kama hataki ujumbe wa pili utumwe
  bool sendWelcomeBackMsg = true;

  // 1. Ongeza variable hii juu kwenye State ya widget yako
  bool _isNotificationSent = false;

  Future<void> _triggerAutoNotifications() async {
    if (widget.customerPhone.isEmpty || _isNotificationSent) return;
    _isNotificationSent = true;

    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    double totalDiscount = 0;
    String itemsDetails = '';

    for (int i = 0; i < widget.medicineNames.length; i++) {
      String itemName = widget.medicineNames[i].trim();
      double d = prefs.getDouble('discount_$itemName') ?? 0.0;
      totalDiscount += (d * widget.medicineQuantities[i]);
      itemsDetails += " *${widget.medicineNames[i]}* (x${widget.medicineQuantities[i]})\n";
    }

    String supportLine = "\n\n📞 Ukiwa na Changamoto Au Pendekezo tufikie kupitia: $businessPhone. Karibu tena uje upate huduma kwetu !";

    String discountText = totalDiscount > 0
        ? "🎁 *Punguzo ulilopata ni :* TSH ${currencyFormatter.format(totalDiscount)}\n"
        : "";

    final bool isMkopo = widget.paymentMethod.trim().toUpperCase() == "TO LEND(MKOPO)";
    String waMsg;

    if (isMkopo) {
      waMsg = "📝 *MKOPO KUTOKA $business_name*\n\n"
          "Habari ${widget.customerName}! 🌸\n"
          "Tunafurahi kukuhudumia. Samahani Umepokea bidhaa zenye thamani ya  TSH ${currencyFormatter.format(widget.totalPrice)} Kwa mkopo kama zilivyo orodheshwa hapa :\n\n"
          "$itemsDetails"
          "$discountText"
          "💳 *JUMLA YA DENI:* TSH ${currencyFormatter.format(widget.totalPrice)}\n\n"
          "Asante sana kwa kuendelea kutuamini na Tupo hapa kukupatia huduma bora zaidi . "
          "Tunathamini ushirikiano wako na tunakutakia matumizi mema ya bidhaa zako 🙏✨\n"
          "$supportLine";
    } else {
      waMsg = "🎉 *HUDUMA KUTOKA $business_name*\n\n"
          "Habari ${widget.customerName}! 🌸\n"
          "Tunashukru sana mteja wetu kuja kupata Huduma hapa kwetu Umenunua bidha vifuatazo:\n\n"
          "$itemsDetails"
          "$discountText"
          "💰 *JUMLA KUU:* TSH ${currencyFormatter.format(widget.totalPrice)}\n\n"
          "Tunakushukru Sana mteja Wetu Na Tunakukaribisha Tena uje upate Huduma tena Hapa Kwetu. "
          "Karibu tena wakati wowote—furaha yetu ni kukuhudumia wewe Mteja wetu 💖✨\n"
          "$supportLine";
    }


    // Rekebisha namba ya simu
    String rawPhone = widget.customerPhone.replaceAll(RegExp(r'\D'), '');
    String formattedPhone = rawPhone.startsWith('255')
        ? '+$rawPhone'
        : rawPhone.startsWith('0')
        ? '+255${rawPhone.substring(1)}'
        : '+255$rawPhone';

    try {
      // Tuma WhatsApp ya kwanza
      await sendWhatsApp(formattedPhone, waMsg);

      // Tuma ujumbe wa pili wa shukrani
      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        String karibuSanaMsg = "✨ *SHUKRANI ZA PEKEE KUTOKA $business_name*\n\n"
            "Habari ${widget.customerName}! 🙏\n"
            "Tunashukru Sana na Asante sana Mteja wetu Mpendwa kwa kutupa nafasi ya kukuhudumia leo. Tunajivunia kuwa na mteja kama wewe! 🌟\n\n"
            "Tunaahidi Kukupa huduma bora kila wakati.Tunakukaribisha siku nyingine uje upate Tena Huma hapa kwetu "
            "$supportLine";
        await sendWhatsApp(formattedPhone, karibuSanaMsg);
      });

      // Tuma SMS kama smsKey ipo
      if (smsKey.isNotEmpty) {
        String smsStatus = isMkopo ? "Mkopo wa" : "Malipo ya";
        String smsMsg = "Habari Mteja wetu  ${widget.customerName}! 🎉 $smsStatus TSH ${currencyFormatter.format(widget.totalPrice)} Yamepokelewa kikamilifu Na  $business_name. Asante sana Na tunashukru kwa kukuhudumia na kuja kupata huduma hapa kwetu ! 💖$supportLine";

        await http.post(
          Uri.parse("https://app.sms-gateway.app/services/send.php"),
          body: {
            'number': formattedPhone.replaceAll('+', ''),
            'message': smsMsg,
            'key': smsKey,
          },
        );
      }

      debugPrint("✅ Ujumbe wa mteja umetumwa kikamilifu!");

    } catch (e) {
      debugPrint("❌ Tatizo la notification: $e");
      _isNotificationSent = false;
    }
  }

  @override
  void dispose() {
    _clearDiscounts(); // Safisha SharedPreferences mteja akiondoka
    super.dispose();
  }

  Future<void> _clearDiscounts() async {
    final prefs = await SharedPreferences.getInstance();
    for (var name in widget.medicineNames) {
      await prefs.remove('discount_${name.trim()}');
    }
    debugPrint("Discounts cleared for current session.");
  }
  // --- PDF GENERATOR ---
  Future<pw.Document> _generateReceiptPdf() async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');

    // 🔥 1. Fungua SharedPreferences na Reload data mpya
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    pw.MemoryImage? logoImage;
    if (businessLogoPath.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(businessLogoPath));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint("Logo fetch failed: $e");
      }
    }

    final bool isMkopo =
        widget.paymentMethod.trim().toUpperCase() == "TO LEND(MKOPO)";
    final String documentTitle = isMkopo ? "INVOICE" : "RECEIPT";
    final String statusText = isMkopo ? "UNPAID" : "PAID";
    final PdfColor statusColor =
    isMkopo ? PdfColors.red700 : PdfColors.green700;

    // 🔥 2. Tayarisha list ya discounts kwa kila bidhaa
    List<double> fetchedDiscounts = [];
    double totalSavings = 0;
    for (int i = 0; i < widget.medicineNames.length; i++) {
      String itemName = widget.medicineNames[i].trim();
      double d = prefs.getDouble('discount_$itemName') ?? 0.0;
      fetchedDiscounts.add(d);
      totalSavings += (d * widget.medicineQuantities[i]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Opacity(
              opacity: 0.07,
              child: pw.Transform.rotate(
                angle: -0.4,
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: statusColor, width: 5),
                    borderRadius: pw.BorderRadius.circular(15),
                  ),
                  child: pw.Text(
                    statusText,
                    style: pw.TextStyle(
                      fontSize: 100,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.bottomCenter,
              child: pw.Text(
                " KARIBU SANA- ${business_name.toUpperCase()}",
                style:
                pw.TextStyle(fontSize: 8, color: PdfColors.grey),
              ),
            ),
          ],
        ),
        build: (pw.Context context) => [
          // 🔹 HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Image(logoImage, width: 80, height: 80)
              else
                pw.SizedBox(width: 80),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      documentTitle,
                      style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: statusColor),
                    ),
                    pw.Text(
                      business_name.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold),
                    ),
                    if (businessEmail.isNotEmpty)
                      pw.Text("Email: $businessEmail",
                          style: pw.TextStyle(fontSize: 9)),
                    pw.Text("Phone: $businessPhone",
                        style: pw.TextStyle(fontSize: 9)),
                    if (businessWhatsapp.isNotEmpty)
                      pw.Text("WhatsApp: $businessWhatsapp",
                          style: pw.TextStyle(fontSize: 9)),
                    if (businessLocation.isNotEmpty)
                      pw.Text("Location: $businessLocation",
                          style: pw.TextStyle(fontSize: 9)),
                    if (businessAddress.isNotEmpty)
                      pw.Text("Address: $businessAddress",
                          style: pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1, color: PdfColors.teal),
          pw.SizedBox(height: 15),

          // 🔹 CUSTOMER INFO
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text("$documentTitle No:",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(widget.receiptNumber,
                        style: pw.TextStyle(fontSize: 10))),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text("Customer:",
                        style: pw.TextStyle(fontSize: 10))),
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text(
                        widget.customerName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 10))),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text("Payment Method:",
                        style: pw.TextStyle(fontSize: 10))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(
                    isMkopo
                        ? "DEBIT(MKOPO)"
                        : widget.paymentMethod.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: isMkopo
                            ? PdfColors.red700
                            : PdfColors.black),
                  ),
                ),
              ]),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Center(
              child: pw.Text("ITEM DETAILS",
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),

          // 🔹 ITEMS TABLE
          pw.Table.fromTextArray(
            headers: [
              'Product',
              'Qty',
              'Original',
              'Disc',
              'Net Price',
              'Sub Total'
            ],
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9),
            headerDecoration:
            const pw.BoxDecoration(color: PdfColors.teal),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            data: List.generate(widget.medicineNames.length, (i) {
              double netPrice = widget.medicinePrices[i];
              double disc = fetchedDiscounts[i];
              double original = netPrice + disc;
              double sub =
                  widget.medicineQuantities[i] * netPrice;

              return [
                widget.medicineNames[i],
                widget.medicineQuantities[i].toString(),
                currencyFormatter.format(original),
                currencyFormatter.format(disc),
                currencyFormatter.format(netPrice),
                currencyFormatter.format(sub),
              ];
            }),
          ),

          pw.SizedBox(height: 15),

          // 🔹 TOTAL
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (totalSavings > 0)
                  pw.Text(
                    "DISCOUNT (PUNGUZO): TSH ${currencyFormatter.format(totalSavings)}",
                    style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.green700,
                        fontWeight: pw.FontWeight.bold),
                  ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: statusColor, width: 2)),
                  child: pw.Row(
                    mainAxisSize: pw.MainAxisSize.min,
                    children: [
                      pw.Text(
                        isMkopo
                            ? "TOTAL AMOUNT DUE: "
                            : "TOTAL PAID: ",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13),
                      ),
                      pw.Text(
                        "TSH ${currencyFormatter.format(widget.totalPrice)}",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13,
                            color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 40),

          // 🔥 BARCODE + MHURI
          pw.Center(
            child: pw.Column(
              children: [
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: widget.receiptNumber,
                  width: 180,
                  height: 60,
                  drawText: true,
                ),
                pw.SizedBox(height: 15),
                _buildBusinessSeal(context),
                pw.SizedBox(height: 10),
                pw.Text(
                  "Authorized By:\n${widget.confirmedBy.toUpperCase()}",
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
                pw.Container(
                  width: 150,
                  height: 0.5,
                  color: PdfColors.grey400,
                  margin: const pw.EdgeInsets.only(top: 5),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf;
  }


  pw.Widget _buildBusinessSeal(pw.Context context) {
    final stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
    const stampColor = PdfColors.blue;
    const secondaryStampColor = PdfColors.red900;

    return pw.Container(
      width: 170,
      height: 110,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: stampColor, width: 3.5),
      ),
      child: pw.Container(
        width: 160,
        height: 100,
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(16),
          border: pw.Border.all(color: stampColor, width: 1.0),
        ),
        padding: const pw.EdgeInsets.all(4),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              business_name.toUpperCase(),
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: stampColor),
            ),
            pw.SizedBox(height: 2),
            pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: stampColor, height: 8, thickness: 0.5),
            pw.Text(
              '${businessAddress.isNotEmpty ? businessAddress : ''}${businessAddress.isNotEmpty && businessLocation.isNotEmpty ? ' • ' : ''}${businessLocation.isNotEmpty ? businessLocation : ''}'.toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor),
            ),
            if (businessPhone.isNotEmpty)
              pw.Text('TEL: $businessPhone'.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, color: secondaryStampColor)),
            pw.SizedBox(height: 4),
            pw.Text('DATE: $stampDate', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: stampColor)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReceiptAction(String action) async {
    if (action == "share_direct") {
      // 🔥 Tumia function uliyoitengeneza tayari
      await _triggerAutoNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Notifications sent to +255...")),
        );
      }
      return;
    }

    final pdf = await _generateReceiptPdf();
    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/receipt_${widget.receiptNumber}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    if (action == "view") {
      await OpenFilex.open(filePath);
    } else if (action == "email") {
      _sendEmailWithPdf(filePath);
    } else if (action == "share_sheet") {
      await SharePlus.instance.share(
        ShareParams(
            files: [XFile(filePath)],
            text: "Risiti ya Malipo kutoka $business_name\nNamba: ${widget.receiptNumber}"
        ),
      );
    }
  }

  void _showWhatsAppOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (bc) => Wrap(
        children: [
          ListTile(leading: const Icon(Icons.picture_as_pdf), title: const Text('Share PDF File'), onTap: () { Navigator.pop(context); _handleReceiptAction("share_sheet"); }),
          ListTile(leading: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green), title: const Text('Send Full Text Receipt'), onTap: () { Navigator.pop(context); _handleReceiptAction("share_direct"); }),
        ],
      ),
    );
  }

  Future<void> _sendEmailWithPdf(String filePath) async {
    final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz', username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 465, ssl: true);
    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', business_name)
      ..recipients.add(widget.customerEmail)
      ..subject = 'Receipt #${widget.receiptNumber}'
      ..text = 'Dear ${widget.customerName}, please find your receipt attached.'
      ..attachments.add(FileAttachment(File(filePath)));
    try {
      await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Email sent!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("RECEIPT DETAILS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        // ✅ Hii inaondoa mshale (back button) kwenye AppBar
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)])
            )
        ),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
                    ),
                    child: const Column(
                        children: [
                          Icon(Icons.check_circle, size: 50, color: Colors.green),
                          Text("Transaction Successful", style: TextStyle(fontWeight: FontWeight.bold))
                        ]
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _receiptRow("Receipt #", widget.receiptNumber, textCol, subTextCol, isBold: true),
                        _receiptRow("Customer", widget.customerName, textCol, subTextCol),
                        _receiptRow("Payment", widget.paymentMethod, textCol, subTextCol),
                        _receiptRow("Staff", widget.confirmedBy, textCol, subTextCol),
                        Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey.shade200),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: Text("ITEMS PURCHASED", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.purpleAccent : Colors.deepPurple, fontSize: 12))
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(widget.medicineNames.length, (index) {
                          double sub = widget.medicineQuantities[index] * widget.medicinePrices[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text("${widget.medicineNames[index]} x${widget.medicineQuantities[index]}", style: TextStyle(fontSize: 13, color: textCol))),
                                Text("TSH ${NumberFormat('#,##0.00').format(sub)}", style: TextStyle(fontWeight: FontWeight.w600, color: textCol, fontSize: 13)),
                              ],
                            ),
                          );
                        }),
                        Divider(height: 30, color: isDark ? Colors.white10 : Colors.grey.shade200),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textCol)),
                            Text("TSH ${NumberFormat('#,##0.00').format(widget.totalPrice)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: isDark ? Colors.purpleAccent : Colors.deepPurple)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _actionButton(label: "PDF View", icon: Icons.picture_as_pdf, color: Colors.blue, onTap: () => _handleReceiptAction("view"))),
                const SizedBox(width: 12),
                Expanded(child: _actionButton(label: "Print", icon: Icons.print, color: Colors.green, onTap: () async {
                  final pdf = await _generateReceiptPdf();
                  await Printing.layoutPdf(onLayout: (f) async => pdf.save());
                })),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _actionButton(label: "WhatsApp", icon: FontAwesomeIcons.whatsapp, color: Colors.green, onTap: _showWhatsAppOptions)),
                const SizedBox(width: 12),
                Expanded(child: _actionButton(label: "Email", icon: Icons.email, color: Colors.orange, onTap: () => _handleReceiptAction("email"))),
              ],
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.shopping_cart_checkout, color: Colors.white),
                label: const Text(
                  "BACK TO SALES",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF311B92),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _receiptRow(String l, String v, Color c, Color sc, {bool isBold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(color: sc, fontSize: 13)), Text(v, style: TextStyle(color: c, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 13))]),
  );

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.5))),
      child: Column(children: [FaIcon(icon, color: color), const SizedBox(height: 5), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12))]),
    ),
  );
}