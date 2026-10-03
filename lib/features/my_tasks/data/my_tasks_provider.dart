import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../domain/my_task.dart';
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
/// so they survive switching tabs, and reset when the user changes.
final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(
  TaskFilterNotifier.new,
);

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() {
    ref.watch(authStateProvider.select((user) => user.value?.uid));
    return const TaskFilter();
  }

  void change(TaskFilter filter) => state = filter;
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
