import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'checklist_progress.dart';
import 'due_date_label.dart';
import 'task_activity_sheet.dart';
import 'task_form.dart';

/// The [pendingDeletionsProvider] key for [task].
String taskDeletionKey(Task task) => switch (task.projectId) {
  null => 'tasks/${task.id}',
  final projectId => 'projects/$projectId/tasks/${task.id}',
};

/// A task in a list, personal or in a project: a checkbox to complete it,
/// its title and details, and tap to edit. A project task also has a button
/// for its comments.
class TaskCard extends ConsumerWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.members,
    this.projectName,
    this.canEdit = true,
    this.canChangeStatus = true,
  });

  final Task task;

  /// The project's members, as user ID → name, to show the assignee and
  /// offer them in the edit form. Null for personal tasks.
  final Map<String, String>? members;

  /// Shown on the card when it's listed away from its project (the Tasks
  /// page). Null on the project's own page, and for personal tasks.
  final String? projectName;

  /// Whether the user may edit and delete it. Project viewers can't.
  final bool canEdit;

  /// Whether the user may tick it off. Viewers can on tasks assigned to them.
  final bool canChangeStatus;

  Future<void> _setComplete(
    BuildContext context,
    WidgetRef ref,
    bool complete,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(taskRepositoryProvider)
          .setStatus(
            task,
            complete ? TaskStatus.complete : TaskStatus.notStarted,
          );
    } on FirebaseException {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't update \"${task.title}\".")),
      );
    }
  }

  void _delete(BuildContext context, WidgetRef ref) {
    final repository = ref.read(taskRepositoryProvider);
    // No confirmation: a task is small, and Undo covers mistakes.
    deleteWithUndo(
      context,
      ref,
      key: taskDeletionKey(task),
      message: 'Deleted "${task.title}".',
      failureMessage: "Couldn't delete \"${task.title}\".",
      delete: () => repository.deleteTask(task),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final done = task.isComplete;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit
            ? () => showTaskForm(context, task: task, members: members)
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Checkbox(
                  value: done,
                  semanticLabel: 'Complete "${task.title}"',
                  onChanged: canChangeStatus
                      ? (value) => _setComplete(context, ref, value ?? false)
                      : null,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm + 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Struck through and dimmed when done, fading rather
                      // than jumping.
                      AnimatedDefaultTextStyle(
                        duration: duration,
                        curve: Curves.easeOut,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: done
                              ? colors.onSurfaceVariant
                              : colors.onSurface,
                          decoration: done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: colors.onSurfaceVariant,
                        ),
                        child: Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          task.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          PriorityChip(task.priority),
                          StatusChip(task.status),
                          if (task.dueDate != null)
                            DueDateLabel(task, today: DateTime.now()),
                          if (task.checklist.isNotEmpty)
                            ChecklistProgress(task),
                          if (members?[task.assigneeId] case final name?)
                            _Assignee(name),
                          if (projectName case final name?) _ProjectName(name),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Open to viewers too: anyone in the project can comment.
              if (!task.isPersonal)
                IconButton(
                  tooltip: 'Comments on "${task.title}"',
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () => showTaskActivity(
                    context,
                    task: task,
                    members: members,
                    canModerate: canEdit,
                  ),
                ),
              if (canEdit)
                IconButton(
                  tooltip: 'Delete "${task.title}"',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, ref),
                )
              else
                const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectName extends StatelessWidget {
  const _ProjectName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'In $name',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Assignee extends StatelessWidget {
  const _Assignee(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Assigned to $name',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_outline, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grey placeholder with the shape of a [TaskCard], shown while loading.
class TaskCardSkeleton extends StatelessWidget {
  const TaskCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 20, height: 20),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 200, height: 18),
                  SizedBox(height: AppSpacing.sm),
                  Skeleton(width: 120, height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
