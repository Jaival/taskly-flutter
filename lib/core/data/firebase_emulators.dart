import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
Future<void> connectToFirebaseEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
}
