import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/data/firebase_emulators.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/projects instead of /#/projects).
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useFirebaseEmulators) await connectToFirebaseEmulators();
  // Wait for any saved session to be restored, so the first route is resolved
  // with the correct signed-in state instead of flashing the login page.
  await FirebaseAuth.instance.authStateChanges().first;

  runApp(const ProviderScope(child: TasklyApp()));
}
