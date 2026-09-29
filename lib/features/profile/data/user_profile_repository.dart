import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_provider.dart';
import '../domain/user_profile.dart';
import 'user_profile_firestore.dart';

/// Reads and writes `users/{uid}` profiles.
class UserProfileRepository {
  UserProfileRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<UserProfile> get _users => usersCollection(_db);

  Future<void> createProfile(UserProfile profile) =>
      _users.doc(profile.uid).set(profile);

  /// Creates the profile if it's missing, e.g. because the network dropped
  /// right after sign-up. Does nothing if it already exists.
  Future<void> ensureProfile(UserProfile profile) async {
    final existing = await _users.doc(profile.uid).get();
    if (!existing.exists) await createProfile(profile);
  }

  /// Renames the user, creating their profile first if needed.
  Future<void> saveDisplayName({
    required String uid,
    required String email,
    required String displayName,
  }) async {
    final doc = _users.doc(uid);
    if (!(await doc.get()).exists) {
      return createProfile(
        UserProfile(uid: uid, displayName: displayName, email: email),
      );
    }
    await doc.update({
      'displayName': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// The profile, or null if it doesn't exist (yet).
  Stream<UserProfile?> watchProfile(String uid) =>
      _users.doc(uid).snapshots().map((snapshot) => snapshot.data());
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(firestoreProvider)),
);
