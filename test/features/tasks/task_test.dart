import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/data/task_firestore.dart';
import 'package:taskly/features/tasks/domain/checklist_item.dart';
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

  test('due dates round-trip as the same calendar day', () async {
    final ref = personalTasksCollection(db).doc('t1');
    await ref.set(task.copyWith(dueDate: () => DateTime(2026, 10, 1, 23, 59)));

    expect((await ref.get()).data()!.dueDate, DateTime(2026, 10, 1));
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

  test('a checklist round-trips in order', () async {
    final ref = personalTasksCollection(db).doc('t1');
    final checklist = [
      const ChecklistItem('Draft', done: true),
      const ChecklistItem('Review'),
    ];
    await ref.set(task.copyWith(checklist: checklist));

    final saved = (await ref.get()).data()!;
    expect(saved.checklist, checklist);
    expect(saved.checklistDone, 1);
  });

  test('a malformed checklist reads as what can be saved of it', () async {
    await db.doc('tasks/t1').set({
      'ownerId': 'alice',
      'title': 'x',
      'checklist': [
        'not a map',
        {'text': 'Kept', 'done': 'yes'},
        {'done': true},
      ],
    });
    final saved = (await personalTasksCollection(db).doc('t1').get()).data()!;
    expect(saved.checklist, [
      const ChecklistItem('Kept'),
      const ChecklistItem('', done: true),
    ]);

    await db.doc('tasks/t2').set({'ownerId': 'alice', 'title': 'y'});
    final old = (await personalTasksCollection(db).doc('t2').get()).data()!;
    expect(old.checklist, isEmpty);
  });
}
