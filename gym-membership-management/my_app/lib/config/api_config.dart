import 'dart:async' show TimeoutException;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// API host and gym defaults.
///
/// First launch shows [ServerSetupScreen] until a URL is saved (unless dart-define overrides).
///
/// ```bash
/// flutter run --dart-define=API_HOST=192.168.1.10
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5000/api
/// ```
class ApiConfig {
  ApiConfig._();

  static String? _savedBaseUrl;

  /// After [initialize]: `true` → open app normally; `false` → show server setup first.
  static bool skipServerSetupGate = false;

  static bool _hasCompileTimeOverride() {
    const a = String.fromEnvironment('API_BASE_URL');
    const b = String.fromEnvironment('API_HOST');
    return a.isNotEmpty || b.isNotEmpty;
  }

  /// Call from [main] before [runApp].
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_prefsKey);
    _savedBaseUrl = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
    skipServerSetupGate =
        _hasCompileTimeOverride() || (_savedBaseUrl != null && _savedBaseUrl!.isNotEmpty);
  }

  static const _prefsKey = 'api_base_url';

  /// Longer than API calls — first connection on Wi-Fi can be slow.
  static const Duration healthCheckTimeout = Duration(seconds: 25);

  static String get networkTroubleshootHint {
    return 'Quick checks:\n'
        '- Backend running? (terminal: nodemon / npm run dev)\n'
        '- Correct IP? Run ipconfig on the PC -- Wi-Fi IPv4 changes with DHCP.\n'
        '- Same Wi-Fi as the phone (not "guest" Wi-Fi -- it often blocks device-to-device).\n'
        '- Windows Firewall: allow Node.js or port 5001 on Private networks.\n'
        '- Turn VPN off on phone or PC while testing.\n'
        '- USB: adb reverse tcp:5001 tcp:5001 then use 127.0.0.1:5001';
  }

  /// Human-readable reason for failed HTTP (timeout, refused, etc.).
  static String describeRequestFailure(Object e, Uri? attempted) {
    final loc = attempted != null ? '\nTried: $attempted' : '';
    final msg = e.toString().toLowerCase();
    if (e is TimeoutException || msg.contains('timed out') || msg.contains('timeout')) {
      return 'Timed out waiting for the server.$loc\n'
          'Usually: wrong IP, firewall, guest Wi-Fi isolation, or API not running.';
    }
    if (msg.contains('connection refused') || msg.contains('errno = 111')) {
      return 'Connection refused.$loc\n'
          'Nothing is listening on that address -- start the API or fix the port.';
    }
    if (msg.contains('failed host lookup') || msg.contains('name not resolved')) {
      return 'Could not resolve hostname.$loc';
    }
    if (msg.contains('network is unreachable')) {
      return 'Network unreachable.$loc';
    }
    return 'Connection error: $e$loc';
  }

  /// Rejects incomplete IPs like `192.168.1.` before DNS fails with a cryptic error.
  static void assertPcAddressLooksComplete(String raw) {
    var s = raw.trim();
    if (s.isEmpty) {
      throw FormatException(
        'Type your PC\'s full address from ipconfig (example: 192.168.1.15:5000).',
      );
    }
    if (s.toLowerCase().startsWith('http://')) {
      s = s.substring(7);
    } else if (s.toLowerCase().startsWith('https://')) {
      s = s.substring(8);
    }
    final hostPort = s.split('/').first.trim();
    final host = hostPort.contains(':')
        ? hostPort.split(':').first.trim()
        : hostPort.trim();
    if (host.isEmpty) {
      throw FormatException('Missing IP or hostname.');
    }
    if (host.endsWith('.')) {
      throw FormatException(
        'IP is incomplete (ends with a dot). Use all four numbers, e.g. 192.168.1.15:5000',
      );
    }
    // Digit-only IPv4-style host must have exactly four octets
    if (RegExp(r'^[\d.]+$').hasMatch(host)) {
      final parts = host.split('.').where((p) => p.isNotEmpty).toList();
      if (parts.length != 4) {
        throw FormatException(
          'IPv4 needs four parts (from ipconfig). Example: 192.168.1.15:5000 -- not 192.168.1.',
        );
      }
      for (final p in parts) {
        final n = int.tryParse(p);
        if (n == null || n < 0 || n > 255) {
          throw FormatException('Invalid IPv4 number in address.');
        }
      }
    }
  }

  /// Normalizes to `scheme://host[:port]/api`.
  /// - HTTPS with no explicit port -> `https://host/api` (standard 443, no port appended)
  /// - HTTP with no explicit port or port 80 -> defaults to port 5001 (local dev)
  static String normalizeBaseUrl(String raw) {
    assertPcAddressLooksComplete(raw);
    var s = raw.trim();
    if (s.isEmpty) {
      throw FormatException('Enter your PC\'s address (e.g. 192.168.1.10:5001)');
    }
    final lower = s.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      s = 'http://$s';
    }
    final u = Uri.parse(s);
    if (!u.hasScheme || u.host.isEmpty) {
      throw FormatException('Invalid address. Example: 192.168.1.10:5001');
    }
    final String origin;
    final port = u.port;
    if (u.scheme == 'https' && (port == 0 || port == 443)) {
      origin = 'https://${u.host}';
    } else {
      final effectivePort = (port == 0 || port == 80) ? 5001 : port;
      origin = '${u.scheme}://${u.host}:$effectivePort';
    }
    return '$origin/api';
  }

  /// Confirms Node API is up (`GET /health` then `GET /`).
  static Future<void> verifyBackendReachable(String normalizedApiBase) async {
    final origin = Uri.parse(normalizedApiBase).origin;
    final urls = [Uri.parse('$origin/health'), Uri.parse('$origin/')];
    Object? lastErr;
    for (final url in urls) {
      try {
        final res = await http.get(url).timeout(healthCheckTimeout);
        if (res.statusCode < 500) return;
        lastErr = Exception('HTTP ${res.statusCode} from $url');
      } catch (e) {
        lastErr = e;
      }
    }
    final url = urls.first;
    throw Exception(
      '${describeRequestFailure(lastErr!, url)}\n\n$networkTroubleshootHint',
    );
  }

  static Future<void> setSavedBaseUrl(String raw) async {
    final normalized = normalizeBaseUrl(raw);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, normalized);
    _savedBaseUrl = normalized;
  }

  static Future<void> clearSavedBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    _savedBaseUrl = null;
  }

  /// Base URL including `/api`.
  static String get baseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    const host = String.fromEnvironment('API_HOST');
    if (host.isNotEmpty) return 'http://$host:5001/api';
    if (_savedBaseUrl != null && _savedBaseUrl!.isNotEmpty) return _savedBaseUrl!;
    if (kIsWeb) return 'http://localhost:5001/api';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:5001/api';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:5001/api';
      default:
        return 'http://localhost:5001/api';
    }
  }

  static String get apiOrigin => Uri.parse(baseUrl).origin;

  static const String cognitoUserPoolId = 'ap-south-1_fujnJpibc';
  static const String cognitoClientId = '3133ldc1jrvu87ka18ce56fto9';
  static const String cognitoDomain = 'ap-south-1fujnjpibc.auth.ap-south-1.amazoncognito.com';
  static const String cognitoRegion = 'ap-south-1';
  static const String googleClientIdAndroid = '129404364493-jfeepuki379ejj12rmt2vmn5tq2uh395.apps.googleusercontent.com';
  static const String googleClientIdWeb = '129404364493-go4260bf4t222nlqrbe7ijrtb5lfnl26.apps.googleusercontent.com';
  static const String cognitoClientSecret = '5c9il77h6j2jrhbkp3snphrdppfjc1mjglpkrqegs5osqge2q0d';

  static String get redirectUri {
    if (kIsWeb) {
      final base = Uri.base;
      final isLocalhost = base.host == 'localhost' || base.host == '127.0.0.1';
      final origin = isLocalhost
          ? '${base.scheme}://localhost:8080'
          : '${base.scheme}://${base.host}';
      return '$origin/auth/callback';
    }
    return 'myapp://callback';
  }
}
