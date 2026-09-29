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

  /// The profile, or null if it doesn't exist (yet).
  Stream<UserProfile?> watchProfile(String uid) =>
      _users.doc(uid).snapshots().map((snapshot) => snapshot.data());

  Future<UserProfile?> fetchProfile(String uid) async =>
      (await _users.doc(uid).get()).data();
}

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => UserProfileRepository(ref.watch(firestoreProvider)),
);
