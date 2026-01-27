import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'FOTTER/CurvedRainbowBar.dart';
import 'login_screen.dart';

class NotRegisteredPage extends StatefulWidget {
  const NotRegisteredPage({super.key});

  @override
  _NotRegisteredPageState createState() => _NotRegisteredPageState();
}

class _NotRegisteredPageState extends State<NotRegisteredPage> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController professionalController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();

  bool isLoading = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    phoneController.text = '+255';
  }

  String formatPhoneNumber(String phone) {
    phone = phone.trim().replaceAll(' ', '');
    if (phone.startsWith('+2550')) return '+255${phone.substring(5)}';
    if (phone.startsWith('0')) return '+255${phone.substring(1)}';
    if (!phone.startsWith('+255')) return '+255$phone';
    return phone;
  }

 // Hakikisha umeongeza hii juu kwa ajili ya SocketException

  Future<void> registerUser() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    // 1. Kusanya Data
    String fullName = fullNameController.text.trim();
    String email = emailController.text.trim();
    String phone = formatPhoneNumber(phoneController.text);
    String password = passwordController.text.trim();
    String prof = professionalController.text.trim();
    String bizName = businessNameController.text.trim();
    String bizLoc = locationController.text.trim();
    String bizAddr = addressController.text.trim();
    String bizWhat = whatsappController.text.trim();

    // 2. ULINZI WA AWALI
    if (fullName.isEmpty || email.isEmpty || password.isEmpty ||
        bizName.isEmpty || bizLoc.isEmpty || bizAddr.isEmpty || bizWhat.isEmpty) {
      setState(() {
        errorMessage = 'Tafadhali jaza nafasi ZOTE. Kila taarifa ni muhimu kwa usajili.';
        isLoading = false;
      });
      return;
    }

    try {
      // 3. Angalia Internet (Connectivity check pekee haitoshi mara nyingi, catch itatusaidia zaidi)
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw "Hamna muunganisho wa mtandao. Tafadhali washa data au Wi-Fi.";
      }

      // 4. KAGUA KAMA DUKA LIPO
      final existingBiz = await supabase
          .from('businesses')
          .select('business_name')
          .eq('business_name', bizName)
          .maybeSingle();

      if (existingBiz != null) throw 'Samahani, duka la "$bizName" tayari limeshasajiliwa. Tumia jina lingine.';

      // 5. JARIBU KUSAJILI AKAUNTI (Auth)
      final authRes = await supabase.auth.signUp(email: email, password: password);

      if (authRes.user == null) throw "Samahani Usajili umeshindikana kwa sasa. Jaribu tena baada ya muda kidogo.";

      final String uid = authRes.user!.id;

      // 6. TENGENEZA DUKA
      final businessData = await supabase.from('businesses').insert({
        'business_name': bizName,
        'email': email,
        'phone': phone,
        'location': bizLoc,
        'address': bizAddr,
        'whatsapp': bizWhat,
      }).select('id').single();

      final int newBusinessId = businessData['id'];

      // 7. TENGENEZA PROFILE YA MTUMIAJI
      await supabase.from('users').insert({
        'id': uid,
        'full_name': fullName,
        'phone': phone,
        'role': 'admin',
        'professional': prof,
        'business_name': bizName,
        'business_id': newBusinessId,
        'last_seen': DateTime.now().toIso8601String(),
      });

      // 8. Tuma Email
      await sendEmailToUser(email, phone, fullName, password, 'admin', bizName);

      if (mounted) _showSuccess();

    } on AuthException catch (e) {
      setState(() {
        // Tafsiri ya makosa ya SignUp
        if (e.message.contains("already registered") || e.statusCode == "422") {
          errorMessage = "Samahani, barua pepe hii ($email) tayari inatumika. Tumia nyingine au ingia kwenye akaunti yako.";
        } else if (e.message.contains("weak password")) {
          errorMessage = "Neno la siri ni dhaifu. Tumia herufi na namba zisizopungua sita.";
        } else {
          errorMessage = "Loo! Imeshindikana kusajili: Maelezo uliyotoa yana hitilafu.";
        }
        isLoading = false;
      });
    } on SocketException {
      // Inakamata kosa la "Failed host lookup" au mtandao kuzimwa kabisa
      setState(() {
        errorMessage = "Loo! Hamna muunganisho wa mtandao. Tafadhali washa internet na ujaribu tena.";
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        String errorText = e.toString();
        setState(() {
          // ZUIA UJUMBE WA TEKNOLOJIA (Failed host lookup, Supabase error codes nk)
          if (errorText.contains('Failed host lookup') || errorText.contains('ClientException')) {
            errorMessage = "Loo! Hitilafu ya mtandao imetokea. Hakikisha simu yako ina internet.";
          } else {
            errorMessage = "Loo! Hitilafu isiyotarajiwa imetokea. Tafadhali jaribu tena baada ya muda.";
          }
          isLoading = false;
        });
      }
    }
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hongera!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF311B92))),
        content: const Text('Duka lako limesajiliwa kwa mafanikio. Sasa unaweza kuingia kutumia mfumo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())
              ),
              child: const Text('INGIA SASA', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF673AB7)))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);
    const Color bgLight = Color(0xFFF5F7FB);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "USAJILI WA BIASHARA",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [deepPurple, primaryPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Admin Personal Details
            _buildPurpleCard(
              title: "Taarifa za Admin",
              icon: Icons.admin_panel_settings,
              children: [
                _buildModernField(fullNameController, "Jina Kamili", Icons.person_outline),
                const SizedBox(height: 12),
                _buildModernField(emailController, "Barua Pepe (Email)", Icons.email_outlined),
                const SizedBox(height: 12),
                _buildModernField(phoneController, "Namba ya Simu", Icons.phone_android_outlined),
                const SizedBox(height: 12),
                _buildModernField(passwordController, "Nywila (Password)", Icons.lock_outline, obscure: true),
                const SizedBox(height: 12),
                _buildModernField(professionalController, "Wadhifa (mfano: Manager)", Icons.badge_outlined),
              ],
            ),

            const SizedBox(height: 20),

            // Official Business Details
            _buildPurpleCard(
              title: "Taarifa za Biashara",
              icon: Icons.storefront_outlined,
              children: [
                _buildModernField(businessNameController, "Jina la Biashara/ mfano MATUNDU SUPERMARKET", Icons.business_outlined),
                const SizedBox(height: 12),
                _buildModernField(locationController, "Mkoa/Eneo", Icons.public_outlined),
                const SizedBox(height: 12),
                _buildModernField(addressController, "Anwani (Mtaa au Jengo/P.O.BOX 3013)", Icons.location_on_outlined),
                const SizedBox(height: 12),
                _buildModernField(whatsappController, "Namba ya WhatsApp ", Icons.chat_outlined),
              ],
            ),

            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13)
                  ),
                ),
              ),

            const SizedBox(height: 30),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isLoading ? null : registerUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 5,
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("KAMILISHA USAJILI", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 40),
    );
  }

  // --- Helper UI Components ---

  Widget _buildPurpleCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF673AB7), size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF311B92))),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF673AB7), size: 20),
        filled: true,
        fillColor: const Color(0xFFF5F7FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        labelStyle: const TextStyle(fontSize: 14, color: Colors.blueGrey),
        floatingLabelStyle: const TextStyle(color: Color(0xFF311B92), fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> sendEmailToUser(String email, String phone, String name, String pass, String role, String biz) async {
    final smtpServer = SmtpServer(
      'mail.ephamarcysoftware.co.tz',
      username: 'suport@ephamarcysoftware.co.tz',
      password: 'Matundu@2050',
      port: 465,
      ssl: true,
    );

    final message = mailer.Message()
      ..from = mailer.Address('suport@ephamarcysoftware.co.tz', biz)
      ..recipients.add(email)
      ..subject = 'Akaunti Yako ya Biashara - $biz'
      ..html = '''
      <h3>Karibu kwenye STOCK & INVENTORY SOFTWARE</h3>
      <p>Habari $name,</p>
      <p>Usajili wako wa biashara ya <b>$biz</b> umekamilika.</p>
      <p><b>Login Credentials:</b></p>
      <ul>
        <li><b>Email:</b> $email</li>
        <li><b>Password:</b> $pass</li>
      </ul>
      <p>Tumia taarifa hizi kuingia kwenye mfumo.</p>
    ''';

    try {
      await mailer.send(message, smtpServer);
    } catch (e) {
      // Email failure is handled silently to not disturb user flow
    }
  }
}