import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/domain/task_stats.dart';

void main() {
  // A Thursday afternoon.
  final now = DateTime(2026, 10, 1, 15);

  Task open(String id, {DateTime? due}) =>
      Task(id: id, ownerId: 'alice', title: id, dueDate: due);

  Task done(String id, {DateTime? at, DateTime? updatedAt, DateTime? due}) =>
      Task(
        id: id,
        ownerId: 'alice',
        title: id,
        status: TaskStatus.complete,
        dueDate: due,
        completedAt: at,
        updatedAt: updatedAt,
      );

  test('counts open tasks past their due date', () {
    final stats = TaskStats.of([
      open('late', due: DateTime(2026, 9, 30)),
      open('later', due: DateTime(2026, 9, 1)),
      open('today', due: DateTime(2026, 10, 1)),
      open('undated'),
      done('finished late', due: DateTime(2026, 9, 30), at: now),
    ], now);

    expect(stats.overdue, 2);
  });

  test('counts completions on the day they happened, today last', () {
    final stats = TaskStats.of([
      done('a', at: DateTime(2026, 10, 1, 9)),
      done('b', at: DateTime(2026, 10, 1, 0, 1)),
      // Late the evening before is still the day before.
      done('c', at: DateTime(2026, 9, 30, 23, 59)),
      done('d', at: DateTime(2026, 9, 25, 12)),
      // Eight days ago: off the chart.
      done('e', at: DateTime(2026, 9, 24, 23)),
      open('f'),
    ], now);

    expect(stats.doneByDay, [1, 0, 0, 0, 0, 1, 2]);
    expect(stats.done, 4);
  });

  test('a task done before the time was recorded counts when it last '
      'changed', () {
    final stats = TaskStats.of([
      done('old', updatedAt: DateTime(2026, 9, 29, 8)),
      // The time it was completed wins over a later edit.
      done('edited', at: DateTime(2026, 9, 28), updatedAt: now),
    ], now);

    expect(stats.doneByDay, [0, 0, 0, 1, 1, 0, 0]);
  });

  test('a tick still on its way to the server counts today', () {
    expect(TaskStats.of([done('pending')], now).doneByDay.last, 1);
    // So does one the server stamped a little ahead of this clock.
    final ahead = done('ahead', at: DateTime(2026, 10, 2, 0, 0, 5));
    expect(TaskStats.of([ahead], DateTime(2026, 10, 1, 23, 59, 58)).doneByDay, [
      0,
      0,
      0,
      0,
      0,
      0,
      1,
    ]);
  });

  test('with nothing, everything is zero', () {
    final stats = TaskStats.of(const [], now);
    expect(
      stats,
      const TaskStats(overdue: 0, doneByDay: [0, 0, 0, 0, 0, 0, 0]),
    );
    expect(stats.done, 0);
  });
}
