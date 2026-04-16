import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'web_popup_manager.dart';

class WebPopupManagerImpl implements WebPopupManager {
  html.WindowBase? _popup;
  StreamSubscription? _messageSubscription;

  @override
  Future<String?> openAuthPopup({
    required String url,
    required String redirectUri,
    required Future<String?> Function(String code) onCodeCaptured,
  }) async {
    final completer = Completer<String?>();
    
    // Choose dimensions
    final screenWidth = html.window.screen?.width ?? 1200;
    final screenHeight = html.window.screen?.height ?? 800;
    final popupWidth = 500;
    final popupHeight = 700;
    final left = ((screenWidth - popupWidth) / 2).round();
    final top = ((screenHeight - popupHeight) / 2).round();

    _popup = html.window.open(
      url,
      'cognito_auth',
      'width=$popupWidth,height=$popupHeight,left=$left,top=$top,scrollbars=yes,resizable=yes',
    );

    bool codeProcessed = false;

    _messageSubscription = html.window.onMessage.listen((event) async {
      // Security: Verify origin
      if (event.origin != html.window.location.origin) return;
      if (codeProcessed) return;

      try {
        final data = event.data;
        if (data == null) return;
        
        final code = data['code']?.toString();
        final error = data['error']?.toString();

        if (error != null) {
          codeProcessed = true;
          _cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        if (code != null) {
          codeProcessed = true;
          _cleanup();
          final token = await onCodeCaptured(code);
          if (!completer.isCompleted) completer.complete(token);
        }
      } catch (e) {
        debugPrint('WebPopupManager: postMessage error: $e');
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    try {
      return await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _cleanup();
          throw Exception('Sign-in timed out.');
        },
      );
    } catch (e) {
      _cleanup();
      rethrow;
    }
  }

  void _cleanup() {
    _messageSubscription?.cancel();
    _popup?.close();
    _popup = null;
    _messageSubscription = null;
  }

  @override
  void closePopup() => _cleanup();
}

WebPopupManager createManager() => WebPopupManagerImpl();
