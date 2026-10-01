import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/undo_delete.dart';
import '../../auth/data/auth_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/due_date.dart';
import '../../tasks/presentation/task_card.dart';
import '../../tasks/presentation/task_form.dart';
import '../data/my_tasks_provider.dart';
import '../domain/my_task.dart';
import '../domain/task_filter.dart';
import 'my_task_card.dart';
import 'task_filter_bar.dart';

/// `/tasks`: the user's personal tasks and the project tasks assigned to
/// them, to search, filter and sort. Grouped by when they're due unless
/// sorted otherwise.
class TasksPage extends ConsumerWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingDeletionsProvider);
    final items = ref.watch(myTasksProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskForm(context),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: switch (items) {
        AsyncData(:final value) => switch ([
          for (final item in value)
            if (!hidden.contains(taskDeletionKey(item.task))) item,
        ]) {
          [] => EmptyState(
            icon: Icons.task_alt_outlined,
            title: 'No tasks yet',
            message:
                'Add the things you need to do yourself. Project tasks '
                'assigned to you show up here too.',
            action: FilledButton.icon(
              onPressed: () => showTaskForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add a task'),
            ),
          ),
          final visible => _FilteredTasks(visible),
        },
        AsyncError() => ErrorState(
          message: "Couldn't load your tasks.",
          onRetry: () => ref
            ..invalidate(personalTasksProvider)
            ..invalidate(projectsProvider),
        ),
        _ => _TaskListView(
          itemCount: 5,
          itemBuilder: (context, _) => const TaskCardSkeleton(),
        ),
      },
    );
  }
}

/// The filter bar above the tasks it lets through.
class _FilteredTasks extends ConsumerWidget {
  const _FilteredTasks(this.items);

  final List<MyTask> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final projects = ref.watch(projectsProvider).value ?? const [];
    final today = DateTime.now();
    final shown = filter.apply(items, today);

    Widget card(MyTask item) =>
        MyTaskCard(item, key: ValueKey(taskDeletionKey(item.task)), uid: uid);

    return Column(
      children: [
        _Width(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            child: TaskFilterBar(
              projects: projects,
              shown: shown.length,
              total: items.length,
            ),
          ),
        ),
        Expanded(
          child: switch (shown) {
            [] => EmptyState(
              icon: Icons.search_off,
              title: 'No matching tasks',
              message: 'Try a different search, or fewer filters.',
              action: OutlinedButton(
                onPressed: () => ref
                    .read(taskFilterProvider.notifier)
                    .change(filter.cleared()),
                child: const Text('Clear filters'),
              ),
            ),
            _ when filter.sort == TaskSort.dueDate => _GroupedTasks(
              groupByDue(shown, today, (item) => item.task),
              card: card,
            ),
            _ => _TaskListView(
              itemCount: shown.length,
              itemBuilder: (context, index) => card(shown[index]),
            ),
          },
        ),
      ],
    );
  }
}

/// Each group's heading, then its tasks.
class _GroupedTasks extends StatelessWidget {
  const _GroupedTasks(this.groups, {required this.card});

  final Map<DueGroup, List<MyTask>> groups;
  final Widget Function(MyTask) card;

  @override
  Widget build(BuildContext context) {
    // Without any due dates, a lone "No due date" heading says nothing.
    final headings = groups.keys.any((group) => group != DueGroup.noDate);
    // Headings and tasks in one lazy list.
    final entries = <Object>[
      for (final MapEntry(key: group, value: items) in groups.entries) ...[
        if (headings) group,
        ...items,
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
        final MyTask item => card(item),
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

/// Centres [child] and keeps it to a readable width on wide screens.
class _Width extends StatelessWidget {
  const _Width({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}

/// A single column of cards, at a readable width.
class _TaskListView extends StatelessWidget {
  const _TaskListView({required this.itemCount, required this.itemBuilder});

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return _Width(
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
        separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.xs),
      ),
    );
  }
}
