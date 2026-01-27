import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_and_inventory_software/updater/update_service.dart';
import 'login.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _currentWordIndex = 0;
  final List<String> _welcomeWords = [
    'WELCOME',
    'TO',
    'STOCK & INVENTORY',
    'STOCK & INVENTORY'
  ];

  Timer? _wordTimer;
  final UpdateService _updateService = UpdateService();
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _wordTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_currentWordIndex < _welcomeWords.length - 1) {
        if (mounted) setState(() => _currentWordIndex++);
      } else {
        timer.cancel();
      }
    });

    _launchApp();
  }

  Future<void> _launchApp() async {
    await _updateService.init();

    if (!mounted) return;

    if (Platform.isWindows || Platform.isAndroid) {
      try {
        setState(() => _isDownloading = true);

        await _updateService.checkForUpdatesOncePer24Hours(
          onProgress: (p) {
            if (mounted) setState(() => _downloadProgress = p.clamp(0.0, 1.0));
          },
        );
      } catch (e) {
        debugPrint("Update check failed: $e");
      } finally {
        if (mounted) setState(() => _isDownloading = false);
      }
    }

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    _wordTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryPurple = Color(0xFF673AB7);
    const Color deepPurple = Color(0xFF311B92);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deepPurple, primaryPurple],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: -100,
              right: -100,
              child: CircleAvatar(
                radius: 150,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Opacity(opacity: _fadeAnimation.value, child: child),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Image.asset('assets/logo.png', width: 120),
                  ),
                ),
                const SizedBox(height: 50),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _welcomeWords[_currentWordIndex],
                    key: ValueKey<int>(_currentWordIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (_isDownloading)
                  Column(
                    children: [
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(_downloadProgress * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                else
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
            const Positioned(
              bottom: 50,
              child: Column(
                children: [
                  Text(
                    "STOCK&INVENTORY SOFTWARE",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text("v 2.5.0", style: TextStyle(color: Colors.white24, fontSize: 9)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
