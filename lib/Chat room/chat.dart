import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AdvancedChatScreen extends StatefulWidget {
  final String currentUserName;
  final String? initialRoomId;
  final Map<String, dynamic>? initialReply;

  const AdvancedChatScreen({
    super.key,
    required this.currentUserName,
    this.initialRoomId,
    this.initialReply,
  });

  @override
  State<AdvancedChatScreen> createState() => _AdvancedChatScreenState();
}

class _AdvancedChatScreenState extends State<AdvancedChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String activeRoomId;
  String? selectedBusinessName;
  Map<String, dynamic>? replyingToMessage;
  String? editingMessageId;

  List<String> usersTyping = [];
  bool isUploading = false;
  bool _isDarkMode = false;
  late RealtimeChannel _groupChannel;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    activeRoomId = widget.initialRoomId ?? 'business_global_group';
    if (widget.initialReply != null) replyingToMessage = widget.initialReply;

    _loadTheme();
    _loadBusinessNames();
    _initRealtime();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _groupChannel.unsubscribe();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
  }

  Future<void> _loadBusinessNames() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Personalization: Using your public.businesses table
      final response = await supabase
          .from('businesses')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() => selectedBusinessName = response['business_name'].toString().trim());
      }
    } catch (e) {
      debugPrint("Profile Error: $e");
    }
  }

  void _initRealtime() {
    _groupChannel = supabase.channel(activeRoomId);

    _groupChannel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final String user = payload['user'] ?? "Unknown";
        final bool isTyping = payload['isTyping'] ?? false;
        if (mounted) {
          setState(() {
            if (isTyping) {
              if (!usersTyping.contains(user)) usersTyping.add(user);
            } else {
              usersTyping.remove(user);
            }
          });
        }
      },
    ).subscribe();
  }

  void _onTypingChanged(String text) {
    final myIdentity = selectedBusinessName ?? widget.currentUserName;

    _groupChannel.sendBroadcastMessage(
      event: 'typing',
      payload: {'user': myIdentity, 'isTyping': text.isNotEmpty},
    );

    // Auto-stop typing indicator after 2 seconds of no input
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _groupChannel.sendBroadcastMessage(
          event: 'typing',
          payload: {'user': myIdentity, 'isTyping': false},
        );
      }
    });
  }

  Future<void> _sendMsg() async {
    final text = _msgController.text.trim();
    final myIdentity = selectedBusinessName ?? widget.currentUserName;
    if (text.isEmpty && !isUploading) return;

    final String? replyId = replyingToMessage?['id']?.toString();
    final String? currentEditId = editingMessageId;

    _msgController.clear();
    setState(() {
      replyingToMessage = null;
      editingMessageId = null;
    });

    try {
      if (currentEditId != null) {
        await supabase
            .from('messages')
            .update({'content': text})
            .eq('id', currentEditId);
      } else {
        await supabase.from('messages').insert({
          'content': text,
          'sender_name': myIdentity,
          'room_id': activeRoomId,
          'reply_to_id': replyId,
        });
      }
    } catch (e) {
      debugPrint("Chat Error: $e");
    }
  }

  Future<void> _uploadFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image);
    if (res == null) return;
    setState(() => isUploading = true);

    try {
      final file = File(res.files.single.path!);
      final name = "chat/${DateTime.now().millisecondsSinceEpoch}.jpg";
      await supabase.storage.from('chat_files').upload(name, file);
      final url = supabase.storage.from('chat_files').getPublicUrl(name);

      await supabase.from('messages').insert({
        'content': '📷 Photo',
        'sender_name': selectedBusinessName ?? widget.currentUserName,
        'room_id': activeRoomId,
        'file_url': url,
      });
    } catch (e) {
      debugPrint("Upload Error: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Widget _buildStatusPreview(IconData icon, String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      color: isDark ? Colors.black45 : Colors.white,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black))),
          IconButton(
            icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black54),
            onPressed: () => setState(() {
              replyingToMessage = null;
              editingMessageId = null;
              _msgController.clear();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_a_photo, color: Colors.grey),
              onPressed: _uploadFile,
            ),
            Expanded(
              child: TextField(
                controller: _msgController,
                onChanged: _onTypingChanged,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: const TextStyle(color: Colors.grey),
                  fillColor: isDark ? const Color(0xFF2A3942) : Colors.grey[100],
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF075E54),
              child: IconButton(
                icon: Icon(editingMessageId != null ? Icons.check : Icons.send, color: Colors.white),
                onPressed: _sendMsg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> msg, bool isDark) {
    bool isMe = msg['sender_name'] == (selectedBusinessName ?? widget.currentUserName);
    String? replyToId = msg['reply_to_id']?.toString();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Text(msg['sender_name'],
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
            if (replyToId != null) _buildReplyQuote(replyToId, isDark),
            if (msg['file_url'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(msg['file_url'], fit: BoxFit.cover),
              ),
            const SizedBox(height: 4),
            Text(msg['content'] ?? "",
                style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  DateFormat('HH:mm').format(DateTime.parse(msg['created_at'])),
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white60 : Colors.black45),
                ),
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => _showOptions(msg),
                  child: Icon(Icons.keyboard_arrow_down, size: 16, color: isDark ? Colors.white60 : Colors.black45),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyQuote(String replyId, bool isDark) {
    return FutureBuilder(
      future: supabase.from('messages').select().eq('id', replyId).maybeSingle(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              border: const Border(left: BorderSide(color: Colors.teal, width: 4)),
              borderRadius: BorderRadius.circular(4)
          ),
          child: Text(
              snap.data!['content'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)
          ),
        );
      },
    );
  }

  void _showOptions(Map<String, dynamic> msg) {
    final myIdentity = selectedBusinessName ?? widget.currentUserName;
    bool isMe = msg['sender_name'] == myIdentity;

    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text("Reply"),
            onTap: () {
              Navigator.pop(context);
              setState(() => replyingToMessage = msg);
            },
          ),
          if (isMe) ...[
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text("Edit"),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _msgController.text = msg['content'];
                  editingMessageId = msg['id'].toString();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete"),
              onTap: () async {
                await supabase.from('messages').delete().eq('id', msg['id']);
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color(0xFF075E54),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("SHARE YOU HAVE", style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.bold)),
            if (usersTyping.isNotEmpty)
              Text("${usersTyping.join(', ')} typing...",
                  style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic))
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('room_id', activeRoomId)
                  .order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error loading chat"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final msgs = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) => _messageBubble(msgs[i], _isDarkMode),
                );
              },
            ),
          ),
          if (isUploading) const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Colors.teal),
          if (replyingToMessage != null) _buildStatusPreview(Icons.reply, "Replying to ${replyingToMessage!['sender_name']}", Colors.teal, _isDarkMode),
          if (editingMessageId != null) _buildStatusPreview(Icons.edit, "Editing Message", Colors.orange, _isDarkMode),
          _buildInputArea(_isDarkMode),
        ],
      ),
    );
  }
}