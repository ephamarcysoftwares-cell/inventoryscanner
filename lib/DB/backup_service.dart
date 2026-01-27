// backup_service.dart
Future<void> startDailyBackupScheduler({required String businessName}) async {
  while (true) {
    print('🔄 [${DateTime.now()}] Starting daily backup and email for $businessName');
    try {
      await sendBackupEmail(businessName: businessName);
      print('✅ [${DateTime.now()}] Backup and email completed successfully');
    } catch (e) {
      print('❌ [${DateTime.now()}] Failed to send backup email: $e');
    }

    print('🕒 Waiting 24 hours before next backup...');
    await Future.delayed(const Duration(hours: 24));
  }
}

Future<void> sendBackupEmail({required String businessName}) async {
  // ✉️ Your real backup + email logic here
  // e.g., create backup file, attach to email, and send via SMTP
  print('DEBUG: sendBackupEmail() called for $businessName');
}