import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_emulator_check_none.dart'
    if (dart.library.js_interop) 'auth_emulator_check_browser.dart';

/// Whether to use the local Firebase Emulator Suite instead of the real
/// project. Turn on with `--dart-define=USE_FIREBASE_EMULATORS=true`.
const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

/// Where the emulators run. Defaults to this machine. On the Android emulator,
/// FlutterFire maps `localhost` to `10.0.2.2`, which is the host computer.
/// For a physical phone, pass your computer's LAN IP with
/// `--dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x`.
const _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);

/// Points Auth and Firestore at the emulators. Must run before anything else
/// uses Firebase. Ports match `firebase.json`.
///
/// In a browser, a session saved by an earlier run (say, before the
/// emulators were restarted and lost their accounts) makes Auth refresh it
/// with the real project as the app starts. After that, Firebase won't
/// point Auth at the emulator, and FlutterFire hides the error, so the app
/// would sign in to the real project while its data stays on the emulator.
/// So this checks, and if Auth isn't on the emulator it forgets the saved
/// session and reloads the page, once. If that doesn't do it either, the app
/// stops rather than use the real project.
Future<void> connectToFirebaseEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  if (authUsesEmulator()) {
    emulatorReached();
    return;
  }
  // Signing out only clears what's saved on the device: no request.
  await FirebaseAuth.instance.signOut();
  // The page is going away: start nothing more meanwhile.
  if (reloadForEmulatorOnce()) return Completer<void>().future;
  throw StateError(
    "Auth isn't using the emulator, so the app won't start: it would talk "
    'to the real Firebase project. Clear the site data and reload.',
  );
}
