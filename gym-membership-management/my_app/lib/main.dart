// IMPORTANT: Always run web with: flutter run -d chrome --web-port 8080
// The OAuth callback redirect_uri is hardcoded to localhost:8080
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'config/api_config.dart';
import 'constants/app_colors.dart';
import 'services/auth_service.dart';
import 'services/route_guard.dart';
import 'services/web_auth_resolver.dart';

String globalOwnerName = 'there';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize local configuration
  await ApiConfig.initialize();

  // Initialize platform-specific auth helpers
  initializeWebAuth();

  if (!kIsWeb) {
    final appLinks = AppLinks();
    final initialLink = await appLinks.getInitialLink();
    if (initialLink != null) {
      AuthService.handleDeepLink(initialLink.toString());
    }
  }

  // 3. Determine initial entry screen (reads SharedPreferences for stored token)
  final Widget startScreen = await RouteGuard.determineStartScreen();

  // 4. Launch App
  runApp(GymOpsApp(home: startScreen));
}

class GymOpsApp extends StatelessWidget {
  final Widget home;

  const GymOpsApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GymOps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppColors.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: AppColors.primaryText),
        ),
      ),
      home: home,
    );
  }
}
