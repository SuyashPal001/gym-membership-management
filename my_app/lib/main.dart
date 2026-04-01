import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'constants/app_colors.dart';

// Global state for user's inputs
String globalStudioName = '';
String globalOwnerName = '';

void main() {
  runApp(UberInspiredApp());
}

class UberInspiredApp extends StatelessWidget {
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
      home: OnboardingScreen(),
    );
  }
}
