import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/project_role.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../data/invite_repository.dart';
import '../domain/invite.dart';
import 'invite_form.dart';

/// Invites waiting for the signed-in user's answer, each with Accept and
/// Decline. Shows nothing if there are none.
class ReceivedInvites extends ConsumerWidget {
  const ReceivedInvites({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(receivedInvitesProvider).value ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final invite in invites)
          Padding(
            key: ValueKey(invite.id),
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _InviteCard(invite: invite),
          ),
      ],
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.invite});

  final Invite invite;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _answer({required bool accept}) async {
    final invite = widget.invite;
    final repository = ref.read(inviteRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _busy = true);
    try {
      if (accept) {
        await repository.accept(
          invite,
          uid: ref.read(authRepositoryProvider).currentUser!.uid,
        );
        router.go(Routes.project(invite.projectId));
      } else {
        await repository.decline(invite);
      }
    } on FirebaseException {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? "Couldn't join ${invite.projectName}. It may have been "
                      'deleted.'
                : "Couldn't decline the invite. Try again.",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invite = widget.invite;
    final inviter = ref.watch(userProfileProvider(invite.invitedBy)).value;
    final from = switch (inviter?.displayName.trim()) {
      final name? when name.isNotEmpty => name,
      _ => 'Someone',
    };
    final asRole = switch (invite.role) {
      ProjectRole.editor => 'an editor',
      ProjectRole.viewer => 'a viewer',
      ProjectRole.owner => 'an owner',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invite.projectName, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$from invited you as $asRole. ${describeRole(invite.role)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: _busy ? null : () => _answer(accept: false),
                  child: const Text('Decline'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _answer(accept: true),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
