import 'dart:async';

abstract class WebPopupManager {
  static WebPopupManager get instance => _instance;
  static late final WebPopupManager _instance;

  Future<String?> openAuthPopup({
    required String url,
    required String redirectUri,
    required Future<String?> Function(String code) onCodeCaptured,
  });

  void closePopup();
}

// Internal logic to handle the conditional injection
void setWebPopupManager(WebPopupManager manager) {
  WebPopupManager._instance = manager;
}
