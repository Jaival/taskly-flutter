import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/data/task_firestore.dart';
import 'package:taskly/features/tasks/domain/task.dart';

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  const task = Task(
    id: 't1',
    ownerId: 'alice',
    title: 'Write copy',
    priority: Priority.immediate,
    assigneeId: 'bob',
    order: 1.5,
  );

  test('a project task gets its projectId from the path', () async {
    final ref = projectTasksCollection(db, 'p1').doc('t1');
    await ref.set(task);

    final saved = (await ref.get()).data()!;
    expect(saved.projectId, 'p1');
    expect(saved.isPersonal, isFalse);
    expect(saved.title, 'Write copy');
    expect(saved.priority, Priority.immediate);
    expect(saved.assigneeId, 'bob');
    expect(saved.order, 1.5);

    final raw = (await db.doc('projects/p1/tasks/t1').get()).data()!;
    expect(raw.containsKey('projectId'), isFalse);
  });

  test('a personal task has no projectId', () async {
    final ref = personalTasksCollection(db).doc('t1');
    await ref.set(task);

    final saved = (await ref.get()).data()!;
    expect(saved.projectId, isNull);
    expect(saved.isPersonal, isTrue);
  });

  test('due dates round-trip', () async {
    final due = DateTime.utc(2026, 10, 1, 9);
    final ref = personalTasksCollection(db).doc('t1');
    await ref.set(task.copyWith(dueDate: () => due));

    expect((await ref.get()).data()!.dueDate!.toUtc(), due);
  });

  test('copyWith can clear nullable fields', () {
    final unassigned = task.copyWith(assigneeId: () => null);
    expect(unassigned.assigneeId, isNull);
    expect(task.copyWith(title: 'x').assigneeId, 'bob');
  });

  test('isComplete follows status', () {
    expect(task.isComplete, isFalse);
    expect(task.copyWith(status: TaskStatus.complete).isComplete, isTrue);
  });

  test('integer order values read as doubles', () async {
    await db.doc('tasks/t2').set({'title': 'x', 'order': 3});
    final saved = (await personalTasksCollection(db).doc('t2').get()).data()!;
    expect(saved.order, 3.0);
  });
}
