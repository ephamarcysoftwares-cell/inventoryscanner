import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:http/http.dart' as http; // For making HTTP requests (for payment integration)

// 1. TrialManager class for trial management and encryption/decryption
class TrialManager {
  // Generate a random key each time, you can store it in SharedPreferences if needed
  static String generateRandomKey() {
    final random = Random.secure();
    final List<int> randomKey = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(randomKey);
  }

  // Encrypt data
  static String encryptData(String text, String key) {
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key.fromBase64(key)));
    final encrypted = encrypter.encrypt(text, iv: encrypt.IV.fromLength(16));
    return encrypted.base64;
  }

  // Decrypt data
  static String decryptData(String encryptedText, String key) {
    final encrypter = encrypt.Encrypter(encrypt.AES(encrypt.Key.fromBase64(key)));
    final decrypted = encrypter.decrypt64(encryptedText, iv: encrypt.IV.fromLength(16));
    return decrypted;
  }

  // Get hidden file path
  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.trial_date');
  }

  // Save installation date securely
  static Future<void> saveInstallationDate() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('install_date')) return; // Already stored

    DateTime now = DateTime.now();
    String randomKey = generateRandomKey();
    String encryptedDate = encryptData(now.toIso8601String(), randomKey);

    // Save to hidden file
    File file = await _getFile();
    await file.writeAsString(encryptedDate);

    // Save the random key in SharedPreferences (to use for decryption)
    await prefs.setString('encryption_key', randomKey);

    // Save installation date with encrypted date in SharedPreferences as backup
    await prefs.setString('install_date', encryptedDate);
  }

  // Get installation date
  static Future<DateTime?> getInstallationDate() async {
    final prefs = await SharedPreferences.getInstance();
    String? encryptionKey = prefs.getString('encryption_key');

    if (encryptionKey == null) return null; // No encryption key available

    File file = await _getFile();

    if (await file.exists()) {
      String encryptedDate = await file.readAsString();
      return DateTime.parse(decryptData(encryptedDate, encryptionKey));
    } else {
      if (prefs.containsKey('install_date')) {
        String encryptedDate = prefs.getString('install_date')!;
        return DateTime.parse(decryptData(encryptedDate, encryptionKey));
      }
    }
    return null;
  }

  // Check if trial expired
  static Future<bool> isTrialExpired() async {
    DateTime? installDate = await getInstallationDate();
    if (installDate == null) return false;

    DateTime expiryDate = installDate.add(Duration(days: 30));
    return DateTime.now().isAfter(expiryDate);
  }

  // Renew trial
  static Future<void> renewTrial() async {
    DateTime now = DateTime.now();
    String randomKey = generateRandomKey();
    String encryptedDate = encryptData(now.toIso8601String(), randomKey);

    // Save the new encrypted date and the new key
    File file = await _getFile();
    await file.writeAsString(encryptedDate);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('install_date', encryptedDate);
    await prefs.setString('encryption_key', randomKey);
  }

  // Handle payment for trial renewal
  static Future<void> handlePaymentForTrialRenewal() async {
    bool expired = await isTrialExpired();
    if (!expired) {
      print('Trial is still active!');
      return;
    }

    // Example: Integrate with PayPal or Pesapal after trial expiration
    bool paymentSuccess = await initiatePayment();
    if (paymentSuccess) {
      await renewTrial();
      print('Trial has been renewed after successful payment.');
    } else {
      print('Payment failed. Cannot renew trial.');
    }
  }

  // Initiates a payment process with PayPal or Pesapal (this is a mock-up)
  static Future<bool> initiatePayment() async {
    try {
      // Example: PayPal integration or call to Pesapal API for payment processing
      // Replace this with the actual payment API call

      // Example request to PayPal or Pesapal API endpoint (dummy API call)
      final response = await http.post(
        Uri.parse('https://api.example.com/payment'),
        body: {
          'amount': '10.00', // Trial renewal fee
          'currency': 'USD', // Or the relevant currency
          'user_id': 'user123', // Replace with actual user id
        },
      );

      if (response.statusCode == 200) {
        return true; // Payment successful
      } else {
        print('Payment failed with status: ${response.statusCode}');
        return false; // Payment failed
      }
    } catch (e) {
      print('Payment error: $e');
      return false; // Payment error
    }
  }
}
