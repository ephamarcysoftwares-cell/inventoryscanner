import 'dart:async';

import 'package:stock_and_inventory_software/API/payment_conmfemetion.dart';
 // or wherever your model is
  // where fetchAndSaveTransaction is located

class PaymentSyncService {
  static Timer? _timer;

  static void startPeriodicSync() {
    // Cancel any existing timer before starting a new one
    _timer?.cancel();

    // Run the task immediately
    fetchAndSaveTransaction();

    // Schedule every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      fetchAndSaveTransaction();
    });
  }

  static void stopSync() {
    _timer?.cancel();
  }
}
