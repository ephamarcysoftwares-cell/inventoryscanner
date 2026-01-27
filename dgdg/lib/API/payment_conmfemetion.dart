import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../DB/database_helper.dart';

// PaymentTransaction model
class PaymentTransaction {
  final String orderTrackingId;
  final String status;
  final String message;
  final String paymentMethod;
  final double amount;
  final String confirmationCode;
  final String merchantReference;
  final String currency;
  final String paymentDate;
  final String nextPaymentDate;
  final String businessName;
  final String firstName;
  final String lastName;

  PaymentTransaction({
    required this.orderTrackingId,
    required this.status,
    required this.message,
    required this.paymentMethod,
    required this.amount,
    required this.confirmationCode,
    required this.merchantReference,
    required this.currency,
    required this.paymentDate,
    required this.nextPaymentDate,
    required this.businessName,
    required this.firstName,
    required this.lastName,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    // Safely parse amount as double regardless if int/double/string
    double parseAmount(dynamic amount) {
      if (amount == null) return 0.0;
      if (amount is int) return amount.toDouble();
      if (amount is double) return amount;
      if (amount is String) return double.tryParse(amount) ?? 0.0;
      return 0.0;
    }

    return PaymentTransaction(
      orderTrackingId: json['order_tracking_id'] ?? '',
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      amount: parseAmount(json['amount']),
      confirmationCode: json['confirmation_code'] ?? '',
      merchantReference: json['merchant_reference'] ?? '',
      currency: json['currency'] ?? '',
      paymentDate: json['payment_date'] ?? '',
      nextPaymentDate: json['next_payment_date'] ?? '',
      businessName: json['business_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_tracking_id': orderTrackingId,
      'status': status,
      'message': message,
      'payment_method': paymentMethod,
      'amount': amount,
      'confirmation_code': confirmationCode,
      'merchant_reference': merchantReference,
      'currency': currency,
      'payment_date': paymentDate,
      'next_payment_date': nextPaymentDate,
      'business_name': businessName,
      'first_name': firstName,
      'last_name': lastName,
    };
  }
}

// Database helper extension
extension PaymentDbHelper on DatabaseHelper {

  Future<bool> businessExists(String businessName) async {
    final db = await database;
    final result = await db.query(
      'businesses',
      where: 'business_name = ?',
      whereArgs: [businessName],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> insertTransactionIfBusinessExists(PaymentTransaction transaction) async {
    final db = await database;

    bool exists = await businessExists(transaction.businessName);
    if (!exists) {
      debugPrint('[DEBUG] Business not found: ${transaction.businessName}');
      return false;
    }

    final existing = await db.query(
      'payment_transactions',
      where: 'order_tracking_id = ?',
      whereArgs: [transaction.orderTrackingId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      debugPrint('[DEBUG] Transaction already exists: ${transaction.orderTrackingId}');
      return false;
    }

    await db.insert(
      'payment_transactions',
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    debugPrint('[DEBUG] Inserted transaction: ${transaction.orderTrackingId}');
    return true;
  }
}

// Update synced flag on live server
Future<void> updateTransactionSyncedOnServer(String transactionId) async {
  final url = Uri.parse('http://ephamarcysoftware.co.tz/payment/update_synced.php');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'transaction_id': transactionId,
        'synced': 1,
      }),
    );

    if (response.statusCode == 200) {
      debugPrint('[SYNC DEBUG] POST response status: ${response.statusCode}');
      debugPrint('[SYNC DEBUG] POST response body: ${response.body}');
    } else {
      debugPrint('[SYNC ERROR] Failed to update sync status. Status code: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('[SYNC ERROR] Exception updating sync status: $e');
  }
}

// Fetch from server, insert locally, then update live server
Future<void> fetchAndSaveTransaction() async {
  final url = Uri.parse('http://ephamarcysoftware.co.tz/payment/index.php');

  try {
    debugPrint('[DEBUG] fetchAndSaveTransaction() started');
    debugPrint('[DEBUG] Sending GET request...');

    final response = await http.get(url);

    debugPrint('[DEBUG] Response status: ${response.statusCode}');
    debugPrint('[DEBUG] Raw response body: "${response.body}"');

    if (response.statusCode == 200) {
      if (response.body.trim().isEmpty) {
        debugPrint('[DEBUG] Response body is empty');
        return;
      }

      final data = json.decode(response.body);

      if (data == null) {
        debugPrint('[DEBUG] Response data is null');
        return;
      }

      if (data is List) {
        debugPrint('[DEBUG] Response is a list with length: ${data.length}');
        for (var jsonItem in data) {
          final jsonMap = Map<String, dynamic>.from(jsonItem);
          final transaction = PaymentTransaction.fromJson(jsonMap);

          final inserted = await DatabaseHelper.instance.insertTransactionIfBusinessExists(transaction);
          if (inserted) {
            await updateTransactionSyncedOnServer(transaction.orderTrackingId);
          }
        }
      } else if (data is Map) {
        debugPrint('[DEBUG] Response is a single transaction object');
        final jsonMap = Map<String, dynamic>.from(data);
        final transaction = PaymentTransaction.fromJson(jsonMap);

        final inserted = await DatabaseHelper.instance.insertTransactionIfBusinessExists(transaction);
        if (inserted) {
          await updateTransactionSyncedOnServer(transaction.orderTrackingId);
        }
      } else {
        debugPrint('[DEBUG] Unexpected response format');
      }
    } else {
      debugPrint('[ERROR] HTTP failed: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('[ERROR] Exception fetching data: $e');
  }
}
