import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import 'task_card.dart';
import 'task_form.dart';

/// A project's tasks with an "Add task" button, for the project page to
/// embed.
///
/// Takes plain values rather than a `Project`, so the tasks feature doesn't
/// depend on the projects feature (which depends on this).
class ProjectTaskList extends ConsumerWidget {
  const ProjectTaskList({
    super.key,
    required this.projectId,
    required this.uid,
    required this.canEdit,
    this.members = const {},
  });

  final String projectId;

  /// The project's members, as user ID → name, for assigning tasks.
  final Map<String, String> members;

  /// The signed-in user.
  final String uid;

  /// Owners and editors can add, edit and delete tasks. Viewers can only
  /// tick off the tasks assigned to them.
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingDeletionsProvider);
    final tasks = ref.watch(projectTasksProvider(projectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (canEdit)
              TextButton.icon(
                onPressed: () => showTaskForm(
                  context,
                  projectId: projectId,
                  members: members,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ...switch (tasks) {
          AsyncData(:final value) => switch ([
            for (final task in value)
              if (!hidden.contains(taskDeletionKey(task))) task,
          ]) {
            [] => [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  canEdit
                      ? 'No tasks yet. Add one to get started.'
                      : 'No tasks yet.',
                ),
              ),
            ],
            final visible => [
              for (final task in visible)
                Padding(
                  key: ValueKey(task.id),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: TaskCard(
                    task: task,
                    members: members,
                    canEdit: canEdit,
                    canChangeStatus: canEdit || task.assigneeId == uid,
                  ),
                ),
            ],
          },
          AsyncError() => [
            Text(
              "Couldn't load tasks.",
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          _ => [for (var i = 0; i < 3; i++) const TaskCardSkeleton()],
        },
      ],
    );
  }
}
