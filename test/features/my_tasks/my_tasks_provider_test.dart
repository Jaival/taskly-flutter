import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/data/firestore_provider.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/my_tasks/data/my_tasks_provider.dart';
import 'package:taskly/features/my_tasks/domain/my_task.dart';
import 'package:taskly/features/my_tasks/domain/task_filter.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FakeAuthRepository auth;
  late ProviderContainer container;

  Future<void> seedProject(String id, List<String> members) =>
      db.doc('projects/$id').set({
        'ownerId': members.first,
        'name': 'Project $id',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'memberIds': members,
        'roles': {for (final uid in members) uid: 'editor'},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  Future<void> seedTask(String path, {String owner = 'ada', String? to}) =>
      db.doc(path).set({
        'ownerId': owner,
        'title': path,
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'assigneeId': to,
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  setUp(() {
    db = FakeFirebaseFirestore();
    auth = FakeAuthRepository(currentUser: const AppUser(uid: 'ada'));
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<List<MyTask>> myTasks() async {
    container.listen(myTasksProvider, (_, _) {});
    await pumpEventQueue();
    return container.read(myTasksProvider).requireValue;
  }

  test('personal tasks, then project tasks assigned to the user', () async {
    await seedProject('p1', ['bob', 'ada']);
    await seedTask('tasks/mine');
    await seedTask('tasks/bobs', owner: 'bob');
    await seedTask('projects/p1/tasks/for-ada', owner: 'bob', to: 'ada');
    await seedTask('projects/p1/tasks/for-bob', owner: 'bob', to: 'bob');
    await seedTask('projects/p1/tasks/nobody', owner: 'bob');
    // Assigned to her, but she isn't in p2.
    await seedProject('p2', ['bob']);
    await seedTask('projects/p2/tasks/other', owner: 'bob', to: 'ada');

    final items = await myTasks();

    expect(
      [for (final item in items) item.task.title],
      ['tasks/mine', 'projects/p1/tasks/for-ada'],
    );
    expect(items.first.project, isNull);
    expect(items.last.project?.name, 'Project p1');
  });

  test('a task assigned later shows up', () async {
    await seedProject('p1', ['bob', 'ada']);
    await seedTask('projects/p1/tasks/t', owner: 'bob');
    expect(await myTasks(), isEmpty);

    await db.doc('projects/p1/tasks/t').update({'assigneeId': 'ada'});

    expect(await myTasks(), hasLength(1));
  });

  test('the filter starts empty, and resets for the next user', () async {
    container.listen(taskFilterProvider, (_, _) {});
    container
        .read(taskFilterProvider.notifier)
        .change(const TaskFilter(query: 'milk'));
    expect(container.read(taskFilterProvider).query, 'milk');

    auth.emit(const AppUser(uid: 'bob'));
    await pumpEventQueue();

    expect(container.read(taskFilterProvider), const TaskFilter());
  });
}
