import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'theme/tesla_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load custom backend URL from shared preferences
  try {
    final prefs = await SharedPreferences.getInstance();
    final customUrl = prefs.getString('custom_backend_url');
    if (customUrl != null && customUrl.isNotEmpty) {
      ApiService.setCustomBaseUrl(customUrl);
    }
  } catch (e) {
    debugPrint('Failed to load custom backend URL: $e');
  }

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  runApp(const FaceRecognitionApp());
}

class FaceRecognitionApp extends StatelessWidget {
  const FaceRecognitionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gurukul School Attendance',
      theme: TeslaTheme.theme(),
      darkTheme: TeslaTheme.theme(),
      themeMode: ThemeMode.dark,
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
