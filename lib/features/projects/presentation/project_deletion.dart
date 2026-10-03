import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/undo_delete.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';

/// The [pendingDeletionsProvider] key for the project with [id].
String projectDeletionKey(String id) => 'projects/$id';

/// Asks for confirmation, hides the project, and offers "Undo". The project
/// is only deleted once the snackbar closes without Undo being pressed.
///
/// Resolves to true as soon as the user confirms, so callers can navigate
/// away while the snackbar is showing.
Future<bool> deleteProjectWithUndo(
  BuildContext context,
  WidgetRef ref,
  Project project,
) async {
  final taskNote = 'Its tasks will be deleted too.';
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete "${project.name}"?',
    message: project.memberIds.length > 1
        ? '$taskNote It will also be removed for the '
              '${project.memberIds.length - 1} other people in it.'
        : taskNote,
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  final repository = ref.read(projectRepositoryProvider);
  deleteWithUndo(
    context,
    ref,
    key: projectDeletionKey(project.id),
    message: 'Deleted "${project.name}".',
    failureMessage: "Couldn't delete ${project.name}.",
    delete: () => repository.deleteProject(project),
  );
  return true;
}
