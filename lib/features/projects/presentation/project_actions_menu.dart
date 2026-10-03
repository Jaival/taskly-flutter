import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';
import 'project_deletion.dart';
import 'project_form.dart';

/// The "⋮" menu on a project: Edit for editors, Delete for the owner, and
/// Leave for everyone else.
class ProjectActionsMenu extends ConsumerWidget {
  const ProjectActionsMenu({
    super.key,
    required this.project,
    required this.uid,
    this.onGone,
  });

  final Project project;
  final String uid;

  /// Called once the user has deleted or left the project, e.g. to close
  /// its page.
  final VoidCallback? onGone;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave "${project.name}"?',
      message: "You'll lose access until someone invites you again.",
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(projectRepositoryProvider)
          .removeMember(project.id, uid: uid);
      onGone?.call();
      messenger.showSnackBar(
        SnackBar(content: Text('You left "${project.name}".')),
      );
    } on FirebaseException {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't leave \"${project.name}\".")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = project.canEdit(uid);
    final isOwner = project.isOwner(uid);
    if (project.roleOf(uid) == null) return const SizedBox(height: 40);

    return MenuAnchor(
      menuChildren: [
        if (canEdit)
          MenuItemButton(
            leadingIcon: const Icon(Icons.edit_outlined),
            onPressed: () => showProjectForm(context, project: project),
            child: const Text('Edit'),
          ),
        if (isOwner)
          MenuItemButton(
            leadingIcon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              if (await deleteProjectWithUndo(context, ref, project)) {
                onGone?.call();
              }
            },
            child: const Text('Delete'),
          ),
        if (!isOwner)
          MenuItemButton(
            leadingIcon: const Icon(Icons.logout),
            onPressed: () => _leave(context, ref),
            child: const Text('Leave project'),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Actions for ${project.name}',
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
