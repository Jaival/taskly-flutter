import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';
import 'package:taskly/features/tasks/domain/checklist_item.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/domain/task_repeat.dart';

void main() {
  group('the next date', () {
    final due = DateTime(2026, 10, 5); // a Monday

    test('one step after the due date, done on time', () {
      expect(TaskRepeat.daily.next(due, due), DateTime(2026, 10, 6));
      expect(TaskRepeat.weekly.next(due, due), DateTime(2026, 10, 12));
      expect(TaskRepeat.monthly.next(due, due), DateTime(2026, 11, 5));
    });

    test('done early: still a step after it was due', () {
      expect(
        TaskRepeat.weekly.next(due, DateTime(2026, 10, 3)),
        DateTime(2026, 10, 12),
      );
    });

    test('done late: the first date still to come, not a backlog', () {
      expect(
        TaskRepeat.daily.next(due, DateTime(2026, 10, 8, 23, 59)),
        DateTime(2026, 10, 9),
      );
      expect(
        TaskRepeat.weekly.next(due, DateTime(2026, 10, 20)),
        DateTime(2026, 10, 26),
      );
      // On a date of the schedule itself: the one after.
      expect(
        TaskRepeat.weekly.next(due, DateTime(2026, 10, 19)),
        DateTime(2026, 10, 26),
      );
    });

    test('monthly keeps the day, or the last day of a shorter month', () {
      final jan31 = DateTime(2027, 1, 31);
      expect(TaskRepeat.monthly.next(jan31, jan31), DateTime(2027, 2, 28));
      // Counted from the original date, so March gets the 31st back.
      expect(
        TaskRepeat.monthly.next(jan31, DateTime(2027, 3, 1)),
        DateTime(2027, 3, 31),
      );
      expect(
        TaskRepeat.monthly.next(DateTime(2027, 12, 15), DateTime(2027, 12, 15)),
        DateTime(2028, 1, 15),
      );
      expect(
        TaskRepeat.monthly.next(DateTime(2028, 1, 31), DateTime(2028, 1, 31)),
        DateTime(2028, 2, 29),
      );
    });

    test('daily counts calendar days across a clock change', () {
      // Clocks go back in much of Europe on 25 October 2026.
      final next = TaskRepeat.daily.next(
        DateTime(2026, 10, 25),
        DateTime(2026, 10, 25),
      );
      expect(next, DateTime(2026, 10, 26));
    });

    test('an unknown stored value means it does not repeat', () {
      expect(TaskRepeat.fromName('weekly'), TaskRepeat.weekly);
      expect(TaskRepeat.fromName('yearly'), isNull);
      expect(TaskRepeat.fromName(null), isNull);
    });
  });

  group('completing a task that repeats', () {
    late FakeFirebaseFirestore db;
    late TaskRepository repository;
    var now = DateTime(2026, 10, 5, 9);
    const carol = AppUser(uid: 'carol', email: 'carol@example.com');

    setUp(() {
      db = FakeFirebaseFirestore();
      now = DateTime(2026, 10, 5, 9);
      repository = TaskRepository(
        db,
        clock: () => now,
        currentUser: () => carol,
      );
    });

    Future<Task> create({TaskRepeat? repeat, DateTime? due}) async {
      await repository.createTask(
        projectId: 'p1',
        ownerId: 'alice',
        title: 'Send the report',
        description: 'To the team',
        priority: Priority.high,
        assigneeId: 'carol',
        dueDate: due ?? DateTime(2026, 10, 5),
        repeat: repeat,
        checklist: const [
          ChecklistItem('Draft', done: true),
          ChecklistItem('Check'),
        ],
      );
      // So the next one sorts after it.
      now = now.add(const Duration(minutes: 1));
      return (await repository.watchProjectTasks('p1').first).single;
    }

    Future<List<Task>> tasks() => repository.watchProjectTasks('p1').first;

    test('adds the next one, a fresh copy due a step later', () async {
      final task = await create(repeat: TaskRepeat.weekly);

      final nextDue = await repository.setStatus(task, TaskStatus.complete);

      expect(nextDue, DateTime(2026, 10, 12));
      final [done, next] = await tasks();
      expect(done.id, task.id);
      expect(done.isComplete, isTrue);
      expect(next.dueDate, DateTime(2026, 10, 12));
      expect(next.status, TaskStatus.notStarted);
      expect(next.title, 'Send the report');
      expect(next.description, 'To the team');
      expect(next.priority, Priority.high);
      expect(next.assigneeId, 'carol');
      expect(next.checklist, const [
        ChecklistItem('Draft'),
        ChecklistItem('Check'),
      ]);
      // Made by whoever ticked the last one off, as the rules require.
      expect(next.ownerId, 'carol');
      final stored = (await db.doc('projects/p1/tasks/${next.id}').get())
          .data()!;
      expect(stored['repeatedFrom'], task.id);
    });

    test('the schedule moves on to the next one', () async {
      final task = await create(repeat: TaskRepeat.daily);
      await repository.setStatus(task, TaskStatus.complete);

      final [done, next] = await tasks();
      expect(done.repeat, isNull);
      expect(next.repeat, TaskRepeat.daily);
      expect(next.repeats, isTrue);
    });

    test('reopening and completing it again adds no second one', () async {
      final task = await create(repeat: TaskRepeat.weekly);
      await repository.setStatus(task, TaskStatus.complete);
      final done = (await tasks()).first;

      await repository.setStatus(done, TaskStatus.notStarted);
      final again = await repository.setStatus(
        (await tasks()).first,
        TaskStatus.complete,
      );

      expect(again, isNull);
      expect(await tasks(), hasLength(2));
    });

    test(
      'nothing more without a schedule, a due date, or completion',
      () async {
        final once = await create();
        expect(await repository.setStatus(once, TaskStatus.complete), isNull);

        await db.doc('projects/p1/tasks/${once.id}').delete();
        final undated = (await create(repeat: TaskRepeat.weekly))
            .copyWith(dueDate: () => null);
        expect(
          await repository.setStatus(undated, TaskStatus.complete),
          isNull,
        );

        await db.doc('projects/p1/tasks/${undated.id}').delete();
        final started = await create(repeat: TaskRepeat.weekly);
        expect(
          await repository.setStatus(started, TaskStatus.inProgress),
          isNull,
        );
        expect(await tasks(), hasLength(1));
      },
    );

    test('completing it from the form adds the next one as edited', () async {
      final task = await create(repeat: TaskRepeat.weekly);

      final nextDue = await repository.updateDetails(
        task,
        title: 'Send the weekly report',
        description: 'To the team',
        priority: Priority.high,
        status: TaskStatus.complete,
        dueDate: DateTime(2026, 10, 6),
        repeat: () => TaskRepeat.monthly,
      );

      expect(nextDue, DateTime(2026, 11, 6));
      final [done, next] = await tasks();
      expect(done.repeat, isNull);
      expect(next.title, 'Send the weekly report');
      expect(next.repeat, TaskRepeat.monthly);
    });

    test('the form can stop a task repeating', () async {
      final task = await create(repeat: TaskRepeat.weekly);
      await repository.updateDetails(
        task,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: task.status,
        dueDate: task.dueDate,
        repeat: () => null,
      );
      expect((await tasks()).single.repeat, isNull);
    });

    test('a personal task repeats too', () async {
      await repository.createTask(
        ownerId: 'carol',
        title: 'Water the plants',
        dueDate: DateTime(2026, 10, 5),
        repeat: TaskRepeat.daily,
      );
      now = now.add(const Duration(minutes: 1));
      final task = (await repository.watchPersonalTasks('carol').first).single;

      await repository.setStatus(task, TaskStatus.complete);

      final [_, next] = await repository.watchPersonalTasks('carol').first;
      expect(next.isPersonal, isTrue);
      expect(next.dueDate, DateTime(2026, 10, 6));
    });
  });
}
