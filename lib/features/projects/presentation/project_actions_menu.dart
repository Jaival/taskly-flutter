import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/project.dart';
import 'project_deletion.dart';
import 'project_form.dart';

/// The "⋮" menu on a project: Edit for editors, Delete for the owner.
/// Hidden entirely for viewers, who can't do either.
class ProjectActionsMenu extends ConsumerWidget {
  const ProjectActionsMenu({
    super.key,
    required this.project,
    required this.uid,
    this.onDeleted,
  });

  final Project project;
  final String uid;

  /// Called once the user confirms deleting, e.g. to leave a detail page.
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canEdit = project.canEdit(uid);
    final isOwner = project.isOwner(uid);
    if (!canEdit && !isOwner) return const SizedBox(height: 40);

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
                onDeleted?.call();
              }
            },
            child: const Text('Delete'),
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
