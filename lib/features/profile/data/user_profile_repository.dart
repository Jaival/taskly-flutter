import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/connection.dart';
import '../../../core/data/firestore_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/user_profile.dart';
import 'user_profile_firestore.dart';

/// Reads and writes `users/{uid}` profiles.
class UserProfileRepository {
  UserProfileRepository(this._db, {this._saved = untilSent});

  final FirebaseFirestore _db;

  /// How long to wait for a write: not at all while offline, in the app.
  final AwaitWrite _saved;

  CollectionReference<UserProfile> get _users => usersCollection(_db);

  Future<void> createProfile(UserProfile profile) =>
      _saved(_users.doc(profile.uid).set(profile));

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
    await _saved(
      doc.update({
        'displayName': displayName,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  Future<void> deleteProfile(String uid) => _saved(_users.doc(uid).delete());

  /// The profile, or null if it doesn't exist (yet).
  Stream<UserProfile?> watchProfile(String uid) =>
      _users.doc(uid).snapshots().map((snapshot) => snapshot.data());
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(
    ref.watch(firestoreProvider),
    saved: ref.watch(connectionProvider).sentOrQueued,
  ),
);

/// Anyone's public profile, e.g. to show a teammate's name. Null if they
/// have none. Restarted when the signed-in user changes, since signing out
/// kills the listener.
final userProfileProvider = StreamProvider.autoDispose
    .family<UserProfile?, String>((ref, uid) {
      ref.watch(currentUserProvider.select((user) => user?.uid));
      return ref.watch(userProfileRepositoryProvider).watchProfile(uid);
    });
