import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Scanner/VieWAllToinOne.dart';


class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isDarkMode = false;

  // --- 1. WIDGET BUILD YAKO ILIYOBORESHWA ---
  @override
  Widget build(BuildContext context) {
    final Color nmbBlue = const Color(0xFF005696);
    final Color bgColor = _isDarkMode ? const Color(0xFF0A1128) : const Color(0xFFF0F4F8);
    final Color cardColor = _isDarkMode ? const Color(0xFF16213E) : Colors.white;
    final Color textColor = _isDarkMode ? Colors.white : Colors.black;

    return Theme(
      data: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        drawer: _buildDrawer(context, textColor),
        backgroundColor: bgColor,
        body: LayoutBuilder(builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 900;
          return Row(
            children: [
              if (isWide) _buildDesktopSidebar(cardColor, nmbBlue, textColor),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    _buildNMBAppBar(nmbBlue),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSearchHeader(cardColor, textColor),
                            const SizedBox(height: 20),
                            _buildImageSlider(cardColor),
                            const SizedBox(height: 25),
                            _buildInventoryChart(cardColor, nmbBlue, textColor),
                            const SizedBox(height: 30),
                            _buildSectionLabel("Operational Modules", nmbBlue),
                            const SizedBox(height: 15),
                            _buildResponsiveGrid(constraints.maxWidth, cardColor, nmbBlue, textColor),
                            const SizedBox(height: 120), // Nafasi ya Footer
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
        // Hapa ndipo tunaita Footer yenye Rainbow Bar na Scan Button
        bottomNavigationBar: MediaQuery.of(context).size.width <= 900
            ? _buildNMBFloatingDock(nmbBlue) : null,
      ),
    );
  }

  // --- 2. FUNCTION YA FOOTER (RAINBOW + SCAN BUTTON) ---
  Widget _buildNMBFloatingDock(Color themeColor) {
    return Container(
      height: 115, // Urefu wa kutosha ili kitufe kielewe juu
      color: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // A. RAINBOW BAR (Tabaka la chini)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CurvedRainbowBar(height: 85),
          ),

          // B. KITUFE CHA KUSCAN (Tabaka la juu kabisa)
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.heavyImpact(); // Mtetemo kidogo
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UniversalTerminalPage(user: widget.user),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.white, // Border ya nje
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))
                  ],
                ),
                child: Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [themeColor, Colors.indigo, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 35),
                      Text("SCAN",
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // C. ICONS ZA PEMBENI
          Positioned(
            bottom: 15,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDockIcon(Icons.grid_view_rounded, "Menu", true),
                  const SizedBox(width: 80), // Nafasi ya kitufe cha Kati
                  _buildDockIcon(Icons.analytics_outlined, "Reports", false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockIcon(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 28),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  // --- ZIADA: PLACEHOLDERS ZA FUNCTIONS ZAKO NYINGINE ---
  // (Hakikisha hizi zipo kwenye kodi yako)
  Widget _buildDrawer(BuildContext context, Color textColor) => const Drawer();
  Widget _buildDesktopSidebar(Color c, Color b, Color t) => Container();
  Widget _buildNMBAppBar(Color b) => const SliverAppBar();
  Widget _buildSearchHeader(Color c, Color t) => Container();
  Widget _buildImageSlider(Color c) => Container();
  Widget _buildInventoryChart(Color c, Color b, Color t) => Container();
  Widget _buildSectionLabel(String s, Color b) => Text(s);
  Widget _buildResponsiveGrid(double w, Color c, Color b, Color t) => Container();
}

// --- 3. CURVED RAINBOW BAR WIDGET ---
class CurvedRainbowBar extends StatelessWidget {
  final double height;
  const CurvedRainbowBar({this.height = 50, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: ArcClipper(),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.red, Colors.teal, Colors.pink, Colors.green,
              Colors.blue, Colors.indigo, Colors.purple
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

// --- 4. ARC CLIPPER (Kukata Rainbow Bar iwe na Curve) ---
class ArcClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, size.height * 0.4);

    // Curve nzuri ya kuelekea juu
    path.cubicTo(
      size.width * 0.25, size.height + 25,
      size.width * 0.75, size.height - 45,
      size.width, size.height * 0.4,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}