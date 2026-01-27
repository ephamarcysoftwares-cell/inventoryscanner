import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SubRegisterScreenStaff extends StatefulWidget {
  const SubRegisterScreenStaff({super.key});

  @override
  _SubRegisterScreenStaffState createState() => _SubRegisterScreenStaffState();
}

class _SubRegisterScreenStaffState extends State<SubRegisterScreenStaff> {
  final SupabaseClient supabase = Supabase.instance.client;

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  List<Map<String, dynamic>> _allBranches = [];
  Map<String, dynamic>? _selectedBranch;
  String _selectedRole = 'staff';
  String? currentUserRole;

  bool isLoading = false;
  bool isInitializing = true;
  String errorMessage = '';

  // Orodha kamili ya Role zote
  final List<Map<String, String>> _allAvailableRoles = [
    // {'value': 'staff', 'label': 'Staff (Mfanyakazi)'},
    // {'value': 'sub_admin', 'label': 'Sub-Admin (Meneja Tawi)'},
    {'value': 'accountant', 'label': 'Accountant (Mhasibu)'},
    {'value': 'supplier', 'label': 'Supplier (Muuzaji)'},
    {'value': 'it', 'label': 'IT Support'},
    {'value': 'hr', 'label': 'HR (Rasilimali Watu)'},
    {'value': 'storekeeper', 'label': 'Storekeeper (Mkutunza Stoo)'},
  ];

  @override
  void initState() {
    super.initState();
    phoneController.text = '+255';
    _fetchAccessData();
  }

  Future<void> _fetchAccessData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('users')
          .select('role, business_name, business_id, sub_business_name')
          .eq('id', user.id)
          .single();

      currentUserRole = profile['role'];

      if (currentUserRole == 'admin') {
        final branches = await supabase
            .from('businesses')
            .select('id, business_name, sub_name')
            .eq('business_name', profile['business_name']);

        setState(() {
          _allBranches = List<Map<String, dynamic>>.from(branches);
          if (_allBranches.isNotEmpty) _selectedBranch = _allBranches[0];
        });
      } else {
        // Ikiwa ni Sub-Admin au role nyingine, anafungwa kwenye tawi lake tu
        setState(() {
          _selectedBranch = {
            'id': profile['business_id'],
            'business_name': profile['business_name'],
            'sub_name': profile['sub_business_name'],
          };
          _allBranches = [_selectedBranch!];
          _selectedRole = 'staff'; // Default role kwa ajili ya sub-admin kusajili
        });
      }
    } catch (e) {
      setState(() => errorMessage = "Kosa la kupata ruhusa.");
    } finally {
      setState(() => isInitializing = false);
    }
  }

  // Hii inachuja role kulingana na nani anasajili
  List<Map<String, String>> _getFilteredRoles() {
    if (currentUserRole == 'admin') {
      return _allAvailableRoles; // Admin anaona zote
    } else {
      // Sub-Admin hawezi kusajili Sub-Admin mwenzake
      return _allAvailableRoles.where((r) => r['value'] != 'sub_admin').toList();
    }
  }

  Future<void> handleRegistration() async {
    if (_selectedBranch == null) {
      setState(() => errorMessage = "Tafadhali chagua tawi.");
      return;
    }

    setState(() { isLoading = true; errorMessage = ''; });

    try {
      final authRes = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (authRes.user == null) throw "Kushindwa kuunda Auth.";

      await supabase.from('users').insert({
        'id': authRes.user!.id,
        'full_name': fullNameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': _selectedRole,
        'business_id': _selectedBranch!['id'],
        'business_name': _selectedBranch!['business_name'],
        'sub_business_name': _selectedBranch!['sub_name'],
        'is_temp_password': true,
        'is_disabled': false,
        'last_seen': DateTime.now().toIso8601String(),
      });

      await sendEmailToUser(
        emailController.text.trim(),
        fullNameController.text.trim(),
        passwordController.text.trim(),
        _selectedBranch!['sub_name'] ?? _selectedBranch!['business_name'],
      );

      _showSuccess(fullNameController.text, _selectedRole);

    } on AuthException catch (e) {
      if (e.message.contains('already registered') || e.statusCode == '422') {
        setState(() => errorMessage = "Mtumiaji huyu tayari ameshasajiliwa.");
      } else {
        setState(() => errorMessage = "Hitilafu: ${e.message}");
      }
    } catch (e) {
      setState(() => errorMessage = "Tatizo la kiufundi limetokea.");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color deepPurple = Color(0xFF311B92);
    final filteredRoles = _getFilteredRoles();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text("USAJILI WA WATUMIAJI", style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: deepPurple,
      ),
      body: isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSection(
              title: "Chagua Role na Tawi",
              icon: Icons.store_mall_directory,
              child: Column(
                children: [
                  _buildDropdown<String>(
                    label: "Nafasi (Role)",
                    value: _selectedRole,
                    items: filteredRoles.map((role) {
                      return DropdownMenuItem(
                        value: role['value'],
                        child: Text(role['label']!),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),

                  const SizedBox(height: 15),

                  _buildDropdown<Map<String, dynamic>>(
                    label: "Tawi la Kazi",
                    value: _selectedBranch,
                    items: _allBranches.map((b) {
                      String branchDisplay = (b['sub_name'] == null || b['sub_name'] == '')
                          ? "${b['business_name']} (Main)"
                          : "${b['business_name']} - ${b['sub_name']}";

                      return DropdownMenuItem(
                        value: b,
                        child: Text(branchDisplay, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: currentUserRole == 'admin'
                        ? (val) => setState(() => _selectedBranch = val)
                        : null, // Sub-admin hawezi kubadili tawi
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _buildSection(
              title: "Taarifa za Mtumiaji",
              icon: Icons.person_add,
              child: Column(
                children: [
                  _textField(fullNameController, "Jina Kamili", Icons.person),
                  _textField(emailController, "Barua Pepe", Icons.email),
                  _textField(phoneController, "Simu", Icons.phone, type: TextInputType.phone),
                  _textField(passwordController, "Password ya Muda", Icons.lock, obscure: true),
                ],
              ),
            ),

            if (errorMessage.isNotEmpty)
              Padding(padding: const EdgeInsets.all(10), child: Text(errorMessage, style: const TextStyle(color: Colors.red))),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : handleRegistration,
                style: ElevatedButton.styleFrom(backgroundColor: deepPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAJILI MTUMIAJI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildSection({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: Colors.indigo, size: 20), const SizedBox(width: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
          const Divider(height: 25),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, ValueChanged<T?>? onChanged}) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      isExpanded: true,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, IconData icon, {bool obscure = false, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: const Color(0xFFF5F7FB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _showSuccess(String name, String role) {
    String roleLabel = _allAvailableRoles.firstWhere((r) => r['value'] == role)['label']!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Icon(Icons.check_circle, color: Colors.green, size: 50),
        content: Text("$name amesajiliwa kama $roleLabel."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("SAWA"))],
      ),
    );
  }

  Future<void> sendEmailToUser(String email, String name, String pass, String biz) async {
    final smtpServer = SmtpServer('mail.ephamarcysoftware.co.tz', username: 'suport@ephamarcysoftware.co.tz', password: 'Matundu@2050', port: 465, ssl: true);
    final message = mailer.Message()
      ..from = mailer.Address('suport@ephamarcysoftware.co.tz', biz)
      ..recipients.add(email)
      ..subject = 'Karibu - $biz'
      ..html = "Habari $name, akaunti yako imekamilika. Password: $pass";
    try { await mailer.send(message, smtpServer); } catch (e) { debugPrint(e.toString()); }
  }
}