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
      ),
    );
  }

  @override
  Future<void> signOut() async => emit(null);
}
