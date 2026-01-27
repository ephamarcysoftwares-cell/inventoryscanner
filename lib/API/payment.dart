import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:stock_and_inventory_software/API/payment_alternative.dart';
import 'package:url_launcher/url_launcher.dart';

import '../DB/database_helper.dart';
import '../DB/database_helper.dart' as db_helper;
  // Ensure this import is correct

class PesapalPaymentScreen extends StatefulWidget {
  @override
  _PesapalPaymentScreenState createState() => _PesapalPaymentScreenState();
}

class _PesapalPaymentScreenState extends State<PesapalPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  String? qrCodeUrl;
  String? redirectUrl;
  String? error;

  List<String> businessNames = [];
  String? selectedBusiness;

  static const String ipnId = "27dfa026-4fb2-4b8e-984d-dc0173f18a07";
  static const bool isLive = true;

  final String consumerKey = "72CeUDOSt+U05/2DNkuhMiarfE36c7M+";
  final String consumerSecret = "skdqX0IcjNLigCDcuBePSii/vuc=";

  String get authUrl => isLive
      ? "https://pay.pesapal.com/v3/api/Auth/RequestToken"
      : "https://cybqa.pesapal.com/pesapalv3/api/Auth/RequestToken";

  String get submitOrderUrl => isLive
      ? "https://pay.pesapal.com/v3/api/Transactions/SubmitOrderRequest"
      : "https://cybqa.pesapal.com/pesapalv3/api/Transactions/SubmitOrderRequest";

  @override
  void initState() {
    super.initState();
    fetchBusinessNames();
  }

  Future<void> fetchBusinessNames() async {
    final businesses = await db_helper.DatabaseHelper.instance.getBusinessNames();

    setState(() {
      businessNames = businesses;
    });
  }

  Future<void> submitPayment() async {
    setState(() {
      qrCodeUrl = null;
      redirectUrl = null;
      error = null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final token = await getAuthToken();
      if (token == null) {
        Navigator.of(context).pop();
        setState(() => error = "Authentication failed.");
        return;
      }

      final orderId = Random().nextInt(1000000000).toString();

      final paymentData = {
        "id": orderId,
        "currency": "TZS", // changed to Tanzanian Shillings
        "amount": 10500, // example amount in TZS; replace with your actual price
        "description": "STOCK&INVENTORY SOFTWARE MONTHLY FEE",
        "callback_url":
        "http://ephamarcysoftware.co.tz/payment/payment_processing.php?"
            "business_name=${Uri.encodeComponent(selectedBusiness ?? '')}&"
            "first_name=${Uri.encodeComponent(firstName)}&"
            "last_name=${Uri.encodeComponent(lastName)}&"
            "email=${Uri.encodeComponent(email)}",
        "notification_id": ipnId,
        "branch": selectedBusiness ?? "STOCK&INVENTORY SOFTWARE",
        "business_name": selectedBusiness ?? "STOCK&INVENTORY SOFTWARE",
        "billing_address": {
          "email_address": email,
          "phone_number": "",
          "country_code": "TZ",
          "first_name": firstName,
          "last_name": lastName,
          "line_1": "STOCK&INVENTORY SOFTWARE",
        }
      };




      final response = await http.post(
        Uri.parse(submitOrderUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(paymentData),
      );

      Navigator.of(context).pop();

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          redirectUrl = json["redirect_url"];
          qrCodeUrl = "https://chart.googleapis.com/chart?chs=250x250&cht=qr&chl=${Uri.encodeComponent(redirectUrl!)}&choe=UTF-8";
        });
      } else {
        setState(() => error = "Error processing payment. Try again.");
      }
    } catch (e) {
      Navigator.of(context).pop();
      setState(() => error = "Exception: ${e.toString()}");
    }
  }

  Future<String?> getAuthToken() async {
    final body = jsonEncode({
      "consumer_key": consumerKey,
      "consumer_secret": consumerSecret,
    });

    final response = await http.post(
      Uri.parse(authUrl),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json["token"];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(' STOCK&INVENTORY SOFTWARE-Payment Portal'),
        backgroundColor: Colors.green,
      ),
      backgroundColor: Color(0xfff4f7f6),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(30),
            margin: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            width: 400,
            child: Column(
              children: [
                Text(
                  'PAY STOCK&INVENTOY SOFTWARE',
                  style: TextStyle(color: Colors.green, fontSize: 22),
                ),
                SizedBox(height: 10),
                Text(
                  'Notice: SUPPORT US TO BRING BEST SERVICE FOR YOU.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10,),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) =>  PaymentConfirmationCode()),
                    );
                  },
                  child: Text("Click here I have been payed(If only you payed) "),
                ),
                SizedBox(height: 20),
                if (error != null)
                  Text(error!, style: TextStyle(color: Colors.red)),
                if (redirectUrl == null)
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        buildInputField("First Name", (val) => firstName = val),
                        buildInputField("Last Name", (val) => lastName = val),
                        buildInputField("Email Address", (val) => email = val, type: TextInputType.emailAddress),
                        buildDropdownField(),
                        SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              submitPayment();
                            }
                          },
                          child: Text('Proceed to Payment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            minimumSize: Size(double.infinity, 45),
                          ),
                        ),

                        SizedBox(height: 10),
                        Text(
                          'OR',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () async {
                            const url = 'https://store.pesapal.com/ephamarcysoftwaremonthlyfee';
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            } else {
                              Fluttertoast.showToast(msg: "Could not open payment link.");
                            }
                          },
                          child: Text('Pay Here if get Trouble on payment above'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            minimumSize: Size(double.infinity, 45),
                          ),

                        ),
                      ],

                    ),
                  )
                else
                  Column(
                    children: [
                      if (qrCodeUrl != null)
                        Image.network(qrCodeUrl!, height: 250, width: 250),
                      SizedBox(height: 20),
                      Text("Or click below:"),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          if (redirectUrl != null && await canLaunchUrl(Uri.parse(redirectUrl!))) {
                            await launchUrl(Uri.parse(redirectUrl!), mode: LaunchMode.externalApplication);
                          } else {
                            Fluttertoast.showToast(msg: "Unable to launch payment link.");
                          }
                        },
                        child: Text('Proceed to Payment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: Size(double.infinity, 45),
                        ),
                      ),


                    ],
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInputField(String label, Function(String) onSaved, {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 5),
          TextFormField(
            keyboardType: type,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: label,
            ),
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            onSaved: (val) => onSaved(val!),
          ),
        ],
      ),
    );
  }

  Widget buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Business Name", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            value: selectedBusiness,
            items: (businessNames.isEmpty
                ? ["I don't have yet"]
                : businessNames)
                .map((name) {
              return DropdownMenuItem(
                value: name,
                child: Text(name),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedBusiness = value;
              });
            },
            validator: (value) =>
            value == null || value.isEmpty
                ? 'Please select a business'
                : null,
          ),
        ],
      ),
    );
  }



}
