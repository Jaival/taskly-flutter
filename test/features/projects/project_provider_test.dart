import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/projects/domain/project.dart';

import '../../helpers/fake_auth_repository.dart';

/// Behaves like Firestore under the security rules: a non-member's listener
/// fails with "permission denied" and then stays dead.
class _RulesLikeRepository extends ProjectRepository {
  _RulesLikeRepository(this._auth) : super(FakeFirebaseFirestore());

  final FakeAuthRepository _auth;
  final members = <String>{'bob'};
  final _changes = StreamController<void>.broadcast();

  Project get _project => Project(
    id: 'p1',
    ownerId: 'bob',
    name: 'Launch',
    memberIds: members.toList(),
    roles: {for (final uid in members) uid: ProjectRole.editor},
  );

  void join(String uid) {
    members.add(uid);
    _changes.add(null);
  }

  @override
  Stream<List<Project>> watchProjects(String uid) async* {
    yield members.contains(uid) ? [_project] : [];
    await for (final _ in _changes.stream) {
      yield members.contains(uid) ? [_project] : [];
    }
  }

  @override
  Stream<Project?> watchProject(String id) =>
      members.contains(_auth.currentUser?.uid)
      ? Stream.value(_project)
      : Stream.error(
          FirebaseException(plugin: 'firestore', code: 'permission-denied'),
        );
}

void main() {
  late FakeAuthRepository auth;
  late _RulesLikeRepository repository;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository(currentUser: const AppUser(uid: 'ada'));
    repository = _RulesLikeRepository(auth);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        projectRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<Project?> watchedProject() async {
    await pumpEventQueue();
    return container.read(projectProvider('p1')).value;
  }

  test('switching to an account that is a member finds the project', () async {
    container.listen(projectProvider('p1'), (_, _) {});
    expect(await watchedProject(), isNull);

    auth.emit(const AppUser(uid: 'bob'));

    expect((await watchedProject())?.name, 'Launch');
  });

  test('joining a project that showed "not found" finds it', () async {
    container
      ..listen(projectsProvider, (_, _) {})
      ..listen(projectProvider('p1'), (_, _) {});
    expect(await watchedProject(), isNull);

    repository.join('ada');

    expect((await watchedProject())?.name, 'Launch');
  });
}
