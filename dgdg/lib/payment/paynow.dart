// import 'dart:convert';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
//
// class PesapalPaymentScreen extends StatefulWidget {
//   @override
//   _PesapalPaymentScreenState createState() => _PesapalPaymentScreenState();
// }
//
// class _PesapalPaymentScreenState extends State<PesapalPaymentScreen> {
//   final _formKey = GlobalKey<FormState>();
//
//   final _firstNameController = TextEditingController();
//   final _lastNameController = TextEditingController();
//   final _emailController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _amountController = TextEditingController();
//
//   String? _redirectUrl;
//   String? _error;
//   bool isLoading = false;
//
//   // Replace with your live or sandbox keys
//   final bool isLive = true;
//   final String ipnId = "27dfa026-4fb2-4b8e-984d-dc0173f18a07";
//   final String consumerKey = "72CeUDOSt+U05/2DNkuhMiarfE36c7M+";
//   final String consumerSecret = "skdqX0IcjNLigCDcuBePSii/vuc=";
//
//   Future<void> _processPayment() async {
//     if (!_formKey.currentState!.validate()) return;
//
//     setState(() {
//       isLoading = true;
//       _error = null;
//       _redirectUrl = null;
//     });
//
//     try {
//       // Step 1: Get OAuth Token
//       final tokenUrl = isLive
//           ? 'https://pay.pesapal.com/v3/api/Auth/RequestToken'
//           : 'https://cybqa.pesapal.com/pesapalv3/api/Auth/RequestToken';
//
//       final tokenRes = await http.post(
//         Uri.parse(tokenUrl),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({
//           'consumer_key': consumerKey,
//           'consumer_secret': consumerSecret,
//         }),
//       );
//
//       if (tokenRes.statusCode != 200) {
//         setState(() => _error = "Authentication failed");
//         return;
//       }
//
//       final token = json.decode(tokenRes.body)['token'];
//
//       // Step 2: Submit Payment Order
//       final orderId = Random().nextInt(999999999);
//       final submitUrl = isLive
//           ? 'https://pay.pesapal.com/v3/api/Transactions/SubmitOrderRequest'
//           : 'https://cybqa.pesapal.com/pesapalv3/api/Transactions/SubmitOrderRequest';
//
//       final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
//
//       final paymentData = {
//         "id": orderId.toString(),
//         "currency": "USD",
//         "amount": amount,
//         "description": "E-PHAMARCY SOFTWARE MONTHLY FEE",
//         "callback_url": "http://localhost/flutter/payment_processing.php",
//         "notification_id": ipnId,
//         "branch": "E-PHAMARCY SOFTWARE",
//         "billing_address": {
//           "email_address": _emailController.text.trim(),
//           "phone_number": _phoneController.text.trim(),
//           "country_code": "TZ",
//           "first_name": _firstNameController.text.trim(),
//           "last_name": _lastNameController.text.trim(),
//           "line_1": "E-PHAMARCY SOFTWARE"
//         }
//       };
//
//       final paymentRes = await http.post(
//         Uri.parse(submitUrl),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: json.encode(paymentData),
//       );
//
//       final response = json.decode(paymentRes.body);
//       if (paymentRes.statusCode == 200 && response['redirect_url'] != null) {
//         setState(() => _redirectUrl = response['redirect_url']);
//       } else {
//         setState(() => _error = "Payment failed: ${response['message'] ?? 'Unknown error'}");
//       }
//     } catch (e) {
//       setState(() => _error = "Error: $e");
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }
//
//   // Navigate to the WebView screen
//   void _launchPayment() {
//     if (_redirectUrl != null) {
//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => PaymentWebView(paymentUrl: _redirectUrl!),
//         ),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _emailController.dispose();
//     _phoneController.dispose();
//     _amountController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Pesapal Payment")),
//       body: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Center(
//           child: SingleChildScrollView(
//             child: Card(
//               elevation: 6,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//               child: Padding(
//                 padding: const EdgeInsets.all(20),
//                 child: Column(
//                   children: [
//                     const Text(
//                       "Pay for E-Phamarcy",
//                       style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 20),
//                     if (_error != null)
//                       Text(_error!, style: const TextStyle(color: Colors.red)),
//                     if (_redirectUrl == null) ...[
//                       Form(
//                         key: _formKey,
//                         child: Column(
//                           children: [
//                             TextFormField(
//                               controller: _firstNameController,
//                               decoration: const InputDecoration(labelText: 'First Name'),
//                               validator: (value) => value!.isEmpty ? "Enter first name" : null,
//                             ),
//                             const SizedBox(height: 10),
//                             TextFormField(
//                               controller: _lastNameController,
//                               decoration: const InputDecoration(labelText: 'Last Name'),
//                               validator: (value) => value!.isEmpty ? "Enter last name" : null,
//                             ),
//                             const SizedBox(height: 10),
//                             TextFormField(
//                               controller: _emailController,
//                               decoration: const InputDecoration(labelText: 'Email Address'),
//                               validator: (value) => value!.isEmpty ? "Enter email" : null,
//                             ),
//                             const SizedBox(height: 10),
//                             TextFormField(
//                               controller: _phoneController,
//                               decoration: const InputDecoration(labelText: 'Phone Number'),
//                               validator: (value) => value!.isEmpty ? "Enter phone number" : null,
//                             ),
//                             const SizedBox(height: 10),
//                             TextFormField(
//                               controller: _amountController,
//                               decoration: const InputDecoration(labelText: 'Amount (e.g. 5.00)'),
//                               keyboardType: TextInputType.number,
//                               validator: (value) =>
//                               (value == null || value.isEmpty || double.tryParse(value) == null)
//                                   ? "Enter valid amount"
//                                   : null,
//                             ),
//                             const SizedBox(height: 20),
//                             ElevatedButton(
//                               onPressed: isLoading ? null : _processPayment,
//                               child: isLoading
//                                   ? const CircularProgressIndicator(color: Colors.white)
//                                   : const Text("Proceed to Payment"),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ] else ...[
//                       ElevatedButton(
//                         onPressed: _launchPayment,
//                         child: const Text("Open Payment Link in WebView"),
//                       ),
//                     ]
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// class PaymentWebView extends StatefulWidget {
//   final String paymentUrl;
//
//   const PaymentWebView({Key? key, required this.paymentUrl}) : super(key: key);
//
//   @override
//   State<PaymentWebView> createState() => _PaymentWebViewState();
// }
//
// class _PaymentWebViewState extends State<PaymentWebView> {
//   late InAppWebViewController webView;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Complete Payment")),
//       body: InAppWebView(
//         initialUrlRequest: URLRequest(url: Uri.parse(widget.paymentUrl)),
//         onWebViewCreated: (controller) {
//           webView = controller;
//         },
//         onLoadStop: (controller, url) {
//           if (url.toString().contains("payment_processing.php")) {
//             // Payment callback reached
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(content: Text("Payment Completed")),
//             );
//             Navigator.pop(context);
//           }
//         },
//       ),
//     );
//   }
// }
