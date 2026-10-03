import 'dart:async';

import 'package:taskly/features/auth/data/auth_failures.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/auth/domain/auth_failure.dart';

/// In-memory auth with a handful of accounts, for widget tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser});

  @override
  AppUser? currentUser;

  final _changes = StreamController<AppUser?>.broadcast();
  final _accounts = <String, ({AppUser user, String password})>{};

  /// Emails a verification link was sent to, in order.
  final verificationEmailsSent = <String>[];

  /// Emails a password reset link was sent to, in order.
  final passwordResetsSent = <String>[];

  /// The signed-in user's password, unless [addAccount] gave them another.
  static const defaultPassword = 'old-password';

  /// The signed-in user's password, once it's been changed.
  String? changedPassword;

  String get _currentPassword =>
      changedPassword ??
      _accounts[currentUser?.email]?.password ??
      defaultPassword;

  /// If set, the next call throws this instead of doing anything.
  AuthFailure? failNextWith;

  /// What [reloadUser] does: pretend the user clicked the link meanwhile.
  bool verifiedOnReload = false;

  void addAccount(AppUser user, {required String password}) =>
      _accounts[user.email!] = (user: user, password: password);

  void emit(AppUser? user) {
    currentUser = user;
    _changes.add(user);
  }

  void _maybeFail() {
    if (failNextWith case final failure?) {
      failNextWith = null;
      throw failure;
    }
  }

  @override
  Stream<AppUser?> userChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    _maybeFail();
    final account = _accounts[email.trim()];
    if (account == null || account.password != password) {
      throw authFailureFromCode('invalid-credential');
    }
    emit(account.user);
    return account.user;
  }

  @override
  Future<AppUser> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    _maybeFail();
    if (_accounts.containsKey(email.trim())) {
      throw authFailureFromCode('email-already-in-use');
    }
    final user = AppUser(
      uid: 'uid-${_accounts.length + 1}',
      email: email.trim(),
      displayName: displayName.trim(),
    );
    addAccount(user, password: password);
    verificationEmailsSent.add(user.email!);
    emit(user);
    return user;
  }

  /// Who [signInWithGoogle] signs in. Null as if they closed the window.
  AppUser? googleUser;

  @override
  bool supportsGoogleSignIn = true;

  @override
  Future<AppUser?> signInWithGoogle() async {
    _maybeFail();
    if (googleUser case final user?) emit(user);
    return googleUser;
  }

  /// How often [reauthenticateWithGoogle] was called.
  int googleReauthentications = 0;

  @override
  Future<void> reauthenticateWithGoogle() async {
    _maybeFail();
    googleReauthentications++;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _maybeFail();
    passwordResetsSent.add(email.trim());
  }

  @override
  Future<void> sendEmailVerification() async {
    _maybeFail();
    verificationEmailsSent.add(currentUser!.email!);
  }

  @override
  Future<void> reloadUser() async {
    _maybeFail();
    final user = currentUser;
    if (user != null && verifiedOnReload) {
      emit(
        AppUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          emailVerified: true,
          hasPassword: user.hasPassword,
        ),
      );
    }
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    _maybeFail();
    final user = currentUser!;
    emit(
      AppUser(
        uid: user.uid,
        email: user.email,
        displayName: displayName.trim(),
        emailVerified: user.emailVerified,
        hasPassword: user.hasPassword,
      ),
    );
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _maybeFail();
    if (currentPassword != _currentPassword) {
      throw const AuthFailure('Your current password is incorrect.');
    }
    changedPassword = newPassword;
  }

  /// Whether [deleteAccount] has succeeded.
  bool accountDeleted = false;

  /// Makes [deleteAccount] fail, as if the connection had dropped.
  bool failAccountDeletion = false;

  @override
  Future<void> reauthenticate(String password) async {
    _maybeFail();
    if (password != _currentPassword) {
      throw const AuthFailure('Your current password is incorrect.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    _maybeFail();
    if (failAccountDeletion) {
      throw authFailureFromCode('network-request-failed');
    }
    accountDeleted = true;
    _accounts.remove(currentUser?.email);
    emit(null);
  }

  @override
  Future<void> signOut() async => emit(null);
}
