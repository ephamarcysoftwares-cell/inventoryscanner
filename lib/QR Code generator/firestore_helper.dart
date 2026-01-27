import 'dart:convert';
import 'package:http/http.dart' as http;

class FirestoreHelper {
  static const String projectId = 'e-phamarcy-qrcode';  // Your Firebase Project ID
  static const String apiKey = 'AIzaSyDxzsPX59d4D15P2NQ1gdiq5H823kOTffA';  // Your Web API Key
  static const String collectionName = 'products';  // Your Firestore collection name

  // Firestore URL
  static String _getFirestoreUrl() {
    return 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionName';
  }

  // Add a new product to Firestore
  static Future<void> addProduct(Map<String, dynamic> product) async {
    final url = _getFirestoreUrl();
    final response = await http.post(
      Uri.parse(url),
      body: json.encode({
        'fields': {
          'productName': {'stringValue': product['productName']},
          'businessName': {'stringValue': product['businessName']},
          'category': {'stringValue': product['category']},
          'phoneNumber': {'stringValue': product['phoneNumber']},
          'email': {'stringValue': product['email']},
          'kg': {'stringValue': product['kg']},
        }
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print("Product added successfully!");
    } else {
      print("Failed to add product: ${response.body}");
    }
  }

  // Get product details by ID
  static Future<Map<String, dynamic>> getProductById(String id) async {
    final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionName/$id';
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'productName': data['fields']['productName']['stringValue'],
        'businessName': data['fields']['businessName']['stringValue'],
        'category': data['fields']['category']['stringValue'],
        'phoneNumber': data['fields']['phoneNumber']['stringValue'],
        'email': data['fields']['email']['stringValue'],
        'kg': data['fields']['kg']['stringValue'],
      };
    } else {
      print("Failed to get product: ${response.body}");
      return {};
    }
  }
}
