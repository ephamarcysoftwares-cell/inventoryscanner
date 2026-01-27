import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../API/payment_alternative.dart'; // DatabaseHelper import

class ContractFormPage extends StatefulWidget {
  @override
  _ContractFormPageState createState() => _ContractFormPageState();
}

class _ContractFormPageState extends State<ContractFormPage> {
  // Business info
  String businessName = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';

  // Employee info
  final nameController = TextEditingController();
  final idController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final locationController = TextEditingController();
  final jobController = TextEditingController();
  final salaryController = TextEditingController();

  // Contract period
  final startDateController = TextEditingController();
  final endDateController = TextEditingController();

  // Terms, Duties, Witness
  final termsController = TextEditingController();
  final dutiesController = TextEditingController();
  final witnessController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadBusinessInfo();
  }

  Future<void> loadBusinessInfo() async {
    try {
      final db = await DatabaseHelper.instance.database;
      List<Map<String, dynamic>> result = await db.rawQuery('SELECT * FROM businesses');
      if (result.isNotEmpty) {
        setState(() {
          businessName = result[0]['business_name'] ?? '';
          businessEmail = result[0]['email'] ?? '';
          businessPhone = result[0]['phone'] ?? '';
          businessLocation = result[0]['location'] ?? '';
          businessLogoPath = result[0]['logo'] ?? '';
        });
      }
    } catch (e) {
      print("Error loading business info: $e");
    }
  }

  Future<void> _generateContract() async {
    final pdf = pw.Document();

    final termsList = termsController.text.split("\n").where((t) => t.trim().isNotEmpty).toList();
    final dutiesList = dutiesController.text.split("\n").where((t) => t.trim().isNotEmpty).toList();
    final witnessList = witnessController.text.split("\n").where((t) => t.trim().isNotEmpty).toList();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Business info header
            if (businessLogoPath.isNotEmpty) ...[
              pw.Center(
                child: pw.Image(
                  pw.MemoryImage(File(businessLogoPath).readAsBytesSync()),
                  width: 80,
                  height: 80,
                ),
              ),
              pw.SizedBox(height: 10),
            ],
            pw.Center(
              child: pw.Text(
                businessName,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Center(child: pw.Text(businessLocation)),
            pw.Center(child: pw.Text("Email: $businessEmail | Phone: $businessPhone")),
            pw.Divider(),
            pw.SizedBox(height: 20),

            // Employee info
            pw.Text(
              "Mimi, ${nameController.text}, mwenye Kitambulisho namba ${idController.text}, "
                  "ninaishi ${locationController.text}, simu ${phoneController.text}, barua pepe ${emailController.text}, "
                  "nakubali kufanya kazi kama ${jobController.text}.",
            ),
            pw.SizedBox(height: 10),
            pw.Text(
              "Mkataba huu unaanza tarehe ${startDateController.text} hadi tarehe ${endDateController.text}, "
                  "na mshahara wa TZS ${salaryController.text} kwa mwezi.",
            ),
            pw.SizedBox(height: 15),

            // Terms & Conditions
            pw.Text(
              "Masharti ya Kazi (Terms & Conditions):",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...(
                termsList.isNotEmpty
                    ? termsList
                    : [
                  "Kufanya kazi kwa saa 8 kila siku",
                  "Likizo ya siku 28 kwa mwaka",
                  "Kutunza siri za kampuni",
                  "Kuwajibika kwa uadilifu na usahihi",
                  "Kufuata sheria na taratibu za kampuni"
                ]
            ).map((term) => pw.Bullet(text: term)).toList(),

            pw.SizedBox(height: 20),

            // Duties
            pw.Text(
              "Majukumu ya Mfanyakazi:",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            ...dutiesList.map((duty) => pw.Bullet(text: duty)).toList(),

            // Breach of Contract
            pw.SizedBox(height: 20),
            pw.Text(
              "Uvunji wa Mkataba (Breach of Contract):",
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Bullet(
                text: "Mfanyakazi anapovunja masharti ya mkataba, mwajiri ana haki ya kumalizia ajira baada ya kutoa notisi stahiki."),
            pw.Bullet(
                text: "Mwajiri anapovunja masharti ya mkataba bila sababu halali, mfanyakazi ana haki ya madai ya fidia kulingana na sheria."),
            pw.Bullet(
                text: "Kila upande lazima utoe notisi ya angalau siku 30 kabla ya kumalizia mkataba, isipokuwa pale ambapo masharti ya dharura yanahitajika."),

            // Employee acceptance sentence
            pw.SizedBox(height: 20),
            pw.Text(
              "MWAMBI, MIMI (${nameController.text}), NAKUBALI MASHARTI YALIYOPO KWENYE MKATABA HUU NA NAKUBALI KUFANYA KAZI KWENYE ${businessName.toUpperCase()}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 30),

            // Witness
            if (witnessList.isNotEmpty) ...[
              pw.Text(
                "Mashahidi:",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ...witnessList.map((w) => pw.Bullet(text: w)).toList(),
              pw.SizedBox(height: 20),
            ],

            // Signatures
            pw.Text("Sahihi ya Mfanyakazi: __________________"),
            pw.SizedBox(height: 40),
            pw.Text("Sahihi ya Mwajiri (Manager/Admin): __________________"),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin - Tengeneza Mkataba Kamili")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Employee info
            TextField(controller: nameController, decoration: InputDecoration(labelText: "Jina Kamili")),
            TextField(controller: idController, decoration: InputDecoration(labelText: "Namba ya Kitambulisho")),
            TextField(controller: phoneController, decoration: InputDecoration(labelText: "Namba ya Simu")),
            TextField(controller: emailController, decoration: InputDecoration(labelText: "Barua Pepe")),
            TextField(controller: locationController, decoration: InputDecoration(labelText: "Makazi / Location")),
            TextField(controller: jobController, decoration: InputDecoration(labelText: "Kazi / Wadhifa")),
            TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Mshahara (TZS)")),

            // Contract period
            TextField(
              controller: startDateController,
              decoration: InputDecoration(labelText: "Tarehe ya Kuanza"),
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );
                if (picked != null) {
                  startDateController.text = "${picked.day}/${picked.month}/${picked.year}";
                }
              },
            ),
            TextField(
              controller: endDateController,
              decoration: InputDecoration(labelText: "Tarehe ya Kumalizia"),
              readOnly: true,
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );
                if (picked != null) {
                  endDateController.text = "${picked.day}/${picked.month}/${picked.year}";
                }
              },
            ),

            // Terms
            TextField(
              controller: termsController,
              decoration: InputDecoration(
                labelText: "Masharti ya Kazi (Terms & Conditions)",
                hintText: "- Kufanya kazi kwa saa 8 kila siku\n- Likizo ya siku 28 kwa mwaka\n- Kutunza siri za kampuni",
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),

            // Duties
            TextField(
              controller: dutiesController,
              decoration: InputDecoration(
                labelText: "Majukumu ya Mfanyakazi (Employee Duties)",
                hintText: "- Kufika kazini kwa wakati\n- Kutekeleza majukumu kwa uadilifu\n- Kuheshimu sheria za kampuni",
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              keyboardType: TextInputType.multiline,
            ),

            // Witnesses
            TextField(
              controller: witnessController,
              decoration: InputDecoration(
                labelText: "Mashahidi (optional)",
                hintText: "- Jina la Shahidi 1\n- Jina la Shahidi 2",
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              keyboardType: TextInputType.multiline,
            ),

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _generateContract,
              child: Text("Tengeneza Mkataba (PDF)"),
            ),
          ],
        ),
      ),
    );
  }
}
