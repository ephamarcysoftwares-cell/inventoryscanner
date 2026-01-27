import 'dart:io';
import 'package:flutter/material.dart';

import '../../DB/database_helper.dart';
import 'edit_business_screen.dart'; // Make sure you have this screen created

class ViewBusinessesScreen extends StatefulWidget {
  const ViewBusinessesScreen({super.key});

  @override
  _ViewBusinessesScreenState createState() => _ViewBusinessesScreenState();
}

class _ViewBusinessesScreenState extends State<ViewBusinessesScreen> {
  late Future<List<Map<String, dynamic>>> _businesses;

  @override
  void initState() {
    super.initState();
    _refreshBusinesses();
  }

  void _refreshBusinesses() {
    _businesses = DatabaseHelper.instance.getAllBusinesses();
  }

  Future<void> _deleteBusiness(int id) async {
    await DatabaseHelper.instance.deleteBusiness(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Business deleted successfully')),
    );
    setState(() {
      _refreshBusinesses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('All Businesses'),
        backgroundColor: Colors.greenAccent,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _businesses,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No businesses found.'));
          } else {
            List<Map<String, dynamic>> businesses = snapshot.data!;
            return ListView.builder(
              itemCount: businesses.length,
              itemBuilder: (context, index) {
                final business = businesses[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: business['logo'] != null
                              ? Image.file(
                            File(business['logo']),
                            width: 100,
                            height: 100,
                          )
                              : Icon(Icons.business, size: 80, color: Colors.green[700]),
                        ),
                        SizedBox(height: 10),

                        Text(
                          business['business_name'] ?? '',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 6),
                        Text('Phone: ${business['phone']}'),
                        Text('Email: ${business['email']}'),
                        Text('Location: ${business['location']}'),
                        Text('Address: ${business['address']}'),
                        Text('WhatsApp: ${business['whatsapp']}'),
                        Text('Lipa Number: ${business['lipa_number']}'),
                        SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: Icon(Icons.edit, color: Colors.green[700]),
                              label: Text('Edit', style: TextStyle(color: Colors.green[700])),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditBusinessScreen(business: business),
                                  ),
                                );
                                setState(() {
                                  _refreshBusinesses();
                                });
                              },
                            ),
                            SizedBox(width: 8),
                            TextButton.icon(
                              icon: Icon(Icons.delete, color: Colors.red[700]),
                              label: Text('Delete', style: TextStyle(color: Colors.red[700])),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Delete Business'),
                                    content: Text('Are you sure you want to delete this business?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text('Delete', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm ?? false) {
                                  _deleteBusiness(business['id']);
                                }
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
