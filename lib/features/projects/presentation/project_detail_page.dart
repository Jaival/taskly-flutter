import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/page_title.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../core/widgets/undo_delete.dart';
import '../../auth/data/auth_repository.dart';
import '../../tasks/presentation/project_task_list.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import 'project_actions_menu.dart';
import 'project_deletion.dart';
import 'project_members.dart';

/// `/projects/:id`: a project's details and its tasks.
class ProjectDetailPage extends ConsumerWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(projectId));
    final isBeingDeleted = ref.watch(
      pendingDeletionsProvider.select(
        (keys) => keys.contains(projectDeletionKey(projectId)),
      ),
    );
    final uid = ref.watch(currentUserProvider)?.uid ?? '';

    return PageTitle(
      switch (project) {
        AsyncData(value: final project?) => project.name,
        AsyncData() => 'Project not found',
        _ => 'Project',
      },
      child: Scaffold(
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
                onGone: () {
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
      ),
    );
  }
}

class _ProjectDetails extends ConsumerWidget {
  const _ProjectDetails({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    final members = watchMembers(ref, project);

    final tasks = ProjectTaskList(
      projectId: project.id,
      uid: uid,
      canEdit: project.canEdit(uid),
      members: memberNames(members, uid),
    );
    final people = ProjectMembers(project: project, members: members, uid: uid);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Side by side when there's room, tasks first.
        final wide = constraints.maxWidth >= 900;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _Summary(project: project),
                const SizedBox(height: AppSpacing.lg),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: tasks),
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(child: people),
                    ],
                  )
                else ...[
                  tasks,
                  const SizedBox(height: AppSpacing.lg),
                  people,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Priority, status, member count and description.
class _Summary extends StatelessWidget {
  const _Summary({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
      ],
    );
  }
}
