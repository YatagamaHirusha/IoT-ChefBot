import 'package:flutter/material.dart';

class ReconnectWelcomeScreen extends StatelessWidget {
  const ReconnectWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.sync, size: 80, color: Colors.blue[600]),
              const SizedBox(height: 24),
              Text(
                "Welcome Back!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We see you already have a ChefBot cooker registered to your account. Let's find it on your Wi-Fi network.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Please make sure your phone is connected to your home Wi-Fi.",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // Navigate to the searching screen
                  Navigator.pushReplacementNamed(
                    context,
                    '/reconnect_searching',
                  );
                },
                child: const Text("Find My Cooker"),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Allow user to go to the first-time setup
                  Navigator.pushReplacementNamed(context, '/first_time_setup');
                },
                child: const Text("Need to set up a new cooker instead?"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
