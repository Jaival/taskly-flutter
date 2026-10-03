import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import 'task_board.dart';
import 'task_card.dart';
import 'task_form.dart';

enum TaskView { list, board }

/// Whether project pages show tasks as a list or a board. One choice for
/// all projects, kept while the app runs.
final taskViewProvider = NotifierProvider<TaskViewNotifier, TaskView>(
  TaskViewNotifier.new,
);

class TaskViewNotifier extends Notifier<TaskView> {
  @override
  TaskView build() => TaskView.list;

  void show(TaskView view) => state = view;
}

/// A project's tasks, as a list or a board, with an "Add task" button, for
/// the project page to embed.
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
    final view = ref.watch(taskViewProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The controls drop below the heading when there's no room beside
        // it, and below each other with large text on a phone.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: AppSpacing.xs,
          children: [
            Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: AppSpacing.xs,
              children: [
                SegmentedButton<TaskView>(
                  segments: const [
                    ButtonSegment(
                      value: TaskView.list,
                      icon: Icon(Icons.view_agenda_outlined),
                      tooltip: 'Show as a list',
                    ),
                    ButtonSegment(
                      value: TaskView.board,
                      icon: Icon(Icons.view_kanban_outlined),
                      tooltip: 'Show as a board',
                    ),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  onSelectionChanged: (selected) =>
                      ref.read(taskViewProvider.notifier).show(selected.single),
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
            final visible when view == TaskView.board => [
              TaskBoard(
                tasks: visible,
                members: members,
                uid: uid,
                canEdit: canEdit,
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
