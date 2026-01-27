import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SmsSenderScreen extends StatefulWidget {
  @override
  _SmsSenderScreenState createState() => _SmsSenderScreenState();
}

class _SmsSenderScreenState extends State<SmsSenderScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  // Method to send SMS
  Future<void> sendSms(String phone, String message) async {
    setState(() {
      _isLoading = true;
    });

    // Replace this with your SMS API URL and API key
    final String apiUrl =
        'https://sms.arkesel.com/sms/api?action=send-sms&api_key=Y29yb1doV25oTGxWc1BWbEpnc0s&to=$phone&from=SenderID&sms=$message';

    try {
      // Send SMS API request
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        // SMS sent successfully
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS sent successfully!')),
        );
      } else {
        // Error in sending SMS
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send SMS. Try again later.')),
        );
      }
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Send SMS"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phone Number Field
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Enter Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            // Message Field
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                labelText: 'Enter Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 20),
            // Send SMS Button
            _isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () {
                String phone = _phoneController.text.trim();
                String message = _messageController.text.trim();

                if (phone.isEmpty || message.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill in all fields')),
                  );
                } else {
                  sendSms(phone, message);
                }
              },
              child: Text("Send SMS"),
            ),
          ],
        ),
      ),
    );
  }
}
