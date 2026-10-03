import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'web_app_none.dart' if (dart.library.js_interop) 'web_app_browser.dart';

/// What running in a browser adds to the app: a newer version that has been
/// downloaded and is waiting, and the offer to install the app on the device.
/// Listen to it to follow changes.
///
/// This class is what every other platform gets, where neither ever happens.
class WebApp extends ChangeNotifier {
  /// Whether a newer version is ready to switch to.
  bool get updateReady => _updateReady;
  bool _updateReady = false;

  @protected
  set updateReady(bool value) {
    if (value == _updateReady) return;
    _updateReady = value;
    notifyListeners();
  }

  /// Whether the browser is offering to install the app.
  bool get canInstall => _canInstall;
  bool _canInstall = false;

  @protected
  set canInstall(bool value) {
    if (value == _canInstall) return;
    _canInstall = value;
    notifyListeners();
  }

  /// Switches to the newer version, by reloading the page.
  void applyUpdate() {}

  /// Shows the browser's own "Install app?" dialog.
  Future<void> install() async {}
}

final webAppProvider = Provider<WebApp>((ref) {
  final app = createWebApp();
  ref.onDispose(app.dispose);
  return app;
});
