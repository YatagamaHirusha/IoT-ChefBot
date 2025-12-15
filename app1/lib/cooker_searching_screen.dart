import 'dart:async';
import 'package:flutter/material.dart';

class CookerSearchingScreen extends StatefulWidget {
  const CookerSearchingScreen({super.key});

  @override
  State<CookerSearchingScreen> createState() => _CookerSearchingScreenState();
}

class _CookerSearchingScreenState extends State<CookerSearchingScreen> {
  @override
  void initState() {
    super.initState();
    _startSearch();
  }

  void _startSearch() {
    // This is a simulation.
    // In a real app, you would start your mDNS or network scan here.
    Timer(const Duration(seconds: 3), () {
      // After 3 seconds, simulate that we found the cooker
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/reconnect_found');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 32),
            Text(
              "Searching for your ChefBot...",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                "Make sure your cooker is powered on and connected to your home Wi-Fi.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
