// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
//
// class MembersManagementScreen extends StatefulWidget {
//   final Map<String, dynamic> user;
//   MembersManagementScreen({required this.user});
//
//   @override
//   _MembersManagementScreenState createState() => _MembersManagementScreenState();
// }
//
// class _MembersManagementScreenState extends State<MembersManagementScreen> {
//   final SupabaseClient supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> _members = [];
//   bool _isLoading = true;
//   bool _isDarkMode = false;
//   int? _businessId;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadTheme();
//     _initializeData();
//   }
//
//   Future<void> _loadTheme() async {
//     final prefs = await SharedPreferences.getInstance();
//     setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
//   }
//
//   Future<void> _initializeData() async {
//     // Tunachukua business_id kutoka kwenye widget ya user tuliyopitishiwa
//     _businessId = widget.user['business_id'] != null
//         ? int.tryParse(widget.user['business_id'].toString())
//         : null;
//     await _fetchMembers();
//   }
//
//   Future<void> _fetchMembers() async {
//     setState(() => _isLoading = true);
//     try {
//       final response = await supabase
//           .from('members')
//           .select()
//           .eq('business_id', _businessId)
//           .order('full_name', ascending: true);
//
//       setState(() {
//         _members = List<Map<String, dynamic>>.from(response);
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint("Error fetching members: $e");
//       setState(() => _isLoading = false);
//     }
//   }
//
//   // Function ya kuongeza mwanachama kupitia Dialog
//   void _showAddMemberDialog() {
//     final nameController = TextEditingController();
//     final phoneController = TextEditingController();
//
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: _isDarkMode ? Color(0xFF1E293B) : Colors.white,
//         title: Text("Ongeza Mwanachama", style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             TextField(
//               controller: nameController,
//               style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
//               decoration: InputDecoration(labelText: "Jina Kamili"),
//             ),
//             TextField(
//               controller: phoneController,
//               keyboardType: TextInputType.phone,
//               style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
//               decoration: InputDecoration(labelText: "Namba ya Simu"),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: Text("Futa")),
//           ElevatedButton(
//             onPressed: () async {
//               if (nameController.text.isNotEmpty) {
//                 await supabase.from('members').insert({
//                   'full_name': nameController.text.trim(),
//                   'phone': phoneController.text.trim(),
//                   'business_id': _businessId,
//                 });
//                 Navigator.pop(context);
//                 _fetchMembers();
//               }
//             },
//             child: Text("Hifadhi"),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final isDark = _isDarkMode;
//     final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F7FA);
//     final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
//
//     return Scaffold(
//       backgroundColor: bgColor,
//       appBar: AppBar(
//         title: Text("WANACHAMA WA VIKOBA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//         flexibleSpace: Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF311B92), Colors.purple]))),
//         actions: [
//           IconButton(icon: Icon(Icons.refresh), onPressed: _fetchMembers),
//         ],
//       ),
//       body: _isLoading
//           ? Center(child: CircularProgressIndicator())
//           : Column(
//         children: [
//           _buildSummaryHeader(),
//           Expanded(
//             child: _members.isEmpty
//                 ? Center(child: Text("Hakuna mwanachama aliyesajiliwa", style: TextStyle(color: isDark ? Colors.white : Colors.black)))
//                 : ListView.builder(
//               itemCount: _members.length,
//               padding: EdgeInsets.all(10),
//               itemBuilder: (context, index) {
//                 final member = _members[index];
//                 return _buildMemberCard(member, cardColor, isDark);
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _showAddMemberDialog,
//         backgroundColor: Colors.purple,
//         child: Icon(Icons.person_add, color: Colors.white),
//       ),
//     );
//   }
//
//   Widget _buildSummaryHeader() {
//     return Container(
//       padding: EdgeInsets.all(20),
//       width: double.infinity,
//       color: Colors.purple.withOpacity(0.1),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _sumItem("Wanachama", _members.length.toString()),
//           _sumItem("Jumla Akiba", "TSh 0"), // Hizi unaweza kuzipigia hesabu toka kwenye list
//         ],
//       ),
//     );
//   }
//
//   Widget _sumItem(String title, String value) {
//     return Column(
//       children: [
//         Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
//         Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple)),
//       ],
//     );
//   }
//
//   Widget _buildMemberCard(Map<String, dynamic> member, Color cardColor, bool isDark) {
//     return Card(
//       color: cardColor,
//       margin: EdgeInsets.only(bottom: 10),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//       child: ListTile(
//         leading: CircleAvatar(
//           backgroundColor: Colors.purple.shade100,
//           child: Text(member['full_name'][0].toUpperCase(), style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
//         ),
//         title: Text(member['full_name'], style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
//         subtitle: Text("Simu: ${member['phone'] ?? 'N/A'}", style: TextStyle(color: Colors.grey, fontSize: 12)),
//         trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
//         onTap: () {
//           // Hapa utapeleka kwenye page ya MemberDetails kuona michango na mikopo yake
//         },
//       ),
//     );
//   }
// }