import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';

import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart'; // Import your database helper

class ExcelReaderScreen extends StatefulWidget {
  @override
  _ExcelReaderScreenState createState() => _ExcelReaderScreenState();
}

class _ExcelReaderScreenState extends State<ExcelReaderScreen> {
  List<List<Data?>> excelData = [];
  List<Data?> columns = [];
  bool isLoading = false;

  Future<void> pickAndReadExcelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        final bytes = file.readAsBytesSync();
        final excel = Excel.decodeBytes(bytes);

        List<List<Data?>> parsedData = [];
        List<Data?> parsedColumns = [];

        for (var table in excel.tables.keys) {
          final rows = excel.tables[table]!.rows;

          if (rows.isEmpty) return;

          parsedColumns = rows[0]; // First row is the column headers

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];

            if (row.every((cell) => cell == null || cell.value.toString().trim().isEmpty)) {
              continue;
            }

            parsedData.add(row);
          }
          break; // Only process the first sheet
        }

        setState(() {
          columns = parsedColumns;
          excelData = parsedData;
        });

        // Debug print rows
        for (var row in parsedData) {
          var unit = row.length > 12 ? row[12]?.value.toString().trim() ?? '' : '';
          print("Parsed UNIT: '$unit'");
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No file selected')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading the file: $e')),
      );
    }
  }

  Future<void> insertExcelDataToDB(List<List<Data?>> parsedData) async {
    for (var row in parsedData) {
      if (row.length >= 14) {
        var name = row[0]?.value.toString().trim() ?? '';
        var company = row[1]?.value.toString().trim() ?? '';
        var totalQuantity = int.tryParse(row[2]?.value.toString().trim() ?? '0') ?? 0;
        var remainingQuantity = int.tryParse(row[3]?.value.toString().trim() ?? '0') ?? 0;
        var price = double.tryParse(row[4]?.value.toString().trim() ?? '0') ?? 0.0;
        var finalPrice = double.tryParse(row[5]?.value.toString().trim() ?? '0') ?? 0.0;
        var buy = double.tryParse(row[6]?.value.toString().trim() ?? '0') ?? 0.0;
        var discount = double.tryParse(row[7]?.value.toString().trim() ?? '0') ?? 0.0;
        var manufactureDate = row[8]?.value.toString().trim() ?? '';
        var expiryDate = row[9]?.value.toString().trim() ?? '';
        var batchNumber = row[10]?.value.toString().trim() ?? '';
        var addedBy = row[11]?.value.toString().trim() ?? '';
        var unit = row[12]?.value.toString().trim() ?? '';
        var addedTime = row[13]?.value.toString().trim() ?? DateTime.now().toIso8601String();

        Map<String, dynamic> medicine = {
          'name': name,
          'company': company,
          'total_quantity': totalQuantity,
          'remaining_quantity': remainingQuantity,
          'price': price,
          // 'finalPrice': finalPrice, // include if needed
          'buy': buy,
          'discount': discount,
          'manufacture_date': manufactureDate,
          'expiry_date': expiryDate,
          'batchNumber': batchNumber,
          'unit': unit,
          'added_by': addedBy,
          'added_time': addedTime,
        };

        await DatabaseHelper.instance.insertMedicine(medicine);
      } else {
        print("Skipping row due to insufficient columns: ${row.map((e) => e?.value)}");
      }
    }
  }

  void saveToDatabase() async {
    if (excelData.isNotEmpty) {
      setState(() => isLoading = true);

      await insertExcelDataToDB(excelData);

      setState(() {
        isLoading = false;
        excelData.clear();
        columns.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data saved to database!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to save. Please load Excel data first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Excel Data in Table",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload Excel File',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: pickAndReadExcelFile,
              child: Text("Pick Excel File", style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: saveToDatabase,
              child: Text("Map to SQLite", style: TextStyle(fontSize: 16)),
            ),
            SizedBox(height: 10),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
              child: excelData.isNotEmpty
                  ? SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                        Colors.blueGrey.shade200),
                    columns: columns.map((e) {
                      return DataColumn(
                        label: Text(
                          e?.value.toString() ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    rows: excelData.map((row) {
                      return DataRow(
                        cells: row.map((e) {
                          return DataCell(
                            Text(e?.value.toString() ?? ''),
                          );
                        }).toList(),
                      );
                    }).toList(),
                  ),
                ),
              )
                  : Center(
                  child: Text("No data to display",
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey))),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
