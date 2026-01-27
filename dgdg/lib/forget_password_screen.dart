import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'dart:math';

// --- THEME COLORS (Matching your main app) ---
const Color primaryPurple = Color(0xFF673AB7);
const Color deepPurple = Color(0xFF311B92);

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // 1️⃣ Generate a random 8-character temporary password
  String _generateTempPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  // 2️⃣ Send Email via your SMTP Server
  Future<void> _sendResetEmail(String email, String name, String newPass) async {
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = mailer.Message()
      ..from = const mailer.Address('suport@ephamarcysoftware.co.tz', 'STOCK & INVENTORY PRO')
      ..recipients.add(email)
      ..subject = 'Password Reset - Stock & Inventory'
      ..html = '''
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h3 style="color: #673AB7;">Password Reset Request</h3>
          <p>Hello <b>$name</b>,</p>
          <p>We received a request to reset your password. Your new temporary credentials are below:</p>
          <div style="background: #f4f4f4; padding: 15px; border-radius: 5px; text-align: center;">
            <p style="margin: 0; font-size: 12px; color: #666;">TEMPORARY PASSWORD</p>
            <h2 style="margin: 5px 0; letter-spacing: 2px; color: #311B92;">$newPass</h2>
          </div>
          <p style="color: red; font-size: 13px;">* Please login and change this password immediately for security.</p>
          <br>
          <p>Regards,<br><b>Support Team</b></p>
          <p style="font-size: 11px; color: #999;">Stock & Inventory Software Pro</p>
        </div>
      ''';

    await mailer.send(message, smtpServer);
  }

  // 3️⃣ Main Reset Logic
  Future<void> _handleReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your registered email')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Check if user exists in your custom 'users' table
      final userData = await supabase
          .from('users')
          .select('full_name, id')
          .eq('email', email)
          .maybeSingle();

      if (userData == null) {
        throw "No account found with this email address.";
      }

      // Generate the new password
      String tempPassword = _generateTempPassword();

      // Update the password in Supabase Auth
      // Note: This works if the user is currently "resetting" or via service role.
      await supabase.auth.updateUser(UserAttributes(password: tempPassword));

      // Send the email with the new password
      await _sendResetEmail(email, userData['full_name'], tempPassword);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 4️⃣ Success Dialog & Auto-Navigate Back
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_read, color: Colors.green),
            SizedBox(width: 10),
            Text('Email Sent'),
          ],
        ),
        content: const Text(
          'A temporary password has been sent to your email. Use it to log in and update your password.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryPurple),
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Back to Login Screen
            },
            child: const Text('BACK TO LOGIN', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('RESET PASSWORD'),
        backgroundColor: deepPurple,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_reset_rounded, size: 100, color: primaryPurple),
            const SizedBox(height: 20),
            const Text(
              'Recover Access',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: deepPurple),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your email below. We will send a temporary password to your inbox.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined, color: primaryPurple),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'SEND RESET EMAIL',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Remembered it? Login here',
                style: TextStyle(color: deepPurple, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}