import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../PERMISSION/AssignPermissionsScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewUsersScreen extends StatefulWidget {
  const ViewUsersScreen({super.key});

  @override
  _ViewUsersScreenState createState() => _ViewUsersScreenState();
}

class _ViewUsersScreenState extends State<ViewUsersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> userList = [];
  bool isLoading = true;
  String? _currentAdminBusiness;
  bool _isDarkMode = false;

  // Email ya Super Admin pekee
  final String superAdminEmail = 'mlyukakenedy@gmail.com';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    fetchUsers();
  }

  /// 1. VUTA WAFANYAKAZI (Security + Context Filtering)
  /// 1. VUTA WAFANYAKAZI (Kennedy anaona wote, wengine wanaona biashara zao tu)
  Future<void> fetchUsers() async {
    setState(() => isLoading = true);
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) return;

      // 1. Pata profile ya aliyelogin sasa hivi
      final myProfile = await supabase.from('users').select().eq('id', currentUser.id).single();
      final String myEmail = myProfile['email'] ?? "";
      final String myBiz = myProfile['business_name'] ?? "";
      setState(() => _currentAdminBusiness = myBiz);

      // 2. Anza Query
      var query = supabase.from('users').select();

      // --- HAPA NDIPO LOGIC YA KENNEDY ILIPO ---
      if (myEmail == superAdminEmail) {
        // KENNEDY: Usiweke .eq() yoyote, vuta kila kitu kwenye table
        debugPrint("Super Admin identified: Loading all users globally.");
      } else {
        // ADMIN MWINGINE: Lazima aone wa biashara yake tu
        debugPrint("Standard Admin identified: Filtering by $myBiz");
        query = query.eq('business_name', myBiz);
      }

      final response = await query.order('full_name', ascending: true);

      setState(() {
        userList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint("⚠️ Makosa: $e");
      setState(() => isLoading = false);
    }
  }

  /// 2. BLOCK/UNBLOCK LOGIC + KINGA YA ADMIN
  Future<void> toggleUserStatus(Map<String, dynamic> staff) async {
    final currentUser = supabase.auth.currentUser;
    final bool currentlyDisabled = staff['is_disabled'] == true;

    // A. KINGA: Huwezi kujiblock mwenyewe (Kennedy au Admin mwingine)
    if (staff['id'] == currentUser?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Huwezi kuifunga akaunti yako mwenyewe!"), backgroundColor: Colors.red),
      );
      return;
    }

    if (!currentlyDisabled) {
      // B. KAMA TUNAMBLOCK: Omba sababu
      String reason = "";
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Mfungie ${staff['full_name']}"),
          content: TextField(
            maxLines: 2,
            onChanged: (val) => reason = val,
            decoration: const InputDecoration(
              hintText: "Andika sababu ya kumzuia...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                if (reason.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lazima uandike sababu!")));
                  return;
                }
                Navigator.pop(context);
                _processStatusUpdate(staff['id'], true, reason);
              },
              child: const Text("BLOCK NOW"),
            ),
          ],
        ),
      );
    } else {
      // C. KAMA TUNAMFUNGUA (UNBLOCK)
      _processStatusUpdate(staff['id'], false, null);
    }
  }

  Future<void> _processStatusUpdate(String userId, bool disable, String? reason) async {
    setState(() => isLoading = true);
    try {
      await supabase.from('users').update({
        'is_disabled': disable,
        'block_reason': reason,
      }).eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(disable ? "User amefungiwa." : "User amefunguliwa.")),
      );
      fetchUsers();
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  /// 3. HAMISHA TAWI (LOAD ALL BRANCHES FIRST)
  Future<void> _changeUserBranch(Map<String, dynamic> staff) async {
    setState(() => isLoading = true);
    try {
      final branchesRes = await supabase
          .from('businesses')
          .select('id, sub_name, location')
          .eq('business_name', _currentAdminBusiness!)
          .order('sub_name', ascending: true);

      final List<Map<String, dynamic>> branches = List<Map<String, dynamic>>.from(branchesRes);
      setState(() => isLoading = false);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Mhamishe ${staff['full_name']}"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: branches.length,
              itemBuilder: (context, index) {
                final b = branches[index];
                return ListTile(
                  leading: const Icon(Icons.location_on, color: Colors.orange),
                  title: Text(b['sub_name'] ?? "MAIN BRANCH"),
                  subtitle: Text(b['location'] ?? ""),
                  onTap: () async {
                    Navigator.pop(context);
                    await supabase.from('users').update({
                      'business_id': b['id'],
                      'sub_business_name': b['sub_name'],
                    }).eq('id', staff['id']);
                    fetchUsers();
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) { setState(() => isLoading = false); }
  }

  /// 4. MAELEZO KAMILI (FULL DETAILS)
  void _showStaffDetails(Map<String, dynamic> staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        height: MediaQuery.of(context).size.height * 0.75,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 15),
              Text(staff['full_name'] ?? "N/A", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(staff['professional'] ?? "General Staff", style: const TextStyle(color: Colors.grey)),
              const Divider(height: 40),
              _infoRow(Icons.email, "Email Address", staff['email'] ?? "N/A"),
              _infoRow(Icons.phone, "Phone Number", staff['phone'] ?? "N/A"),
              _infoRow(Icons.store, "Business / Branch", "${staff['business_name']} - ${staff['sub_business_name'] ?? 'Main'}"),
              _infoRow(Icons.admin_panel_settings, "Role", staff['role'] ?? "Staff"),
              _infoRow(Icons.access_time, "Last Seen", staff['last_seen']?.toString().substring(0,16) ?? "N/A"),
              if (staff['is_disabled'] == true)
                _infoRow(Icons.warning, "Block Reason", staff['block_reason'] ?? "N/A"),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE"))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKennedy = supabase.auth.currentUser?.email == superAdminEmail;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(isKennedy ? "SUPER ADMIN: ALL USERS" : "MY STAFF LIST", style: const TextStyle(color: Colors.white, fontSize: 14)),
        backgroundColor: const Color(0xFF311B92),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: userList.length,
        itemBuilder: (context, index) {
          final staff = userList[index];
          final bool isDisabled = staff['is_disabled'] == true;

          return Card(
            child: ListTile(
              onTap: () => _showStaffDetails(staff),
              leading: CircleAvatar(
                backgroundColor: isDisabled ? Colors.red.withOpacity(0.1) : Colors.deepPurple.withOpacity(0.1),
                child: Icon(Icons.person, color: isDisabled ? Colors.red : Colors.deepPurple),
              ),
              title: Text(staff['full_name'] ?? "No Name", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${staff['sub_business_name'] ?? 'Main'} • ${staff['role']}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.swap_horiz, color: Colors.orange), onPressed: () => _changeUserBranch(staff)),
                  Switch(
                    value: !isDisabled,
                    activeColor: Colors.green,
                    inactiveThumbColor: Colors.red,
                    onChanged: (val) => toggleUserStatus(staff),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, color: Colors.deepPurple, size: 22),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ])),
      ]),
    );
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }
}