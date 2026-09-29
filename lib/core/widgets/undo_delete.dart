import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys (document paths, e.g. `projects/abc`) of things the user deleted
/// whose "Undo" snackbar is still showing. Lists hide them, but they aren't
/// deleted yet.
class PendingDeletions extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void hide(String key) => state = {...state, key};

  void show(String key) => state = {...state}..remove(key);
}

final pendingDeletionsProvider =
    NotifierProvider<PendingDeletions, Set<String>>(PendingDeletions.new);

const _undoWindow = Duration(seconds: 6);

/// Hides [key] straight away and shows [message] with an "Undo" action.
/// [delete] only runs once the snackbar closes without Undo being pressed.
///
/// Waiting is simpler than deleting at once and re-creating on Undo, and
/// always allowed: the rules won't let anyone re-create a document with its
/// old `createdAt`, or a project with other members already in it.
///
/// Returns immediately, so callers can navigate away while the snackbar is
/// showing.
void deleteWithUndo(
  BuildContext context,
  WidgetRef ref, {
  required String key,
  required String message,
  required String failureMessage,
  required Future<void> Function() delete,
}) {
  // Captured now: the page may be gone by the time the snackbar closes.
  final pending = ref.read(pendingDeletionsProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);

  pending.hide(key);
  unawaited(
    _deleteUnlessUndone(
      key: key,
      message: message,
      failureMessage: failureMessage,
      delete: delete,
      pending: pending,
      messenger: messenger,
    ),
  );
}

Future<void> _deleteUnlessUndone({
  required String key,
  required String message,
  required String failureMessage,
  required Future<void> Function() delete,
  required PendingDeletions pending,
  required ScaffoldMessengerState messenger,
}) async {
  final reason = await messenger
      .showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(label: 'Undo', onPressed: () {}),
          // Snack bars with an action stay open by default. This one must
          // close on its own, because closing is what confirms the delete.
          persist: false,
          duration: _undoWindow,
        ),
      )
      .closed;

  if (reason == SnackBarClosedReason.action) {
    pending.show(key);
    return;
  }
  try {
    await delete();
  } on Exception {
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
  } finally {
    // Deleted: it's already gone from the lists. Failed: show it again.
    pending.show(key);
  }
}
