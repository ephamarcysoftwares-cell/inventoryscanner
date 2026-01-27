import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../phamacy/STORE/edit_business_screen.dart';
import 'edit_business_screen.dart';

class ViewBusinessesScreen extends StatefulWidget {
  const ViewBusinessesScreen({super.key});

  @override
  _ViewBusinessesScreenState createState() => _ViewBusinessesScreenState();
}

class _ViewBusinessesScreenState extends State<ViewBusinessesScreen> {
  // Local variables for state management
  String business_name = 'Loading...';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String businessWhatsapp = '';
  String businessLipaNumber = '';
  String businessAddress = '';

  bool _isLoading = true;
  Map<String, dynamic>? _rawBusinessData;

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
  }

  /// ☁️ FETCH ONLY ASSOCIATED BUSINESS INFO
  Future<void> getBusinessInfo() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // 1. Get current user email
      final currentUserEmail = supabase.auth.currentUser?.email;

      if (currentUserEmail == null) {
        debugPrint("⚠️ No active user session.");
        setState(() => _isLoading = false);
        return;
      }

      // 2. Query restricted to the current user's email
      final data = await supabase
          .from('businesses')
          .select()
          .eq('email', currentUserEmail) // 🔥 Filtered to current login only
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _rawBusinessData = data;
          // Mapping Supabase columns to variables
          business_name = data['business_name']?.toString() ?? 'Unnamed Business';
          businessEmail = data['email']?.toString() ?? '';
          businessPhone = data['phone']?.toString() ?? '';
          businessLocation = data['location']?.toString() ?? '';
          businessLogoPath = data['logo']?.toString() ?? '';
          businessWhatsapp = data['whatsapp']?.toString() ?? '';
          businessLipaNumber = data['lipa_number']?.toString() ?? '';
          businessAddress = data['address']?.toString() ?? '';
        });
        debugPrint("✅ Business Profile Synced: $business_name");
      }
    } catch (e) {
      debugPrint('❌ Supabase Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Business Profile", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : _rawBusinessData == null
          ? _buildNoProfileState()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 20),
            _buildDetailsCard(),
            const SizedBox(height: 30),
            _buildEditButton(),
          ],
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.teal.shade50,
          backgroundImage: (businessLogoPath.isNotEmpty && File(businessLogoPath).existsSync())
              ? FileImage(File(businessLogoPath))
              : null,
          child: (businessLogoPath.isEmpty || !File(businessLogoPath).existsSync())
              ? const Icon(Icons.business_center, size: 60, color: Colors.teal)
              : null,
        ),
        const SizedBox(height: 15),
        Text(
          business_name.toUpperCase(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal),
        ),
        Text(businessEmail, style: TextStyle(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            _infoRow(Icons.phone, "Phone Number", businessPhone),
            _infoRow(Icons.location_on, "Location", businessLocation),
            _infoRow(Icons.map, "Physical Address", businessAddress),
            _infoRow(Icons.chat, "WhatsApp", businessWhatsapp),
            _infoRow(Icons.account_balance_wallet, "Lipa Number", businessLipaNumber),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal.shade400, size: 22),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value.isNotEmpty ? value : "Not Set",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.edit, color: Colors.white),
        label: const Text("EDIT PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditBusinessScreen(business: _rawBusinessData!),
            ),
          );
          if (result == true) getBusinessInfo();
        },
      ),
    );
  }

  Widget _buildNoProfileState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange.shade300),
          const SizedBox(height: 10),
          const Text("No profile found for your login email."),
          TextButton(onPressed: getBusinessInfo, child: const Text("Retry Sync")),
        ],
      ),
    );
  }
}