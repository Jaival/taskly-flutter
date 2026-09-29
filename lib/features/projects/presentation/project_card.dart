import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/priority_chip.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/project.dart';
import 'project_actions_menu.dart';

class ProjectCard extends ConsumerWidget {
  const ProjectCard({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).value?.uid ?? '';
    final others = project.memberIds.length - 1;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.project(project.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PriorityChip(project.priority),
                  const Spacer(),
                  ProjectActionsMenu(project: project, uid: uid),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  project.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    project.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  StatusChip(project.status),
                  const Spacer(),
                  if (others > 0)
                    Tooltip(
                      message:
                          'Shared with $others '
                          '${others == 1 ? 'person' : 'people'}',
                      child: Row(
                        children: [
                          Icon(
                            Icons.group_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${others + 1}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey placeholder with the shape of a [ProjectCard], shown while loading.
class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 64, height: 20),
            SizedBox(height: AppSpacing.md),
            Skeleton(width: 180, height: 20),
            SizedBox(height: AppSpacing.sm),
            Skeleton(height: 14),
            Spacer(),
            Skeleton(width: 100, height: 16),
          ],
        ),
      ),
    );
  }
}
