import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../DB/database_helper.dart';

class MigrationLogsScreen extends StatefulWidget {
  @override
  _MigrationLogsScreenState createState() => _MigrationLogsScreenState();
}

class _MigrationLogsScreenState extends State<MigrationLogsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = ''; // To store the search query

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Migration Logs",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: Column(
        children: [
          // Date Pickers in One Line
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,  // Space the buttons evenly
              children: [
                // Start Date Picker Button
                ElevatedButton(
                  onPressed: () async {
                    // Show date picker for start date
                    DateTime? pickedDate = await _selectDate(context);
                    if (pickedDate != null) {
                      setState(() {
                        _startDate = pickedDate;
                      });
                    }
                  },
                  child: Text(
                    _startDate == null
                        ? 'Select Start Date'
                        : 'Start Date: ${_formatDate(_startDate!)}', // Format and show the selected date
                  ),
                ),

                // End Date Picker Button
                ElevatedButton(
                  onPressed: () async {
                    // Show date picker for end date
                    DateTime? pickedDate = await _selectDate(context);
                    if (pickedDate != null) {
                      setState(() {
                        _endDate = pickedDate;
                      });
                    }
                  },
                  child: Text(
                    _endDate == null
                        ? 'Select End Date'
                        : 'End Date: ${_formatDate(_endDate!)}', // Format and show the selected date
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
              decoration: InputDecoration(
                labelText: 'Search by product Name',
                suffixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Apply Filter Button
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {});  // Trigger re-fetch of migration logs based on the selected date range
              },
              child: Text('Apply Date Filter'),
            ),
          ),

          // Display Data Table with Migration Logs
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _getMigrationLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No migration logs found.'));
                }

                final logs = snapshot.data!;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal, // Enable horizontal scroll
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,  // Enable vertical scroll
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Medicine Name')),
                        DataColumn(label: Text('Qty')),
                        DataColumn(label: Text('Company')),
                        DataColumn(label: Text('Batch Number')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Business')),
                        DataColumn(label: Text('Migrated By')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: logs.map((log) {
                        return DataRow(cells: [
                          DataCell(Text('${log['medicine_name']}')),
                          DataCell(Text('${log['quantity_migrated']}')),
                          DataCell(Text('${log['company']}')),
                          DataCell(Text('${log['batchNumber']}')),
                          DataCell(Text('${log['status']}')),
                          DataCell(Text('${log['business_name']}')),
                          DataCell(Text('${log['added_by']}')),
                          DataCell(Text('${log['migration_date']}')),
                        ]);
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Function to format DateTime object to string in 'yyyy-mm-dd' format
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<DateTime?> _selectDate(BuildContext context) async {
    // Show date picker
    return await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
  }

  Future<List<Map<String, dynamic>>> _getMigrationLogs() async {
    final db = await DatabaseHelper.instance.database;

    // Base query for migration logs
    String query = 'SELECT * FROM migration_logs';
    List<dynamic> arguments = [];

    // Apply date range filter if both start and end dates are selected
    if (_startDate != null && _endDate != null) {
      String startDateString = _startDate!.toIso8601String().split('T')[0]; // Get the start date part
      String endDateString = _endDate!.toIso8601String().split('T')[0]; // Get the end date part

      query += " WHERE migration_date BETWEEN ? AND ?";
      arguments.add(startDateString);
      arguments.add(endDateString);
    }

    // Apply search query if present
    if (_searchQuery.isNotEmpty) {
      query += _startDate != null && _endDate != null ? ' AND' : ' WHERE';
      query += " medicine_name LIKE ?";
      arguments.add('%$_searchQuery%');  // Using % for partial match
    }

    // Fetch the data from database with the applied filters
    return await db.rawQuery(query, arguments);
  }
}
