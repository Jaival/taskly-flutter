import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import 'auth_failures.dart';

/// Everything the app does with Firebase Auth. Methods throw [AuthFailure],
/// never Firebase's own exceptions.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// Emits on sign-in and sign-out, and also when the user's details change
  /// (display name, email verified after [reloadUser]).
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toAppUser);

  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toAppUser(credential.user)!;
      });

  /// Creates the account, sets its display name and sends a verification
  /// email. The user is signed in when this returns.
  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    await user.updateDisplayName(displayName.trim());
    await user.sendEmailVerification();
    // The display name isn't on `user` until it's reloaded.
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: displayName.trim(),
    );
  });

  /// Always succeeds for well-formed emails, even without an account, so the
  /// response can't reveal who has signed up.
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  Future<void> sendEmailVerification() => _guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });

  /// Fetches the latest account details, e.g. after the user clicked the
  /// verification link in another tab. Also refreshes the ID token, so
  /// security rules see `email_verified` straight away.
  Future<void> reloadUser() => _guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    await _auth.currentUser?.getIdToken(true);
  });

  Future<void> updateDisplayName(String displayName) => _guard(() async {
    await _auth.currentUser?.updateDisplayName(displayName.trim());
  });

  /// Sets a new password, after checking [currentPassword].
  ///
  /// Firebase only changes a password soon after a sign-in, and checking the
  /// current one counts as that. It also means someone at an unlocked laptop
  /// can't lock the owner out of their account.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) => _guard(() async {
    final user = await _reauthenticate(currentPassword);
    await user.updatePassword(newPassword);
  });

  /// Checks [password] is the current user's. Call it before
  /// [deleteAccount], which Firebase only allows soon after a sign-in.
  Future<void> reauthenticate(String password) =>
      _guard(() => _reauthenticate(password));

  /// Deletes the account and signs out. Its data in Firestore has to be
  /// deleted first, while there's still a user to delete it as.
  Future<void> deleteAccount() => _guard(() async {
    await _auth.currentUser?.delete();
  });

  Future<void> signOut() => _auth.signOut();

  /// Signs the current user in again with [password], which Firebase wants
  /// before anything security-sensitive.
  Future<User> _reauthenticate(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw authFailureFromCode('requires-recent-login');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      // "Email or password is incorrect" would be confusing here: there's
      // no email to get wrong.
      if (const {
        'invalid-credential',
        'wrong-password',
        'INVALID_LOGIN_CREDENTIALS',
      }.contains(e.code)) {
        throw const AuthFailure('Your current password is incorrect.');
      }
      rethrow;
    }
    return user;
  }

  static Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw authFailureFromCode(e.code);
    }
  }

  static AppUser? _toAppUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          emailVerified: user.emailVerified,
        );
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).userChanges(),
);
