import 'web_popup_manager.dart';
import 'web_popup_manager_mobile.dart'
    if (dart.library.html) 'web_popup_manager_web.dart' as loader;

void initializeWebAuth() {
  setWebPopupManager(loader.createManager());
}
