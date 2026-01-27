import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../FOTTER/CurvedRainbowBar.dart';

class NormalUsageForm extends StatefulWidget {
  final dynamic userId;
  final String addedBy;

  const NormalUsageForm({super.key, required this.userId, required this.addedBy});

  @override
  _NormalUsageFormState createState() => _NormalUsageFormState();
}

class _NormalUsageFormState extends State<NormalUsageForm> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient supabase = Supabase.instance.client;

  String? _selectedCategory;
  String _businessName = "PAKIA...";
  int? _currentBusinessId; // 🆔 Imeongezwa hapa
  bool _isLoading = false;
  bool _isDarkMode = false;
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final List<String> _categories = [
    'Transport', 'Security', 'Tax', 'Food',
    'Electricity', 'Water', 'Rent', 'Salaries', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _fetchBusinessData(); // Imebadilishwa jina
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
    }
  }

  /// 🔐 Inavuta Jina na ID ya biashara ili isolation ifanye kazi
  Future<void> _fetchBusinessData() async {
    debugPrint("🔍 DEBUG: Inatafuta data za biashara...");
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('users')
            .select('business_name, business_id')
            .eq('id', user.id)
            .maybeSingle();

        if (data != null && mounted) {
          setState(() {
            _businessName = data['business_name'].toString().toUpperCase();
            // Inahifadhi business_id kama integer kwa ajili ya ripoti
            _currentBusinessId = int.tryParse(data['business_id'].toString());
          });
          debugPrint("✅ DEBUG: Biashara: $_businessName | ID: $_currentBusinessId");
        }
      }
    } catch (e) {
      debugPrint("🚨 DEBUG ERROR (Biz Fetch): $e");
      if (mounted) setState(() => _businessName = "REKODI MATUMIZI");
    }
  }

  int _parseToInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF0288D1),
              onPrimary: Colors.white,
              surface: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              onSurface: _isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Uhakiki wa Business ID
    if (_currentBusinessId == null) {
      _showSnackBar('Kosa: ID ya biashara haijapatikana. Refresh na ujaribu tena.', Colors.red);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    debugPrint("🚀 DEBUG: Inatuma data Supabase...");

    try {
      final Map<String, dynamic> expenseData = {
        'user_id': _parseToInt(widget.userId),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'added_by': widget.addedBy,
        'usage_date': _selectedDate.toUtc().toIso8601String(),
        'business_name': _businessName,
        'business_id': _currentBusinessId, // 🚀 MUHIMU: Inahifadhi ID hapa
      };

      debugPrint("📦 DEBUG: Payload with BusinessID: $expenseData");

      await supabase.from('normal_usage').insert(expenseData);

      debugPrint("✅ DEBUG: Data imehifadhiwa!");

      if (mounted) {
        _showSuccessDialog();
        _formKey.currentState?.reset();
        setState(() {
          _selectedCategory = null;
          _descriptionController.clear();
          _amountController.clear();
          _selectedDate = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint("🚨 DEBUG ERROR (Submission): $e");
      if (mounted) _showSnackBar('Kosa: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Sehemu iliyobaki ya UI kama _showSuccessDialog, build, nk. inabaki vilevile)

  void _showSuccessDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF03A9F4), size: 70),
            const SizedBox(height: 15),
            Text("IMEHIFADHIWA",
                style: TextStyle(fontWeight: FontWeight.w900, color: _isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 5),
            Text("Rekodi ya matumizi imewekwa sawa.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white70 : Colors.grey)),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF03A9F4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("SAWA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(_businessName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            const Text("REKODI MATUMIZI", style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0277BD), Color(0xFF03A9F4)]),
          ),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF03A9F4)))
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle("CHAGUA TAREHE", Icons.calendar_today_outlined, isDark),
              const SizedBox(height: 10),
              _buildDateCard(cardColor, isDark),
              const SizedBox(height: 25),
              _sectionTitle("MAELEZO YA MALIPO", Icons.payments_outlined, isDark),
              const SizedBox(height: 10),
              _buildFormCard(cardColor, isDark),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CurvedRainbowBar(height: 45),
    );
  }

  Widget _sectionTitle(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF03A9F4)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: isDark ? Colors.white70 : Colors.blueGrey[800])),
      ],
    );
  }

  Widget _buildDateCard(Color cardColor, bool isDark) {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF03A9F4).withOpacity(0.1),
              child: const Icon(Icons.date_range_rounded, color: Color(0xFF03A9F4), size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tarehe ya matumizi", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(Color cardColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            decoration: _inputStyle("Aina ya Matumizi", Icons.layers_outlined, isDark),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
            validator: (v) => v == null ? 'Chagua aina' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            maxLines: 2,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            decoration: _inputStyle("Maelezo ya Matumizi", Icons.short_text_rounded, isDark),
            validator: (v) => (v == null || v.isEmpty) ? 'Jaza sehemu hii' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20),
            decoration: _inputStyle("Kiasi (TSH)", Icons.account_balance_wallet_rounded, isDark),
            validator: (v) => (v == null || v.isEmpty) ? 'Jaza sehemu hii' : null,
          ),
          const SizedBox(height: 35),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0288D1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
              ),
              child: const Text('HIFADHI REKODI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: Colors.blueGrey),
      prefixIcon: Icon(icon, color: const Color(0xFF03A9F4), size: 20),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F9FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.blue.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF03A9F4), width: 1.5)),
    );
  }

  void _showSnackBar(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }
}