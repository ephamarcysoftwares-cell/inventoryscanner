import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class ViewCompaniesScreen extends StatefulWidget {
  const ViewCompaniesScreen({super.key});

  @override
  _ViewCompaniesScreenState createState() => _ViewCompaniesScreenState();
}

class _ViewCompaniesScreenState extends State<ViewCompaniesScreen> {
  // --- STATE VARIABLES ---
  List<Map<String, dynamic>> _companies = [];
  String _currentBranch = "Pakia...";
  bool _isLoading = true;
  bool _isDarkMode = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _initializeData();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  // --- LOGIC: FETCHING ---
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    String branchName = await _fetchUserBusinessName();
    if (mounted) setState(() => _currentBranch = branchName);
    await _loadCompanies(branchName);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<String> _fetchUserBusinessName() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return "STOCK ONLINE STORE";

      final resp = await supabase.from('users').select('business_name').eq('id', userId).maybeSingle();
      return resp?['business_name']?.toString() ?? "STOCK ONLINE STORE";
    } catch (e) {
      return "STOCK ONLINE STORE";
    }
  }

  Future<void> _loadCompanies(String branchName) async {
    try {
      final data = await Supabase.instance.client
          .from('companies')
          .select('id, name, address')
          .eq('business_name', branchName)
          .order('name', ascending: true);
      if (mounted) setState(() => _companies = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint("Load error: $e");
    }
  }

  // --- LOGIC: SAVE / UPDATE / DELETE ---
  Future<void> _saveOrUpdate(String? existingId) async {
    if (_nameController.text.isEmpty) return;

    try {
      final supabase = Supabase.instance.client;
      final data = {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'business_name': _currentBranch,
      };

      if (existingId == null) {
        await supabase.from('companies').insert(data);
      } else {
        await supabase.from('companies').update({
          'name': data['name'],
          'address': data['address'],
        }).eq('id', existingId);
      }

      _nameController.clear();
      _addressController.clear();
      Navigator.pop(context);
      _initializeData();
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _deleteCompany(String id) async {
    await Supabase.instance.client.from('companies').delete().eq('id', id);
    _initializeData();
  }

  // --- UI: BOTTOM SHEET FORM ---
  void _showForm(Map<String, dynamic>? company) {
    if (company != null) {
      _nameController.text = company['name'];
      _addressController.text = company['address'];
    } else {
      _nameController.clear();
      _addressController.clear();
    }

    final bool isDark = _isDarkMode;
    final Color sheetColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 25, left: 20, right: 20),
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text(company == null ? "Sajili Kampuni Mpya" : "Hariri Kampuni",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 20),
            _buildField(_nameController, "Jina la Kampuni / Brand", Icons.business_outlined, isDark),
            const SizedBox(height: 15),
            _buildField(_addressController, "Anwani (Location)", Icons.location_on_outlined, isDark),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF311B92),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => _saveOrUpdate(company?['id']?.toString()),
                child: Text(company == null ? "HIFADHI SASA" : "SASISHA TAARIFA", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, bool isDark) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF673AB7)),
        filled: true,
        fillColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF673AB7))),
      ),
    );
  }

  // --- UI: MAIN SCREEN ---
  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            const Text("ORODHA YA KAMPUNI", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
            Text("BRANCH: $_currentBranch", style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)]),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _initializeData),
        ],
      ),
      body: Column(
        children: [
          // Banner ya kisasa
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: isDark ? Colors.white70 : Colors.blueGrey),
                const SizedBox(width: 8),
                Text("Kampuni zote zilizosajiliwa chini ya: $_currentBranch",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.blueGrey)),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF673AB7)))
                : _companies.isEmpty
                ? _emptyState(isDark)
                : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: _companies.length,
              itemBuilder: (context, index) {
                final company = _companies[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF673AB7).withOpacity(0.1),
                      child: const Icon(Icons.business_rounded, color: Color(0xFF673AB7)),
                    ),
                    title: Text(company['name'],
                        style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    subtitle: Text(company['address'] ?? 'Anwani haijatajwa',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
                      onSelected: (val) {
                        if (val == 'edit') _showForm(company);
                        if (val == 'delete') _deleteCompany(company['id'].toString());
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text("Hariri")])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text("Futa", style: TextStyle(color: Colors.red))])),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 5,
        backgroundColor: const Color(0xFF1B5E20),
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add_business_rounded, color: Colors.white),
      ),
      bottomNavigationBar: CurvedRainbowBar(height: 40),
    );
  }

  Widget _emptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 15),
          const Text("Hakuna kampuni zilizopatikana",
              style: TextStyle(color: Colors.blueGrey, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}