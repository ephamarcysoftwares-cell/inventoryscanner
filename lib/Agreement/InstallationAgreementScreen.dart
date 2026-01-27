import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../login.dart'; // Ensure this points to your LoginScreen file

class InstallationAgreementScreen extends StatelessWidget {

  // Mark as accepted so the Splash screen skips this next time
  Future<void> _setAgreementAccepted() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreenAccent.shade100,
      appBar: AppBar(
        title: const Text(
          "Installation Agreement",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)), // Smoother for mobile
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Optimized Image for Mobile
              Center(
                child: Image.asset(
                  'assets/aggreement.png',
                  width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
                  height: 250, // Fixed height for mobile
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "END-USER LICENSE AGREEMENT",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Agreement Text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '''
This agreement is between you and STOCK&INVENTORY SOFTWARE.

🔐 Subscription Fee:
TSH 10,000/= (3.9 USD) per month.

📥 Login Conditions:
Email: admin@example.com
Password: admin123

📞 Contact:
Email: support@ephamarcysoftware.co.tz
Phone: +255 742 448 965

📜 COPYRIGHT:
This software is protected under COSOTA. Unauthorized distribution is prohibited. Violation results in heavy fines.
                  ''',
                  style: TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                ),
              ),

              const SizedBox(height: 30),

              // ACCEPT BUTTON
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  minimumSize: const Size(double.infinity, 50), // Full width button
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text(
                  'I Accept & Continue to Login',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                onPressed: () async {
                  await _setAgreementAccepted(); // Save preference

                  // DIRECT TO LOGIN PAGE
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }
}