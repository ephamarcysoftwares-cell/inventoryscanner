import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LiveWebhookMessages extends StatefulWidget {
  const LiveWebhookMessages({super.key});

  @override
  State<LiveWebhookMessages> createState() => _LiveWebhookMessagesState();
}

class _LiveWebhookMessagesState extends State<LiveWebhookMessages> {
  final TextEditingController _messageController = TextEditingController();
  Timer? _timer;

  List<Map<String, dynamic>> allMessages = [];
  String selectedNumber = '';
  final String jsonUrl = 'https://ephamarcysoftware.co.tz/watsapp/webhook_log.json';
  final String sendUrl = 'https://ephamarcysoftware.co.tz/watsapp/send_message.php';

  @override
  void initState() {
    super.initState();
    fetchMessagesSilently();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => fetchMessagesSilently());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> fetchMessagesSilently() async {
    try {
      final response = await http.get(Uri.parse(jsonUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        allMessages = data.map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {}); // refresh UI
      }
    } catch (_) {}
  }

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || selectedNumber.isEmpty) return;

    final newMsg = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'from': 'You',
      'to': selectedNumber,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'sent',
    };

    allMessages.add(newMsg);
    _messageController.clear();
    setState(() {});

    try {
      await http.post(
        Uri.parse(sendUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'from': 'You',
          'to': selectedNumber,
          'text': text,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  List<String> getPhoneNumbers() {
    final numbers = allMessages.map((e) {
      if (e['from'] != 'You') return e['from'];
      if (e['to'] != 'You') return e['to'];
      return null;
    }).whereType<String>().toSet().toList();
    numbers.sort();
    return numbers;
  }

  List<Map<String, dynamic>> getMessagesFor(String number) {
    return allMessages
        .where((e) => (e['from'] == number || e['to'] == number))
        .toList();
  }

  String cleanNumber(String number) {
    // Remove after '@' if exists
    if (number.contains('@')) {
      return number.split('@')[0];
    }
    return number;
  }

  Widget buildMessageBubble(Map msg) {
    bool isSentByUser = msg['from'] == 'You';
    Color bubbleColor = isSentByUser ? Colors.green[400]! : Colors.grey[300]!;
    Color textColor = isSentByUser ? Colors.white : Colors.black87;
    Alignment alignment = isSentByUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isSentByUser ? 16 : 0),
              bottomRight: Radius.circular(isSentByUser ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
            isSentByUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(msg['text'] ?? '', style: TextStyle(color: textColor, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                msg['timestamp'] != null
                    ? msg['timestamp'].replaceAll('T', ' ').substring(0, 16)
                    : '',
                style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phoneNumbers = getPhoneNumbers();

    return Scaffold(
      appBar: AppBar(title: const Text('STOCK&INVENTORY- WHATSAPP'), backgroundColor: Colors.blueAccent),
      body: Row(
        children: [
          // Left panel: phone numbers
          Container(
            width: 200,
            color: Colors.grey[100],
            child: ListView.builder(
              itemCount: phoneNumbers.length,
              itemBuilder: (context, index) {
                final number = phoneNumbers[index];
                return ListTile(
                  title: Text(cleanNumber(number)),
                  selected: selectedNumber == number,
                  onTap: () {
                    setState(() {
                      selectedNumber = number;
                    });
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel: chat
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: getMessagesFor(selectedNumber).map((msg) {
                      return buildMessageBubble(msg);
                    }).toList(),
                  ),
                ),
                if (selectedNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: "Type a message to ${cleanNumber(selectedNumber)}",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: Colors.grey[200],
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.blueAccent,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
