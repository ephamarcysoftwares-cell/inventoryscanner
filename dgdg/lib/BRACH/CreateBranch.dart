import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateSubBusinessScreen extends StatefulWidget {
  const CreateSubBusinessScreen({super.key});

  @override
  _CreateSubBusinessScreenState createState() => _CreateSubBusinessScreenState();
}

class _CreateSubBusinessScreenState extends State<CreateSubBusinessScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers kulingana na columns za database yako
  final TextEditingController _subNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _lipaNumberController = TextEditingController();

  bool _isInitialLoading = true;
  bool _isSaving = false;

  String? _mainBusinessName;
  int? _mainBusinessId;

  @override
  void initState() {
    super.initState();
    _fetchParentInfo();
  }

  /// 1. VUTA TAARIFA ZA BIASHARA MAMA (PARENT)
  Future<void> _fetchParentInfo() async {
    setState(() => _isInitialLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Pata biashara mama ya huyu Admin aliyelogin
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null) {
        final String bName = userProfile['business_name'];

        final businessData = await supabase
            .from('businesses')
            .select('id, business_name')
            .eq('business_name', bName)
            .eq('is_main_business', true) // Hakikisha tunapata Main Branch
            .maybeSingle();

        if (businessData != null) {
          setState(() {
            _mainBusinessId = businessData['id'];
            _mainBusinessName = businessData['business_name'];
          });
        }
      }
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    } finally {
      setState(() => _isInitialLoading = false);
    }
  }

  /// 2. HIFADHI TAWI JIPYA (BRANCH)
  Future<void> _createSubBusiness() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mainBusinessId == null) {
      _showSnackBar("Biashara mama haijatambuliwa!", Colors.red);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String inputSubName = _subNameController.text.trim();

      // Angalia kama tawi lenye jina hili lipo tayari chini ya biashara hii
      final existing = await supabase
          .from('businesses')
          .select('id')
          .eq('business_name', _mainBusinessName!)
          .eq('sub_name', inputSubName)
          .maybeSingle();

      if (existing != null) {
        _showSnackBar("Tawi la '$inputSubName' lipo tayari!", Colors.orange);
        setState(() => _isSaving = false);
        return;
      }

      // INSERT KWENYE DATABASE
      await supabase.from('businesses').insert({
        'business_name': _mainBusinessName, // Jina la biashara mama
        'sub_name': inputSubName,          // Jina la tawi (e.g. Arusha)
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'lipa_number': _lipaNumberController.text.trim(),
        'parent_id': _mainBusinessId,      // ID ya biashara mama
        'is_main_business': false,        // Hili ni tawi (Sub), siyo Mama
        'user_id': supabase.auth.currentUser!.id,
      });

      _showSnackBar("Tawi limesajiliwa kikamilifu!", Colors.green);
      if (mounted) Navigator.pop(context); // Rudi nyuma baada ya kusajili

    } catch (e) {
      _showSnackBar("Imeshindwa kusave: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF311B92);

    return Scaffold(
      appBar: AppBar(
        title: const Text("SAJILI TAWI JIPYA", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: primaryColor,
        elevation: 0,
      ),
      body: _isInitialLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Card
              _buildHeaderCard(primaryColor),
              const SizedBox(height: 25),

              // Inputs
              _buildInputField("Jina la Tawi (e.g., Arusha Branch)", _subNameController, Icons.store),
              _buildInputField("Eneo (Location)", _locationController, Icons.location_on),
              _buildInputField("Namba ya Simu", _phoneController, Icons.phone, type: TextInputType.phone),
              _buildInputField("Anwani (Address)", _addressController, Icons.map),
              _buildInputField("WhatsApp Number", _whatsappController, Icons.chat, type: TextInputType.phone),
              _buildInputField("Lipa Number / Till", _lipaNumberController, Icons.payment),

              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isSaving ? null : _createSubBusiness,
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("HIFADHI TAWI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("BIASHARA MAMA:", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(_mainBusinessName ?? "Inapakia...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        validator: (v) => v == null || v.isEmpty ? "Sehemu hii inahitajika" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.indigo, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}