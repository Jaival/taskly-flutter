import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/preferences.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/due_date.dart';
import '../domain/my_task.dart';
import '../domain/task_calendar.dart';
import '../domain/task_filter.dart';

/// The user's personal tasks, then the tasks assigned to them in each of
/// their projects.
///
/// Loading until the personal tasks, the projects and every project's
/// assigned tasks have arrived. A project whose tasks fail to load is
/// skipped rather than failing the page: that's what happens for a moment
/// after leaving a project, before the project list catches up and this
/// stops asking.
final myTasksProvider = Provider.autoDispose<AsyncValue<List<MyTask>>>((ref) {
  final personal = ref.watch(personalTasksProvider);
  final projects = ref.watch(projectsProvider);

  if (personal case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  if (projects case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  final (personalTasks, projectList) = (personal.value, projects.value);
  if (personalTasks == null || projectList == null) {
    return const AsyncLoading();
  }

  final items = [for (final task in personalTasks) MyTask(task)];
  var loading = false;
  for (final project in projectList) {
    final assigned = ref.watch(assignedTasksProvider(project.id));
    if (assigned.value case final tasks?) {
      items.addAll([for (final task in tasks) MyTask(task, project: project)]);
    } else if (!assigned.hasError) {
      loading = true;
    }
  }
  return loading ? const AsyncLoading() : AsyncData(items);
});

/// The search, filters and sort on the Tasks page. Kept while the app runs,
/// so they survive switching tabs, and reset when the user changes. Sorted
/// the default way until another sort is picked; changing the default in
/// Settings changes it here too.
final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() {
    ref.watch(currentUserProvider.select((user) => user?.uid));
    ref.listen(
      tasksDefaultsProvider.select((defaults) => defaults.sort),
      (_, sort) => state = state.copyWith(sort: sort),
    );
    return TaskFilter(sort: ref.read(tasksDefaultsProvider).sort);
  }

  void change(TaskFilter filter) => state = filter;
}

/// The filter as it applies to the view that's showing: a calendar shows
/// every due date, so the "Due" filter set in the list doesn't apply there.
final activeTaskFilterProvider = Provider<TaskFilter>((ref) {
  final filter = ref.watch(taskFilterProvider);
  return switch (ref.watch(tasksViewProvider)) {
    TasksView.calendar => filter.withoutDue(),
    TasksView.list => filter,
  };
});

/// How the Tasks page shows its tasks.
enum TasksView { list, calendar }

/// Remembered while the app runs, like the filters. Starts out as the
/// default view, and follows it when it's changed in Settings.
final tasksViewProvider = NotifierProvider<TasksViewNotifier, TasksView>(
  TasksViewNotifier.new,
);

class TasksViewNotifier extends Notifier<TasksView> {
  @override
  TasksView build() {
    ref.listen(
      tasksDefaultsProvider.select((defaults) => defaults.view),
      (_, view) => state = view,
    );
    return ref.read(tasksDefaultsProvider).view;
  }

  void show(TasksView view) => state = view;
}

/// How the Tasks page looks when the app opens.
typedef TasksDefaults = ({TasksView view, TaskSort sort});

/// The default view and sort for the Tasks page, set in Settings and kept
/// on the device. The built-in ones until the saved ones have been read.
final tasksDefaultsProvider =
    NotifierProvider<TasksDefaultsNotifier, TasksDefaults>(
      TasksDefaultsNotifier.new,
    );

class TasksDefaultsNotifier extends Notifier<TasksDefaults> {
  static const _viewKey = 'tasks.defaultView';
  static const _sortKey = 'tasks.defaultSort';

  /// Whether one has been chosen here, which a slow read mustn't undo.
  bool _changed = false;

  @override
  TasksDefaults build() {
    unawaited(_load());
    return (view: TasksView.list, sort: TaskSort.dueDate);
  }

  Future<void> _load() async {
    try {
      final prefs = ref.read(preferencesProvider);
      final (view, sort) = (
        await prefs.read(_viewKey),
        await prefs.read(_sortKey),
      );
      if (!ref.mounted || _changed) return;
      state = (
        view: TasksView.values.asNameMap()[view] ?? state.view,
        sort: TaskSort.values.asNameMap()[sort] ?? state.sort,
      );
    } on Object {
      // Nothing saved that can be read: the built-in defaults will do.
    }
  }

  void setView(TasksView view) {
    _changed = true;
    state = (view: view, sort: state.sort);
    _save(_viewKey, view.name);
  }

  void setSort(TaskSort sort) {
    _changed = true;
    state = (view: state.view, sort: sort);
    _save(_sortKey, sort.name);
  }

  /// If it can't be stored, it still holds until the app closes.
  void _save(String key, String value) {
    try {
      unawaited(
        ref.read(preferencesProvider).write(key, value).catchError((_) {}),
      );
    } on Object {
      // As above.
    }
  }
}

/// The day chosen in the calendar, which also decides the month it shows.
/// Today until another is picked.
final calendarDayProvider = NotifierProvider<CalendarDayNotifier, DateTime>(
  CalendarDayNotifier.new,
);

class CalendarDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);

  void showToday() => select(DateTime.now());

  /// Moves [months] forward, or back if negative. Lands on today in the
  /// current month and on the 1st in any other.
  void showMonth(int months) {
    final month = DateTime(state.year, state.month + months);
    final today = dateOnly(DateTime.now());
    state = sameMonth(month, today) ? today : month;
  }
}

/// A request to put the cursor in the Tasks page's search box: the "/"
/// shortcut, which can be pressed on any page. Holds when it was asked for.
final taskSearchRequestProvider =
    NotifierProvider<TaskSearchRequestNotifier, DateTime?>(
      TaskSearchRequestNotifier.new,
    );

class TaskSearchRequestNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void request() => state = DateTime.now();

  /// Whether a request is waiting. It goes stale: if there was no search
  /// box to answer it (no tasks yet), one that appears later shouldn't grab
  /// the focus.
  bool get isWaiting => switch (state) {
    null => false,
    final requestedAt =>
      DateTime.now().difference(requestedAt) < const Duration(seconds: 2),
  };

  /// Whether the search box should take the focus now. Uses the request up.
  bool take() {
    final waiting = isWaiting;
    state = null;
    return waiting;
  }
}
