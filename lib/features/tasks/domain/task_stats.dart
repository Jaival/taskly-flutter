import 'package:flutter/foundation.dart';

import 'due_date.dart';
import 'task.dart';

/// What the dashboard says about a list of tasks: how many are late, and
/// how many were finished on each of the last few days.
@immutable
class TaskStats {
  const TaskStats({required this.overdue, required this.doneByDay});

  /// Counts [tasks] as of [now], looking [days] days back, today included.
  factory TaskStats.of(Iterable<Task> tasks, DateTime now, {int days = 7}) {
    final doneByDay = List.filled(days, 0);
    var overdue = 0;
    for (final task in tasks) {
      if (task.isOverdue(now)) overdue++;
      if (!task.isComplete) continue;
      // Tasks completed before the time was recorded count on the day they
      // last changed. A tick that hasn't reached the server yet has neither
      // time, and happened just now.
      final doneAt = task.completedAt ?? task.updatedAt ?? now;
      // Never in the future, even if the server's clock is ahead of ours.
      final daysAgo = -daysUntil(doneAt, now).clamp(-days, 0);
      if (daysAgo < days) doneByDay[days - 1 - daysAgo]++;
    }
    return TaskStats(overdue: overdue, doneByDay: doneByDay);
  }

  /// Open tasks past their due date.
  final int overdue;

  /// Tasks completed on each day, oldest first. The last one is today.
  final List<int> doneByDay;

  /// Tasks completed over all of [doneByDay].
  int get done => doneByDay.fold(0, (sum, count) => sum + count);

  @override
  bool operator ==(Object other) =>
      other is TaskStats &&
      other.overdue == overdue &&
      listEquals(other.doneByDay, doneByDay);

  @override
  int get hashCode => Object.hash(overdue, Object.hashAll(doneByDay));

  @override
  String toString() => 'TaskStats(overdue: $overdue, doneByDay: $doneByDay)';
}
