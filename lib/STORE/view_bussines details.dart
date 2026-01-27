import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../FOTTER/CurvedRainbowBar.dart';

class ViewBusinessesScreen extends StatefulWidget {
  const ViewBusinessesScreen({super.key});

  @override
  _ViewBusinessesScreenState createState() => _ViewBusinessesScreenState();
}

class _ViewBusinessesScreenState extends State<ViewBusinessesScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _lipaController = TextEditingController();

  String? _businessId;
  String? _logoUrl;
  String? _myBusinessName; // Jina la biashara ya aliyelogin
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchAndPopulate();
  }

  /// INAVUTA TAARIFA ZA BIASHARA HUSIKA TU (FILTERED)
  Future<void> _fetchAndPopulate() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showSnackBar("User session not found!", Colors.red);
        return;
      }

      // 1. Pata business_name kutoka kwenye profile ya mtumiaji
      final userData = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userData != null && userData['business_name'] != null) {
        _myBusinessName = userData['business_name'];

        // 2. Vuta taarifa za biashara hiyo pekee
        final data = await supabase
            .from('businesses')
            .select()
            .eq('business_name', _myBusinessName!)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _businessId = data['id'].toString();
            _nameController.text = data['business_name'] ?? '';
            _emailController.text = data['email'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _locationController.text = data['location'] ?? '';
            _addressController.text = data['address'] ?? '';
            _whatsappController.text = data['whatsapp'] ?? '';
            _lipaController.text = data['lipa_number'] ?? '';
            _logoUrl = data['logo'];
          });
        } else {
          debugPrint("Business details not found for $_myBusinessName");
        }
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
      _showSnackBar("Error loading profile", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImageUpload() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;

    setState(() => _isSaving = true);
    try {
      final file = File(image.path);
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final storagePath = 'business_logos/$fileName';

      await supabase.storage.from('avatars').upload(storagePath, file);
      final String rawUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);

      setState(() {
        _logoUrl = "$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}";
      });
      _showSnackBar("Logo uploaded! Remember to Save Profile.", Colors.blue);
    } catch (e) {
      _showSnackBar("Upload failed: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAll() async {
    if (!_formKey.currentState!.validate()) return;
    if (_businessId == null) {
      _showSnackBar("Cannot update: Business ID missing", Colors.red);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Safisha URL kwa ajili ya kuhifadhi
      String? cleanUrl = _logoUrl?.split('?')[0];

      final updates = {
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'address': _addressController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'lipa_number': _lipaController.text.trim(),
        'logo': cleanUrl,
      };

      // TUNASAVE KWA KUTUMIA ID YA BIASHARA HII TU
      await supabase.from('businesses').update(updates).eq('id', _businessId!);

      _showSnackBar("Business Profile Updated Successfully!", Colors.green);
    } catch (e) {
      _showSnackBar("Update Error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating)
  );

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("BUSINESS PROFILE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [deepPurple, primaryPurple]))),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: deepPurple))
          : Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildAvatarSection(primaryPurple),
              const SizedBox(height: 30),

              // Business Name na Email ni LOCKED (Zinasomwa tu)
              _buildLockedField("Business Name", _nameController, Icons.lock),
              const SizedBox(height: 15),
              _buildLockedField("Official Email", _emailController, Icons.mail_lock),

              const SizedBox(height: 15),
              const Divider(thickness: 1),
              const SizedBox(height: 15),

              // Sehemu ya kuedit
              _buildInputField("Phone Number", _phoneController, Icons.phone_android_outlined),
              _buildInputField("City / Location", _locationController, Icons.location_on_outlined),
              _buildInputField("Physical Address", _addressController, Icons.map_outlined),
              _buildInputField("WhatsApp Support", _whatsappController, Icons.chat_bubble_outline),
              _buildInputField("Lipa Number", _lipaController, Icons.payments_outlined),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  onPressed: _isSaving ? null : _saveAll,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE PROFILE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildAvatarSection(Color color) {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: ClipOval(
              child: _logoUrl != null && _logoUrl!.isNotEmpty
                  ? Image.network(
                _logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              )
                  : const Icon(Icons.business, size: 60, color: Colors.grey),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              backgroundColor: color,
              radius: 20,
              child: IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                onPressed: _handleImageUpload,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedField(String label, TextEditingController controller, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!)
      ),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        decoration: InputDecoration(
          labelText: "$label (Locked)",
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          helperText: "Contact Administrator to change this field.",
          helperStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 9),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, color: const Color(0xFF673AB7)),
            border: InputBorder.none
        ),
      ),
    );
  }
}