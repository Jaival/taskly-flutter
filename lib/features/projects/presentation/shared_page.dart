import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../auth/data/auth_repository.dart';
import '../../sharing/data/invite_repository.dart';
import '../../sharing/presentation/received_invites.dart';
import '../data/project_repository.dart';
import 'project_card.dart';

/// `/shared`: invites waiting for an answer, and projects other people
/// shared with you.
///
/// "Shared with me" needs no collection of its own: it's the projects
/// you're a member of but don't own.
class SharedPage extends ConsumerWidget {
  const SharedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final uid = user?.uid;
    final invites = ref.watch(receivedInvitesProvider);
    final projects = ref
        .watch(projectsProvider)
        .whenData(
          (projects) => [
            for (final project in projects)
              if (project.ownerId != uid) project,
          ],
        );
    final unverified = user != null && !user.emailVerified;

    if (projects case AsyncError()) {
      return ErrorState(
        message: "Couldn't load the projects shared with you.",
        onRetry: () => ref.invalidate(projectsProvider),
      );
    }

    if ((invites, projects) case (AsyncData(value: []), AsyncData(value: []))) {
      return EmptyState(
        icon: Icons.group_outlined,
        title: 'Nothing shared with you',
        message: unverified
            ? 'Verify your email to see invites sent to it. Projects people '
                  'share with you will appear here.'
            : 'When someone invites you to a project, the invite and then '
                  'the project will appear here.',
      );
    }

    final shared = projects.value;
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (invites.value?.isNotEmpty ?? false) ...[
                      Text('Invites', style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.sm),
                      const ReceivedInvites(),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (unverified)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          'Verify your email to see invites sent to it.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    Text('Shared with me', style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    if (shared?.isEmpty ?? false)
                      Text(
                        'No shared projects yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverGrid(
            // The same grid as the projects page.
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: ProjectCard.heightFor(context),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            delegate: shared == null
                ? SliverChildBuilderDelegate(
                    (context, _) => const ProjectCardSkeleton(),
                    childCount: 3,
                  )
                : SliverChildBuilderDelegate(
                    (context, index) => ProjectCard(
                      key: ValueKey(shared[index].id),
                      project: shared[index],
                    ),
                    childCount: shared.length,
                  ),
          ),
        ),
      ],
    );
  }
}
