import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/data/firestore_provider.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/my_tasks/data/my_tasks_provider.dart';
import 'package:taskly/features/my_tasks/domain/my_task.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/projects/domain/project.dart';

import '../../helpers/fake_auth_repository.dart';

const _ada = AppUser(uid: 'ada', email: 'ada@example.com');

/// Like the real thing, says who is signed in a little after being asked:
/// the answer comes from the platform.
class _SlowAuth extends FakeAuthRepository {
  _SlowAuth({super.currentUser});

  @override
  Stream<AppUser?> userChanges() async* {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    yield* super.userChanges();
  }
}

/// Long enough for [_SlowAuth] to speak and the data to arrive.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  late FakeFirebaseFirestore db;
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = _SlowAuth(currentUser: _ada);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
  });

  test('the user is known before the auth stream has said anything', () {
    expect(container.read(authStateProvider).isLoading, isTrue);

    expect(container.read(currentUserProvider), _ada);
  });

  test('follows signing out and in', () async {
    container.listen(currentUserProvider, (_, _) {});
    await _settle();

    auth.emit(null);
    await _settle();
    expect(container.read(currentUserProvider), isNull);

    auth.emit(const AppUser(uid: 'bob'));
    await _settle();
    expect(container.read(currentUserProvider)?.uid, 'bob');
  });

  // When the app starts, the saved session is already there. Lists must
  // wait for that user's data, not show "nothing yet" for a moment first.
  group('at startup, nothing is reported as empty before it has loaded', () {
    setUp(() async {
      await db.doc('projects/p1').set({
        'ownerId': 'ada',
        'name': 'Launch',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'memberIds': ['ada'],
        'roles': {'ada': 'owner'},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await db.doc('tasks/t1').set({
        'ownerId': 'ada',
        'title': 'Buy milk',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    });

    test('projects', () async {
      final seen = <AsyncValue<List<Project>>>[];
      container.listen(
        projectsProvider,
        (_, state) => seen.add(state),
        fireImmediately: true,
      );
      await _settle();

      final lists = [for (final state in seen) ?state.value];
      expect(lists, isNotEmpty);
      expect(lists.every((projects) => projects.length == 1), isTrue);
    });

    test('tasks', () async {
      final seen = <AsyncValue<List<MyTask>>>[];
      container.listen(
        myTasksProvider,
        (_, state) => seen.add(state),
        fireImmediately: true,
      );
      await _settle();

      final lists = [for (final state in seen) ?state.value];
      expect(lists, isNotEmpty);
      expect(lists.every((tasks) => tasks.length == 1), isTrue);
    });
  });
}
