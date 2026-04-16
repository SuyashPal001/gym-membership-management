import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;
import 'package:flutter/material.dart';
import '../screens/main_scaffold.dart';
import '../screens/login_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/api_exception.dart';

class RouteGuard {
  static Future<Widget> determineStartScreen() async {
    try {
      // 1. Check token exists in local storage
      final token = await AuthService.getStoredToken();
      if (token == null) {
        return const LoginScreen();
      }

      // 2. Check token expiry (Simplified local check)
      if (AuthService.isTokenExpired(token)) {
        await AuthService.signOut();
        return const LoginScreen();
      }

      // 3. Sync Identity with Backend
      try {
        final gymProfile = await ApiService.fetchMe();
        
        // Success (200) -> Established Identity
        final gymId = gymProfile['id']?.toString();
        if (gymId != null) {
          await AuthService.storeGymId(gymId);
        }
        return MainScaffold();
        
      } on ApiException catch (e) {
        print('RouteGuard ApiException: ${e.statusCode} — ${e.message}');

        if (e.statusCode == 404) {
          // No gym found for this Cognito sub → Needs onboarding
          return const OnboardingScreen();
        }

        if (e.statusCode == 401) {
          // Token rejected → force fresh login
          await AuthService.signOut();
          return const LoginScreen();
        }

        if (e.statusCode == 0) {
          print('RouteGuard: No network, routing offline.');
          return MainScaffold(); // keeps session intact, user sees offline state
        }
        // All other backend errors (500 etc) → don't wipe session
        print('RouteGuard: Backend error ${e.statusCode}, routing to MainScaffold offline.');
        return MainScaffold();

      } on SocketException catch (_) {
        print('RouteGuard: No network, routing offline.');
        return const LoginScreen();

      } on TimeoutException catch (_) {
        print('RouteGuard: Request timed out, routing offline.');
        return const LoginScreen();

      } on Exception catch (e) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('not authenticated')) {
          return const LoginScreen();
        }
        print('RouteGuard Error: $e');
        return const LoginScreen();
      }
      
    } catch (e) {
      print('RouteGuard Fatal Error: $e');
      return const LoginScreen();
    }
  }
}
