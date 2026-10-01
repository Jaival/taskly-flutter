import 'package:flutter/foundation.dart';

import '../../projects/domain/project.dart';
import '../../tasks/domain/task.dart';

/// A task on the Tasks page: personal, or in a [project] and assigned to
/// the user.
@immutable
class MyTask {
  const MyTask(this.task, {this.project});

  final Task task;

  /// Null for a personal task.
  final Project? project;

  @override
  bool operator ==(Object other) =>
      other is MyTask && other.task == task && other.project == project;

  @override
  int get hashCode => Object.hash(task, project);
}
