import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/undo_delete.dart';
import '../../auth/data/auth_repository.dart';
import '../../my_tasks/data/my_tasks_provider.dart';
import '../../my_tasks/domain/my_task.dart';
import '../../my_tasks/domain/task_filter.dart';
import '../../my_tasks/presentation/my_task_card.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/project_form.dart';
import '../../tasks/domain/due_date.dart';
import '../../tasks/presentation/task_card.dart';
import '../../tasks/presentation/task_form.dart';
import 'progress_card.dart';

/// How many open tasks and recent projects the dashboard shows.
const _upNextCount = 5;
const _recentProjectCount = 4;

/// `/home`: counts, the last week's progress, the next few of the user's
/// tasks and recently changed projects.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  /// Opens the new-project form, then the project once it's created.
  Future<void> _createProject(BuildContext context) async {
    final id = await showProjectForm(context);
    if (id != null && context.mounted) context.go(Routes.project(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final hidden = ref.watch(pendingDeletionsProvider);
    final tasks = ref
        .watch(myTasksProvider)
        .whenData(
          (items) => [
            for (final item in items)
              if (!hidden.contains(taskDeletionKey(item.task))) item,
          ],
        );
    final projects = ref.watch(projectsProvider);

    // A brand-new account: nothing to summarise yet.
    if (tasks case AsyncData(value: [])) {
      if (projects case AsyncData(value: [])) {
        return EmptyState(
          icon: Icons.waving_hand_outlined,
          title: 'Welcome to Taskly',
          message:
              'Create a project to plan work with other people, or add a '
              'task just for yourself.',
          action: Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.icon(
                onPressed: () => _createProject(context),
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Create a project'),
              ),
              OutlinedButton.icon(
                // Once saved, the dashboard replaces this and lists it.
                onPressed: () => showTaskForm(context),
                icon: const Icon(Icons.task_alt_outlined),
                label: const Text('Add a task'),
              ),
            ],
          ),
        );
      }
    }

    final upNext = _UpNext(tasks: tasks, uid: user?.uid ?? '');
    final recent = _RecentProjects(projects: projects);

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(switch (user?.firstName) {
                  final name? => 'Hi, $name',
                  null => 'Hi there',
                }, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.md),
                _Stats(tasks: tasks, projects: projects),
                ProgressCard(tasks: tasks),
                const SizedBox(height: AppSpacing.lg),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: upNext),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(child: recent),
                    ],
                  )
                else ...[
                  upNext,
                  const SizedBox(height: AppSpacing.lg),
                  recent,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Counts of projects and the user's tasks by status. Each opens its list,
/// filtered to that status.
class _Stats extends ConsumerWidget {
  const _Stats({required this.tasks, required this.projects});

  final AsyncValue<List<MyTask>> tasks;
  final AsyncValue<List<Project>> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    int? count(TaskStatus status) =>
        tasks.value?.where((item) => item.task.status == status).length;
    // The Tasks page, showing only [status].
    void openTasks(TaskStatus status) {
      ref
          .read(taskFilterProvider.notifier)
          .change(TaskFilter(statuses: {status}));
      context.go(Routes.tasks);
    }

    final stats = [
      (
        label: 'Projects',
        count: projects.value?.length,
        onTap: () => context.go(Routes.projects),
      ),
      for (final (label, status) in [
        ('To do', TaskStatus.notStarted),
        ('In progress', TaskStatus.inProgress),
        ('Done', TaskStatus.complete),
      ])
        (label: label, count: count(status), onTap: () => openTasks(status)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four in a row when there's room, otherwise two by two.
        final perRow = constraints.maxWidth >= 600 ? 4 : 2;
        return Column(
          children: [
            for (var start = 0; start < stats.length; start += perRow)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    for (final (i, stat)
                        in stats.skip(start).take(perRow).indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _StatCard(
                          label: stat.label,
                          count: stat.count,
                          onTap: stat.onTap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;

  /// Null while loading.
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = this.count;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          label: count == null ? '$label: loading' : '$label: $count',
          excludeSemantics: true,
          button: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (count == null)
                  const Skeleton(width: 32, height: 32)
                else
                  Text('$count', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title with a "see all" link.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.linkLabel,
    required this.onPressed,
  });

  final String title;
  final String linkLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(onPressed: onPressed, child: Text(linkLabel)),
      ],
    );
  }
}

/// The first few of the user's open tasks: the most urgent by due date,
/// then the undated ones in list order.
class _UpNext extends ConsumerWidget {
  const _UpNext({required this.tasks, required this.uid});

  final AsyncValue<List<MyTask>> tasks;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Up next',
          linkLabel: 'All tasks',
          // All of them: whatever was filtered last time is cleared.
          onPressed: () {
            final filter = ref.read(taskFilterProvider);
            ref.read(taskFilterProvider.notifier).change(filter.cleared());
            context.go(Routes.tasks);
          },
        ),
        ...switch (tasks) {
          AsyncData(:final value) => switch (openTasksByDue(
            value,
            DateTime.now(),
            (item) => item.task,
          )) {
            [] => [
              _Placeholder(
                value.isEmpty ? 'No tasks yet.' : "You're all done. Nice work!",
              ),
            ],
            final open => [
              for (final item in open.take(_upNextCount))
                Padding(
                  key: ValueKey(taskDeletionKey(item.task)),
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: MyTaskCard(item, uid: uid),
                ),
            ],
          },
          AsyncError() => [const _Placeholder("Couldn't load your tasks.")],
          _ => [for (var i = 0; i < 3; i++) const TaskCardSkeleton()],
        },
      ],
    );
  }
}

/// The projects changed most recently.
class _RecentProjects extends StatelessWidget {
  const _RecentProjects({required this.projects});

  final AsyncValue<List<Project>> projects;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          title: 'Recent projects',
          linkLabel: 'All projects',
          onPressed: () => context.go(Routes.projects),
        ),
        ...switch (projects) {
          AsyncData(value: []) => [const _Placeholder('No projects yet.')],
          AsyncData(:final value) => [
            for (final project in value.take(_recentProjectCount))
              _ProjectTile(key: ValueKey(project.id), project: project),
          ],
          AsyncError() => [const _Placeholder("Couldn't load your projects.")],
          _ => [
            for (var i = 0; i < 3; i++)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Skeleton(height: 40),
                ),
              ),
          ],
        },
      ],
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final members = project.memberIds.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.go(Routes.project(project.id)),
        leading: Icon(StatusChip.iconFor(project.status)),
        title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          members == 1
              ? project.status.label
              : '${project.status.label} · $members members',
        ),
        trailing: PriorityChip(project.priority),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
