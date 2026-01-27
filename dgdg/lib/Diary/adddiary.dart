import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddDiaryPage extends StatefulWidget {
  const AddDiaryPage({super.key});

  @override
  State<AddDiaryPage> createState() => _AddDiaryPageState();
}

class _AddDiaryPageState extends State<AddDiaryPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController activityTitleController = TextEditingController();
  final TextEditingController activityDescriptionController = TextEditingController();

  String businessName = '';
  String userName = '';
  String userEmail = '';
  String message = '';
  bool isSaving = false;
  bool isLoadingProfile = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchCurrentUserProfile();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _fetchCurrentUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userProfile = await supabase
          .from('users')
          .select('full_name, business_name, email')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null) {
        final bData = await supabase
            .from('businesses')
            .select('email')
            .eq('business_name', userProfile['business_name'])
            .maybeSingle();

        if (mounted) {
          setState(() {
            userName = userProfile['full_name'] ?? 'User';
            businessName = userProfile['business_name'] ?? 'Pharmacy';
            userEmail = bData?['email'] ?? user.email ?? '';
            isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _saveDiary() async {
    final activityTitle = activityTitleController.text.trim();
    final activityDescription = activityDescriptionController.text.trim();
    final activityDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (activityTitle.isEmpty || activityDescription.isEmpty) {
      setState(() => message = '⚠️ Title and Description are required.');
      return;
    }

    setState(() { isSaving = true; message = '🔄 Syncing...'; });

    try {
      final user = supabase.auth.currentUser;
      await supabase.from('diary').insert({
        'user_id': user?.id,
        'business_name': businessName,
        'user_name': userName,
        'activity_title': activityTitle,
        'activity_description': activityDescription,
        'activity_date': activityDate,
      });

      await _sendEmail(activityTitle, activityDescription, activityDate);

      if (mounted) {
        setState(() {
          isSaving = false;
          message = '✅ Diary saved and synced!';
          activityTitleController.clear();
          activityDescriptionController.clear();
        });
      }
    } catch (e) {
      setState(() { isSaving = false; message = '❌ Error: $e'; });
    }
  }

  Future<void> _sendEmail(String title, String description, String date) async {
    try {
      if (userEmail.isEmpty) return;
      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465, ssl: true,
      );

      final mailMessage = mailer.Message()
        ..from = mailer.Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.add(userEmail)
        ..subject = 'Diary Entry: $title'
        ..html = "<h3>Daily Log for $businessName</h3><p><strong>By:</strong> $userName</p><hr><p>$description</p>";

      await mailer.send(mailMessage, smtpServer);
    } catch (e) { debugPrint('SMTP Error: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    // Colors Definition
    final Color primaryPurple = const Color(0xFF673AB7);
    final Color deepPurple = const Color(0xFF311B92);

    // Background and Field Background
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color fieldFillColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;

    // Text Colors
    final Color primaryTextColor = _isDarkMode ? Colors.white : Colors.black87;
    final Color labelTextColor = _isDarkMode ? Colors.white70 : Colors.blueGrey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(isLoadingProfile ? "CONNECTING..." : "DIARY: ${businessName.toUpperCase()}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: isLoadingProfile
          ? Center(child: CircularProgressIndicator(color: primaryPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Log Daily Progress",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryTextColor)),
            const SizedBox(height: 25),

            // --- TITLE FIELD ---
            _buildModernField(
              controller: activityTitleController,
              label: "Activity Title",
              icon: Icons.title_rounded,
              fillColor: fieldFillColor,
              textColor: primaryTextColor,
              labelColor: labelTextColor,
              accentColor: primaryPurple,
            ),

            const SizedBox(height: 20),

            // --- DESCRIPTION FIELD ---
            _buildModernField(
              controller: activityDescriptionController,
              label: "Write your description...",
              icon: Icons.description_outlined,
              fillColor: fieldFillColor,
              textColor: primaryTextColor,
              labelColor: labelTextColor,
              accentColor: primaryPurple,
              maxLines: 8,
            ),

            const SizedBox(height: 35),

            // --- ACTION BUTTON ---
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _saveDiary,
                icon: isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined, color: Colors.white),
                label: Text(isSaving ? "SYNCING..." : "SAVE DAILY LOG", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
              ),
            ),

            if (message.isNotEmpty) Padding(
              padding: const EdgeInsets.only(top: 25),
              child: Center(
                child: Text(message, style: TextStyle(color: message.contains('✅') ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Helper Widget for consistent Dark Mode fields
  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color fillColor,
    required Color textColor,
    required Color labelColor,
    required Color accentColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _isDarkMode ? Colors.black38 : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        cursorColor: accentColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: labelColor, fontSize: 14),
          prefixIcon: Icon(icon, color: accentColor),
          filled: true,
          fillColor: fillColor, // DARK OR LIGHT BASED ON THEME
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}