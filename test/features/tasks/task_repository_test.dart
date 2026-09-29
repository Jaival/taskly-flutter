import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TaskRepository repository;
  var now = DateTime(2026, 9, 1);

  setUp(() {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 9, 1);
    repository = TaskRepository(db, clock: () => now);
  });

  test(
    'a personal task is stored under tasks/, owned by its creator',
    () async {
      final id = await repository.createTask(
        ownerId: 'alice',
        title: '  Buy milk ',
        priority: Priority.low,
      );

      final saved = (await db.doc('tasks/$id').get()).data()!;
      expect(saved['ownerId'], 'alice');
      expect(saved['title'], 'Buy milk');
      expect(saved['priority'], 'low');
      expect(saved['status'], 'notStarted');
      // Never the string "null", as v1 saved from empty dropdowns.
      expect(saved['assigneeId'], isNull);
    },
  );

  test('lists only your personal tasks, oldest first', () async {
    Future<void> add(String owner, String title) async {
      await repository.createTask(ownerId: owner, title: title);
      now = now.add(const Duration(minutes: 1));
    }

    await add('alice', 'first');
    await add('bob', "bob's");
    await add('alice', 'second');

    final tasks = await repository.watchPersonalTasks('alice').first;
    expect([for (final t in tasks) t.title], ['first', 'second']);
    expect(tasks.every((t) => t.isPersonal), isTrue);
  });

  test('a project task lives in its project and knows it', () async {
    final id = await repository.createTask(
      projectId: 'p1',
      ownerId: 'alice',
      title: 'Write copy',
    );

    expect((await db.doc('projects/p1/tasks/$id').get()).exists, isTrue);
    final tasks = await repository.watchProjectTasks('p1').first;
    expect(tasks.single.projectId, 'p1');
    expect(tasks.single.id, id);
  });

  test('editing details keeps the assignee someone else set', () async {
    await repository.createTask(projectId: 'p1', ownerId: 'alice', title: 'x');
    final task = (await repository.watchProjectTasks('p1').first).single;
    await db.doc('projects/p1/tasks/${task.id}').update({'assigneeId': 'bob'});

    await repository.updateDetails(
      task,
      title: 'Renamed',
      description: 'More detail',
      priority: Priority.immediate,
      status: TaskStatus.inProgress,
    );

    final saved = (await repository.watchProjectTasks('p1').first).single;
    expect(saved.title, 'Renamed');
    expect(saved.description, 'More detail');
    expect(saved.priority, Priority.immediate);
    expect(saved.status, TaskStatus.inProgress);
    expect(saved.assigneeId, 'bob');
  });

  test('setStatus changes only the status and updatedAt', () async {
    await repository.createTask(ownerId: 'alice', title: 'x');
    final task = (await repository.watchPersonalTasks('alice').first).single;
    final before = (await db.doc('tasks/${task.id}').get()).data()!;

    await repository.setStatus(task, TaskStatus.complete);

    final after = (await db.doc('tasks/${task.id}').get()).data()!;
    final changed = {
      for (final key in after.keys)
        if (after[key] != before[key]) key,
    };
    expect(after['status'], 'complete');
    expect(changed, contains('status'));
    expect(changed.difference({'status', 'updatedAt'}), isEmpty);
    expect(after['updatedAt'], isA<Timestamp>());
  });

  test('deleteTask deletes the right document', () async {
    await repository.createTask(ownerId: 'alice', title: 'personal');
    await repository.createTask(projectId: 'p1', ownerId: 'alice', title: 'p');
    final task = (await repository.watchProjectTasks('p1').first).single;

    await repository.deleteTask(task);

    expect(await repository.watchProjectTasks('p1').first, isEmpty);
    expect(await repository.watchPersonalTasks('alice').first, hasLength(1));
  });
}
