import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

// Kumbuka ku-import footer yako hapa:
// import '../FOTTER/CurvedRainbowBar.dart';

// ---------------------------------------------------------------------------
// 1. ELITE ADMINISTRATIVE GRAPH ENGINE (PAINTER)
// ---------------------------------------------------------------------------

class AdminDashboardPainter extends CustomPainter {
  final List<double> points;
  final Color graphColor;
  final bool isDark;

  AdminDashboardPainter({
    required this.points,
    required this.graphColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final double verticalPadding = 25.0;
    final double horizontalPadding = 15.0;
    final double drawHeight = size.height - (verticalPadding * 2);
    final double drawWidth = size.width - (horizontalPadding * 2);

    // BACKGROUND GRID LOGIC
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 4; i++) {
      double y = verticalPadding + (drawHeight / 4) * i;
      canvas.drawLine(Offset(horizontalPadding, y), Offset(size.width - horizontalPadding, y), gridPaint);
    }

    // CALCULATE PATHS
    final path = Path();
    final fillPath = Path();

    double dx = drawWidth / (points.length - 1);
    double maxVal = points.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 1;

    for (int i = 0; i < points.length; i++) {
      double x = horizontalPadding + (i * dx);
      double y = (size.height - verticalPadding) - (points[i] / maxVal * drawHeight);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        double prevX = horizontalPadding + ((i - 1) * dx);
        double prevY = (size.height - verticalPadding) - (points[i - 1] / maxVal * drawHeight);

        var ctrl1 = Offset(prevX + (x - prevX) / 2, prevY);
        var ctrl2 = Offset(prevX + (x - prevX) / 2, y);

        path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, x, y);
        fillPath.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, x, y);
      }

      if (i == points.length - 1) {
        fillPath.lineTo(x, size.height);
        fillPath.close();
      }
    }

    // DRAW FILL GRADIENT
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, verticalPadding),
        Offset(0, size.height),
        [graphColor.withOpacity(0.3), graphColor.withOpacity(0.0)],
      );
    canvas.drawPath(fillPath, fillPaint);

    // DRAW MAIN LINE
    final linePaint = Paint()
      ..color = graphColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // DRAW INTERACTIVE DOTS
    final dotPaint = Paint()..color = graphColor;
    for (int i = 0; i < points.length; i++) {
      double x = horizontalPadding + (i * dx);
      double y = (size.height - verticalPadding) - (points[i] / maxVal * drawHeight);
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = isDark ? const Color(0xFF0F172A) : Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant AdminDashboardPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// 2. MAIN PAID LEND LOGS SCREEN
// ---------------------------------------------------------------------------

class PaidLendLogsScreen extends StatefulWidget {
  final String userRole;
  final String userName;

  const PaidLendLogsScreen({
    super.key,
    required this.userRole,
    required this.userName,
  });

  @override
  State<PaidLendLogsScreen> createState() => _PaidLendLogsScreenState();
}

class _PaidLendLogsScreenState extends State<PaidLendLogsScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // App Personalization
  bool _isDarkMode = false;
  String _currentRole = '';
  String _authenticatedUser = '';
  String _businessName = 'Recovery System';
  dynamic _bizId;
  bool _isLoading = false;

  // Data State
  Future<List<Map<String, dynamic>>>? _logsFuture;
  Future<double>? _totalFuture;

  // Filtering Controls
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _authenticatedUser = widget.userName;
    _currentRole = widget.userRole.toLowerCase();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _isDarkMode = prefs.getBool('darkMode') ?? false);
    await _fetchUserMetadata();
    _refresh();
  }

  Future<void> _fetchUserMetadata() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final res = await supabase.from('users').select().eq('id', user.id).maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _bizId = res['business_id'];
          _currentRole = res['role']?.toString().toLowerCase() ?? 'staff';
          _authenticatedUser = res['full_name'] ?? widget.userName;
          _businessName = res['sub_business_name'] ?? res['business_name'] ?? 'Main Office';
        });
      }
    } catch (e) {
      debugPrint("Metadata Fetch Failure: $e");
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _logsFuture = _fetchLogsFromDB();
        _totalFuture = _calculateGrandTotal();
      });
      _logsFuture?.then((_) => setState(() => _isLoading = false));
      _animController.forward(from: 0);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. SECURE DATA LAYER (PRIVACY LOGIC)
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> _fetchLogsFromDB() async {
    if (_bizId == null) return [];
    try {
      var query = supabase.from('To_lent_payedlogs').select().eq('business_id', _bizId);

      // SECURITY SHIELD: Check access level
      final bool isPrivileged = ['admin', 'sub_admin', 'accountant', 'hr'].contains(_currentRole);

      if (!isPrivileged) {
        // Staff see only what they personally processed
        query = query.eq('confirmed_by', _authenticatedUser);
      }

      if (_searchController.text.isNotEmpty) {
        String k = '%${_searchController.text.trim()}%';
        query = query.or('receipt_number.ilike.$k,customer_name.ilike.$k');
      }

      if (_startDate != null && _endDate != null) {
        query = query.gte('paid_time', DateFormat('yyyy-MM-dd').format(_startDate!))
            .lte('paid_time', DateFormat('yyyy-MM-dd 23:59:59').format(_endDate!));
      }

      final response = await query.order('paid_time', ascending: false);
      List<Map<String, dynamic>> rawData = List<Map<String, dynamic>>.from(response);

      // TIMELINE GROUPING LOGIC
      Map<String, Map<String, dynamic>> receiptGroups = {};
      for (var row in rawData) {
        String receiptNo = row['receipt_number'] ?? 'UNKWN';
        double amount = double.tryParse(row['total_price']?.toString() ?? '0') ?? 0.0;

        if (!receiptGroups.containsKey(receiptNo)) {
          receiptGroups[receiptNo] = Map<String, dynamic>.from(row);
          receiptGroups[receiptNo]!['calculated_total'] = amount;
          receiptGroups[receiptNo]!['transaction_history'] = [row];
        } else {
          receiptGroups[receiptNo]!['calculated_total'] += amount;
          receiptGroups[receiptNo]!['transaction_history'].add(row);
        }
      }
      return receiptGroups.values.toList();
    } catch (e) {
      debugPrint("Log Fetch Error: $e");
      return [];
    }
  }

  Future<double> _calculateGrandTotal() async {
    if (_bizId == null) return 0.0;
    try {
      var query = supabase.from('To_lent_payedlogs').select('total_price').eq('business_id', _bizId);

      final bool isPrivileged = ['admin', 'sub_admin', 'accountant', 'hr'].contains(_currentRole);
      if (!isPrivileged) {
        query = query.eq('confirmed_by', _authenticatedUser);
      }

      if (_startDate != null && _endDate != null) {
        query = query.gte('paid_time', DateFormat('yyyy-MM-dd').format(_startDate!))
            .lte('paid_time', DateFormat('yyyy-MM-dd 23:59:59').format(_endDate!));
      }

      final res = await query;
      double sum = 0.0;
      for (var r in res) {
        sum += double.tryParse(r['total_price']?.toString() ?? '0') ?? 0.0;
      }
      return sum;
    } catch (e) {
      return 0.0;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. UI ARCHITECTURE
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isDark = _isDarkMode;
    final Color scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final Color surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final Color mainText = isDark ? Colors.white : const Color(0xFF1E293B);
    const Color brandPrimary = Color(0xFF6366F1);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildEliteAppBar(brandPrimary),
      body: Column(
        children: [
          _buildFilterDashboard(surfaceColor, mainText, brandPrimary),
          Expanded(
            child: RefreshIndicator(
              color: brandPrimary,
              onRefresh: () async => _refresh(),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildSummarySlab(surfaceColor, brandPrimary),
                  const SizedBox(height: 20),
                  _buildTrendVisual(surfaceColor, brandPrimary, isDark),
                  const SizedBox(height: 25),
                  _buildListHeader(mainText),
                  const SizedBox(height: 12),
                  _buildLogList(surfaceColor, mainText, isDark),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildEliteAppBar(Color brand) {
    return AppBar(
      toolbarHeight: 120,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [brand, brand.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(35)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
              const SizedBox(height: 8),
              const Text("RECOVERY INTELLIGENCE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.2)),
              Text("${_currentRole.toUpperCase()} : ${_businessName.toUpperCase()}",
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("User: $_authenticatedUser", style: const TextStyle(color: Colors.white54, fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDashboard(Color card, Color txt, Color brand) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15)],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _refresh(),
              style: TextStyle(color: txt, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search customer, medicine or receipt...",
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                icon: Icon(Icons.search_rounded, color: brand, size: 22),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDateButton("START DATE", _startDate, () => _pickDate(true), card, txt, brand)),
              const SizedBox(width: 12),
              Expanded(child: _buildDateButton("END DATE", _endDate, () => _pickDate(false), card, txt, brand)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton(String label, DateTime? date, VoidCallback onTap, Color card, Color txt, Color brand) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brand.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 14, color: brand),
                const SizedBox(width: 8),
                Text(date == null ? "Select" : DateFormat('dd MMM yy').format(date),
                    style: TextStyle(color: txt, fontSize: 11, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySlab(Color card, Color brand) {
    return FutureBuilder<double>(
      future: _totalFuture,
      builder: (context, snap) {
        String totalVal = snap.hasData ? NumberFormat('#,##0').format(snap.data) : "---";
        final bool isPrivileged = ['admin', 'sub_admin', 'accountant', 'hr'].contains(_currentRole);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [BoxShadow(color: brand.withOpacity(0.08), blurRadius: 25)],
          ),
          child: Column(
            children: [
              Text(isPrivileged ? "HISTORIA YA MADENI" : "JUMLA MADENI ULIYOLIPISHA",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text("TSH $totalVal",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, color: Colors.green, size: 14),
                    SizedBox(width: 6),
                    Text("Data Sync Active", style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrendVisual(Color card, Color brand, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();

        List<double> trendPoints = snap.data!
            .take(12)
            .map((e) => (e['calculated_total'] as double))
            .toList()
            .reversed
            .toList();

        if (trendPoints.length < 2) return const SizedBox.shrink();

        return Container(
          height: 180,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(25)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("COLLECTION VELOCITY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 18),
              Expanded(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: AdminDashboardPainter(points: trendPoints, graphColor: Colors.green, isDark: isDark),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListHeader(Color txt) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("TRANSACTION TIMELINE", style: TextStyle(color: txt, fontWeight: FontWeight.w900, fontSize: 13)),
        const Icon(Icons.history_edu_rounded, color: Colors.grey, size: 18),
      ],
    );
  }

  Widget _buildLogList(Color card, Color txt, bool isDark) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _logsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }

        final data = snap.data ?? [];
        if (data.isEmpty) {
          return Center(child: Column(
            children: [
              const SizedBox(height: 50),
              Icon(Icons.no_accounts_rounded, size: 60, color: Colors.grey.withOpacity(0.3)),
              const Text("No recovery logs found for your access level", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ));
        }

        return Column(
          children: data.map((log) => _buildTransactionCard(log, card, txt, isDark)).toList(),
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> log, Color card, Color txt, bool isDark) {
    List history = log['transaction_history'] ?? [];
    double total = log['calculated_total'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10)],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.green,
          title: Text(log['customer_name'] ?? 'Mteja',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: txt),
              overflow: TextOverflow.ellipsis),
          subtitle: Text("Receipt #${log['receipt_number']} • ${history.length} Event(s)",
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          trailing: Text("TSH ${NumberFormat('#,##0').format(total)}",
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 14)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 5, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 15),
                  const Text("MLITIRIKO WA MALIPO (TIMELINE)",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                  const SizedBox(height: 15),
                  ...history.map((h) => _buildTimelineEvent(h, txt)).toList(),
                  const Divider(height: 30),
                  _buildMetaDetail("Processed By", log['confirmed_by'], txt),
                  _buildMetaDetail("Method", log['payment_method'], txt),
                  _buildMetaDetail("Branch", log['business_name'], txt),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineEvent(Map<String, dynamic> event, Color txt) {
    String dateStr = DateFormat('dd MMM, HH:mm').format(DateTime.parse(event['paid_time']));
    double amt = double.tryParse(event['total_price'].toString()) ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.check_circle, size: 14, color: Colors.green),
            Container(width: 1.5, height: 35, color: Colors.green.withOpacity(0.2)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(event['medicine_name'] ?? 'Payment',
                        style: TextStyle(fontSize: 12, color: txt, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text("TSH ${NumberFormat('#,##0').format(amt)}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green)),
                ],
              ),
              Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 10),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMetaDetail(String label, dynamic value, Color txt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(value?.toString() ?? 'Default',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txt),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. HELPER METHODS & LIFECYCLE
  // ---------------------------------------------------------------------------

  Future<void> _pickDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6366F1)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
        _refresh();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }
}