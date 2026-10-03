import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/status_colors.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'checklist_progress.dart';
import 'due_date_label.dart';
import 'repeat_label.dart';
import 'task_activity_sheet.dart';
import 'task_card.dart';
import 'task_form.dart';

/// A project's tasks as a board: a column per status. Drag a card to
/// another column to change its status (press and hold first on a phone),
/// or use the card's menu, which also works from a keyboard or screen
/// reader.
class TaskBoard extends StatelessWidget {
  const TaskBoard({
    super.key,
    required this.tasks,
    required this.members,
    required this.uid,
    required this.canEdit,
  });

  /// In list order, without any being deleted.
  final List<Task> tasks;

  /// The project's members, as user ID → name.
  final Map<String, String> members;

  /// The signed-in user.
  final String uid;

  /// Owners and editors can move, edit and delete any task. Viewers can
  /// only move the tasks assigned to them.
  final bool canEdit;

  static const _columnWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final columns = [
      for (final status in TaskStatus.values)
        _BoardColumn(
          status: status,
          tasks: [
            for (final task in tasks)
              if (task.status == status) task,
          ],
          members: members,
          uid: uid,
          canEdit: canEdit,
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.sm;
        // Side by side when all three fit; on a phone, scroll sideways.
        if (constraints.maxWidth >= 3 * 220 + 2 * gap) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [for (final column in columns) Expanded(child: column)],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: gap,
            children: [
              for (final column in columns)
                SizedBox(width: _columnWidth, child: column),
            ],
          ),
        );
      },
    );
  }
}

class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({
    required this.status,
    required this.tasks,
    required this.members,
    required this.uid,
    required this.canEdit,
  });

  final TaskStatus status;
  final List<Task> tasks;
  final Map<String, String> members;
  final String uid;
  final bool canEdit;

  bool _canMove(Task task) => canEdit || task.assigneeId == uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DragTarget<Task>(
      onWillAcceptWithDetails: (details) =>
          details.data.status != status && _canMove(details.data),
      onAcceptWithDetails: (details) =>
          moveTask(context, ref, details.data, status),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: hovering
                ? colors.secondaryContainer
                : colors.surfaceContainerLow,
            borderRadius: AppRadius.mdAll,
            border: Border.all(
              color: hovering ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Semantics(
                  header: true,
                  label:
                      '${status.label}, ${tasks.length} '
                      '${tasks.length == 1 ? 'task' : 'tasks'}',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Icon(
                        StatusChip.iconFor(status),
                        size: 18,
                        color: colors.statusColor(status),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${status.label} · ${tasks.length}',
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    'Nothing here',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final task in tasks)
                  Padding(
                    key: ValueKey(task.id),
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: _DraggableCard(
                      task: task,
                      canMove: _canMove(task),
                      card: BoardCard(
                        task: task,
                        members: members,
                        canEdit: canEdit,
                        canMove: _canMove(task),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

/// Moves [task] to [status], saying so if it fails, or if that added the
/// next task in a series.
Future<void> moveTask(
  BuildContext context,
  WidgetRef ref,
  Task task,
  TaskStatus status,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final localizations = MaterialLocalizations.of(context);
  try {
    final next = await ref.read(taskRepositoryProvider).setStatus(task, status);
    if (next != null) showNextTaskAdded(messenger, localizations, next);
  } on FirebaseException {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't move \"${task.title}\".")),
    );
  }
}

/// Makes [card] draggable when the user may move it. On touch screens a
/// drag starts with a long press, so swiping still scrolls the board.
class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.task,
    required this.canMove,
    required this.card,
  });

  final Task task;
  final bool canMove;
  final Widget card;

  @override
  Widget build(BuildContext context) {
    if (!canMove) return card;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The card under the pointer keeps its width while dragged.
        final feedback = SizedBox(
          width: constraints.maxWidth,
          child: Material(
            type: MaterialType.transparency,
            elevation: 6,
            child: card,
          ),
        );
        final placeholder = Opacity(opacity: 0.4, child: card);
        return switch (Theme.of(context).platform) {
          TargetPlatform.android ||
          TargetPlatform.iOS ||
          TargetPlatform.fuchsia => LongPressDraggable<Task>(
            data: task,
            feedback: feedback,
            childWhenDragging: placeholder,
            child: card,
          ),
          _ => Draggable<Task>(
            data: task,
            feedback: feedback,
            childWhenDragging: placeholder,
            child: card,
          ),
        };
      },
    );
  }
}

/// A compact task card for the board. Its status is the column it's in.
class BoardCard extends ConsumerWidget {
  const BoardCard({
    super.key,
    required this.task,
    required this.members,
    required this.canEdit,
    required this.canMove,
  });

  final Task task;
  final Map<String, String> members;
  final bool canEdit;
  final bool canMove;

  void _delete(BuildContext context, WidgetRef ref) {
    final repository = ref.read(taskRepositoryProvider);
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
    final assignee = members[task.assigneeId];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canEdit
            ? () => showTaskForm(context, task: task, members: members)
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            0,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _CardMenu(
                    task: task,
                    canMove: canMove,
                    canDelete: canEdit,
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
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PriorityChip(task.priority),
                    if (task.dueDate != null)
                      DueDateLabel(task, today: DateTime.now()),
                    if (task.repeats) RepeatLabel(task),
                    if (task.checklist.isNotEmpty) ChecklistProgress(task),
                    if (assignee != null)
                      Semantics(
                        label: 'Assigned to $assignee',
                        excludeSemantics: true,
                        child: Text(
                          assignee,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Move to …" for each other status, the comments, and Delete for editors.
class _CardMenu extends ConsumerWidget {
  const _CardMenu({
    required this.task,
    required this.canMove,
    required this.canDelete,
    required this.onComments,
    required this.onDelete,
  });

  final Task task;
  final bool canMove;
  final bool canDelete;
  final VoidCallback onComments;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<VoidCallback>(
      tooltip: 'Actions for "${task.title}"',
      onSelected: (action) => action(),
      // Not the menu's own context, which is gone once an item is chosen.
      itemBuilder: (_) => [
        if (canMove) ...[
          for (final status in TaskStatus.values)
            if (status != task.status)
              PopupMenuItem(
                value: () => moveTask(context, ref, task, status),
                child: Text('Move to ${status.label}'),
              ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: onComments,
          child: const Text('Comments and activity'),
        ),
        if (canDelete) ...[
          const PopupMenuDivider(),
          PopupMenuItem(value: onDelete, child: const Text('Delete')),
        ],
      ],
    );
  }
}
