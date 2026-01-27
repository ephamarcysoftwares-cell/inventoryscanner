import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PaymentManager {
  static const int trialDays = 7; // 7-day free trial
  static const int monthlyFee = 5000;

  // Get the path to the hidden file
  static Future<String> get _hiddenFilePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/.epharmacy_data'; // Hidden file
  }

  // Save installation date on first run
  static Future<void> saveInstallationDate() async {
    final file = File(await _hiddenFilePath);
    if (!await file.exists()) {
      await file.writeAsString(DateTime.now().toIso8601String());
    }
  }

  // Read installation date
  static Future<DateTime?> getInstallationDate() async {
    final file = File(await _hiddenFilePath);
    if (await file.exists()) {
      String content = await file.readAsString();
      return DateTime.tryParse(content);
    }
    return null;
  }

  // Check if the trial is expired
  static Future<bool> isTrialExpired() async {
    DateTime? installDate = await getInstallationDate();
    if (installDate == null) return false;

    DateTime expiryDate = installDate.add(Duration(days: trialDays));
    return DateTime.now().isAfter(expiryDate);
  }

  // Save successful payment date
  static Future<void> savePaymentDate() async {
    final file = File(await _hiddenFilePath);
    await file.writeAsString(DateTime.now().toIso8601String());
  }

  // Check if payment is valid (paid within last 30 days)
  static Future<bool> isPaymentValid() async {
    DateTime? lastPayment = await getInstallationDate();
    if (lastPayment == null) return false;

    DateTime nextDueDate = lastPayment.add(Duration(days: 30));
    return DateTime.now().isBefore(nextDueDate);
  }
}
