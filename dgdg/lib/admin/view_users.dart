import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperViewUsersScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const SuperViewUsersScreen({super.key, required this.user});

  @override
  _SuperViewUsersScreenState createState() => _SuperViewUsersScreenState();
}

class _SuperViewUsersScreenState extends State<SuperViewUsersScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  bool isProfileLoading = true;
  String? businessName;
  String? myRole;
  String? myEmail;
  String? myId;
  dynamic myBusinessId;

  String searchQuery = "";
  final String superAdminEmail = 'mlyukakenedy@gmail.com';

  @override
  void initState() {
    super.initState();
    getBusinessInfo();
  }

  /// ✅ 1. KUPATA TAARIFA ZA MTUMIAJI ALIYELOGIN
  Future<void> getBusinessInfo() async {
    try {
      setState(() => isProfileLoading = true);
      final userId = widget.user['id'];
      if (userId == null) return;

      final userProfile = await supabase
          .from('users')
          .select('business_name, business_id, role, email, id')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile != null && mounted) {
        setState(() {
          businessName = userProfile['business_name']?.toString();
          myBusinessId = userProfile['business_id'];
          myRole = userProfile['role']?.toString();
          myEmail = userProfile['email']?.toString();
          myId = userProfile['id']?.toString();
          isProfileLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error Fetching Info: $e');
      if (mounted) setState(() => isProfileLoading = false);
    }
  }

  /// ✅ 2. KUFUNGIA AU KUFUNGUA MTUMIAJI (TOGGLE STATUS)
  Future<void> _toggleUserStatus(Map<String, dynamic> staff) async {
    bool currentlyDisabled = staff['is_disabled'] == true;

    if (!currentlyDisabled) {
      String reason = "";
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Mfungie ${staff['full_name']}"),
          content: TextField(
            onChanged: (val) => reason = val,
            decoration: const InputDecoration(
              hintText: "Andika sababu ya kumfungia...",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("GHAIRI")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (reason.trim().isEmpty) return;
                await supabase.from('users').update({
                  'is_disabled': true,
                  'block_reason': reason
                }).eq('id', staff['id']);
                Navigator.pop(context);
              },
              child: const Text("BLOCK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      // Fungua Mtumiaji (Unlock)
      await supabase.from('users').update({
        'is_disabled': false,
        'block_reason': null
      }).eq('id', staff['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isProfileLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isKennedy = myEmail == superAdminEmail;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(
          isKennedy ? "SYSTEM OVERSEER" : "STAFF WA $businessName",
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF311B92),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchArea(),
          Expanded(child: _buildStaffRealtimeList(isKennedy)),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Container(
      color: const Color(0xFF311B92),
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 15),
      child: TextField(
        onChanged: (v) => setState(() => searchQuery = v),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Tafuta mfanyakazi...",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildStaffRealtimeList(bool isKennedy) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('users').stream(primaryKey: ['id']).order('full_name'),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Hitilafu: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allUsers = snapshot.data!;

        final filtered = allUsers.where((u) {
          // 1. Kennedy anaona wote
          if (isKennedy) return true;

          // 2. Linganisha Business kwa usalama
          String staffBizName = (u['business_name'] ?? "").toString().toLowerCase().trim();
          String myBizName = (businessName ?? "").toString().toLowerCase().trim();
          String staffBizId = (u['business_id'] ?? "").toString();
          String myBizId = (myBusinessId ?? "").toString();

          bool matchesBusiness = false;
          if (myRole == 'admin') {
            matchesBusiness = staffBizName == myBizName && myBizName.isNotEmpty;
          } else {
            matchesBusiness = staffBizId == myBizId && myBizId.isNotEmpty;
          }

          // 3. Search filter
          bool matchesSearch = u['full_name'].toString().toLowerCase().contains(searchQuery.toLowerCase());

          // 4. Usijione wewe mwenyewe (Current User)
          bool isNotMe = u['id'].toString() != myId;

          return matchesBusiness && matchesSearch && isNotMe;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  searchQuery.isEmpty ? "Hakuna mfanyakazi mwingine aliyepatikana." : "Mtafutwa hajapatikana.",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final staff = filtered[index];
            final bool isBlocked = staff['is_disabled'] == true;

            return Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                leading: CircleAvatar(
                  backgroundColor: isBlocked ? Colors.red[50] : Colors.blue[50],
                  child: Icon(Icons.person, color: isBlocked ? Colors.red : const Color(0xFF311B92)),
                ),
                title: Text(
                  staff['full_name'] ?? "N/A",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${staff['role']} • ${staff['business_name'] ?? 'N/A'}"),
                trailing: Container(
                  decoration: BoxDecoration(
                    color: isBlocked ? Colors.red[50] : Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: Icon(
                      isBlocked ? Icons.lock : Icons.lock_open,
                      color: isBlocked ? Colors.red : Colors.green,
                    ),
                    onPressed: () => _toggleUserStatus(staff),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}