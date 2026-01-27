import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Agreement/InstallationAgreementScreen.dart'; // Still imported but bypassed as requested
import 'login.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  int _currentWordIndex = 0;
  final List<String> _welcomeWords = ['WELCOME', 'TO', 'STOCK & INVENTORY', 'STOCK & INVENTORY'];

  // 1️⃣ Add a reference to the timer so we can cancel it
  Timer? _wordTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500),
        vsync: this
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutBack,
        )
    );

    _controller.forward();

    // 2️⃣ Assign the timer to the variable
    _wordTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_currentWordIndex < _welcomeWords.length - 1) {
        // 3️⃣ CRITICAL: Check if mounted before calling setState
        if (mounted) {
          setState(() => _currentWordIndex++);
        }
      } else {
        timer.cancel();
      }
    });

    _launchApp();
  }

  Future<void> _launchApp() async {
    await Future.delayed(const Duration(seconds: 4));

    // 4️⃣ Ensure we don't navigate if the user closed the app during the delay
    if (!mounted) return;

    // DIRECT TO LOGIN: We ignore 'isFirstLaunch' check here as requested
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    // 5️⃣ CLEANUP: Cancel the timer and dispose the controller to prevent memory leaks
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
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
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
                const SizedBox(height: 60),
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