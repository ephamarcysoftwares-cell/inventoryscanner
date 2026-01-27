import 'dart:async'; // Added for Timer
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:twilio_flutter/twilio_flutter.dart';
import '../DB/database_helper.dart';
import '../FOTTER/CurvedRainbowBar.dart';
import '../SMS/sms_gateway.dart';
import '../phamacy/ReceiptScreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ControlNumber.dart';
class CartScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CartScreen({Key? key, required this.user}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  double grandTotal = 0.0;
  String paymentMethod = "Cash";
  int _parseToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      String cleaned = value.trim();
      if (cleaned.isEmpty) return 0;
      // Try parsing as standard integer first
      int? directInt = int.tryParse(cleaned);
      if (directInt != null) return directInt;
      // Handle "10.0" strings by parsing to double then converting
      double? doubleVal = double.tryParse(cleaned);
      return doubleVal?.toInt() ?? 0;
    }
    return 0;
  }
  // Existing controllers for customer details
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController emailController = TextEditingController();

  TextEditingController referenceController = TextEditingController();
  int? businessId;
  String business_name = '';
  String sub_business_name = '';
  String businessEmail = '';
  String businessPhone = '';
  String businessLocation = '';
  String businessLogoPath = '';
  String address = '';
  String whatsapp = '';
  String lipaNumber = '';
  int? _businessId; // Itatoka users table
  String? _currentUserId; // UUID ya mtumiaji
  String _staffName = '';
  String selectedCountry = 'Tanzania'; // Default selected country
  String countryCode = '+255'; // Default country code for Tanzania
  bool _isDarkMode = false;

  List<Map<String, String>> countries = [
    {'country': 'Tanzania', 'code': '+255'},
    {'country': 'Kenya', 'code': '+254'},
    {'country': 'Uganda', 'code': '+256'},
    // Add more countries as needed
  ];

  TwilioFlutter? twilioFlutter;

  // 👇 NEW: State variables for customer search and debouncing
  List<Map<String, dynamic>> customerSearchResults = [];
  Timer? _customerSearchDebouncer;
  bool _isLoading = false;


  bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
    );
    return emailRegex.hasMatch(email);
  }


  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchCartItems();
    getBusinessInfo();

    // 👇 NEW: Listener for customer search with debouncing
    nameController.addListener(_onCustomerSearchChanged);

    // Twilio setup
    twilioFlutter = TwilioFlutter(
      accountSid: 'your_twilio_account_sid', // Your Twilio Account SID
      authToken: 'your_twilio_auth_token',  // Your Twilio Auth Token
      twilioNumber: 'your_twilio_phone_number',  // Your Twilio phone number
    );
  }

  @override
  void dispose() {
    // 👇 NEW: Dispose debouncer
    _customerSearchDebouncer?.cancel();
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    referenceController.dispose();
    super.dispose();
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  // 👇 NEW: Debouncer to limit database hits while typing
  // Debouncer to limit database hits while typing



  void _onCustomerSearchChanged() {
    // Cancel the previous timer if the user types another letter
    if (_customerSearchDebouncer?.isActive ?? false) _customerSearchDebouncer!.cancel();

    _customerSearchDebouncer = Timer(const Duration(milliseconds: 500), () {
      // 🛑 Lifecycle check: Only proceed if the user is still on this screen
      if (!mounted) return;

      if (nameController.text.trim().isNotEmpty) {
        _fetchCustomerDetails();
      } else {
        setState(() {
          customerSearchResults = [];
        });
      }
    });
  }
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }
  Future<void> _loadBusinessInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final userProfile = await supabase
          .from('users')
          .select('business_name')
          .eq('id', user.id)
          .maybeSingle();

      if (userProfile != null) {
        final String myBusiness = userProfile['business_name'].toString().trim(); // Clean the space here!

        final response = await supabase
            .from('businesses')
            .select()
            .eq('business_name', myBusiness)
            .maybeSingle();

        if (mounted && response != null) {
          setState(() {
            business_name = response['business_name']?.toString().trim() ?? '';
            businessEmail = response['email']?.toString() ?? '';
            // ... rest of your fields
          });

          debugPrint("✅ Business Name set to: '$business_name'. Now fetching records...");

          // 🔥 CRITICAL: Trigger the data fetch NOW that we have the name
          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading business: $e');
    }
  }
  void _applyFilters() {
    setState(() {
      // This triggers a UI rebuild to show the cart is empty
      // and refreshes any total calculations on the screen.
      _isLoading = false;
    });
  }
  // Function to fetch customer details from the sales table
  Future<void> _fetchCustomerDetails() async {
    String searchQuery = nameController.text.trim();

    // 1. Kama hakuna neno lililoandikwa, safisha matokeo
    if (searchQuery.isEmpty) {
      if (mounted) setState(() => customerSearchResults = []);
      return;
    }

    // Hakikisha tuna business_id kabla ya kuanza search
    // businessId ni variable ya kiwango cha class (state variable)
    if (businessId == null) {
      debugPrint("⚠️ Haiwezi kutafuta: businessId ni null. Inajaribu kupata info...");
      await getBusinessInfo();
      if (businessId == null) return; // Kama bado ni null, sitisha
    }

    try {
      final supabase = Supabase.instance.client;

      // 2. Tafuta kutoka table ya 'sales' kwa kutumia business_id
      final salesResponse = await supabase
          .from('sales')
          .select('customer_name, customer_phone, customer_email')
          .eq('business_id', businessId!) // ✅ Kutumia Integer ID ni fasta na salama zaidi
          .or('customer_name.ilike.%$searchQuery%,customer_phone.ilike.%$searchQuery%')
          .limit(20);

      // 3. Tafuta pia kutoka table ya '"To_lend"'
      final loansResponse = await supabase
          .from('"To_lend"')
          .select('customer_name, customer_phone, customer_email')
          .eq('business_id', businessId!) // ✅ Filter kwa ID
          .or('customer_name.ilike.%$searchQuery%,customer_phone.ilike.%$searchQuery%')
          .limit(20);

      // 4. Unganisha matokeo ya table zote mbili
      final List<dynamic> combinedResults = [...salesResponse, ...loansResponse];

      if (combinedResults.isNotEmpty) {
        final Map<String, Map<String, dynamic>> distinctCustomers = {};

        for (var row in combinedResults) {
          String name = (row['customer_name'] ?? 'Unknown').toString().trim();
          String phone = (row['customer_phone'] ?? '').toString().trim();

          // Key ya kipekee ili mteja asijirudie kwenye list
          String key = "${name}-${phone}".toLowerCase();

          if (name.toLowerCase() != 'unknown' && !distinctCustomers.containsKey(key)) {
            distinctCustomers[key] = Map<String, dynamic>.from(row);
          }
        }

        if (mounted) {
          setState(() {
            customerSearchResults = distinctCustomers.values.toList();
          });
          debugPrint("✅ Wateja ${customerSearchResults.length} wamepatikana kwa ID: $businessId");
        }
      } else {
        if (mounted) setState(() => customerSearchResults = []);
      }
    } catch (e) {
      debugPrint("❌ Customer search error: $e");
    }
  }

  // FIX: Function to handle customer selection from the search results
  void _selectCustomer(Map<String, dynamic> customer) {
    String rawPhone = (customer['customer_phone'] ?? '').toString().trim();

    // Safisha namba: Ondoa '+' kama ipo mwanzoni
    if (rawPhone.startsWith('+')) {
      rawPhone = rawPhone.substring(1);
    }

    String newCountryCode = this.countryCode;
    String localPhone = rawPhone;
    String newSelectedCountry = this.selectedCountry;

    for (var country in countries) {
      String cCode = country['code']!.replaceAll('+', ''); // Linganisha bila +

      if (rawPhone.startsWith(cCode)) {
        newCountryCode = country['code']!; // Hapa tunarudisha yenye + (mfano +255)
        localPhone = rawPhone.substring(cCode.length);
        newSelectedCountry = country['country']!;

        // Safisha '0' inayoweza kuwa imejificha baada ya kodi ya nchi
        if (localPhone.startsWith('0')) {
          localPhone = localPhone.replaceFirst('0', '');
        }
        break;
      }
    }

    // Kama namba haikuanza na kodi ya nchi, lakini ni namba ya kawaida ya '07...'
    if (localPhone.startsWith('0') && localPhone.length >= 10) {
      localPhone = localPhone.substring(1);
    }

    setState(() {
      nameController.text = customer['customer_name'] ?? '';
      phoneController.text = localPhone;
      emailController.text = customer['customer_email'] ?? '';
      countryCode = newCountryCode;
      selectedCountry = newSelectedCountry;
      customerSearchResults = [];
    });

    FocusScope.of(context).unfocus();
  }
  // END FIX
  // 👆 END NEW CUSTOMER SEARCH LOGIC

  Future<void> _fetchCartItems() async {
    List<Map<String, dynamic>> finalItems = [];
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;
    final String userIdUuid = user.id;

    try {
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // 1. Pata Profile ya aliyeingia
        final userProfile = await supabase
            .from('users')
            .select('role, business_id')
            .eq('id', userIdUuid)
            .maybeSingle();

        final String myRole = userProfile?['role']?.toString().toLowerCase() ?? 'staff';
        final int myBusinessId = userProfile?['business_id'] ?? 0;

        // 2. Query Rahisi (Haitumii JOIN tena kwasababu staff_name ipo kwenye cart)
        // ✅ Tumerudisha .select('*') kwa sababu Trigger inajaza staff_name kule Database
        var query = supabase.from('cart').select('*');

        if (myRole == 'admin') {
          query = query.eq('business_id', myBusinessId);
        } else {
          query = query.eq('user_id', userIdUuid);
        }

        final response = await query.order('date_added', ascending: false);
        if (response != null) {
          finalItems = List<Map<String, dynamic>>.from(response);
        }
      } else {
        // OFFLINE MODE (SQLite)
        final db = await DatabaseHelper.instance.database;
        finalItems = await db!.query(
          'cart',
          where: 'user_id = ?',
          whereArgs: [userIdUuid],
        );
      }
    } catch (e) {
      debugPrint("❌ Fetch Cart Error: $e");
    }

    // --- Mahesabu ya Total ---
    double total = 0.0;
    for (var item in finalItems) {
      // Tunatumia _parseToInt uliyoiandika juu au double.tryParse
      double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
      int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
      total += (price * qty);
    }

    if (mounted) {
      setState(() {
        _cartItems = finalItems;
        grandTotal = total;
      });
    }
  }

  Future<void> _removeItemFromCart(int idFromUI) async {
    final supabase = Supabase.instance.client;

    try {
      // 1. Identify the item from your current _cartItems list
      final item = _cartItems.firstWhere((i) => i['id'] == idFromUI);
      final int productId = item['medicine_id'];
      final int qtyToRestore = item['quantity'] ?? 0;
      final String bName = item['business_name'] ?? '';
      final String medName = item['medicine_name'] ?? 'Product';

      // Normalize source (e.g., 'NORMAL PRODUCT' or 'MEDICINE')
      String source = (item['source'] ?? '').toString().toUpperCase().trim();

      // Decide which table to check first based on the 'source' column
      String primaryTable = (source == 'MEDICINE') ? 'medicines' : 'other_product';
      String secondaryTable = (primaryTable == 'medicines') ? 'other_product' : 'medicines';

      debugPrint("🔄 Attempting to restore $qtyToRestore to $primaryTable for $medName...");

      // 2. Try to update the Primary Table
      bool success = await _executeStockRestore(primaryTable, productId, bName, qtyToRestore);

      // 3. FALLBACK: If not found in primary, try the secondary table
      if (!success) {
        debugPrint("⚠️ Not found in $primaryTable. Trying fallback: $secondaryTable");
        success = await _executeStockRestore(secondaryTable, productId, bName, qtyToRestore);
      }

      if (success) {
        // 4. ONLY delete from cart if the stock was successfully updated
        await supabase.from('cart').delete().eq('id', idFromUI);
        debugPrint("✅ Stock restored and item removed from cart.");

        // 5. Refresh the list to update UI
        _fetchCartItems();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Removed $medName & Stock Restored"), backgroundColor: Colors.green),
          );
        }
      } else {
        throw "Product ID $productId not found in any stock table for $bName";
      }

    } catch (e) {
      debugPrint("❌ Removal Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

// 🛠️ HELPER: Handles the Fetch-and-Update logic for a specific table
  Future<bool> _executeStockRestore(String table, int id, String business, int qty) async {
    final supabase = Supabase.instance.client;

    // Fetch current quantity
    final data = await supabase
        .from(table)
        .select('remaining_quantity')
        .eq('id', id)
        .eq('business_name', business)
        .maybeSingle();

    if (data != null) {
      int currentQty = data['remaining_quantity'] ?? 0;

      // Perform the update
      await supabase
          .from(table)
          .update({'remaining_quantity': currentQty + qty})
          .eq('id', id)
          .eq('business_name', business);

      return true; // Success
    }
    return false; // Not found in this table
  }

// Helper function to handle the math safely
  Future<bool> _updateStock(String table, int id, String business, int qty) async {
    final supabase = Supabase.instance.client;

    final data = await supabase
        .from(table)
        .select('remaining_quantity')
        .eq('id', id)
        .eq('business_name', business)
        .maybeSingle();

    if (data != null) {
      int currentQty = data['remaining_quantity'] ?? 0;
      await supabase
          .from(table)
          .update({'remaining_quantity': currentQty + qty})
          .eq('id', id)
          .eq('business_name', business);
      return true;
    }
    return false;
  }



  // Function to get all admin emails
  Future<List<String>> getAdminEmails() async {
    List<String> adminEmails = [];
    final supabase = Supabase.instance.client;

    try {
      // 1. Check for internet connectivity
      var connectivityResult = await (Connectivity().checkConnectivity());
      bool isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // 2. Attempt to fetch from Supabase
        final response = await supabase
            .from('users')
            .select('email')
            .eq('role', 'admin');

        if (response != null && (response as List).isNotEmpty) {
          adminEmails = List<String>.from(response.map((row) => row['email'].toString()));
          debugPrint("✅ Admin emails fetched from Supabase");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Supabase Admin Fetch Error: $e");
    }

    // 3. Fallback to Local SQLite if Cloud is empty/fails or device is offline
    if (adminEmails.isEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        final result = await db.query(
          'users',
          columns: ['email'],
          where: 'role = ?',
          whereArgs: ['admin'],
        );

        adminEmails = result.map((row) => row['email'].toString()).toList();
        debugPrint("🏠 Admin emails fetched from Local SQLite");
      } catch (e) {
        debugPrint("❌ Local DB Admin Fetch Error: $e");
      }
    }

    return adminEmails;
  }

// Function to send email notification to all admins
  Future<void> _sendEmailNotification(int itemId, String medicineName, int quantity, double price) async {
    final adminEmails = await getAdminEmails();

    if (adminEmails.isEmpty) {
      print("No admin found to send email to.");
      return;
    }

    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = Message()
      ..from = Address('suport@ephamarcysoftware.co.tz', business_name.isNotEmpty ? business_name : 'STOCK&INVENTORY SOFTWARE')
      ..recipients.addAll(adminEmails)
      ..subject = ' Bill Canceled - $medicineName'
      ..html = '''
    <html>
    <head>
      <style>
        table {
          border-collapse: collapse;
          width: 100%;
          max-width: 600px;
        }
        th, td {
          padding: 8px;
          text-align: left;
          border: 1px solid #ddd;
        }
        th {
          background-color: #f44336;
          color: white;
        }
      </style>
    </head>
    <body>
      <h2 style="color: #d32f2f;">Bill Cancellation Notification</h2>
      <p>The following item has been <strong>removed</strong> from the pending bill:</p>
      <table>
        <tr>
          <th>Field</th>
          <th>Details</th>
        </tr>
        <tr>
          <td>ID</td>
          <td>$itemId</td>
        </tr>
        <tr>
          <td>Name</td>
          <td>$medicineName</td>
        </tr>
        <tr>
          <td>Quantity</td>
          <td>$quantity</td>
        </tr>
        <tr>
          <td>Price</td>
          <td>TSH ${price.toStringAsFixed(2)}</td>
        </tr>
      </table>
      <p>This action was performed by <strong>${widget.user['full_name']}</strong>.</p>
      <p>Regards,<br/>STOCK & INVENTORY SOFTWARE</p>
    </body>
    </html>
    ''';

    try {
      final sendReport = send(message, smtpServer);
      print('✅ Email sent to all admins: $sendReport');
    } catch (e) {
      print('❌ Failed to send email: $e');
    }
  }


  Future<void> _sendSMS(String customerPhone, String saleDetails) async {
    try {
      // Use your existing sendSingleMessage function
      final response =  sendSingleMessage(
        customerPhone,
        saleDetails,
        device: USE_SPECIFIED, // or USE_ALL_DEVICES / USE_ALL_SIMS as needed
      );

      print('SMS sent successfully: ${response.toString()}');
    } catch (e) {
      print('Failed to send SMS: $e');
    }
  }
  // START: WHATSAPP SENDING FUNCTION
  Future<String> sendWhatsApp(String phoneNumber, String messageText) async {
    try {
      // Load Instance ID and Access Token from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final instanceId = prefs.getString('whatsapp_instance_id') ?? '';
      final accessToken = prefs.getString('whatsapp_access_token') ?? '';

      if (instanceId.isEmpty || accessToken.isEmpty) {
        return "❌ WhatsApp error: Missing credentials. Please contact +255742448965!";
      }

      // Clean phone number (Tanzania example logic)
      String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (!cleanPhone.startsWith('255')) {
        // Assuming a standard local number that needs the country code
        // This is a bit aggressive, better to ensure phoneNumber is already fullPhoneNumber from _confirmSale
        if (cleanPhone.length >= 9) { // Simple check to avoid errors on short numbers
          cleanPhone = '255' + cleanPhone.substring(cleanPhone.length - 9);
        } else {
          return "❌ WhatsApp error: Invalid phone number format!";
        }
      }
      final chatId = '$cleanPhone@c.us';

      Future<http.Response> post(String url, Map<String, String> payload) async {
        return await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: payload,
        );
      }

      // Start typing (optional, for better UX)
      await post('https://wawp.net/wp-json/awp/v1/startTyping', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': chatId,
      });

      // Send message (direct API call)
      final sendRes = await post('https://wawp.net/wp-json/awp/v1/send', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': cleanPhone, // The API might expect only the phone number here
        'message': messageText,
      });

      // Stop typing (optional)
      await post('https://wawp.net/wp-json/awp/v1/stopTyping', {
        'instance_id': instanceId,
        'access_token': accessToken,
        'chatId': chatId,
      });

      if (sendRes.statusCode >= 200 && sendRes.statusCode < 300) {
        return "✅ Direct WhatsApp notification sent successfully!";
      } else {
        return "❌ fail: ${sendRes.body}";
      }
    } catch (e) {
      return "❌ error: $e";
    }
  }
  Future<void> getBusinessInfo() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // 1. Pata ID ya biashara na UUID ya user kutoka table ya users
      final userProfile = await supabase
          .from('users')
          .select('business_id, business_name, id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted || userProfile == null) return;

      setState(() {
        _currentUserId = userProfile['id']; // Hii ndiyo User ID ya kusave kwenye Sales
        _staffName = userProfile['full_name'] ?? 'Staff';
        _businessId = userProfile['business_id'] != null
            ? int.tryParse(userProfile['business_id'].toString())
            : null;
      });

      if (_businessId == null) {
        debugPrint("⚠️ Mtumiaji hana business_id iliyounganishwa.");
        return;
      }

      // 2. Pata taarifa zingine za biashara (Logo, Phone etc) kwa kutumia ID
      final businessData = await supabase
          .from('businesses')
          .select()
          .eq('id', _businessId!)
          .maybeSingle();

      if (mounted && businessData != null) {
        setState(() {
          business_name = businessData['business_name']?.toString() ?? '';
          businessEmail = businessData['email']?.toString() ?? '';
          businessPhone = businessData['phone']?.toString() ?? '';
          businessLocation = businessData['location']?.toString() ?? '';
          businessLogoPath = businessData['logo']?.toString() ?? '';
          address = businessData['address']?.toString() ?? '';
          whatsapp = businessData['whatsapp']?.toString() ?? '';
          lipaNumber = businessData['lipa_number']?.toString() ?? '';
        });

        // Baada ya kupata kila kitu, fetch cart na customers
        _fetchCartItems();
      }
    } catch (e) {
      debugPrint('❌ Error getting info: $e');
    }
  }
  Future<void> _confirmSale() async {
    debugPrint("🚀 [DEBUG] _confirmSale imeanza.");

    if (_cartItems.isEmpty || _businessId == null) return;

    try {
      final supabase = Supabase.instance.client;
      String receiptNumber = "REC${DateTime.now().millisecondsSinceEpoch}";
      String confirmedTimeIso = DateTime.now().toIso8601String();

      bool isMkopo = paymentMethod.trim().toUpperCase().contains('MKOPO');
      String targetTable = isMkopo ? 'To_lend' : 'sales';

      final List<Map<String, dynamic>> rowsToInsert = _cartItems.map((item) {
        double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0.0;
        int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
        String branchName = item['sub_business_name']?.toString() ?? '';

        return {
          'customer_name': nameController.text.trim().isEmpty ? 'Walk-in Customer' : nameController.text.trim(),
          'customer_phone': phoneController.text.trim().isEmpty
              ? 'N/A'
              : '$countryCode${phoneController.text.trim().replaceFirst(RegExp(r'^0'), '')}',
          'customer_email': emailController.text.trim(),
          'medicine_name': item['medicine_name'],
          'total_quantity': qty,
          'remaining_quantity': qty,
          'total_price': (price * qty),
          'receipt_number': receiptNumber,
          'payment_method': paymentMethod,
          'confirmed_time': confirmedTimeIso,
          'business_id': _businessId,
          'user_id': _currentUserId,
          'staff_id': _currentUserId,
          'confirmed_by': _staffName ?? 'Staff',
          'unit': item['unit'] ?? 'pcs',
          'business_name': business_name,
          'sub_business_name': branchName,
          'source': item['source'] ?? 'NORMAL PRODUCT',
          'synced': 1,
        };
      }).toList();

      // 1. Save to Supabase
      await supabase.from(targetTable).insert(rowsToInsert);

      // 2. Safisha Cart ya mtumiaji huyu pekee kwenye Cloud
      await supabase.from('cart').delete().eq('user_id', _currentUserId!);

      // 3. Safisha Cart local ili UI iwe tupu kwa mauzo yajayo
      if (mounted) {
        setState(() {
          _cartItems.clear(); // Hapa ndipo list inafutwa memory
        });
      }

    } catch (e) {
      debugPrint('❌ [CRITICAL ERROR] Sale Confirmation Failed: $e');
      rethrow; // Tupa kosa ili handleConfirmSale ilipate
    }
  }





