import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Wait 2 seconds to show splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is already logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in, go directly to dashboard
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // User is not logged in, go to welcome screen
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Your logo
            Image.asset(
              'assets/images/chefbot_logo.png',
              width: 200, // Adjust size as needed
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Colors.blue),
          ],
        ),
      ),
    );
  }
}
