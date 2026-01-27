import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class MedicalLogsScreen extends StatefulWidget {
  @override
  _MedicalLogsScreenState createState() => _MedicalLogsScreenState();
}

class _MedicalLogsScreenState extends State<MedicalLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = ''; // New search query variable

  @override
  void initState() {
    super.initState();
    _loadMedicalLogs();
  }

  Future<void> _loadMedicalLogs() async {
    try {
      final logs = await DatabaseHelper.instance.getAllMedicalLogs();
      setState(() {
        _logs = logs;
        _filteredLogs = logs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading logs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterLogs() {
    setState(() {
      _filteredLogs = _logs.where((log) {
        // Filter by date range
        DateTime logDate = DateTime.parse(log['date_added']);
        bool withinDateRange = (_startDate == null || _endDate == null ||
            (logDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
                logDate.isBefore(_endDate!.add(Duration(days: 1)))));

        // Filter by search query
        bool matchesSearchQuery = log['medicine_name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            log['company'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
            log['batch_number'].toLowerCase().contains(_searchQuery.toLowerCase());

        return withinDateRange && matchesSearchQuery;
      }).toList();
    });
  }

  Future<void> _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
      _filterLogs();
    }
  }

  Future<void> _pickEndDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _filterLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "product Logs",
          style: TextStyle(color: Colors.white), // ✅ correct place
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(80)),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          SizedBox(height: 10),
          // Search TextField
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (query) {
                setState(() {
                  _searchQuery = query;
                });
                _filterLogs();
              },
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          SizedBox(height: 10),
          // Date Filter Buttons
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickStartDate,
                  icon: Icon(Icons.date_range),
                  label: Text(
                    _startDate == null
                        ? 'Start Date'
                        : DateFormat('yyyy-MM-dd').format(_startDate!),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _pickEndDate,
                  icon: Icon(Icons.date_range),
                  label: Text(
                    _endDate == null
                        ? 'End Date'
                        : DateFormat('yyyy-MM-dd').format(_endDate!),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  tooltip: 'Clear Filter',
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                      _searchQuery = '';
                      _filteredLogs = _logs;
                    });
                  },
                ),
              ],
            ),
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Showing results from ${DateFormat('yyyy-MM-dd').format(_startDate!)} to ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 12,
                    headingRowHeight: 32,
                    dataRowHeight: 40,
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    dataTextStyle: TextStyle(
                      fontSize: 12,
                    ),
                    columns: const [
                      DataColumn(label: Text('Medicine')),
                      DataColumn(label: Text('Company')),
                      DataColumn(label: Text('Qty')),
                      DataColumn(label: Text('Buy')),
                      DataColumn(label: Text('Sell')),
                      DataColumn(label: Text('Batch')),
                      DataColumn(label: Text('Mfg')),
                      DataColumn(label: Text('Exp')),
                      DataColumn(label: Text('Disc%')),
                      DataColumn(label: Text('Unit')),
                      DataColumn(label: Text('Added By')),
                      DataColumn(label: Text('Business')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Action')),
                    ],
                    rows: _filteredLogs.map((log) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${log['medicine_name']}')),
                          DataCell(Text('${log['company']}')),
                          DataCell(Text('${log['total_quantity']}')),
                          DataCell(Text('\ ${log['buy_price']}')),
                          DataCell(Text('\ ${log['selling_price']}')),
                          DataCell(Text('${log['batch_number']}')),
                          DataCell(Text('${log['manufacture_date']}')),
                          DataCell(Text('${log['expiry_date']}')),
                          DataCell(Text('${log['discount']}%')),
                          DataCell(Text('${log['unit']}')),
                          DataCell(Text('${log['added_by']}')),
                          DataCell(Text('${log['business_name']}')),
                          DataCell(Text('${log['date_added']}')),
                          DataCell(Text('${log['action']}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
