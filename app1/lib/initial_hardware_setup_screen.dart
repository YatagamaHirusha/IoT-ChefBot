import 'package:flutter/material.dart';

class InitialHardwareSetupScreen extends StatelessWidget {
  const InitialHardwareSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Set Up Your Cooker"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Icon(Icons.wifi_find, size: 80, color: Colors.blue[600]),
              const SizedBox(height: 24),
              Text(
                "Let's Connect Your Cooker",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),

              // Step 1
              _buildStep(
                context,
                "1",
                "Plug in your ChefBot cooker and wait for the blue Wi-Fi light to start blinking.",
              ),
              const SizedBox(height: 20),

              // Step 2
              _buildStep(
                context,
                "2",
                "On your phone, go to Wi-Fi settings and connect to the network named 'ChefBot-XXXX'.",
              ),
              const SizedBox(height: 20),

              // Step 3
              _buildStep(
                context,
                "3",
                "Return to this app once you are connected to the cooker's Wi-Fi.",
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () {
                  // Navigate to WiFi setup screen where user enters credentials
                  Navigator.pushReplacementNamed(context, '/wifi_setup');
                },
                child: const Text("I'm Connected to 'ChefBot-XXXX'"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build the styled steps
  Widget _buildStep(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue[600],
          radius: 14,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(height: 1.4),
          ),
        ),
      ],
    );
  }
}
