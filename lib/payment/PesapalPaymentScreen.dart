import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class PesapalPaymentScreen extends StatefulWidget {
  final String amount;
  final String currency;
  final String description;
  final String callbackUrl;
  final String customerName;
  final String customerPhone;

  PesapalPaymentScreen({
    required this.amount,
    required this.currency,
    required this.description,
    required this.callbackUrl,
    required this.customerName,
    required this.customerPhone,
  });

  @override
  _PesapalPaymentScreenState createState() => _PesapalPaymentScreenState();
}

class _PesapalPaymentScreenState extends State<PesapalPaymentScreen> {
  bool _isLoading = false;
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            print("Loaded: $url");
          },
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pesapal Payment')),
      body: Center(
        child: _isLoading
            ? CircularProgressIndicator()
            : ElevatedButton(
          onPressed: _processPayment,
          child: Text('Proceed with Pesapal Payment'),
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://e-pharmacy.lovestoblog.com/index.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'amount': widget.amount,
          'currency': widget.currency,
          'description': widget.description,
          'customerName': widget.customerName,
          'customerPhone': widget.customerPhone,
          'callbackUrl': widget.callbackUrl,
        },
      );

      if (response.statusCode == 200) {
        String responseHtml = response.body;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebViewScreen(responseHtml),
          ),
        );
      } else {
        _showErrorDialog('Payment failed. Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('An error occurred: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String responseHtml;

  WebViewScreen(this.responseHtml);

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.responseHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pesapal Payment")),
      body: WebViewWidget(controller: _controller),
    );
  }
}
