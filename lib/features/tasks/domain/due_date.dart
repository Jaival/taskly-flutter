import 'package:collection/collection.dart';

import 'task.dart';

/// A due date is a calendar day, not a moment: "due Friday" means all of
/// Friday wherever you are. So only the year, month and day are compared.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whole days from [today] to [due]: 0 if due today, negative if past.
int daysUntil(DateTime due, DateTime today) => DateTime.utc(
  due.year,
  due.month,
  due.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

/// The sections of a task list sorted by due date, in the order shown.
enum DueGroup {
  overdue('Overdue'),
  today('Today'),
  upcoming('Upcoming'),
  noDate('No due date'),
  done('Done');

  const DueGroup(this.label);

  final String label;
}

extension TaskDueDate on Task {
  /// Past its due date and still not done.
  bool isOverdue(DateTime today) =>
      !isComplete && dueDate != null && daysUntil(dueDate!, today) < 0;

  DueGroup dueGroup(DateTime today) => switch (dueDate) {
    _ when isComplete => DueGroup.done,
    null => DueGroup.noDate,
    final due => switch (daysUntil(due, today)) {
      < 0 => DueGroup.overdue,
      0 => DueGroup.today,
      _ => DueGroup.upcoming,
    },
  };
}

/// [tasks] split into their [DueGroup]s, in the enum's order, leaving out
/// empty groups. Dated tasks are soonest first; ties, undated and done
/// tasks keep the order they came in (the list order).
Map<DueGroup, List<Task>> groupByDue(Iterable<Task> tasks, DateTime today) {
  final groups = {for (final group in DueGroup.values) group: <Task>[]};
  for (final task in tasks) {
    groups[task.dueGroup(today)]!.add(task);
  }
  for (final group in [DueGroup.overdue, DueGroup.upcoming]) {
    // Stable, unlike List.sort, so ties stay in list order.
    mergeSort(
      groups[group]!,
      compare: (a, b) => a.dueDate!.compareTo(b.dueDate!),
    );
  }
  return {
    for (final MapEntry(:key, :value) in groups.entries)
      if (value.isNotEmpty) key: value,
  };
}

/// Open tasks in the order to do them: overdue, today and upcoming by date,
/// then the undated ones in list order.
List<Task> openTasksByDue(Iterable<Task> tasks, DateTime today) => [
  for (final MapEntry(:key, :value) in groupByDue(tasks, today).entries)
    if (key != DueGroup.done) ...value,
];
