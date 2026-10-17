import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Marks that the page was reloaded once to get Auth onto the emulator, so it
/// isn't reloaded again and again.
const _reloadedKey = 'taskly.authEmulatorReload';

/// Whether the browser's Auth really talks to the emulator. FlutterFire keeps
/// the Firebase Auth module on `globalThis.firebase_auth`.
bool authUsesEmulator() {
  final module = globalContext.getProperty<JSObject?>('firebase_auth'.toJS);
  if (module == null) return false;
  final auth = module.callMethod<JSObject>('getAuth'.toJS);
  return auth.getProperty<JSAny?>('emulatorConfig'.toJS) != null;
}

/// Reloads the page, unless it has already been reloaded for this. Returns
/// whether it is reloading.
bool reloadForEmulatorOnce() {
  final storage = web.window.sessionStorage;
  if (storage.getItem(_reloadedKey) != null) return false;
  storage.setItem(_reloadedKey, 'yes');
  web.window.location.reload();
  return true;
}

/// Forgets the reload, once Auth is on the emulator.
void emulatorReached() => web.window.sessionStorage.removeItem(_reloadedKey);
