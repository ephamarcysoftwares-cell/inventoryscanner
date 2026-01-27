import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import 'CreateBranch.dart';

class BranchesManagementScreen extends StatefulWidget {
  const BranchesManagementScreen({super.key});

  @override
  _BranchesManagementScreenState createState() => _BranchesManagementScreenState();
}

class _BranchesManagementScreenState extends State<BranchesManagementScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _subNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  List<Map<String, dynamic>> _branches = [];
  bool _isLoading = true;
  bool _isSaving = false;

  String? _mainBusinessName;
  int? _mainBusinessId;
  int? _editingBranchId; // Kama ni null tunatengeneza mpya, kama ina ID tunaupdate

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata Main Business Info
      final userProfile = await supabase.from('users').select('business_name').eq('id', user.id).maybeSingle();
      if (userProfile != null) {
        _mainBusinessName = userProfile['business_name'];
        final bData = await supabase.from('businesses').select('id').eq('business_name', _mainBusinessName!).eq('is_main_business', true).maybeSingle();
        _mainBusinessId = bData?['id'];

        // 2. Pata Branches zote
        final branchesData = await supabase
            .from('businesses')
            .select()
            .eq('business_name', _mainBusinessName!)
            .eq('is_main_business', false)
            .order('sub_name', ascending: true);

        setState(() => _branches = List<Map<String, dynamic>>.from(branchesData));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Hii inafungua kile kijidirisha cha kuandika (Bottom Sheet)
  void _openBranchForm([Map<String, dynamic>? branch]) {
    if (branch != null) {
      _editingBranchId = branch['id'];
      _subNameController.text = branch['sub_name'] ?? '';
      _locationController.text = branch['location'] ?? '';
      _phoneController.text = branch['phone'] ?? '';
    } else {
      _editingBranchId = null;
      _subNameController.clear();
      _locationController.clear();
      _phoneController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_editingBranchId == null ? "Sajili Tawi Jipya" : "Hariri Tawi",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildTextField(_subNameController, "Jina la Tawi", Icons.store),
              _buildTextField(_locationController, "Eneo / City", Icons.location_on),
              _buildTextField(_phoneController, "Namba ya Simu", Icons.phone),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF311B92), padding: const EdgeInsets.symmetric(vertical: 15)),
                  onPressed: _isSaving ? null : _saveBranch,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("HIFADHI TAWI", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBranch() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final data = {
        'business_name': _mainBusinessName,
        'sub_name': _subNameController.text.trim(),
        'location': _locationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'parent_id': _mainBusinessId,
        'is_main_business': false,
        'user_id': supabase.auth.currentUser!.id,
      };

      if (_editingBranchId == null) {
        await supabase.from('businesses').insert(data);
      } else {
        await supabase.from('businesses').update(data).eq('id', _editingBranchId!);
      }

      Navigator.pop(context); // Funga bottom sheet
      _loadData(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Imefanikiwa!"), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Save Error: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("MANAGEMENT YA MATAWI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: const Color(0xFF311B92),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildHeaderCard(),
          Expanded(
            child: _branches.isEmpty
                ? const Center(child: Text("Huna matawi yoyote kwa sasa."))
                : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _branches.length,
              itemBuilder: (context, index) {
                final b = _branches[index];
                return _buildBranchTile(b);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF311B92),
        onPressed: () async {
          // 1. Inafungua screen ya CreateSubBusinessScreen
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateSubBusinessScreen(),
            ),
          );

          // 2. Mtumiaji akirudi (Navigator.pop), list inajisajisha yenyewe
          _loadData();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Biashara Kuu(Main-Branch):", style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(_mainBusinessName ?? "Loading...", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF311B92))),
        ],
      ),
    );
  }

  Widget _buildBranchTile(Map<String, dynamic> b) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Color(0xFFEDE7F6), child: Icon(Icons.store, color: Color(0xFF311B92))),
        title: Text(b['sub_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${b['location']} | ${b['phone']}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openBranchForm(b)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(b['id'])),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v!.isEmpty ? "Lazima ujaze hapa" : null,
      ),
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Futa Tawi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hapana")),
          TextButton(onPressed: () async {
            await supabase.from('businesses').delete().eq('id', id);
            Navigator.pop(context);
            _loadData();
          }, child: const Text("Ndio, Futa", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}