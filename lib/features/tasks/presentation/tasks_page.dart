import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/task_repository.dart';
import 'task_card.dart';
import 'task_form.dart';

/// `/tasks`: the user's personal tasks. Project tasks live on their
/// project's page.
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
          final visible => _TaskListView(
            itemCount: visible.length,
            itemBuilder: (context, index) => TaskCard(
              key: ValueKey(visible[index].id),
              task: visible[index],
            ),
          ),
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
