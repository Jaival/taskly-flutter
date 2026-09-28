import 'dart:async';

import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.currentUser});

  @override
  AppUser? currentUser;

  final _changes = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    yield* _changes.stream;
  }

  @override
  Future<void> signOut() async => emit(null);

  void emit(AppUser? user) {
    currentUser = user;
    _changes.add(user);
  }
}
