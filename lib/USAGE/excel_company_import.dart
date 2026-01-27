import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'dart:io';

import '../DB/database_helper.dart'; // Adjust the path as needed

class ExcelCompanyImport extends StatefulWidget {
  @override
  _ExcelCompanyImportState createState() => _ExcelCompanyImportState();
}

class _ExcelCompanyImportState extends State<ExcelCompanyImport> {
  List<List<Data?>> companyData = [];
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

          parsedColumns = rows[0];

          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];

            if (row.every((cell) => cell == null || cell.value.toString().trim().isEmpty)) {
              continue;
            }

            parsedData.add(row);
          }
          break;
        }

        setState(() {
          columns = parsedColumns;
          companyData = parsedData;
        });
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

  Future<void> insertCompaniesToDB(List<List<Data?>> parsedData) async {
    for (var row in parsedData) {
      if (row.length >= 2) {
        var name = row[0]?.value.toString().trim() ?? '';
        var address = row[1]?.value.toString().trim() ?? '';

        Map<String, dynamic> company = {
          'name': name,
          'address': address,
        };

        await DatabaseHelper.instance.insertCompany(company);
      } else {
        print("Skipping row due to insufficient columns: ${row.map((e) => e?.value)}");
      }
    }
  }

  void saveToDatabase() async {
    if (companyData.isNotEmpty) {
      setState(() => isLoading = true);

      await insertCompaniesToDB(companyData);

      setState(() {
        isLoading = false;
        companyData.clear();
        columns.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company data saved to database!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No data to save. Please load Excel file first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Import Companies",style: const TextStyle(color: Colors.white),),
        backgroundColor: Colors.blue,
        centerTitle: true,
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
              onPressed: pickAndReadExcelFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
              ),
              child: Text("Pick Excel File"),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: saveToDatabase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text("Map to SQLite"),
            ),
            SizedBox(height: 10),
            isLoading
                ? Center(child: CircularProgressIndicator())
                : Expanded(
              child: companyData.isNotEmpty
                  ? SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor:
                    MaterialStateProperty.all(Colors.grey[300]),
                    columns: columns.map((e) {
                      return DataColumn(
                        label: Text(
                          e?.value.toString() ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    rows: companyData.map((row) {
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
                  : Center(child: Text("No data loaded")),
            ),
          ],
        ),
      ),
    );
  }
}
