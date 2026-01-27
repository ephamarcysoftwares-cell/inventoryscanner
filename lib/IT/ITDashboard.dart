import 'package:flutter/material.dart';

class ITDashboard extends StatelessWidget {
  final Map<String, dynamic> user;  // Accept user as a map

  const ITDashboard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("IT Dashboard"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome, ${user['full_name']}"),  // Display user information
            // Add more widgets here as needed
          ],
        ),
      ),
    );
  }
}
