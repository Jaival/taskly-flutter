import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/priority_colors.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'checklist_progress.dart';
import 'due_date_label.dart';
import 'label_chip.dart';
import 'repeat_label.dart';
import 'task_activity_sheet.dart';
import 'task_form.dart';

/// The [pendingDeletionsProvider] key for [task].
String taskDeletionKey(Task task) => switch (task.projectId) {
  null => 'tasks/${task.id}',
  final projectId => 'projects/$projectId/tasks/${task.id}',
};

/// A task in a list, personal or in a project: a checkbox in its priority's
/// colour to complete it, its title and one line of details, and tap to
/// edit. Its other actions (comments, delete) are in a menu, and on phones
/// it can be swiped: right to tick it off, left to delete it.
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
    final localizations = MaterialLocalizations.of(context);
    try {
      final next = await ref
          .read(taskRepositoryProvider)
          .setStatus(
            task,
            complete ? TaskStatus.complete : TaskStatus.notStarted,
          );
      if (next != null) showNextTaskAdded(messenger, localizations, next);
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
    final priorityColors = theme.extension<PriorityColors>()!;
    final done = task.isComplete;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    // Low priority keeps the plain box: only the others call for attention.
    final priorityColor = task.priority == Priority.low
        ? null
        : priorityColors.of(task.priority);

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Checkbox(
              value: done,
              semanticLabel: 'Complete "${task.title}"',
              // The box is drawn in the priority's colour, with a tint of
              // it inside, so urgent tasks stand out before they're read.
              side: priorityColor == null || done
                  ? null
                  : BorderSide(color: priorityColor, width: 2),
              fillColor: priorityColor == null
                  ? null
                  : WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? colors.primary
                          : priorityColors.tint(task.priority, colors.surface),
                    ),
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
                    style: theme.textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: done ? colors.onSurfaceVariant : colors.onSurface,
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
                  if (task.description.isNotEmpty)
                    Text(
                      task.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  _Details(
                    task: task,
                    assignee: members?[task.assigneeId],
                    projectName: projectName,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          _TaskMenu(
            task: task,
            canEdit: canEdit,
            onEdit: () => showTaskForm(context, task: task, members: members),
            onComments: () => showTaskActivity(
              context,
              task: task,
              members: members,
              canModerate: canEdit,
            ),
            onDelete: () => _delete(context, ref),
          ),
        ],
      ),
    );

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit
            ? () => showTaskForm(context, task: task, members: members)
            : null,
        child: row,
      ),
    );

    // On phones, swipe right to tick it off (or back on), left to delete.
    final phone = MediaQuery.sizeOf(context).width < Breakpoints.medium;
    if (!phone || (!canChangeStatus && !canEdit)) return card;
    return Dismissible(
      key: ValueKey('swipe ${taskDeletionKey(task)}'),
      direction: switch ((canChangeStatus, canEdit)) {
        (true, true) => DismissDirection.horizontal,
        (true, false) => DismissDirection.startToEnd,
        _ => DismissDirection.endToStart,
      },
      background: _SwipeBackground(
        alignment: AlignmentDirectional.centerStart,
        color: colors.primary,
        foreground: colors.onPrimary,
        icon: done ? Icons.undo : Icons.check,
        label: done ? 'Not done' : 'Done',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: AlignmentDirectional.centerEnd,
        color: colors.error,
        foreground: colors.onError,
        icon: Icons.delete_outline,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        unawaited(HapticFeedback.mediumImpact());
        if (direction == DismissDirection.startToEnd) {
          // The row springs back, ticked or unticked.
          await _setComplete(context, ref, !done);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _delete(context, ref),
      child: card,
    );
  }
}

/// What's known about a task, on one line under its title: priority (when
/// it's high), progress, dates, labels, and who and where.
class _Details extends StatelessWidget {
  const _Details({
    required this.task,
    required this.assignee,
    required this.projectName,
  });

  final Task task;
  final String? assignee;
  final String? projectName;

  @override
  Widget build(BuildContext context) {
    final urgent =
        task.priority == Priority.immediate || task.priority == Priority.high;
    final children = [
      if (urgent && !task.isComplete) _PriorityFlag(task.priority),
      // "Not started" goes without saying: the box is empty.
      if (task.status == TaskStatus.inProgress) StatusChip(task.status),
      if (task.dueDate != null) DueDateLabel(task, today: DateTime.now()),
      if (task.repeats) RepeatLabel(task),
      if (task.checklist.isNotEmpty) ChecklistProgress(task),
      for (final label in task.labels) InlineLabel(label),
      if (assignee case final name?) _Assignee(name),
      if (projectName case final name?) _ProjectName(name),
    ];
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

/// A flag and "High" or "Immediate", so priority isn't told by colour
/// alone.
class _PriorityFlag extends StatelessWidget {
  const _PriorityFlag(this.priority);

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${priority.label} priority',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag,
            size: 16,
            color: theme.extension<PriorityColors>()!.of(priority),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              priority.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The task's actions, in a menu: one quiet button instead of a row of
/// them on every task.
class _TaskMenu extends StatelessWidget {
  const _TaskMenu({
    required this.task,
    required this.canEdit,
    required this.onEdit,
    required this.onComments,
    required this.onDelete,
  });

  final Task task;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onComments;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = [
      if (canEdit)
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
          child: const Text('Edit'),
        ),
      // Open to viewers too: anyone in the project can comment.
      if (!task.isPersonal)
        MenuItemButton(
          leadingIcon: const Icon(Icons.chat_bubble_outline),
          onPressed: onComments,
          child: const Text('Comments'),
        ),
      if (canEdit)
        MenuItemButton(
          leadingIcon: Icon(Icons.delete_outline, color: colors.error),
          onPressed: onDelete,
          child: Text('Delete', style: TextStyle(color: colors.error)),
        ),
    ];
    // A viewer's personal task can't happen, but leave the room anyway.
    if (items.isEmpty) return const SizedBox(width: AppSpacing.md);
    return MenuAnchor(
      menuChildren: items,
      builder: (context, controller, _) => IconButton(
        tooltip: 'Actions for "${task.title}"',
        icon: Icon(Icons.more_horiz, color: colors.onSurfaceVariant),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// What's behind a task row as it's swiped.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final AlignmentGeometry alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xs),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.lgAll),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: foreground),
          ),
        ],
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
