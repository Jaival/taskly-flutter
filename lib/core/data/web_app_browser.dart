import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'web_app.dart';

WebApp createWebApp() => _BrowserWebApp().._start();

/// Set by the script in `web/index.html`, which hears the browser's offer to
/// install the app before this code has loaded.
const _installPrompt = 'tasklyInstallPrompt';
const _installChanged = 'taskly-install-change';

/// Tick this in the browser's storage to try the service worker on
/// localhost: `localStorage.setItem('taskly.serviceWorker', 'on')`.
const _localOptIn = 'taskly.serviceWorker';

/// Talks to the service worker in `web/sw.js`, which keeps a copy of the app
/// on the device and looks for newer versions when asked.
class _BrowserWebApp extends WebApp {
  static const _checkEvery = Duration(minutes: 30);

  DateTime _lastCheck = DateTime.now();
  Timer? _firstCheck;

  JSFunction? _onInstallChanged;
  JSFunction? _onMessage;
  JSFunction? _onVisible;

  bool get _hasServiceWorkers =>
      web.window.navigator.has('serviceWorker') && web.window.has('caches');

  /// A debug build is served by `flutter run`, and a worker that answered
  /// from its cache there would hide every change to the code. The same
  /// goes for a release build on localhost, unless it's asked for.
  bool get _wantsServiceWorker {
    if (!kReleaseMode) return false;
    final host = web.window.location.hostname;
    if (host != 'localhost' && host != '127.0.0.1') return true;
    return web.window.localStorage.getItem(_localOptIn) == 'on';
  }

  void _start() {
    _watchInstallOffer();
    if (!_hasServiceWorkers) return;
    unawaited(
      (_wantsServiceWorker ? _startServiceWorker() : _removeServiceWorker())
          .catchError((Object _) {}),
    );
  }

  /// The browser's offer to install the app, while there is one.
  JSObject? get _offer {
    final offer = web.window.getProperty<JSAny?>(_installPrompt.toJS);
    return offer.isTruthy.toDart ? offer as JSObject? : null;
  }

  void _watchInstallOffer() {
    void read() => canInstall = _offer != null;
    _onInstallChanged = ((web.Event _) => read()).toJS;
    web.window.addEventListener(_installChanged, _onInstallChanged);
    read();
  }

  Future<void> _startServiceWorker() async {
    final workers = web.window.navigator.serviceWorker;
    _onMessage = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data is! Map) return;
      switch (data['type']) {
        case 'update':
          updateReady = data['ready'] == true;
        case 'reload':
          web.window.location.reload();
      }
    }).toJS;
    workers.addEventListener('message', _onMessage);
    await workers.register('sw.js'.toJS).toDart;

    // Once the first page has had a moment to load everything it needs.
    _firstCheck = Timer(const Duration(seconds: 8), () {
      final loaded = web.window.performance.getEntriesByType('resource');
      unawaited(
        _send({
          'type': 'keep',
          'urls': [for (final entry in loaded.toDart) entry.name],
        }),
      );
      _check();
    });
    // And when someone comes back to a tab that has been open for a while.
    _onVisible = ((web.Event _) {
      final visible = web.document.visibilityState == 'visible';
      final due = DateTime.now().difference(_lastCheck) >= _checkEvery;
      if (visible && due) _check();
    }).toJS;
    web.document.addEventListener('visibilitychange', _onVisible);
  }

  /// Undoes [_startServiceWorker] where the worker isn't wanted, in case an
  /// earlier build left one behind.
  Future<void> _removeServiceWorker() async {
    final registrations = await web.window.navigator.serviceWorker
        .getRegistrations()
        .toDart;
    for (final registration in registrations.toDart) {
      await registration.unregister().toDart;
    }
    final names = await web.window.caches.keys().toDart;
    for (final name in names.toDart) {
      if (name.toDart.startsWith('taskly-')) {
        await web.window.caches.delete(name.toDart).toDart;
      }
    }
  }

  void _check() {
    _lastCheck = DateTime.now();
    unawaited(_send({'type': 'check'}));
  }

  /// Returns whether there was a worker to send it to.
  Future<bool> _send(Map<String, Object?> message) async {
    try {
      final registration = await web.window.navigator.serviceWorker.ready.toDart
          .timeout(const Duration(seconds: 5));
      final worker = registration.active;
      if (worker == null) return false;
      worker.postMessage(message.jsify());
      return true;
    } on Object {
      return false;
    }
  }

  @override
  void applyUpdate() {
    // The worker swaps the versions, then tells this page to reload.
    unawaited(
      _send({'type': 'apply'}).then((sent) {
        if (!sent) web.window.location.reload();
      }),
    );
  }

  @override
  Future<void> install() async {
    final offer = _offer;
    if (offer == null) return;
    // It can be used once.
    web.window.setProperty(_installPrompt.toJS, null);
    canInstall = false;
    offer.callMethod<JSAny?>('prompt'.toJS);
  }

  @override
  void dispose() {
    _firstCheck?.cancel();
    web.window.removeEventListener(_installChanged, _onInstallChanged);
    if (_onMessage != null) {
      web.window.navigator.serviceWorker.removeEventListener(
        'message',
        _onMessage,
      );
    }
    if (_onVisible != null) {
      web.document.removeEventListener('visibilitychange', _onVisible);
    }
    super.dispose();
  }
}