// Helper to handle the sync queue

// Helper to handle the sync queue

// Helper to prevent repeating sync logic
  Future<void> _queueSync(dynamic db, int userId, String table, String action, dynamic payload) async {
    await db.insert('cart_sync', {
      'user_id': userId.toString(),
      'medicine_name': table,
      'action_type': action,
      'payload': jsonEncode(payload),
      'status': 'pending'
    });
    debugPrint("📝 Sync queued for $action on $table");
  }

// Helper to bundle notifications
  void _sendNotifications(String name, String phone, String email, String rec, String time) async {
    // Add your existing WhatsApp, SMS and AbstractAPI Email logic here
  }
  Future<void> _handleConfirmSale() async {
    final customerName = nameController.text.trim();
    final customerPhone = phoneController.text.trim();
    final customerEmail = emailController.text.trim();
    final refNumber = referenceController.text.trim();

    // 1. Validation
    if (customerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tafadhali weka jina la mteja')));
      return;
    }
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kapu ni tupu')));
      return;
    }

    // Format namba ya simu
    final formattedPhone = '$countryCode${customerPhone.replaceFirst(RegExp(r'^0'), '')}';

    // 2. MOBILE PAYMENTS LOGIC
    if (paymentMethod == 'Pay by Mobile') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MobilePaymentsScreen(
            customerName: customerName,
            customerPhone: formattedPhone,
            customerEmail: customerEmail,
            totalAmount: grandTotal,
            cartItems: List<Map<String, dynamic>>.from(_cartItems),
            user: widget.user,
          ),
        ),
      );
      return;
    }

    // 3. CASH, LIPA NUMBER, MKOPO LOGIC
    setState(() => _isLoading = true);

    try {
      // 🔥 SULUHISHO: Tengeneza nakala ya cart items KABLA ya kuzi-clear
      final List<Map<String, dynamic>> capturedCartItems = List<Map<String, dynamic>>.from(_cartItems);
      final double capturedTotal = grandTotal;

      // Tekeleza mauzo (Hii itasave Supabase na kufuta cart local/cloud)
      await _confirmSale();

      final confirmedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final receiptNumber = "REC${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ReceiptScreen(
              confirmedBy: _staffName ?? 'Staff',
              confirmedTime: confirmedTime,
              customerName: customerName,
              customerPhone: formattedPhone,
              customerEmail: customerEmail,
              paymentMethod: paymentMethod,
              receiptNumber: receiptNumber,
              // ✅ TUMIA capturedCartItems BADALA YA _cartItems
              medicineNames: capturedCartItems.map((item) => item['medicine_name'].toString()).toList(),
              medicineQuantities: capturedCartItems.map((item) => int.tryParse(item['quantity'].toString()) ?? 0).toList(),
              medicinePrices: capturedCartItems.map((item) => double.tryParse(item['price'].toString()) ?? 0.0).toList(),
              medicineUnits: capturedCartItems.map((item) => item['unit']?.toString() ?? 'pcs').toList(),
              medicineSources: capturedCartItems.map((item) => item['source']?.toString() ?? 'N/A').toList(),
              totalPrice: capturedTotal,
              remaining_quantity: capturedCartItems.fold(0, (sum, item) => sum + (int.tryParse(item['quantity'].toString()) ?? 0)),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ HandleConfirmSale Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hitilafu: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> clearBrokenSyncLogs() async {
    final db = await DatabaseHelper.instance.database;
    // This removes only the tasks causing the "invalid input syntax for type integer" error
    int count = await db!.delete(
      'cart_sync',
      where: "payload LIKE ? OR payload LIKE ? OR payload LIKE ?",
      whereArgs: ['%System%', '%Staff%', '%Unknown%'],
    );
    debugPrint("🧹 Cleaned $count broken records from the queue. Sync should be smooth now!");
  }


  InputDecoration _inputDecoration(String label, IconData payments, bool isDark) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  // 1. Fixed buildTextField
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, bool isDark, // This is the 'person' icon or any other icon you pass
          {TextInputType keyboardType = TextInputType.text,
        int? maxLength}
      ) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: _inputDecoration(label, icon, isDark),// <--- FIXED: Now passes 2 arguments
      onTap: () {
        // Clear search results when tapping other fields
        if (controller != nameController) {
          setState(() {
            customerSearchResults = [];
          });
        }
      },
    );
  }

