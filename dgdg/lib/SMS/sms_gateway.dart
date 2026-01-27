import 'dart:convert';
import 'package:http/http.dart' as http;

// Configuration
const String SERVER = "https://app.sms-gateway.app";
const String API_KEY = "c675459f5f54525139aa4ce184322393a1a7b83f";

const int USE_SPECIFIED = 0;
const int USE_ALL_DEVICES = 1;
const int USE_ALL_SIMS = 2;

Future<Map<String, dynamic>> sendSingleMessage(
    String number,
    String message, {
      int device = 0,
      int? schedule,
      bool isMMS = false,
      String? attachments,
      bool prioritize = false,
    }) async {
  String url = "$SERVER/services/send.php";
  var postData = {
    'number': number,
    'message': message,
    'schedule': schedule,
    'key': API_KEY,
    'devices': device,
    'type': isMMS ? "mms" : "sms",
    'attachments': attachments,
    'prioritize': prioritize ? 1 : 0,
  };
  var response = await sendRequest(url, postData);
  return response["messages"][0];
}

Future<Map<String, dynamic>> sendMessages(
    List<Map<String, dynamic>> messages, {
      int option = USE_SPECIFIED,
      List<int> devices = const [],
      int? schedule,
      bool useRandomDevice = false,
    }) async {
  String url = "$SERVER/services/send.php";
  var postData = {
    'messages': jsonEncode(messages),
    'schedule': schedule,
    'key': API_KEY,
    'devices': jsonEncode(devices),
    'option': option,
    'useRandomDevice': useRandomDevice,
  };
  var response = await sendRequest(url, postData);
  return response["messages"];
}

Future<Map<String, dynamic>> sendMessageToContactsList(
    int listID,
    String message, {
      int option = USE_SPECIFIED,
      List<int> devices = const [],
      int? schedule,
      bool isMMS = false,
      String? attachments,
    }) async {
  String url = "$SERVER/services/send.php";
  var postData = {
    'listID': listID,
    'message': message,
    'schedule': schedule,
    'key': API_KEY,
    'devices': jsonEncode(devices),
    'option': option,
    'type': isMMS ? "mms" : "sms",
    'attachments': attachments
  };
  var response = await sendRequest(url, postData);
  return response["messages"];
}
Future<String> sendSms(String phone, String message, String server, String apiKey) async {
  final url = Uri.parse('$server/api/send');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'},
    body: jsonEncode({
      'phone': phone,
      'message': message,
    }),
  );

  if (response.statusCode == 200) {
    return 'SMS sent successfully';
  } else {
    throw Exception('Failed to send SMS: ${response.body}');
  }
}
Future<Map<String, dynamic>> getMessageByID(int id) async {
  String url = "$SERVER/services/read-messages.php";
  var postData = {'key': API_KEY, 'id': id};
  var response = await sendRequest(url, postData);
  return response["messages"][0];
}

Future<Map<String, dynamic>> sendRequest(
    String url, Map<String, dynamic> postData) async {
  postData.removeWhere((key, value) => value == null); // remove nulls

  var res = await http.post(
    Uri.parse(url),
    body: postData.map((key, value) => MapEntry(key, value.toString())),
  );

  if (res.statusCode == 200) {
    var jsonResponse = json.decode(res.body);
    if (jsonResponse == false || jsonResponse == null) {
      throw Exception(
          res.body.isEmpty ? "Missing required data" : res.body.toString());
    } else {
      if (jsonResponse["success"] == true) {
        return jsonResponse["data"];
      } else {
        throw Exception(jsonResponse["error"]["message"]);
      }
    }
  } else {
    throw Exception("HTTP Error Code: ${res.statusCode}");
  }
}
