import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/invite_repository.dart';
import '../domain/invite.dart';

/// The invites the signed-in owner sent for a project that nobody has
/// accepted, each with a button to cancel it. For the project page to embed
/// below its members. Shows nothing if there are none.
class ProjectInvites extends ConsumerWidget {
  const ProjectInvites({super.key, required this.projectId});

  final String projectId;

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Invite invite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(inviteRepositoryProvider).cancel(invite);
    } on FirebaseException {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Couldn't cancel the invite to ${invite.email}."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(sentInvitesProvider(projectId)).value ?? [];
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final invite in invites)
          ListTile(
            key: ValueKey(invite.id),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.mail_outline)),
            title: Text(invite.email, overflow: TextOverflow.ellipsis),
            subtitle: invite.status == InviteStatus.declined
                ? Text(
                    'Declined · ${invite.role.label}',
                    style: TextStyle(color: colors.error),
                  )
                : Text('Invited · ${invite.role.label}'),
            trailing: IconButton(
              tooltip: 'Cancel invite to ${invite.email}',
              icon: const Icon(Icons.close),
              onPressed: () => _cancel(context, ref, invite),
            ),
          ),
      ],
    );
  }
}
