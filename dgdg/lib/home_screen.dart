import 'package:flutter/material.dart';
import 'package:stock_and_inventory_software/phamacy/pharmacyDashboard.dart';

  // Import Pharmacy Dashboard
import 'admin/AdminDashboard.dart'; // Import Admin Dashboard
import 'IT/ITDashboard.dart';  // Import IT Dashboard
import 'login_screen.dart';  // Import Login Screen


class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;  // Accept user as a map

  const HomeScreen({super.key, required this.user});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _logout() async {
    // Clear shared preferences and navigate to login screen
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use the 'role' from the passed 'user' map to determine which dashboard to show
    Widget dashboard;

    switch (widget.user['role']) {
      case 'Admin':
        dashboard = AdminDashboard(user: widget.user);  // Pass the user data here
        break;
      case 'Pharmacy':
        dashboard = PharmacyDashboard(user: widget.user);  // Pass the user data here
        break;
      case 'IT':
        dashboard = PharmacyDashboard(user: widget.user);  // Pass the user data here
        break;
      default:
        dashboard = Center(child: Text("Unknown Role"));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("STOCK&INVENTORY SOFTWARE"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: dashboard,
    );
  }
}
