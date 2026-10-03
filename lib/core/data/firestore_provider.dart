import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Firestore instance every repository uses. Tests override it with
/// `FakeFirebaseFirestore`.
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Keeps a copy of the data on the device, so the app opens and can be used
/// without a connection. Phones do this anyway; browsers have to be asked,
/// and told to share the copy between tabs.
///
/// Must run before anything else uses Firestore.
void keepDataOnDevice() {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );
}
