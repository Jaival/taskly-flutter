import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../domain/user_profile.dart';

/// The `users` collection, keyed by user ID, typed as [UserProfile]s.
CollectionReference<UserProfile> usersCollection(FirebaseFirestore db) => db
    .collection('users')
    .withConverter(
      fromFirestore: userProfileFromFirestore,
      toFirestore: userProfileToFirestore,
    );

UserProfile userProfileFromFirestore(
  DocumentSnapshot<Map<String, Object?>> snapshot,
  SnapshotOptions? _,
) {
  final data = snapshot.data() ?? const {};
  return UserProfile(
    uid: snapshot.id,
    displayName: data.string('displayName'),
    email: data.string('email'),
    photoUrl: data.stringOrNull('photoUrl'),
    createdAt: data.dateTime('createdAt'),
  );
}

Map<String, Object?> userProfileToFirestore(
  UserProfile profile,
  SetOptions? _,
) => {
  'displayName': profile.displayName,
  'email': profile.email,
  'photoUrl': profile.photoUrl,
  'createdAt': createdAtValue(profile.createdAt),
  'updatedAt': FieldValue.serverTimestamp(),
};
