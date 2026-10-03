import 'package:flutter/foundation.dart';

import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../tasks/domain/due_date.dart';
import 'my_task.dart';

enum TaskSort {
  /// Grouped into Overdue, Today, Upcoming, No due date and Done.
  dueDate('Due date'),

  /// Most urgent first, then by due date.
  priority('Priority'),

  /// Most recently created first.
  newest('Newest'),

  /// A to Z.
  title('Title');

  const TaskSort(this.label);

  final String label;
}

/// The groups the "Due" filter offers. Done is left out: that's a status.
const dueFilterGroups = [
  DueGroup.overdue,
  DueGroup.today,
  DueGroup.upcoming,
  DueGroup.noDate,
];

/// What the Tasks page shows. Each set filters only when it's non-empty,
/// and a task must match all of them.
@immutable
class TaskFilter {
  const TaskFilter({
    this.query = '',
    this.priorities = const {},
    this.statuses = const {},
    this.due = const {},
    this.projectIds = const {},
    this.sort = TaskSort.dueDate,
  });

  /// Matched against the title and description, ignoring case.
  final String query;

  final Set<Priority> priorities;
  final Set<TaskStatus> statuses;
  final Set<DueGroup> due;

  /// Project IDs to show, with null standing for personal tasks.
  final Set<String?> projectIds;

  final TaskSort sort;

  /// Whether anything is filtered out. The sort doesn't count.
  bool get isFiltering =>
      query.trim().isNotEmpty ||
      priorities.isNotEmpty ||
      statuses.isNotEmpty ||
      due.isNotEmpty ||
      projectIds.isNotEmpty;

  TaskFilter copyWith({
    String? query,
    Set<Priority>? priorities,
    Set<TaskStatus>? statuses,
    Set<DueGroup>? due,
    Set<String?>? projectIds,
    TaskSort? sort,
  }) => TaskFilter(
    query: query ?? this.query,
    priorities: priorities ?? this.priorities,
    statuses: statuses ?? this.statuses,
    due: due ?? this.due,
    projectIds: projectIds ?? this.projectIds,
    sort: sort ?? this.sort,
  );

  /// The same sort, nothing filtered.
  TaskFilter cleared() => TaskFilter(sort: sort);

  /// For the calendar, which shows every due date: the "Due" filter set in
  /// the list doesn't apply there.
  TaskFilter withoutDue() => copyWith(due: const {});

  bool matches(MyTask item, DateTime today) {
    final task = item.task;
    final words = query.trim().toLowerCase();
    return (words.isEmpty ||
            task.title.toLowerCase().contains(words) ||
            task.description.toLowerCase().contains(words)) &&
        (priorities.isEmpty || priorities.contains(task.priority)) &&
        (statuses.isEmpty || statuses.contains(task.status)) &&
        (due.isEmpty || due.contains(task.dueGroup(today))) &&
        (projectIds.isEmpty || projectIds.contains(task.projectId));
  }

  /// The matching [items], sorted. For [TaskSort.dueDate] they're in list
  /// order; [groupByDue] does the rest.
  List<MyTask> apply(Iterable<MyTask> items, DateTime today) {
    final result = [
      for (final item in items)
        if (matches(item, today)) item,
    ];
    final Comparator<MyTask>? compare = switch (sort) {
      TaskSort.dueDate => null,
      // Priority's values run from most to least urgent.
      TaskSort.priority => (a, b) => switch (a.task.priority.index.compareTo(
        b.task.priority.index,
      )) {
        0 => _compareDue(a, b),
        final order => order,
      },
      // Not yet saved (null) is the newest of all.
      TaskSort.newest => (a, b) => switch ((
        a.task.createdAt,
        b.task.createdAt,
      )) {
        (null, null) => 0,
        (null, _) => -1,
        (_, null) => 1,
        (final x?, final y?) => y.compareTo(x),
      },
      TaskSort.title => (a, b) => a.task.title.toLowerCase().compareTo(
        b.task.title.toLowerCase(),
      ),
    };
    // Stable, so ties keep the list order.
    if (compare != null) mergeSort(result, compare: compare);
    return result;
  }

  /// Soonest due first, undated last.
  static int _compareDue(MyTask a, MyTask b) =>
      switch ((a.task.dueDate, b.task.dueDate)) {
        (null, null) => 0,
        (null, _) => 1,
        (_, null) => -1,
        (final x?, final y?) => x.compareTo(y),
      };

  @override
  bool operator ==(Object other) =>
      other is TaskFilter &&
      other.query == query &&
      setEquals(other.priorities, priorities) &&
      setEquals(other.statuses, statuses) &&
      setEquals(other.due, due) &&
      setEquals(other.projectIds, projectIds) &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAllUnordered(priorities),
    Object.hashAllUnordered(statuses),
    Object.hashAllUnordered(due),
    Object.hashAllUnordered(projectIds),
    sort,
  );
}
