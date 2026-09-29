import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import 'project_card.dart';
import 'project_deletion.dart';
import 'project_form.dart';

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  Future<void> _create(BuildContext context) async {
    final id = await showProjectForm(context);
    if (id != null && context.mounted) context.go(Routes.project(id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = ref.watch(pendingProjectDeletionsProvider);
    final projects = ref.watch(projectsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: switch (projects) {
        AsyncData(:final value) => _ProjectGrid(
          projects: [
            for (final project in value)
              if (!hidden.contains(project.id)) project,
          ],
          onCreate: () => _create(context),
        ),
        AsyncError() => ErrorState(
          message: "Couldn't load your projects.",
          onRetry: () => ref.invalidate(projectsProvider),
        ),
        _ => const _ProjectGrid.loading(),
      },
    );
  }
}

class _ProjectGrid extends StatelessWidget {
  const _ProjectGrid({required this.projects, required this.onCreate});

  const _ProjectGrid.loading() : projects = null, onCreate = null;

  /// Null while loading.
  final List<Project>? projects;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final projects = this.projects;
    if (projects != null && projects.isEmpty) {
      return EmptyState(
        icon: Icons.folder_outlined,
        title: 'No projects yet',
        message:
            'Create a project to plan its tasks, then invite people to '
            'work on it with you.',
        action: FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create a project'),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          // Extra bottom padding so the button never covers the last row.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxl * 2,
          ),
          sliver: SliverGrid(
            // As many columns as fit at up to 360px each: one on phones,
            // two on tablets, three or more on desktops.
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 184,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            delegate: projects == null
                ? SliverChildBuilderDelegate(
                    (context, _) => const ProjectCardSkeleton(),
                    childCount: 6,
                  )
                : SliverChildBuilderDelegate(
                    (context, index) => ProjectCard(
                      key: ValueKey(projects[index].id),
                      project: projects[index],
                    ),
                    childCount: projects.length,
                  ),
          ),
        ),
      ],
    );
  }
}
