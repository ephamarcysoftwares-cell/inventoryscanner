import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddEventPage extends StatefulWidget {
  const AddEventPage({super.key});

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  final supabase = Supabase.instance.client;
  final TextEditingController eventTitleController = TextEditingController();

  DateTime? _selectedEventDate;
  String message = '';
  bool isSaving = false;
  bool isLoadingProfile = true;
  bool _isDarkMode = false;

  // Local user context
  String businessName = '';
  String userName = '';
  String userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchProfile();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _fetchProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('users')
          .select('full_name, business_name, email')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && mounted) {
        setState(() {
          userName = profile['full_name'] ?? 'User';
          businessName = profile['business_name'] ?? 'Pharmacy';
          userEmail = profile['email'] ?? user.email ?? '';
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Profile Fetch Error: $e');
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  Future<void> _pickEventDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: _isDarkMode ? ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF673AB7)),
          ) : ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF673AB7)),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate != null) setState(() => _selectedEventDate = pickedDate);
  }

  Future<void> _saveEvent() async {
    final eventTitle = eventTitleController.text.trim();
    if (eventTitle.isEmpty || _selectedEventDate == null) {
      setState(() => message = '⚠️ Title and Date are required.');
      return;
    }

    setState(() { isSaving = true; message = '🔄 Syncing with Cloud...'; });

    try {
      final user = supabase.auth.currentUser;
      await supabase.from('upcoming_event').insert({
        'user_id': user?.id,
        'business_name': businessName,
        'user_name': userName,
        'event_title': eventTitle,
        'event_date': _selectedEventDate!.toIso8601String(),
      });

      await _sendEmailNotification(eventTitle);

      if (mounted) {
        setState(() {
          isSaving = false;
          message = '✅ Scheduled successfully!';
          eventTitleController.clear();
          _selectedEventDate = null;
        });
      }
    } catch (e) {
      setState(() { isSaving = false; message = '❌ Error: $e'; });
    }
  }

  Future<void> _sendEmailNotification(String eventTitle) async {
    try {
      if (userEmail.isEmpty) return;
      final smtpServer = SmtpServer(
        'mail.ephamarcysoftware.co.tz',
        username: 'suport@ephamarcysoftware.co.tz',
        password: 'Matundu@2050',
        port: 465, ssl: true,
      );

      final email = mailer.Message()
        ..from = mailer.Address('suport@ephamarcysoftware.co.tz', businessName)
        ..recipients.add(userEmail)
        ..subject = '📅 Event Scheduled: $eventTitle'
        ..html = "<h3>New Event for $businessName</h3><p>Title: $eventTitle</p><p>Date: ${DateFormat('yyyy-MM-dd').format(_selectedEventDate!)}</p>";

      await mailer.send(email, smtpServer);
    } catch (e) { debugPrint('Email Fail: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryPurple = const Color(0xFF673AB7);
    final Color deepPurple = const Color(0xFF311B92);
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color cardColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("SCHEDULE EVENT", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: isLoadingProfile
          ? Center(child: CircularProgressIndicator(color: primaryPurple))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_note_rounded, size: 60, color: primaryPurple),
                    const SizedBox(height: 12),
                    Text(businessName.toUpperCase(), style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 24),

                    TextField(
                      controller: eventTitleController,
                      style: TextStyle(color: textColor),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Event Details",
                        labelStyle: TextStyle(color: textColor.withOpacity(0.5)),
                        filled: true,
                        fillColor: bgColor,
                        prefixIcon: Icon(Icons.edit, color: primaryPurple),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 20),

                    InkWell(
                      onTap: _pickEventDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: primaryPurple, size: 20),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                _selectedEventDate == null ? "Select Date" : DateFormat('EEEE, MMM d, yyyy').format(_selectedEventDate!),
                                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: textColor.withOpacity(0.3)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveEvent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                        ),
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("SAVE TO CLOUD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    if (message.isNotEmpty) Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(message, style: TextStyle(color: message.contains('✅') ? Colors.green : Colors.redAccent, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}