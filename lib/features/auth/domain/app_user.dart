import 'package:flutter/foundation.dart';

/// The signed-in user, independent of the auth provider.
@immutable
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.emailVerified = false,
    this.hasPassword = true,
  });

  final String uid;
  final String? email;
  final String? displayName;

  /// Whether the user has clicked the link in the verification email.
  /// Needed to accept project invites.
  final bool emailVerified;

  /// False for someone who only signs in with Google: there's no password
  /// to change, or to ask for before deleting the account.
  final bool hasPassword;

  /// The first word of the display name, for greetings. Null if unnamed.
  String? get firstName {
    final name = displayName?.trim() ?? '';
    return name.isEmpty ? null : name.split(RegExp(r'\s+')).first;
  }

  /// Up to two initials for avatars, falling back to the email.
  String get initials {
    final source = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email ?? '?');
    final parts = source.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.emailVerified == emailVerified &&
      other.hasPassword == hasPassword;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, emailVerified, hasPassword);
}
