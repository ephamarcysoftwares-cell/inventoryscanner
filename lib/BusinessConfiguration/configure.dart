import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsAppSetupPage extends StatefulWidget {
  final Map<String, dynamic> user; // Inatoka kwenye login

  const WhatsAppSetupPage({super.key, required this.user});

  @override
  State<WhatsAppSetupPage> createState() => _WhatsAppSetupPageState();
}

class _WhatsAppSetupPageState extends State<WhatsAppSetupPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers za kuchukua data unazotaka kusave
  final TextEditingController _apiKeyController = TextEditingController(text: "SKrEvNLpJ6nRdPns5rwZJzE8SkqfTG0MZzW7kTd3kR");
  final TextEditingController _clientIdController = TextEditingController(text: "IDZdzneti4V2DNdsuFemUgxLcPmkxkyL");
  final TextEditingController _instanceIdController = TextEditingController();
  final TextEditingController _accessTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingConfig();
  }

  // 1. Vuta data zilizopo tayari (kama zipo) ili mtumiaji asiziandike upya
  Future<void> _loadExistingConfig() async {
    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      // 1. Hakikisha user yupo
      if (currentUser == null) {
        debugPrint("❌ Hakuna mtumiaji aliyelog-in.");
        return;
      }

      // 2. Pata Business ID (Tumia currentUser.id moja kwa moja ni salama zaidi)
      final bizResponse = await supabase
          .from('businesses')
          .select('id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      // 3. Kama biashara haijapatikana, usiendelee
      if (bizResponse == null) {
        debugPrint("⚠️ Biashara haijapatikana kwa huyu mtumiaji.");
        return;
      }

      final businessId = bizResponse['id'];

      // 4. Vuta config ukitumia businessId iliyohakikiwa
      final config = await supabase
          .from('whatsapp_configs')
          .select()
          .eq('business_id', businessId)
          .maybeSingle();

      if (config != null && mounted) {
        setState(() {
          // Tunatumia ?.toString() na ?? '' kuzuia kosa la 'Null' subtype
          _apiKeyController.text = config['api_key']?.toString() ?? _apiKeyController.text;
          _clientIdController.text = config['client_id']?.toString() ?? _clientIdController.text;
          _instanceIdController.text = config['instance_id']?.toString() ?? '';
          _accessTokenController.text = config['access_token']?.toString() ?? '';
        });
        debugPrint("✅ Taarifa zimepakiwa.");
      }
    } catch (e) {
      debugPrint("❌ Error loading config: $e");
    }
  }

  // 2. SAVE LOGIC: Hapa ndipo tunasave kwenye whatsapp_configs
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;

      // A. Pata Business ID ya huyu user
      final biz = await supabase
          .from('businesses')
          .select('id')
          .eq('user_id', widget.user['id'])
          .single();

      final int businessId = biz['id'];

      // B. Upsert (Save or Update) kwenye whatsapp_configs
      await supabase.from('whatsapp_configs').upsert({
        'business_id': businessId,
        'api_key': _apiKeyController.text.trim(),
        'client_id': _clientIdController.text.trim(),
        'instance_id': _instanceIdController.text.trim(),
        'access_token': _accessTokenController.text.trim(),
      }, onConflict: 'business_id');

      // C. Pia save kwenye SharedPreferences kwa ajili ya matumizi ya haraka ya offline
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('whatsapp_instance_id', _instanceIdController.text.trim());
      await prefs.setString('whatsapp_access_token', _accessTokenController.text.trim());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Taarifa zimehifadhiwa kikamilifu!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Hitilafu: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryPurple = Color(0xFF673AB7);

    return Scaffold(
      appBar: AppBar(
        title: const Text("WhatsApp API Setup"),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Business Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("Hifadhi taarifa zako za API na WhatsApp hapa.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 25),

              _buildField(_apiKeyController, "API Key", Icons.vpn_key),
              _buildField(_clientIdController, "Client ID", Icons.assignment_ind),
              _buildField(_instanceIdController, "WhatsApp Instance ID", Icons.phonelink_ring),
              _buildField(_accessTokenController, "WhatsApp Access Token", Icons.lock_outline),

              const SizedBox(height: 30),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveSettings,
                  child: const Text("HIFADHI TAARIFA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        validator: (value) => value!.isEmpty ? "Tafadhali jaza hapa" : null,
      ),
    );
  }
}