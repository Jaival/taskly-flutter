import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import '../domain/due_date.dart';
import '../domain/task.dart';
import 'task_card.dart';
import 'task_form.dart';

/// `/tasks`: the user's personal tasks, grouped by when they're due. Project
/// tasks live on their project's page.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingDeletionsProvider);
    final tasks = ref.watch(personalTasksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: switch (tasks) {
        AsyncData(:final value) => switch ([
          for (final task in value)
            if (!hidden.contains(taskDeletionKey(task))) task,
        ]) {
          [] => EmptyState(
            icon: Icons.task_alt_outlined,
            title: 'No tasks yet',
            message:
                'Add the things you need to do yourself. Tasks for a '
                "project are on that project's page.",
            action: FilledButton.icon(
              onPressed: () => showTaskForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add a task'),
            ),
          ),
          final visible => _GroupedTasks(groupByDue(visible, DateTime.now())),
        },
        AsyncError() => ErrorState(
          message: "Couldn't load your tasks.",
          onRetry: () => ref.invalidate(personalTasksProvider),
        ),
        _ => _TaskListView(
          itemCount: 5,
          itemBuilder: (context, _) => const TaskCardSkeleton(),
        ),
      },
    );
  }
}

/// A single column of cards, centred and kept to a readable width on wide
/// screens.
class _TaskListView extends StatelessWidget {
  const _TaskListView({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView.separated(
          // Extra bottom padding so the button never covers the last task.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl * 2,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: (context, _) =>
              const SizedBox(height: AppSpacing.xs),
        ),
      ),
    );
  }
}

/// Each group's heading, then its tasks.
class _GroupedTasks extends StatelessWidget {
  const _GroupedTasks(this.groups);

  final Map<DueGroup, List<Task>> groups;

  @override
  Widget build(BuildContext context) {
    // Without any due dates, a lone "No due date" heading says nothing.
    final headings = groups.keys.any((group) => group != DueGroup.noDate);
    // Headings and tasks in one lazy list.
    final entries = <Object>[
      for (final MapEntry(key: group, value: tasks) in groups.entries) ...[
        if (headings) group,
        ...tasks,
      ],
    ];
    return _TaskListView(
      itemCount: entries.length,
      itemBuilder: (context, index) => switch (entries[index]) {
        final DueGroup group => _GroupHeading(
          key: ValueKey(group),
          group: group,
          count: groups[group]!.length,
          first: index == 0,
        ),
        final Task task => TaskCard(key: ValueKey(task.id), task: task),
        final other => throw StateError('Unexpected entry $other'),
      },
    );
  }
}

class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    super.key,
    required this.group,
    required this.count,
    required this.first,
  });

  final DueGroup group;
  final int count;

  /// The top heading needs no space above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = group == DueGroup.overdue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xs,
        first ? 0 : AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Semantics(
        header: true,
        label: '${group.label}, $count ${count == 1 ? 'task' : 'tasks'}',
        excludeSemantics: true,
        child: Text(
          '${group.label} · $count',
          style: theme.textTheme.titleSmall?.copyWith(color: color),
        ),
      ),
    );
  }
}
