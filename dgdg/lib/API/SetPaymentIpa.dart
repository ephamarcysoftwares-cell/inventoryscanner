import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BusinessConfigTable extends StatefulWidget {
  const BusinessConfigTable({super.key});

  @override
  State<BusinessConfigTable> createState() => _BusinessConfigTableState();
}

class _BusinessConfigTableState extends State<BusinessConfigTable> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String businessName = 'Loading...';
  int? businessId;
  User? currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserBusiness();
  }

  /// Pakia taarifa za biashara ya mtumiaji aliyelog-in
  Future<void> _loadUserBusiness() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    currentUser = user;

    try {
      final data = await _supabase
          .from('users')
          .select('business_name, business_id')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        setState(() {
          businessName = data['business_name'] ?? 'Unknown Business';
          businessId = data['business_id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load business error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF1A237E);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'BUSINESS BILLING',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 20),
          _sectionTitle("SUBSCRIPTION OVERVIEW"),
          const SizedBox(height: 8),
          _subscriptionSection(),
          const SizedBox(height: 25),
          _sectionTitle("DETAILED PAYMENTS HISTORY"),
          const SizedBox(height: 8),
          _paymentsSection(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  /// ================= HEADER =================
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF311B92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            businessName.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            "BUSINESS ID: ${businessId ?? 'N/A'}",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// ================= SUBSCRIPTION =================
  Widget _subscriptionSection() {
    if (businessId == null) return _emptyCard('Missing Business ID');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from('subscriptions')
          .stream(primaryKey: ['id'])
          .eq('business_id', businessId!)
          .limit(1),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _loadingCard();
        if (snapshot.data!.isEmpty) return _emptyCard('No active subscription found');

        final sub = snapshot.data!.first;

        return _card(children: [
          _row('Price / Month', '${NumberFormat("#,###").format(double.tryParse(sub['price_per_month'].toString()) ?? 0)} TZS'),
          _row('Discount', '${sub['discount_percent']}%'),
          _row('Status', sub['payment_status']?.toString().toUpperCase() ?? 'N/A',
              isStatus: true,
              statusColor: sub['payment_status'] == 'Active' ? Colors.green : Colors.orange),
          const Divider(height: 20),
          _row('Last Paid Date', sub['last_payment_date'] == null ? '-' : DateFormat('dd MMM yyyy').format(DateTime.parse(sub['last_payment_date']))),
        ]);
      },
    );
  }

  /// ================= PAYMENTS (FULL DETAILS) =================
  Widget _paymentsSection() {
    if (businessId == null) return _emptyCard('Missing Business ID');

    final bool isAdmin = currentUser?.email == 'mlyukakenedy@gmail.com';

    final paymentsStream = isAdmin
        ? _supabase.from('payments').stream(primaryKey: ['id']).order('created_at', ascending: false)
        : _supabase.from('payments').stream(primaryKey: ['id']).eq('business_id', businessId!).order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: paymentsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _loadingCard();
        if (snapshot.data!.isEmpty) return _emptyCard('No payments found');

        return Column(
          children: snapshot.data!.map((pay) {
            return _card(children: [
              // --- Header ya Kadi: Reference na Tarehe ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("REF: ${pay['order_reference'] ?? 'N/A'}",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  Text(pay['created_at'] != null
                      ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(pay['created_at']))
                      : '-',
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
              const Divider(height: 15),

              // --- Taarifa za Fedha ---
              _row('Bill Amount', '${NumberFormat("#,###").format(pay['amount'])} ${pay['currency']}'),
              _row('Collected', '${NumberFormat("#,###").format(pay['collected_amount'] ?? 0)} ${pay['currency']}', isBoldValue: true),
              _row('Duration', '${pay['months']} Months'),

              // --- Taarifa za ClickPesa / Billing ---
              _row('Control Number', pay['control_number'] ?? '-', isBoldValue: true),
              _row('Payment Status', pay['status'],
                  isStatus: true,
                  statusColor: pay['status'] == 'SUCCESS' ? Colors.green : Colors.blue),
              _row('Channel', pay['channel'] ?? 'PENDING'),

              // --- Taarifa za Mteja (Columns Mpya) ---
              const Divider(height: 15),
              _row('Customer', pay['customer_name'] ?? '-'),
              _row('Contact', pay['phone_number'] ?? pay['customer_email'] ?? '-'),

              // --- Expiry Details ---
              if (pay['expiry_date'] != null)
                _row('Expiry Date', DateFormat('dd MMM yyyy').format(DateTime.parse(pay['expiry_date'])),
                    statusColor: Colors.redAccent, isStatus: true),

              if (isAdmin) ...[
                const Divider(),
                _row('Biz Name', pay['business_name'] ?? 'N/A', statusColor: Colors.purple, isStatus: true),
              ],
            ]);
          }).toList(),
        );
      },
    );
  }

  /// ================= UI HELPERS =================
  Widget _card({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, dynamic value, {bool isStatus = false, Color? statusColor, bool isBoldValue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          Flexible(
            child: isStatus
                ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: (statusColor ?? Colors.grey).withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
              child: Text(value?.toString() ?? '-', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
            )
                : Text(value?.toString() ?? '-',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontWeight: isBoldValue ? FontWeight.w900 : FontWeight.w600, color: const Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade300, letterSpacing: 1.2)),
    );
  }

  Widget _loadingCard() => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2)));

  Widget _emptyCard(String text) => Container(
    width: double.infinity, padding: const EdgeInsets.all(30),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(
      children: [
        Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}