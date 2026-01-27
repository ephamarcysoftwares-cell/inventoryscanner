import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewDiaryPage extends StatefulWidget {
  const ViewDiaryPage({super.key});

  @override
  State<ViewDiaryPage> createState() => _ViewDiaryPageState();
}

class _ViewDiaryPageState extends State<ViewDiaryPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allEntries = [];
  List<Map<String, dynamic>> filteredEntries = [];

  String searchQuery = '';
  DateTime? fromDate;
  DateTime? toDate;
  bool isLoading = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDiaryEntries();
  }

  void _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _loadDiaryEntries() async {
    try {
      setState(() => isLoading = true);
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('diary')
          .select()
          .eq('user_id', user.id)
          .order('activity_date', ascending: false);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      setState(() {
        allEntries = data;
        filteredEntries = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _filterEntries() {
    setState(() {
      filteredEntries = allEntries.where((entry) {
        final title = (entry['activity_title'] ?? '').toString().toLowerCase();
        final dateStr = entry['activity_date']?.toString() ?? '';
        final date = DateTime.tryParse(dateStr);

        final matchesTitle = title.contains(searchQuery.toLowerCase());
        final matchesFrom = fromDate == null || (date != null && date.isAfter(fromDate!.subtract(const Duration(days: 1))));
        final matchesTo = toDate == null || (date != null && date.isBefore(toDate!.add(const Duration(days: 1))));

        return matchesTitle && matchesFrom && matchesTo;
      }).toList();
    });
  }

  Future<void> _updateOnSupabase(int id, String newTitle, String newDesc) async {
    try {
      await supabase.from('diary').update({
        'activity_title': newTitle,
        'activity_description': newDesc,
      }).eq('id', id);
      _loadDiaryEntries();
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> _deleteFromSupabase(int id) async {
    try {
      await supabase.from('diary').delete().eq('id', id);
      _loadDiaryEntries();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: _isDarkMode ? ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: const Color(0xFF673AB7))) : ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: const Color(0xFF673AB7))),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { if (isFrom) fromDate = picked; else toDate = picked; });
      _filterEntries();
    }
  }

  void _showEditDialog(Map<String, dynamic> entry) {
    final titleController = TextEditingController(text: entry['activity_title'] ?? '');
    final descController = TextEditingController(text: entry['activity_description'] ?? '');

    final Color textColor = _isDarkMode ? Colors.white : Colors.black;
    final Color fieldColor = _isDarkMode ? const Color(0xFF1A2238) : const Color(0xFFF5F7FB);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF16213E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit Diary Entry", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(titleController, "Title", fieldColor, textColor),
            const SizedBox(height: 15),
            _buildDialogField(descController, "Description", fieldColor, textColor, maxLines: 4),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF673AB7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              _updateOnSupabase(entry['id'], titleController.text, descController.text);
              Navigator.pop(context);
            },
            child: const Text("Update", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helper for Dialog TextFields
  Widget _buildDialogField(TextEditingController ctrl, String label, Color bg, Color txt, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(color: txt),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: txt.withOpacity(0.6)),
        filled: true,
        fillColor: bg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryPurple = const Color(0xFF673AB7);
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color cardColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("DIARY HISTORY", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: Column(
        children: [
          _buildFilters(primaryPurple, cardColor, textColor),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryPurple))
                : _buildList(primaryPurple, cardColor, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(Color primary, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: _isDarkMode ? Colors.transparent : Colors.white,
      child: Column(
        children: [
          // Search Field in Dark Mode
          TextField(
            style: TextStyle(color: textColor),
            onChanged: (val) { searchQuery = val; _filterEntries(); },
            decoration: InputDecoration(
              hintText: "Search your activities...",
              hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: primary),
              filled: true,
              fillColor: cardColor, // Strictly dark background in dark mode
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _dateBtn(isFrom: true, color: primary, cardColor: cardColor)),
              const SizedBox(width: 10),
              Expanded(child: _dateBtn(isFrom: false, color: primary, cardColor: cardColor)),
            ],
          )
        ],
      ),
    );
  }

  Widget _dateBtn({required bool isFrom, required Color color, required Color cardColor}) {
    return InkWell(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today_outlined, size: 14, color: color),
            const SizedBox(width: 8),
            Text(
              isFrom ? (fromDate == null ? "From" : DateFormat('MMM dd').format(fromDate!))
                  : (toDate == null ? "To" : DateFormat('MMM dd').format(toDate!)),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(Color primary, Color cardColor, Color textColor) {
    if (filteredEntries.isEmpty) {
      return Center(child: Text("No entries found", style: TextStyle(color: textColor.withOpacity(0.5))));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = filteredEntries[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isDarkMode ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(
              entry['activity_title']?.toUpperCase() ?? 'UNTITLED',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(entry['activity_description'] ?? '', style: TextStyle(color: textColor, fontSize: 13)),
                const SizedBox(height: 10),
                Text(entry['activity_date'] ?? '', style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.5))),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor.withOpacity(0.5)),
              color: cardColor,
              onSelected: (val) {
                if (val == 'edit') _showEditDialog(entry);
                if (val == 'delete') _deleteFromSupabase(entry['id']);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: primary), const SizedBox(width: 8), Text("Edit", style: TextStyle(color: textColor))])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
              ],
            ),
          ),
        );
      },
    );
  }
}