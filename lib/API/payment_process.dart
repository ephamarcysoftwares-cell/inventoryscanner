import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TransactionStatusScreen extends StatefulWidget {
  final String orderTrackingId;
  final String merchantReference;
  final String token;

  const TransactionStatusScreen({
    required this.orderTrackingId,
    required this.merchantReference,
    required this.token,
  });

  @override
  _TransactionStatusScreenState createState() =>
      _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen> {
  Map<String, dynamic>? transaction;
  String? filePath;
  String statusMessage = "";

  @override
  void initState() {
    super.initState();
    fetchTransaction();
  }

  Future<void> fetchTransaction() async {
    final url = Uri.parse(
        "https://pay.pesapal.com/v3/api/Transactions/GetTransactionStatus?orderTrackingId=${widget.orderTrackingId}");

    final response = await http.get(url, headers: {
      "Authorization": "Bearer ${widget.token}",
      "Accept": "application/json",
      "Content-Type": "application/json",
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final now = DateTime.now();
      final nextDate = now.add(Duration(days: 30));

      final transactionData = {
        "status": data['payment_status_description'],
        "message": _getMessage(data['payment_status_description']),
        "payment_method": data['payment_method'],
        "amount": "${data['amount']} TSH",
        "confirmation_code": data['confirmation_code'],
        "order_tracking_id": data['order_tracking_id'],
        "merchant_reference": data['merchant_reference'],
        "currency": data['currency'],
        "payment_date": now.toIso8601String(),
        "next_payment_date": nextDate.toIso8601String(),
      };

      setState(() {
        transaction = transactionData;
      });

      await _saveToJson(transactionData);
    } else {
      setState(() {
        statusMessage = "Failed to fetch transaction details.";
      });
    }
  }

  String _getMessage(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Payment Successful';
      case 'pending':
        return 'Payment is pending';
      case 'failed':
        return 'Payment Failed';
      default:
        return 'Unknown status';
    }
  }

  Future<void> _saveToJson(Map<String, dynamic> data) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/pesapal_transaction.json');
      await file.writeAsString(jsonEncode(data));
      setState(() => filePath = file.path);
    } catch (e) {
      setState(() => statusMessage = "Failed to save file: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transaction Status"),
        backgroundColor: Colors.green,
      ),
      body: transaction != null
          ? Padding(
        padding: const EdgeInsets.all(20.0),
        child: ListView(
          children: transaction!.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value.toString()),
            );
          }).toList(),
        ),
      )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
