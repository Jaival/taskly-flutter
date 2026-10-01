import 'package:flutter/material.dart';

import '../../tasks/presentation/task_card.dart';
import '../domain/my_task.dart';

/// A [TaskCard] for the Tasks page and Home, where personal tasks and the
/// user's project tasks are listed together.
class MyTaskCard extends StatelessWidget {
  const MyTaskCard(this.item, {super.key, required this.uid});

  final MyTask item;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context) {
    final project = item.project;
    return TaskCard(
      task: item.task,
      projectName: project?.name,
      // Viewers can't edit project tasks, but can tick off their own. The
      // edit form has no assignee field here, so editing keeps it.
      canEdit: project?.canEdit(uid) ?? true,
    );
  }
}
