import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// New file names
import 'views/startup_loader.dart';
import 'views/sign_in_page.dart';
import 'views/sign_up_page.dart';
import 'views/home_control_panel.dart';
import 'views/camera_feed_view.dart';
import 'views/cooking_history_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ChefBotProApp());
}

class ChefBotProApp extends StatelessWidget {
  const ChefBotProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChefBot Pro',
      debugShowCheckedModeBanner: false,

      // --- DARK THEME CONFIGURATION ---
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1120), // Very dark navy
        primaryColor: const Color(0xFF818CF8), // Indigo
        // Text Styling
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          bodyMedium: TextStyle(color: Color(0xFFE2E8F0)), // Slate-200
        ),

        // Input Fields (Dark filled style)
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B), // Slate-800
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.5),
          ),
          contentPadding: const EdgeInsets.all(20),
        ),

        // Buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1), // Indigo-500
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),

      // --- ROUTING ---
      initialRoute: '/',
      routes: {
        '/': (context) => const StartupLoader(),
        '/signin': (context) => const SignInPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomeControlPanel(),
        '/camera': (context) => const CameraFeedView(),
        '/history': (context) => const CookingHistoryView(),
      },
    );
  }
}
