import 'package:flutter/foundation.dart';

/// Public profile of a user, stored at `users/{uid}`.
///
/// Other members of your projects read this to show your name and avatar.
/// It's separate from `AppUser`, which is the sign-in identity.
@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final DateTime? createdAt;

  UserProfile copyWith({String? displayName, ValueGetter<String?>? photoUrl}) =>
      UserProfile(
        uid: uid,
        displayName: displayName ?? this.displayName,
        email: email,
        photoUrl: photoUrl != null ? photoUrl() : this.photoUrl,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.email == email &&
      other.photoUrl == photoUrl &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(uid, displayName, email, photoUrl, createdAt);

  @override
  String toString() => 'UserProfile($uid, $displayName)';
}
