import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';
import 'package:taskly/features/tasks/domain/checklist_item.dart';
import 'package:taskly/features/tasks/domain/task.dart';

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
      dueDate: null,
    );

    final saved = (await repository.watchProjectTasks('p1').first).single;
    expect(saved.title, 'Renamed');
    expect(saved.description, 'More detail');
    expect(saved.priority, Priority.immediate);
    expect(saved.status, TaskStatus.inProgress);
    expect(saved.assigneeId, 'bob');
  });

  test('setStatus changes only the status and its times', () async {
    await repository.createTask(ownerId: 'alice', title: 'x');
    final task = (await repository.watchPersonalTasks('alice').first).single;
    final before = (await db.doc('tasks/${task.id}').get()).data()!;

    await repository.setStatus(task, TaskStatus.complete);

    final after = (await db.doc('tasks/${task.id}').get()).data()!;
    final changed = {
      for (final key in after.keys)
        // equals() compares lists and maps by content.
        if (!equals(before[key]).matches(after[key], {})) key,
    };
    expect(after['status'], 'complete');
    expect(changed, contains('status'));
    expect(changed.difference({'status', 'completedAt', 'updatedAt'}), isEmpty);
    expect(after['updatedAt'], isA<Timestamp>());
  });

  group('the completion time', () {
    Future<Task> onlyTask() async =>
        (await repository.watchPersonalTasks('alice').first).single;

    Future<void> edit(Task task, {required TaskStatus status}) =>
        repository.updateDetails(
          task,
          title: 'Renamed',
          description: '',
          priority: Priority.medium,
          status: status,
          dueDate: null,
        );

    test('is set on completing, and cleared on reopening', () async {
      await repository.createTask(ownerId: 'alice', title: 'x');
      expect((await onlyTask()).completedAt, isNull);

      await repository.setStatus(await onlyTask(), TaskStatus.complete);
      expect((await onlyTask()).completedAt, isNotNull);

      await repository.setStatus(await onlyTask(), TaskStatus.inProgress);
      final saved = (await db.collection('tasks').get()).docs.single.data();
      // Null, not missing: the rules want it cleared.
      expect(saved, containsPair('completedAt', null));
    });

    test('follows the status chosen in the form', () async {
      await repository.createTask(ownerId: 'alice', title: 'x');

      await edit(await onlyTask(), status: TaskStatus.complete);
      expect((await onlyTask()).completedAt, isNotNull);

      await edit(await onlyTask(), status: TaskStatus.notStarted);
      expect((await onlyTask()).completedAt, isNull);
    });

    test('stays when a done task is edited or completed again', () async {
      final completedAt = Timestamp.fromDate(DateTime(2026, 8, 20, 9));
      await db.doc('tasks/t1').set({
        'ownerId': 'alice',
        'title': 'x',
        'status': 'complete',
        'completedAt': completedAt,
        'order': 1,
      });

      await edit(await onlyTask(), status: TaskStatus.complete);
      await repository.setStatus(await onlyTask(), TaskStatus.complete);

      final saved = (await db.doc('tasks/t1').get()).data()!;
      expect(saved['title'], 'Renamed');
      expect(saved['completedAt'], completedAt);
    });
  });

  test('deleteTask deletes the right document', () async {
    await repository.createTask(ownerId: 'alice', title: 'personal');
    await repository.createTask(projectId: 'p1', ownerId: 'alice', title: 'p');
    final task = (await repository.watchProjectTasks('p1').first).single;

    await repository.deleteTask(task);

    expect(await repository.watchProjectTasks('p1').first, isEmpty);
    expect(await repository.watchPersonalTasks('alice').first, hasLength(1));
  });

  test('a project task can be assigned, reassigned and unassigned', () async {
    await repository.createTask(
      projectId: 'p1',
      ownerId: 'alice',
      title: 'x',
      assigneeId: 'bob',
    );
    Future<String?> assignee() async =>
        (await repository.watchProjectTasks('p1').first).single.assigneeId;
    expect(await assignee(), 'bob');

    Future<void> assign(String? uid) async => repository.updateDetails(
      (await repository.watchProjectTasks('p1').first).single,
      title: 'x',
      description: '',
      priority: Priority.medium,
      status: TaskStatus.notStarted,
      dueDate: null,
      assigneeId: () => uid,
    );
    await assign('carol');
    expect(await assignee(), 'carol');
    await assign(null);
    expect(await assignee(), isNull);
  });

  test('a due date is set, changed and cleared as a whole day', () async {
    await repository.createTask(
      ownerId: 'alice',
      title: 'x',
      dueDate: DateTime(2026, 9, 3, 18, 30),
    );
    Future<DateTime?> due() async =>
        (await repository.watchPersonalTasks('alice').first).single.dueDate;
    Future<Object?> stored() async =>
        (await db.collection('tasks').get()).docs.single.data()['dueDate'];
    expect(await due(), DateTime(2026, 9, 3));
    expect(await stored(), Timestamp.fromDate(DateTime.utc(2026, 9, 3)));

    Future<void> setDue(DateTime? date) async => repository.updateDetails(
      (await repository.watchPersonalTasks('alice').first).single,
      title: 'x',
      description: '',
      priority: Priority.medium,
      status: TaskStatus.notStarted,
      dueDate: date,
    );
    await setDue(DateTime(2026, 12, 25));
    expect(await due(), DateTime(2026, 12, 25));
    await setDue(null);
    expect(await due(), isNull);
  });

  test('a checklist is saved trimmed, without blank items', () async {
    await repository.createTask(
      ownerId: 'alice',
      title: 'x',
      checklist: const [
        ChecklistItem('  Draft '),
        ChecklistItem('   '),
        ChecklistItem('Review', done: true),
      ],
    );
    final task = (await repository.watchPersonalTasks('alice').first).single;
    expect(task.checklist, const [
      ChecklistItem('Draft'),
      ChecklistItem('Review', done: true),
    ]);

    await repository.updateDetails(
      task,
      title: 'x',
      description: '',
      priority: Priority.medium,
      status: TaskStatus.notStarted,
      dueDate: null,
      checklist: const [ChecklistItem('Draft', done: true)],
    );
    final saved = (await repository.watchPersonalTasks('alice').first).single;
    expect(saved.checklist, const [ChecklistItem('Draft', done: true)]);
  });
}
