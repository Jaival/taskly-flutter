import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/domain/due_date.dart';
import 'package:taskly/features/tasks/domain/task.dart';

void main() {
  final today = DateTime(2026, 10, 1, 15);

  Task task(String id, {DateTime? due, bool done = false, double order = 0}) =>
      Task(
        id: id,
        ownerId: 'alice',
        title: id,
        dueDate: due,
        status: done ? TaskStatus.complete : TaskStatus.notStarted,
        order: order,
      );

  test('daysUntil counts calendar days, whatever the time', () {
    expect(daysUntil(DateTime(2026, 10, 1), today), 0);
    expect(daysUntil(DateTime(2026, 10, 2), today), 1);
    expect(daysUntil(DateTime(2026, 9, 30, 23, 59), today), -1);
    // Across the change to winter time, a day is still a day.
    expect(daysUntil(DateTime(2026, 11, 1), DateTime(2026, 10, 24)), 8);
  });

  test('a task is overdue only if it is past due and not done', () {
    final yesterday = DateTime(2026, 9, 30);
    expect(task('a', due: yesterday).isOverdue(today), isTrue);
    expect(task('a', due: yesterday, done: true).isOverdue(today), isFalse);
    expect(task('a', due: DateTime(2026, 10, 1)).isOverdue(today), isFalse);
    expect(task('a').isOverdue(today), isFalse);
  });

  test('groups in order, soonest first, keeping list order for ties', () {
    final groups = groupByDue(
      [
        task('no date 1'),
        task('next week', due: DateTime(2026, 10, 8)),
        task('done', due: DateTime(2026, 9, 1), done: true),
        task('tomorrow b', due: DateTime(2026, 10, 2)),
        task('last week', due: DateTime(2026, 9, 24)),
        task('today', due: DateTime(2026, 10, 1)),
        task('tomorrow a', due: DateTime(2026, 10, 2)),
        task('yesterday', due: DateTime(2026, 9, 30)),
        task('no date 2'),
      ],
      today,
      (task) => task,
    );

    List<String> titles(DueGroup group) => [
      for (final task in groups[group]!) task.title,
    ];
    expect(groups.keys, DueGroup.values);
    expect(titles(DueGroup.overdue), ['last week', 'yesterday']);
    expect(titles(DueGroup.today), ['today']);
    expect(titles(DueGroup.upcoming), [
      'tomorrow b',
      'tomorrow a',
      'next week',
    ]);
    expect(titles(DueGroup.noDate), ['no date 1', 'no date 2']);
    expect(titles(DueGroup.done), ['done']);
  });

  test('leaves out empty groups', () {
    expect(groupByDue([task('a')], today, (task) => task).keys, [
      DueGroup.noDate,
    ]);
    expect(groupByDue(<Task>[], today, (task) => task), isEmpty);
  });

  test('open tasks by due: dated soonest first, then undated', () {
    final open = openTasksByDue(
      [
        task('undated'),
        task('done', done: true),
        task('friday', due: DateTime(2026, 10, 2)),
        task('late', due: DateTime(2026, 9, 1)),
      ],
      today,
      (task) => task,
    );
    expect([for (final t in open) t.title], ['late', 'friday', 'undated']);
  });
}