// 2. Ensure your decoration method looks like this:


  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Please wait..."),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color textCol = isDark ? Colors.white : Colors.black87;
    final Color subTextCol = isDark ? Colors.white70 : Colors.black54;

    // Admin Dashboard Style Colors
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color lightViolet = Color(0xFF9575CD);

    return Scaffold(
      backgroundColor: bgColor, // Use dynamic bgColor
      appBar: AppBar(
        title: const Text(
          "CHECKOUT - PENDING BILL",
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 1.2,
              fontSize: 16
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple, lightViolet],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Customer Information Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor, // Use dynamic cardColor
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Customer Name Field - Pass isDark
                    _buildTextField(nameController, 'Customer Name', Icons.person, isDark),

                    // Autocomplete Overlay
                    if (customerSearchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(maxHeight: 150),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: primaryPurple.withOpacity(0.2)),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customerSearchResults.length,
                          itemBuilder: (context, index) {
                            final customer = customerSearchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(Icons.history, size: 18, color: primaryPurple),
                              title: Text(
                                customer['customer_name'] ?? 'No Name',
                                style: TextStyle(fontWeight: FontWeight.bold, color: textCol),
                              ),
                              subtitle: Text(customer['customer_phone'] ?? 'N/A', style: TextStyle(color: subTextCol)),
                              onTap: () => _selectCustomer(customer),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 12),
                    // Phone & Email Row
                    Row(
                      children: [
                        Expanded(
                            child: _buildTextField(
                                phoneController,
                                'Phone',
                                Icons.phone,
                                isDark,
                                keyboardType: TextInputType.phone
                            )
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _buildTextField(
                                emailController,
                                'Email',
                                Icons.email,
                                isDark,
                                keyboardType: TextInputType.emailAddress
                            )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Country & Payment Row
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            dropdownColor: cardColor,
                            style: TextStyle(color: textCol),
                            value: paymentMethod,
                            decoration: _inputDecoration('Payment', Icons.payments, isDark),
                            onChanged: (value) {
                              setState(() {
                                paymentMethod = value!;
                              });

                              // 🔥 AUTO-REDIRECT: Ikiwa amechagua Mobile, mfumo unahamia huko moja kwa moja
                              if (value == 'Mobile') {
                                // 1. Uhakiki: Je, Jina na Simu vimejazwa?
                                if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Jaza Jina na Simu kwanza kabla ya kuchagua Mobile!'),
                                        backgroundColor: Colors.red,
                                      )
                                  );
                                  // Rudisha chaguo kuwa Cash kama taarifa hazijajazwa
                                  setState(() => paymentMethod = 'Cash');
                                  return;
                                }

                                // 2. Uhakiki: Je, kuna bidhaa kwenye Cart?
                                if (_cartItems.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Cart ni tupu! Ongeza bidhaa kwanza.'),
                                        backgroundColor: Colors.orange,
                                      )
                                  );
                                  setState(() => paymentMethod = 'Cash');
                                  return;
                                }

                                // 3. ANDAA DATA NA RUUKA KWENYE MOBILE SCREEN
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MobilePaymentsScreen(
                                      customerName: nameController.text.trim(),
                                      customerPhone: '$countryCode${phoneController.text.trim().replaceFirst(RegExp(r'^0'), '')}',
                                      customerEmail: emailController.text.trim(),
                                      totalAmount: grandTotal,
                                      // Tunatengeneza list mpya hapa hapa ili kubadilisha 'medicine_name' kuwa 'product_name'
                                      cartItems: _cartItems.map((item) => {
                                        'id': item['id'],
                                        'product_name': item['medicine_name']?.toString() ?? "Bidhaa",
                                        'quantity': item['quantity'] ?? 1,
                                        'price': item['price'] ?? 0.0,
                                      }).toList(),
                                      user: widget.user,
                                    ),
                                  ),
                                ).then((_) {
                                  // Hii itaitwa akirudi toka Mobile Screen (akighairi au akimaliza),
                                  // tunarudisha iwe Cash ili kuzuia dropdown isibaki kwenye 'Mobile'
                                  setState(() => paymentMethod = 'Cash');
                                });
                              }
                            },
                            items: ['Cash', 'TO LEND(MKOPO)', 'Mobile', 'Lipa Number'].map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(m, style: TextStyle(fontSize: 12, color: textCol))
                            )).toList(),
                          ),
                        ),
                        const SizedBox(width: 10),

                      ],
                    ),
                    if (paymentMethod == 'Lipa Number') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                          referenceController,
                          'Reference Number',
                          Icons.receipt_long,
                          isDark,
                          keyboardType: TextInputType.number
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                  "CART ITEMS",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? lightViolet : deepPurple,
                      letterSpacing: 1
                  )
              ),
              const SizedBox(height: 8),

              // 2. Scrollable Cart Section
              Expanded(
                child: _cartItems.isEmpty
                    ? Center(child: Text("Cart is empty", style: TextStyle(color: subTextCol)))
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 10),
                  itemCount: _cartItems.length,
                  itemBuilder: (context, index) {
                    final item = _cartItems[index];

                    // ✅ Logic ya kupata jina la tawi
                    String branchName = (item['sub_business_name'] == null || item['sub_business_name'] == "")
                        ? "Main Branch"
                        : item['sub_business_name'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10, left: 8, right: 8), // Imetulia kidogo pembeni
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Vertical padding imeongezeka kidogo
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item['medicine_name'] ?? 'Product',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textCol,
                                    fontSize: 16
                                ),
                              ),
                            ),
                            // ✅ Kibandiko cha Tawi (Branch Badge)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: (item['sub_business_name'] ?? "Main Branch") == "Main Branch"
                                      ? Colors.blue.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: (item['sub_business_name'] ?? "Main Branch") == "Main Branch"
                                          ? Colors.blue
                                          : Colors.orange,
                                      width: 0.5
                                  )
                              ),
                              child: Text(
                                item['sub_business_name'] ?? "Main Branch",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: (item['sub_business_name'] ?? "Main Branch") == "Main Branch"
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    'Qty: ${item['quantity']}',
                                    style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)
                                ),
                                Text(
                                    'TSH ${NumberFormat('#,##0.00').format(item['price'])} ea',
                                    style: TextStyle(fontSize: 12, color: subTextCol)
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Subtotal: TSH ${NumberFormat('#,##0.00').format((item['quantity'] ?? 0) * (item['price'] ?? 0))}',
                              style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                            ),

                            const Divider(height: 16, thickness: 0.5), // Nafasi imezidi kidogo ili kusiwe na msongamano

                            // ✅ SEHEMU YA STAFF: Inasoma moja kwa moja 'staff_name' kutoka kwenye trigger
                            Row(
                              children: [
                                Icon(Icons.person_pin_outlined, size: 14, color: subTextCol.withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  "Placed by: ",
                                  style: TextStyle(fontSize: 11, color: subTextCol.withOpacity(0.7)),
                                ),
                                Text(
                                  "${item['staff_name'] ?? 'System'}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600, // Imekozwa kidogo ili ionekane
                                    fontStyle: FontStyle.italic,
                                    color: textCol.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removeItemFromCart(item['id']),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 3. Grand Total and Confirm Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5)
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textCol)),
                        Text(
                          'TSH ${NumberFormat('#,##0.00').format(grandTotal)}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: primaryPurple
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? primaryPurple : deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                        onPressed: _isLoading ? null : () => _handleConfirmSale(),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(
                          'CONFIRM SALE  •  TSH ${NumberFormat('#,##0.00').format(grandTotal)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }}