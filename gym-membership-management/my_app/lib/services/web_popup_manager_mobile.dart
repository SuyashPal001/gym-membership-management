import 'dart:async';
import 'web_popup_manager.dart';

class MobilePopupManager implements WebPopupManager {
  @override
  Future<String?> openAuthPopup({
    required String url,
    required String redirectUri,
    required Future<String?> Function(String code) onCodeCaptured,
  }) async {
    // Mobile uses url_launcher, not popups
    return null;
  }

  @override
  void closePopup() {}
}

WebPopupManager createManager() => MobilePopupManager();
