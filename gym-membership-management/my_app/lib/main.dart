import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'constants/app_colors.dart';
import 'screens/onboarding_screen.dart';
import 'screens/server_setup_screen.dart';

// Global state for user's inputs
String globalStudioName = '';
String globalOwnerName = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.initialize();
  runApp(const UberInspiredApp());
}

class UberInspiredApp extends StatelessWidget {
  const UberInspiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Uber Inspired App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        fontFamily: 'Roboto', 
      ),
      home: ApiConfig.skipServerSetupGate
          ? OnboardingScreen()
          : const ServerSetupScreen(),
    );
  }
}
