import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/dialogs.dart';
import '../data/project_repository.dart';
import '../domain/project.dart';

/// IDs of projects the user deleted whose "Undo" snackbar is still showing.
/// They're hidden from lists but not deleted yet.
class PendingProjectDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String id) => state = {...state, id};

  void show(String id) => state = {...state}..remove(id);
}

final pendingProjectDeletionsProvider =
    NotifierProvider<PendingProjectDeletions, Set<String>>(
      PendingProjectDeletions.new,
    );

/// Asks for confirmation, hides the project, and offers "Undo". The project
/// is only deleted once the snackbar closes without Undo being pressed.
///
/// Deleting straight away and re-creating on Undo wouldn't work: the rules
/// (rightly) won't let anyone create a project with other members already
/// in it, or with an old `createdAt`.
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

  // Captured now: the page may be gone by the time the snackbar closes.
  final pending = ref.read(pendingProjectDeletionsProvider.notifier);
  final repository = ref.read(projectRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  pending.hide(project.id);
  unawaited(_deleteUnlessUndone(project, pending, repository, messenger));
  return true;
}

const _undoWindow = Duration(seconds: 6);

Future<void> _deleteUnlessUndone(
  Project project,
  PendingProjectDeletions pending,
  ProjectRepository repository,
  ScaffoldMessengerState messenger,
) async {
  final reason = await messenger
      .showSnackBar(
        SnackBar(
          content: Text('Deleted "${project.name}".'),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
          // Snack bars with an action stay open by default. This one must
          // close on its own, because closing is what confirms the delete.
          persist: false,
          duration: _undoWindow,
        ),
      )
      .closed;

  if (reason == SnackBarClosedReason.action) {
    pending.show(project.id);
    return;
  }
  try {
    await repository.deleteProject(project.id);
  } on FirebaseException {
    messenger.showSnackBar(
      SnackBar(content: Text("Couldn't delete ${project.name}.")),
    );
  } finally {
    // Deleted: it's already gone from the lists. Failed: show it again.
    pending.show(project.id);
  }
}
