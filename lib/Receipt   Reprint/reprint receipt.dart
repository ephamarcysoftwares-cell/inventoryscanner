import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class AllReceiptsScreen extends StatefulWidget {
  const AllReceiptsScreen({super.key});

  @override
  _AllReceiptsScreenState createState() => _AllReceiptsScreenState();
}

class _AllReceiptsScreenState extends State<AllReceiptsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  TextEditingController _searchController = TextEditingController();
  bool _exactMatch = false;
  List<Map<String, dynamic>> _allReceipts = [];
  List<Map<String, dynamic>> _filteredReceipts = [];

  String businessName = '';
  int? businessId;
  pw.MemoryImage? globalLogo;
  String businessEmail = '';
  String businessAddress= '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';

  final Map<String, TextEditingController> _emailControllers = {};
  final Set<String> _sendingEmails = {};

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
    _fetchReceipts();
  }

  @override
  void dispose() {
    for (final controller in _emailControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReceipts() async {
    debugPrint("🚀 _fetchReceipts imeanza...");

    // 1. Hakikisha tuna businessId
    if (businessId == null) {
      debugPrint("⚠️ businessId ni NULL, tunaita getBusinessInfo...");
      await getBusinessInfo(); // Hii sasa itaupdate class variable 'businessId'

      // Angalia tena baada ya await
      if (businessId == null) {
        debugPrint("❌ businessId bado ni NULL baada ya getBusinessInfo. Fetch imesitishwa.");
        return;
      }
    }

    debugPrint("🆔 Inatafuta data kwa Business ID: $businessId");

    final supabase = Supabase.instance.client;
    String start = _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : '';
    String end = _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : '';

    try {
      // 2. Query SALES - Zimefungwa na business_id pekee
      var salesQuery = supabase
          .from('sales')
          .select()
          .eq('business_id', businessId!); // ✅ Filter muhimu

      // 3. Query TO_LEND - Zimefungwa na business_id pekee
      var lendQuery = supabase
          .from('To_lend')
          .select()
          .eq('business_id', businessId!); // ✅ Filter muhimu

      // Ongeza filters za tarehe kama zipo
      if (start.isNotEmpty) {
        salesQuery = salesQuery.gte('confirmed_time', '$start 00:00:00');
        lendQuery = lendQuery.gte('confirmed_time', '$start 00:00:00');
      }
      if (end.isNotEmpty) {
        salesQuery = salesQuery.lte('confirmed_time', '$end 23:59:59');
        lendQuery = lendQuery.lte('confirmed_time', '$end 23:59:59');
      }

      final results = await Future.wait([
        salesQuery.order('confirmed_time', ascending: false),
        lendQuery.order('confirmed_time', ascending: false),
      ]);

      // ... (Logic yako ya grouping inabaki vilevile)

      final List<Map<String, dynamic>> salesData = List<Map<String, dynamic>>.from(results[0]);
      final List<Map<String, dynamic>> lendData = List<Map<String, dynamic>>.from(results[1]);

      final List<Map<String, dynamic>> rawData = [...salesData, ...lendData];

      // --- GROUPING LOGIC ---
      Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var row in rawData) {
        String rNum = row['receipt_number']?.toString() ?? 'N/A';
        grouped.putIfAbsent(rNum, () => []).add(row);
      }

      List<Map<String, dynamic>> finalReceipts = grouped.entries.map((entry) {
        var items = entry.value;
        var first = items.first;
        double total = items.fold(0.0, (sum, item) =>
        sum + (double.tryParse(item['total_price'].toString()) ?? 0.0));

        return {
          ...first,
          'total_price': total,
          'grouped_items': items,
          'is_mkopo': first['payment_method']?.toString().toUpperCase().contains('LEND') ?? false,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _allReceipts = finalReceipts;
        _filteredReceipts = finalReceipts;
      });

    } catch (e) {
      debugPrint("‼️ ERROR: $e");
    }
  }

  // Tunaita kwa mtiririko ili kuhakikisha businessId ipo kabla ya kutafuta receipts
  Future<void> _initData() async {
    await getBusinessInfo();
    await _fetchReceipts();
  }

  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata Profile ya mtumiaji kwanza
      final userData = await supabase
          .from('users')
          .select('business_id, business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userData == null) return;

      // Hapa tunapata ID sahihi (Mfano: 58)
      final int? sessionBusinessId = userData['business_id'] != null
          ? int.tryParse(userData['business_id'].toString())
          : null;

      if (sessionBusinessId != null) {
        // 2. Tafuta taarifa za biashara kwa kutumia ID (Hii ni accurate zaidi kuliko jina)
        final businessData = await supabase
            .from('businesses')
            .select()
            .eq('id', sessionBusinessId)
            .maybeSingle();

        if (businessData != null && mounted) {
          setState(() {
            // 🔥 Hapa tunahakikisha variable ya class inapata ID sahihi (58)
            businessId = sessionBusinessId;

            businessName = businessData['business_name']?.toString() ?? '';
            businessEmail = businessData['email']?.toString() ?? '';
            businessPhone = businessData['phone']?.toString() ?? '';
            businessLogoPath = businessData['logo']?.toString() ?? '';
          });

          debugPrint("✅ Business Info Loaded: $businessName (ID: $businessId)");

          // 3. Sasa ita receipts kwa kutumia ID hii
          _fetchReceipts();
        }
      }
    } catch (e) {
      debugPrint('❌ Error Fetching Business Info: $e');
    }
  }

  void _updateUI(Map<String, dynamic> data) {
    setState(() {
      businessName = data['business_name']?.toString() ?? '';
      businessEmail = data['email']?.toString() ?? '';
      businessPhone = data['phone']?.toString() ?? '';
      businessLocation = data['location']?.toString() ?? '';
      businessLogoPath = data['logo']?.toString() ?? '';
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
      });
      await _fetchReceipts();
      _filterReceipts(_searchController.text);
    }
  }

  void _filterReceipts(String term) {
    setState(() {
      if (term.isEmpty) {
        _filteredReceipts = _allReceipts;
      } else {
        final search = term.toLowerCase();
        _filteredReceipts = _allReceipts.where((receipt) {
          return receipt['customer_name'].toString().toLowerCase().contains(search) ||
              receipt['receipt_number'].toString().toLowerCase().contains(search);
        }).toList();
      }
    });
  }
  Future<void> fetchLogo() async {
    if (businessLogoPath.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(businessLogoPath));
      if (response.statusCode == 200) {
        setState(() {
          globalLogo = pw.MemoryImage(response.bodyBytes);
        });
        debugPrint("✅ Logo kutoka main branch imepakiwa.");
      }
    } catch (e) {
      debugPrint("❌ Logo fetch error: $e");
    }
  }
  pw.Widget _buildBusinessSeal(pw.Context context) {
    final stampDate = DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
    final stampColor = PdfColors.blue;
    return pw.Container(
      width: 170, height: 110,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(20), border: pw.Border.all(color: stampColor, width: 3.5)),
      child: pw.Container(
        width: 160, height: 100,
        decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(16), border: pw.Border.all(color: stampColor, width: 1.0)),
        padding: pw.EdgeInsets.all(4),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(businessName.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: stampColor)),
            pw.SizedBox(height: 3),
            pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
            pw.Divider(color: stampColor, height: 8, thickness: 0.5),
            pw.Text('${businessAddress} ${businessLocation}'.toUpperCase(), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900)),
            pw.Text('TEL: ${businessPhone}'.toUpperCase(), style: pw.TextStyle(fontSize: 6.5, color: PdfColors.red900)),
            pw.SizedBox(height: 5),
            pw.Text('DATE: $stampDate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: stampColor)),
          ],
        ),
      ),
    );
  }
  Future<void> _printThermalReceipt(Map<String, dynamic> receipt) async {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat('#,##0', 'en_US');
    final items = receipt['grouped_items'] as List;

    // Rangi ya Kijani (Teal) kama software yako
    final PdfColor themeColor = PdfColor.fromInt(0xFF008080);

    pdf.addPage(
      pw.Page(
        // 164 points ni upana wa standard 58mm thermal paper
        pageFormat: const PdfPageFormat(164, double.infinity, marginAll: 5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              pw.Center(
                child: pw.Text("RECEIPT",
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: themeColor)),
              ),
              pw.Center(
                child: pw.Text(businessName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ),
              pw.Center(
                child: pw.Text("TEL: $businessPhone", style: pw.TextStyle(fontSize: 6.5)),
              ),
              pw.Divider(thickness: 1, color: themeColor),

              // --- INFO GRID (Kama picha yako) ---
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
                children: [
                  _buildThermalInfoRow("NO:", "${receipt['receipt_number']}", 6),
                  _buildThermalInfoRow("MTEJA:", "${receipt['customer_name'] ?? 'WALK-IN'}", 6),
                  _buildThermalInfoRow("TAREHE:", "${receipt['confirmed_time']}", 5.5),
                ],
              ),

              pw.SizedBox(height: 5),

              // --- ITEMS TABLE (Inayofata rangi ya software yako) ---
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.3),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  // Header ya Jedwali
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: themeColor),
                    children: [
                      _buildThermalCell("Item", 6, PdfColors.white, true),
                      _buildThermalCell("Qty", 6, PdfColors.white, true),
                      _buildThermalCell("Total", 6, PdfColors.white, true),
                    ],
                  ),
                  // Data ya bidhaa
                  ...items.map((i) => pw.TableRow(
                    children: [
                      _buildThermalCell("${i['medicine_name']}", 6, PdfColors.black, false),
                      _buildThermalCell("${i['remaining_quantity']}", 6, PdfColors.black, false),
                      _buildThermalCell(currencyFormatter.format(i['total_price']), 6, PdfColors.black, false),
                    ],
                  )).toList(),
                ],
              ),

              // --- TOTAL BOX ---
              pw.SizedBox(height: 3),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(2),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: themeColor, width: 1)),
                  child: pw.Text(
                    "TOTAL: TSH ${currencyFormatter.format(receipt['total_price'])}",
                    style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: themeColor),
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              // --- WATERMARK "PAID" (Ndogo ya Thermal) ---
              pw.Center(
                child: pw.Text("--- PAID ---",
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey400)),
              ),

              // --- BARCODE ---
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Container(
                  height: 20,
                  width: 100,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: "${receipt['receipt_number']}",
                    drawText: false,
                  ),
                ),
              ),

              // --- STEMPU YA BLUU (Inayofanana na ya picha) ---
              pw.SizedBox(height: 5),
              pw.Center(child: _buildSmallBlueStampForThermal()),

              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text("KARIBU TENA", style: pw.TextStyle(fontSize: 5, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    // Amuru printer i-print PDF hii
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

// --- HELPER WIDGETS KWA AJILI YA THERMAL ---

  pw.TableRow _buildThermalInfoRow(String label, String value, double size) {
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(1), child: pw.Text(label, style: pw.TextStyle(fontSize: size, fontWeight: pw.FontWeight.bold))),
      pw.Padding(padding: const pw.EdgeInsets.all(1), child: pw.Text(value, style: pw.TextStyle(fontSize: size))),
    ]);
  }

  pw.Widget _buildThermalCell(String text, double size, PdfColor color, bool isHeader) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(1.5),
      child: pw.Text(text,
          textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: size, color: color, fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  pw.Widget _buildSmallBlueStampForThermal() {
    return pw.Container(
      width: 70,
      padding: const pw.EdgeInsets.all(2),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue, width: 0.8),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        children: [
          pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 4, color: PdfColors.blue, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
          pw.Text("OFFICIAL STAMP", style: pw.TextStyle(fontSize: 3, color: PdfColors.red)),
          pw.Text("DATE: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: pw.TextStyle(fontSize: 4, color: PdfColors.blue)),
        ],
      ),
    );
  }
  pw.Document _generateReceiptPdf(
      Map<String, dynamic> receipt,
      pw.MemoryImage? logoImage,
      ) {
    final pdf = pw.Document();
    final currencyFormatter = NumberFormat('#,##0.00', 'en_US');
    final items = receipt['grouped_items'] as List;

    final String rawMethod =
    (receipt['payment_method'] ?? '').toString().trim().toUpperCase();
    final bool isMkopo =
        rawMethod.contains("LEND") || rawMethod.contains("MKOPO");

    final String documentTitle = isMkopo ? "INVOICE" : "RECEIPT";
    final String statusText = isMkopo ? "UNPAID" : "PAID";

    final PdfColor primaryThemeColor =
    isMkopo ? PdfColors.red700 : PdfColors.teal700;
    final PdfColor watermarkColor =
    isMkopo ? PdfColors.red100 : PdfColors.green100;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => pw.Column(
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 80,
                    height: 80,
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  )
                else
                  pw.SizedBox(width: 80, height: 80),

                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        documentTitle,
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryThemeColor,
                        ),
                      ),
                      pw.Text(
                        businessName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("Phone: $businessPhone",
                          style: pw.TextStyle(fontSize: 9)),
                      if (businessEmail.isNotEmpty)
                        pw.Text("Email: $businessEmail",
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
            pw.Divider(thickness: 2, color: primaryThemeColor),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) => [
          pw.Stack(
            children: [
              // 🔹 WATERMARK
              pw.Opacity(
                opacity: 0.1,
                child: pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.only(top: 100),
                  child: pw.Transform.rotate(
                    angle: 0.5,
                    child: pw.Text(
                      statusText,
                      style: pw.TextStyle(
                        fontSize: 130,
                        fontWeight: pw.FontWeight.bold,
                        color: watermarkColor,
                      ),
                    ),
                  ),
                ),
              ),

              // 🔹 CONTENT
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Table(
                    border: pw.TableBorder.all(
                        width: 0.5, color: PdfColors.grey300),
                    children: [
                      _buildInfoRow(
                        "$documentTitle NO:",
                        "${receipt['receipt_number'] ?? 'N/A'}",
                        true,
                      ),
                      _buildInfoRow(
                        "CUSTOMER:",
                        "${(receipt['customer_name'] ?? 'WALK-IN').toString().toUpperCase()}",
                        false,
                      ),
                      _buildInfoRow(
                        "PAYMENT:",
                        isMkopo ? "DEBIT (MKOPO)" : rawMethod,
                        false,
                        isMkopo ? PdfColors.red700 : PdfColors.black,
                      ),
                      _buildInfoRow(
                        "DATE:",
                        "${receipt['confirmed_time'] ?? 'N/A'}",
                        false,
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 25),
                  pw.Text(
                    "ITEM DETAILS",
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                      color: primaryThemeColor,
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  pw.Table.fromTextArray(
                    context: context,
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                    headerDecoration:
                    pw.BoxDecoration(color: primaryThemeColor),
                    cellStyle: pw.TextStyle(fontSize: 9),
                    headers: ['Description', 'Qty', 'Unit Price', 'Total'],
                    data: items
                        .map(
                          (i) => [
                        "${i['medicine_name']}",
                        "${i['remaining_quantity']}",
                        "TSH ${currencyFormatter.format(i['price'] ?? 0)}",
                        "TSH ${currencyFormatter.format(i['total_price'])}",
                      ],
                    )
                        .toList(),
                  ),

                  pw.SizedBox(height: 20),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: primaryThemeColor, width: 2),
                      ),
                      child: pw.Text(
                        "${isMkopo ? 'TOTAL DUE: ' : 'TOTAL PAID: '}TSH ${currencyFormatter.format(receipt['total_price'])}",
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: primaryThemeColor,
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: 40),

                  // 🔥 BARCODE + MHURI
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data:
                          (receipt['receipt_number'] ?? 'N/A')
                              .toString(),
                          width: 180,
                          height: 60,
                          drawText: true,
                        ),
                        pw.SizedBox(height: 15),
                        _buildBusinessSeal(context),
                        pw.SizedBox(height: 10),
                        pw.Text(
                          "AUTHORIZED BY: ${(receipt['confirmed_by'] ?? 'STAFF').toString().toUpperCase()}",
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return pdf;
  }

// Helper Widget kwa ajili ya Table Rows ili kupunguza marudio ya kodi
  pw.TableRow _buildInfoRow(String label, String value, bool isBold, [PdfColor? textColor]) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.black,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _printReceipt(Map<String, dynamic> receipt) async {
    // 1. Tumia globalLogo kama tayari ipo ili kuongeza kasi (Efficiency)
    pw.MemoryImage? logoImage = globalLogo;

    // 2. Ikiwa globalLogo ni null (mfano internet ilizingua mwanzo), jaribu kuipakua sasa
    if (logoImage == null && businessLogoPath.isNotEmpty) {
      try {
        debugPrint("🔄 Logo haikuwepo kwenye memory, tunajaribu kuipakua sasa...");
        final response = await http.get(Uri.parse(businessLogoPath.trim()));

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          if (bytes.isNotEmpty) {
            logoImage = pw.MemoryImage(bytes);
            // Optional: Irasishe globalLogo ili isipakue tena baadae
            globalLogo = logoImage;
          }
        }
      } catch (e) {
        debugPrint("❌ Imeshindwa kupakua logo kwenye Print: $e");
      }
    }

    // 3. Tengeneza PDF
    // Tunapitisha 'logoImage' (inaweza kuwa na picha au iwe null kama imeshindikana)
    final pdf = _generateReceiptPdf(receipt, logoImage);

    // 4. Onyesha Print Preview
    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Receipt_${receipt['receipt_number']}',
      );
    } catch (e) {
      debugPrint("❌ Printing Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imeshindwa kufungua printa')),
        );
      }
    }
  }

  Future<void> _sendEmailWithAttachment(Map<String, dynamic> receipt) async {
    final rNum = receipt['receipt_number'].toString();
    setState(() => _sendingEmails.add(rNum));

    pw.MemoryImage? logoImage;

    // 1. Download the logo first (Same logic as _printReceipt)
    if (businessLogoPath.isNotEmpty && businessLogoPath.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(businessLogoPath));
        if (response.statusCode == 200) {
          logoImage = pw.MemoryImage(response.bodyBytes);
        }
      } catch (e) {
        debugPrint("Logo download error for email: $e");
      }
    }

    // 2. Pass the logoImage to the generator
    final pdf = _generateReceiptPdf(receipt, logoImage);

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/receipt_$rNum.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    try {
      await _sendEmailWithPdf(
          filePath,
          _emailControllers[rNum]?.text.trim() ?? receipt['customer_email'],
          receipt['customer_name']
      );
    } finally {
      setState(() => _sendingEmails.remove(rNum));
    }
  }

  Future<void> _sendEmailWithPdf(String filePath, String email, String customerName) async {
    final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz', username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 465, ssl: true);
    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', businessName)
      ..recipients.add(email)
      ..subject = 'Receipt from $businessName'
      ..text = 'Dear $customerName,\n\nHere is your receipt.\n\nBest regards,\n$businessName'
      ..attachments.add(FileAttachment(File(filePath)));
    try {
      await send(message, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email sent to $email')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send email')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        toolbarHeight: 90,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "ALL RECEIPTS",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              "BRANCH: ${businessName.trim().toUpperCase()}",
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w300),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // --- Date Selectors Row ---
            Row(
              children: [
                Expanded(
                  child: _buildDateButton(
                    _startDate == null ? 'Start Date' : DateFormat('dd/MM/yyyy').format(_startDate!),
                        () => _selectDate(context, true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateButton(
                    _endDate == null ? 'End Date' : DateFormat('dd/MM/yyyy').format(_endDate!),
                        () => _selectDate(context, false),
                  ),
                ),
              ],
            ),

            // --- Search Bar with Shadow Fix ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search receipts...',
                    prefixIcon: const Icon(Icons.search, color: primaryPurple),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (v) => _filterReceipts(v),
                ),
              ),
            ),

            // --- Receipts List ---
            Expanded(
              child: _filteredReceipts.isEmpty
                  ? const Center(child: Text('No receipts found', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: _filteredReceipts.length,
                itemBuilder: (context, index) {
                  final receipt = _filteredReceipts[index];
                  final rNum = receipt['receipt_number'].toString();
                  // Pata jina la tawi kutoka kwenye data ya risiti
                  final branchName = receipt['business_name']?.toString().toUpperCase() ?? businessName.toUpperCase();

                  if (!_emailControllers.containsKey(rNum)) {
                    _emailControllers[rNum] = TextEditingController(
                        text: receipt['customer_email']?.toString() ?? '');
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- SEHEMU MPYA YA BRANCH ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront, size: 14, color: primaryPurple),
                                    const SizedBox(width: 4),
                                    Text(
                                      "BRANCH: $branchName",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: primaryPurple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                DateFormat('dd MMM, HH:mm').format(DateTime.parse(receipt['confirmed_time'])),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Receipt #: $rNum",
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87)),
                              const Icon(Icons.verified, color: Colors.blue, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(receipt['customer_name']?.toString().toUpperCase() ?? "WALK-IN CUSTOMER",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),

                          const Divider(height: 24),

                          const Text("ITEMS PURCHASED",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey, letterSpacing: 1.1)),
                          const SizedBox(height: 8),
                          ...(receipt['grouped_items'] as List).map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.circle, size: 6, color: primaryPurple),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text("${item['medicine_name']} (${item['remaining_quantity']})",
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          )),

                          const SizedBox(height: 16),

                          // Email Field inside card
                          SizedBox(
                            height: 45,
                            child: TextField(
                              controller: _emailControllers[rNum],
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Customer Email',
                                prefixIcon: const Icon(Icons.email_outlined, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Payment Summary
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Total: TSH ${NumberFormat('#,###').format(receipt['total_price'])}",
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.teal)),
                                  Text("Staff: ${receipt['confirmed_by']}",
                                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                              // Nimehamishia Tarehe juu ili kuweka uwiano (Balance)
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                // Tumebadilisha function hapa iwe _printThermalReceipt
                                child: _buildActionBtn(
                                    Icons.print_rounded,
                                    "Thermal Print",
                                    const Color(0xFF008080), // Rangi ya Teal (Kijani)
                                        () => _printThermalReceipt(receipt)
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _sendingEmails.contains(rNum)
                                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                    : _buildActionBtn(
                                    Icons.send_rounded,
                                    "Email",
                                    primaryPurple,
                                        () => _sendEmailWithAttachment(receipt)
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(),
    );
  }

// --- Helper UI Widgets ---

  Widget _buildDateButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today, size: 14, color: Color(0xFF673AB7)),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}