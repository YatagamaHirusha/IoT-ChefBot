import 'package:flutter/material.dart';

class CookerFoundScreen extends StatelessWidget {
  const CookerFoundScreen({super.key});

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
              Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green[600],
              ),
              const SizedBox(height: 24),
              Text(
                "Cooker Found!",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "We found 'Kitchen Cooker' on your network.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                ),
                onPressed: () {
                  // TODO:
                  // 1. Finalize the connection in the app
                  // 2. Navigate to the main dashboard
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
                child: const Text("Connect"),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
