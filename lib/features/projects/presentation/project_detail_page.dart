import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/data/auth_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import 'project_actions_menu.dart';
import 'project_deletion.dart';

/// `/projects/:id`: a project's details and its tasks.
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final isBeingDeleted = ref.watch(
      pendingProjectDeletionsProvider.select((ids) => ids.contains(projectId)),
    );
    final uid = ref.watch(authStateProvider).value?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        // Opened by URL there's nothing to pop, so go to the list instead.
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.projects),
        ),
        title: Text(project.value?.name ?? ''),
        actions: [
          if (project.value case final project? when !isBeingDeleted)
            ProjectActionsMenu(
              project: project,
              uid: uid,
              onDeleted: () {
                if (context.mounted) context.go(Routes.projects);
              },
            ),
        ],
      ),
      body: switch (project) {
        AsyncData(value: final project?) when !isBeingDeleted =>
          _ProjectDetails(project: project),
        AsyncData() => EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'Project not found',
          message: "It may have been deleted, or you're not a member.",
          action: FilledButton(
            onPressed: () => context.go(Routes.projects),
            child: const Text('Back to projects'),
          ),
        ),
        AsyncError() => ErrorState(
          onRetry: () => ref.invalidate(projectProvider(projectId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProjectDetails extends ConsumerWidget {
  const _ProjectDetails({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tasks = ref.watch(projectTasksProvider(project.id));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PriorityChip(project.priority),
            StatusChip(project.status),
            Text(
              project.memberIds.length == 1
                  ? 'Only you'
                  : '${project.memberIds.length} members',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        if (project.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(project.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Tasks', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ...switch (tasks) {
          AsyncData(:final value) when value.isEmpty => [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No tasks yet.'),
            ),
          ],
          AsyncData(:final value) => [
            for (final task in value) _TaskRow(task: task),
          ],
          AsyncError() => [const Text("Couldn't load tasks.")],
          _ => [const LinearProgressIndicator()],
        },
      ],
    );
  }
}

// Replaced by the shared TaskCard in the tasks rewrite (roadmap 3.4).
class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(StatusChip.iconFor(task.status)),
      title: Text(task.title),
      trailing: PriorityChip(task.priority),
    );
  }
}
