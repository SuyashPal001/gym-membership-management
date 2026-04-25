import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart';
import '../config/api_config.dart';
import 'web_popup_manager.dart';

class AuthService {
  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;

  static const String _verifierKey = 'pkce_code_verifier';

  // ─── Web OAuth Callback Handler ──────────────────────────────────────────────

  /// On web, Cognito redirects the browser back to the Flutter app URL with
  /// ?code=XXX appended. Call this FIRST in main() before runApp().
  /// Returns true if a callback was detected and the token was exchanged.
  static Future<bool> handleWebOAuthCallback() async {
    if (!kIsWeb) return false;
    final uri = Uri.base;
    
    final code = uri.queryParameters['code'];

    if (code == null) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final verifier = prefs.getString(_verifierKey);

    if (verifier == null) {
      debugPrint('AuthService: PKCE verifier missing — possible page refresh during auth');
      // Clean up any partial state
      await prefs.remove(_verifierKey);
      return false;
    }

    final redirectUri = _getWebRedirectUri();

    final token = await _exchangeCodeForToken(code, verifier, redirectUri: redirectUri);
    await prefs.remove(_verifierKey);

    return token != null;
  }

  /// Returns the redirect URI appropriate for the current platform.
  /// On web/localhost: always uses port 8080 to prevent random-port redirect_mismatch.
  /// On web/production: uses the real origin.
  /// On mobile: the myapp://callback deep link scheme.
  static String _getWebRedirectUri() {
    return ApiConfig.redirectUri;
  }

  static Future<void> handleDeepLink(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        debugPrint('AuthService: Deep link returned error: $error');
        return;
      }

      if (code == null) {
        debugPrint('AuthService: Deep link has no code, ignoring.');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final verifier = prefs.getString(_verifierKey);

      if (verifier == null) {
        debugPrint('AuthService: No PKCE verifier found for cold-start exchange.');
        return;
      }

      debugPrint('AuthService: Cold-start code exchange starting...');
      await _exchangeCodeForToken(code, verifier);
      debugPrint('AuthService: Cold-start token exchange complete.');
    } catch (e) {
      debugPrint('AuthService: handleDeepLink error: $e');
    }
  }

  // ─── Sign In ─────────────────────────────────────────────────────────────────

  /// Launches the Cognito Hosted UI with PKCE and handles the code exchange.
  static Future<String?> signInWithGoogle() async {

    final completer = Completer<String?>();

    try {
      // 1. Generate and Persist PKCE Verifier/Challenge
      final verifier = _generateRandomString(64);
      final challenge = _generateCodeChallenge(verifier);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_verifierKey, verifier);

      // 2. Choose platform-specific redirect URI
      final redirectUri = _getWebRedirectUri();

      // 3. Construct URL
      final domain = ApiConfig.cognitoDomain;
      final clientId = ApiConfig.cognitoClientId;

      final String urlString = 'https://${ApiConfig.cognitoDomain}/oauth2/authorize?'
          'client_id=$clientId&'
          'response_type=code&'
          'scope=email+openid+profile&'
          'redirect_uri=${Uri.encodeComponent(redirectUri)}&'
          'identity_provider=Google&'
          'code_challenge=$challenge&'
          'code_challenge_method=S256&'
          'prompt=select_account';

      final authUrl = Uri.parse(urlString);

      if (kIsWeb) {
        
        return await WebPopupManager.instance.openAuthPopup(
          url: urlString,
          redirectUri: redirectUri,
          onCodeCaptured: (code) async {
            final prefs = await SharedPreferences.getInstance();
            final verifier = prefs.getString(_verifierKey);
            if (verifier != null) {
              return await _exchangeCodeForToken(
                code,
                verifier,
                redirectUri: redirectUri,
              );
            }
            return null;
          },
        );
      }

      // 4. Mobile: Setup deep link listener then launch browser
      _linkSubscription?.cancel();
      _linkSubscription = _appLinks.uriLinkStream.listen((uri) async {
        if (uri.scheme == 'myapp' && uri.host == 'callback') {
          final code = uri.queryParameters['code'];
          final savedVerifier = (await SharedPreferences.getInstance()).getString(_verifierKey);

          if (code != null && savedVerifier != null) {
            final token = await _exchangeCodeForToken(code, savedVerifier);
            completer.complete(token);
          } else {
            completer.complete(null);
          }

          _linkSubscription?.cancel();
          (await SharedPreferences.getInstance()).remove(_verifierKey);
        }
      }, onError: (err) {
        completer.completeError(err);
      });

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(
          authUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Could not launch browser for authentication.');
      }

      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _linkSubscription?.cancel();
          throw Exception('Sign-in timed out. Please try again.');
        },
      );
    } catch (e) {
      _linkSubscription?.cancel();
      rethrow;
    }
  }

  // ─── Token Exchange ──────────────────────────────────────────────────────────

  /// Exchanges the authorization code for tokens.
  /// [redirectUri] must exactly match what was sent in the auth request.
  static Future<String?> _exchangeCodeForToken(
    String code,
    String verifier, {
    String? redirectUri,
  }) async {
    try {
      final domain = ApiConfig.cognitoDomain.replaceFirst('https://', '');
      final tokenUri = Uri.https(domain, '/oauth2/token');
      final effectiveRedirectUri = redirectUri ?? 'myapp://callback';

      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': ApiConfig.cognitoClientId,
          'client_secret': ApiConfig.cognitoClientSecret,
          'code': code,
          'code_verifier': verifier,
          'grant_type': 'authorization_code',
          'redirect_uri': effectiveRedirectUri,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final idToken = data['id_token'];
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        final prefs = await SharedPreferences.getInstance();
        if (idToken != null) await prefs.setString('jwt_token', idToken);
        if (accessToken != null) await prefs.setString('access_token', accessToken);
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);

        return idToken;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ─── PKCE Utils ─────────────────────────────────────────────────────────────

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  // ─── Token Management ───────────────────────────────────────────────────────

  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<String?> getStoredGymId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gym_id');
  }

  static Future<void> storeGymId(String gymId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gym_id', gymId);
  }

  static Future<String?> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentRefreshToken = prefs.getString('refresh_token');
      if (currentRefreshToken == null) return null;

      final domain = ApiConfig.cognitoDomain.replaceFirst('https://', '');
      final tokenUri = Uri.https(domain, '/oauth2/token');

      final response = await http.post(
        tokenUri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'client_id': ApiConfig.cognitoClientId,
          'refresh_token': currentRefreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newIdToken = data['id_token'];
        final newAccessToken = data['access_token'];
        if (newAccessToken != null) await prefs.setString('access_token', newAccessToken);
        if (newIdToken != null) {
          await prefs.setString('jwt_token', newIdToken);
          return newIdToken;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payloadPart = parts[1];
      final normalized = base64Url.normalize(payloadPart);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = json.decode(decoded) as Map<String, dynamic>;
      final exp = claims['exp'] as int;
      return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
    } catch (_) {
      return true;
    }
  }

  static Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        _linkSubscription?.cancel();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('gym_id');
      await prefs.remove(_verifierKey);

    } catch (_) {}
  }
}
