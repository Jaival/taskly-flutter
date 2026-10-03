import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../sharing/presentation/invite_form.dart';
import '../../sharing/presentation/project_invites.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';

/// A member as the project page shows them.
typedef Member = ({String uid, String name, String? email, ProjectRole role});

/// The project's members, owner first, with names from their profiles.
List<Member> watchMembers(WidgetRef ref, Project project) => [
  for (final uid in project.memberIds)
    _member(uid, project, ref.watch(userProfileProvider(uid))),
];

/// [watchMembers] as they are right now, for use outside `build`.
List<Member> readMembers(WidgetRef ref, Project project) => [
  for (final uid in project.memberIds)
    _member(uid, project, ref.read(userProfileProvider(uid))),
];

/// Who a task can be assigned to, as user ID → name, marking [uid] as you.
Map<String, String> memberNames(List<Member> members, String uid) => {
  for (final member in members)
    member.uid: member.uid == uid ? '${member.name} (you)' : member.name,
};

Member _member(String uid, Project project, AsyncValue<UserProfile?> profile) {
  final value = profile.value;
  final name = switch ((value?.displayName.trim(), value?.email)) {
    (final name?, _) when name.isNotEmpty => name,
    (_, final email?) when email.isNotEmpty => email,
    // Loading, or a member whose profile couldn't be created.
    _ => 'Member',
  };
  return (
    uid: uid,
    name: name,
    email: value?.email,
    role: project.roleOf(uid) ?? ProjectRole.viewer,
  );
}

/// The members of a project and their roles. The owner can invite people,
/// change roles and remove members here.
class ProjectMembers extends ConsumerWidget {
  const ProjectMembers({
    super.key,
    required this.project,
    required this.members,
    required this.uid,
  });

  final Project project;
  final List<Member> members;

  /// The signed-in user.
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = project.isOwner(uid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Members',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: () => showInviteForm(
                  context,
                  projectId: project.id,
                  projectName: project.name,
                  memberEmails: {for (final member in members) ?member.email},
                ),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('Invite'),
              ),
          ],
        ),
        for (final member in members)
          _MemberTile(
            key: ValueKey(member.uid),
            project: project,
            member: member,
            isYou: member.uid == uid,
            canManage: isOwner && member.uid != uid,
          ),
        if (isOwner) ProjectInvites(projectId: project.id),
      ],
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    super.key,
    required this.project,
    required this.member,
    required this.isYou,
    required this.canManage,
  });

  final Project project;
  final Member member;
  final bool isYou;
  final bool canManage;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() change,
    String failure,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await change();
    } on FirebaseException {
      messenger.showSnackBar(SnackBar(content: Text(failure)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${member.name}?',
      message:
          "They'll lose access to ${project.name}. Tasks assigned to them "
          'stay assigned until you change them.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await _run(
      context,
      () => ref
          .read(projectRepositoryProvider)
          .removeMember(project.id, uid: member.uid),
      "Couldn't remove ${member.name}.",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = member.name.characters.first.toUpperCase();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text(initial)),
      title: Text(
        isYou ? '${member.name} (you)' : member.name,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(member.role.label),
      trailing: canManage
          ? MenuAnchor(
              menuChildren: [
                for (final role in [ProjectRole.editor, ProjectRole.viewer])
                  if (role != member.role)
                    MenuItemButton(
                      leadingIcon: Icon(
                        role == ProjectRole.editor
                            ? Icons.edit_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => _run(
                        context,
                        () => ref
                            .read(projectRepositoryProvider)
                            .changeRole(
                              project.id,
                              uid: member.uid,
                              role: role,
                            ),
                        "Couldn't change ${member.name}'s role.",
                      ),
                      child: Text('Make ${role.label.toLowerCase()}'),
                    ),
                MenuItemButton(
                  leadingIcon: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () => _remove(context, ref),
                  child: const Text('Remove from project'),
                ),
              ],
              builder: (context, controller, _) => IconButton(
                tooltip: 'Actions for ${member.name}',
                icon: const Icon(Icons.more_vert),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            )
          : null,
    );
  }
}
