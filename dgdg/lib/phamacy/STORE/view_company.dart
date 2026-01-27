import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewCompaniesScreen extends StatefulWidget {
  const ViewCompaniesScreen({super.key});

  @override
  State<ViewCompaniesScreen> createState() => _ViewCompaniesScreenState();
}

class _ViewCompaniesScreenState extends State<ViewCompaniesScreen> {
  final supabase = Supabase.instance.client;

  List<String> _companies = [];
  List<String> _filteredCompanies = [];
  bool _isLoading = true;
  bool _isDarkMode = false;
  String? _myBusinessName; // Stores the current user's business
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initializeData();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  /// 🛠️ Step 1: Initialize everything
  Future<void> _initializeData() async {
    await _getBusinessInfo(); // First, find out who the user is
    if (_myBusinessName != null) {
      await _fetchCompanies(); // Then, fetch only their companies
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// 👤 Step 2: Get Current User's Business Name
  Future<void> _getBusinessInfo() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', currentUser.id)
          .single();

      if (mounted) {
        setState(() {
          _myBusinessName = userProfile['business_name'] ?? '';
        });
      }
    } catch (e) {
      debugPrint("Error fetching business info: $e");
    }
  }

  /// 🏭 Step 3: Fetch ONLY companies associated with that business
  Future<void> _fetchCompanies() async {
    if (_myBusinessName == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('companies')
          .select('name')
          .eq('business_name', _myBusinessName!) // 🔥 CRITICAL FILTER
          .order('name', ascending: true);

      final List<dynamic> data = response as List<dynamic>;

      setState(() {
        _companies = data.map((item) => item['name'].toString()).toList();
        _filteredCompanies = _companies;
      });
    } catch (e) {
      debugPrint("❌ Fetch Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterCompanies(String query) {
    setState(() {
      _filteredCompanies = _companies
          .where((c) => c.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FB);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_myBusinessName ?? "Loading...",
            style: const TextStyle(color: Colors.white, fontSize: 16)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF311B92), Color(0xFF673AB7)]),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCompanies,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: "Search in $_myBusinessName...",
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                filled: true,
                fillColor: cardColor,
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.white54 : Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCompanies.isEmpty
                ? Center(child: Text("No companies found for this branch", style: TextStyle(color: textCol)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredCompanies.length,
              itemBuilder: (context, index) {
                return Card(
                  color: cardColor,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(_filteredCompanies[index], style: TextStyle(color: textCol)),
                    leading: const Icon(Icons.business, color: Colors.deepPurpleAccent),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}