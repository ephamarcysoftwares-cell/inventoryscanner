import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewEventPage extends StatefulWidget {
  const ViewEventPage({super.key});

  @override
  State<ViewEventPage> createState() => _ViewEventPageState();
}

class _ViewEventPageState extends State<ViewEventPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> allEvents = [];
  List<Map<String, dynamic>> filteredEvents = [];
  bool isLoading = true;
  bool _isDarkMode = false;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchEvents();
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _fetchEvents() async {
    try {
      setState(() => isLoading = true);
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('upcoming_event')
          .select()
          .eq('user_id', user.id)
          .order('event_date', ascending: true);

      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);

      setState(() {
        allEvents = data;
        filteredEvents = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _updateEvent(int id, String newTitle) async {
    try {
      await supabase
          .from('upcoming_event')
          .update({'event_title': newTitle})
          .eq('id', id);

      _fetchEvents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event updated successfully")),
        );
      }
    } catch (e) {
      debugPrint('Update Error: $e');
    }
  }

  Future<void> _deleteEvent(int id) async {
    try {
      await supabase.from('upcoming_event').delete().eq('id', id);
      _fetchEvents();
    } catch (e) {
      debugPrint('Delete Error: $e');
    }
  }

  void _filterSearch(String query) {
    setState(() {
      searchQuery = query;
      filteredEvents = allEvents.where((event) {
        final title = (event['event_title'] ?? '').toString().toLowerCase();
        return title.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme setup based on _isDarkMode
    final Color primaryPurple = const Color(0xFF673AB7);
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color cardColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("UPCOMING EVENTS",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,
        backgroundColor: primaryPurple,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(25))),
      ),
      body: Column(
        children: [
          _buildSearchBar(cardColor, textColor, primaryPurple),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryPurple))
                : filteredEvents.isEmpty
                ? _buildEmptyState(textColor)
                : _buildEventList(primaryPurple, cardColor, textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color cardColor, Color textColor, Color primaryPurple) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isDarkMode ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: TextField(
          onChanged: _filterSearch,
          // ✅ FIX: This ensures the typing text matches your theme
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: "Search events...",
            hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: primaryPurple),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 60, color: textColor.withOpacity(0.2)),
          const SizedBox(height: 10),
          Text("No events found", style: TextStyle(color: textColor.withOpacity(0.4))),
        ],
      ),
    );
  }

  Widget _buildEventList(Color primary, Color cardColor, Color textColor) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        final event = filteredEvents[index];
        final DateTime? eventDate = DateTime.tryParse(event['event_date'] ?? '');
        final String dayName = eventDate != null ? DateFormat('EEE').format(eventDate) : '??';
        final String dayNum = eventDate != null ? DateFormat('dd').format(eventDate) : '00';
        final String fullDate = eventDate != null ? DateFormat('MMMM dd, yyyy').format(eventDate) : 'N/A';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            leading: _buildDateBadge(dayName, dayNum, primary),
            title: Text(
              (event['event_title'] ?? 'Untitled').toString().toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w900, color: textColor, fontSize: 13, letterSpacing: 0.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(fullDate, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 11, fontWeight: FontWeight.w500)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                  onPressed: () => _showEditDialog(event, cardColor, textColor, primary),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(event['id'], cardColor, textColor, primary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateBadge(String day, String num, Color primary) {
    return Container(
      width: 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day.toUpperCase(), style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold)),
          Text(num, style: TextStyle(fontSize: 20, color: primary, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> event, Color cardColor, Color textColor, Color primary) {
    final TextEditingController editController = TextEditingController(text: event['event_title']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Edit Event", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: editController,
          // ✅ FIX: Input text color in the dialog
          style: TextStyle(color: textColor),
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Enter event title",
            hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
            filled: true,
            fillColor: textColor.withOpacity(0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: textColor.withOpacity(0.6), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (editController.text.isNotEmpty) {
                Navigator.pop(context);
                _updateEvent(event['id'], editController.text.trim());
              }
            },
            child: const Text("UPDATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int id, Color cardColor, Color textColor, Color primary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Delete Event?", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text("This will remove the event from your cloud diary forever.",
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: primary))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () { Navigator.pop(context); _deleteEvent(id); },
              child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}