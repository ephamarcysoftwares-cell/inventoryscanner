import 'package:flutter/material.dart';
import '../DB/database_helper.dart'; // Import the database helper file
import 'package:intl/intl.dart';

import '../FOTTER/CurvedRainbowBar.dart'; // For formatting date

class DeletedMedicinesScreen extends StatefulWidget {
  @override
  _DeletedMedicinesScreenState createState() => _DeletedMedicinesScreenState();
}

class _DeletedMedicinesScreenState extends State<DeletedMedicinesScreen> {
  // Variable to store the list of deleted medicines
  List<Map<String, dynamic>> deletedMedicines = [];
  List<Map<String, dynamic>> filteredMedicines = []; // List for search filtering

  // Variables to store the selected date range
  DateTime? fromDate;
  DateTime? toDate;

  // Variable to store the search query
  String searchQuery = '';

  // Function to fetch deleted medicines from the database
  Future<void> fetchDeletedMedicines() async {
    final List<Map<String, dynamic>> medicines = await DatabaseHelper.instance.getAllDeletedMedicines();
    setState(() {
      deletedMedicines = medicines;
      filteredMedicines = medicines; // Initially display all medicines
    });
  }

  // Function to filter medicines by date range and search query
  void filterData() {
    List<Map<String, dynamic>> filteredList = deletedMedicines;

    // Filter by date range if both fromDate and toDate are selected
    if (fromDate != null && toDate != null) {
      filteredList = filteredList.where((medicine) {
        DateTime deletedDate = DateTime.parse(medicine['deleted_date']);
        return deletedDate.isAfter(fromDate!) && deletedDate.isBefore(toDate!);
      }).toList();
    }

    // Filter by search query
    if (searchQuery.isNotEmpty) {
      filteredList = filteredList.where((medicine) {
        return medicine['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            medicine['company'].toLowerCase().contains(searchQuery.toLowerCase());
      }).toList();
    }

    setState(() {
      filteredMedicines = filteredList;
    });
  }

  // Function to pick date using DatePicker
  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      setState(() {
        if (isFromDate) {
          fromDate = pickedDate;
        } else {
          toDate = pickedDate;
        }
      });
      filterData(); // Apply the filter after date selection
    }
  }

  @override
  void initState() {
    super.initState();
    fetchDeletedMedicines(); // Fetch deleted medicines when screen loads
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(
        title: Text(
          "Deleted Products",
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
          // Search Field
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (query) {
                setState(() {
                  searchQuery = query;
                });
                filterData(); // Filter results when search query changes
              },
              decoration: InputDecoration(
                labelText: 'Search by Name or Company',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),

          // Date Pickers (From and To Date)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            fromDate != null
                                ? DateFormat('yyyy-MM-dd').format(fromDate!)
                                : 'Select From Date',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            toDate != null
                                ? DateFormat('yyyy-MM-dd').format(toDate!)
                                : 'Select To Date',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Displaying the data
          Expanded(
            child: filteredMedicines.isEmpty
                ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: FittedBox(
                child: DataTable(
                  columnSpacing: 10,
                  headingRowHeight: 32,
                  dataRowHeight: 38,
                  columns: [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Company')),
                    DataColumn(label: Text('Buy Price')),
                    DataColumn(label: Text('Sale Price')),
                    DataColumn(label: Text('Batch No.')),
                    DataColumn(label: Text('Total Qty')),
                    DataColumn(label: Text('Remaining Qty')),
                    DataColumn(label: Text('Manufacture Date')),
                    DataColumn(label: Text('Expiry Date')),
                    DataColumn(label: Text('Added By')),
                    DataColumn(label: Text('Discount')),
                    DataColumn(label: Text('Date Added')),
                    DataColumn(label: Text('Unit')),
                    DataColumn(label: Text('Business Name')),
                    DataColumn(label: Text('Recover')),
                  ],
                  rows: filteredMedicines.map((medicine) {
                    return DataRow(cells: [
                      DataCell(Text(medicine['name'])),
                      DataCell(Text(medicine['company'])),
                      DataCell(Text('\TSH ${medicine['buy']}')),
                      DataCell(Text('\TSH ${medicine['price']}')),
                      DataCell(Text(medicine['batchNumber'])),
                      DataCell(Text(medicine['total_quantity'].toString())),
                      DataCell(Text(medicine['remaining_quantity'].toString())),
                      DataCell(Text(medicine['manufacture_date'])),
                      DataCell(Text(medicine['expiry_date'])),
                      DataCell(Text(medicine['added_by'])),
                      DataCell(Text(medicine['discount'].toString())),
                      DataCell(Text(medicine['date_added'])),
                      DataCell(Text(medicine['unit'])),
                      DataCell(Text(medicine['business_name'])),
                      DataCell(
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(horizontal: 10),
                          ),
                          child: Text('Recover'),
                          onPressed: () async {
                            await DatabaseHelper.instance.recoverMedicine(medicine);
                            fetchDeletedMedicines(); // Refresh table
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${medicine['name']} recovered.')),
                            );
                          },
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          )

        ],
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}
