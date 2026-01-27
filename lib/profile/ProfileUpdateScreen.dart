import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _professionController;
  late TextEditingController _businessController;

  File? _profileImage; // Picha ya muda kutoka kwenye gallery
  String? _currentServerImageUrl; // Picha ya sasa iliyoko Supabase
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // 1. Jaza data za awali
    _initializeControllers(widget.user);
    _currentServerImageUrl = widget.user['profile_image'] ?? widget.user['profile_picture'];

    // 2. Vuta data mpya (Live) mara moja screen ikifunguka
    _fetchLatestUserData();
  }

  void _initializeControllers(Map<String, dynamic> data) {
    _fullNameController = TextEditingController(text: data['full_name']?.toString() ?? '');
    _emailController = TextEditingController(text: data['email']?.toString() ?? '');
    _phoneController = TextEditingController(text: data['phone']?.toString() ?? '');
    _professionController = TextEditingController(text: data['professional']?.toString() ?? '');
    _businessController = TextEditingController(text: data['business_name']?.toString() ?? '');
    _passwordController = TextEditingController();
  }

  /// 🔄 Inavuta data mpya zaidi kutoka Supabase na kusasisha Fields
  Future<void> _fetchLatestUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _fullNameController.text = data['full_name']?.toString() ?? '';
          _phoneController.text = data['phone']?.toString() ?? '';
          _professionController.text = data['professional']?.toString() ?? '';
          _businessController.text = data['business_name']?.toString() ?? '';
          _currentServerImageUrl = data['profile_image'] ?? data['profile_picture'];
        });
        print("✅ Data Live zimepakiwa: $_currentServerImageUrl");
      }
    } catch (e) {
      print("❌ Hitilafu ya kuvuta data: $e");
    }
  }

  /// 💾 Inahifadhi na kureload data papo hapo
  Future<void> _updateUserDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final String userId = supabase.auth.currentUser!.id;
      String? imageUrl = _currentServerImageUrl;

      // 1. Kama kuna picha mpya, ipandishe
      if (_profileImage != null) {
        final fileExt = _profileImage!.path.split('.').last;
        final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('avatars').upload(
            fileName,
            _profileImage!,
            fileOptions: const FileOptions(upsert: true)
        );

        imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      }

      // 2. Sasisha Database
      await supabase.from('users').update({
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'professional': _professionController.text.trim(),
        'profile_image': imageUrl,
        'profile_picture': imageUrl,
      }).eq('id', userId);

      // 3. 🔥 RELOAD: Vuta data mpya toka Supabase sasa hivi
      await _fetchLatestUserData();

      // 4. Safisha picha ya muda ili ionyeshe Network Image sasa
      setState(() {
        _profileImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Imesave na Kusasisha!"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Hitilafu: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Akaunti Yangu", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.teal,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 25),
              _buildInputField(_fullNameController, "Jina Kamili", Icons.person),
              _buildInputField(_emailController, "Barua Pepe", Icons.email, enabled: false),
              _buildInputField(_phoneController, "Namba ya Simu", Icons.phone, isPhone: true),
              _buildInputField(_professionController, "Taaluma / Kazi", Icons.work_outline),
              _buildInputField(_businessController, "Biashara", Icons.business, enabled: false),
              _buildInputField(_passwordController, "Password Mpya (Hiari)", Icons.lock, isPassword: true),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _updateUserDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("HIFADHI MABADILIKO",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: GestureDetector(
        onTap: () async {
          final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
          if (pickedFile != null) setState(() => _profileImage = File(pickedFile.path));
        },
        child: Stack(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundColor: Colors.teal.withOpacity(0.1),
              backgroundImage: _profileImage != null
                  ? FileImage(_profileImage!)
                  : (_currentServerImageUrl != null
                  ? NetworkImage(_currentServerImageUrl!)
                  : null) as ImageProvider?,
              child: _profileImage == null && _currentServerImageUrl == null
                  ? const Icon(Icons.camera_alt, size: 40, color: Colors.teal)
                  : null,
            ),
            const Positioned(
              bottom: 0,
              right: 5,
              child: CircleAvatar(
                backgroundColor: Colors.teal,
                radius: 18,
                child: Icon(Icons.edit, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon,
      {bool enabled = true, bool isPassword = false, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        obscureText: isPassword,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: enabled ? Colors.teal : Colors.grey),
          filled: !enabled,
          fillColor: enabled ? Colors.white : Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.teal, width: 2),
          ),
        ),
        validator: (val) => (enabled && !isPassword && (val == null || val.isEmpty)) ? "$label inahitajika" : null,
      ),
    );
  }
}