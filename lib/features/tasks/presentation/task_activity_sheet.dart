import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/form_error.dart';
import '../../auth/data/auth_repository.dart';
import '../data/task_repository.dart';
import '../domain/due_date.dart';
import '../domain/task.dart';
import '../domain/task_activity.dart';
import 'due_date_label.dart';

/// Opens the comments and activity log of a project [task]. Pass the
/// project's [members], as user ID → name, to name who a task was assigned
/// to. [canModerate] lets the user delete other people's comments too.
Future<void> showTaskActivity(
  BuildContext context, {
  required Task task,
  Map<String, String>? members,
  bool canModerate = false,
}) => showAdaptiveSheet<void>(
  context,
  builder: (context) =>
      TaskActivitySheet(task: task, members: members, canModerate: canModerate),
);

/// What happened, as a sentence: "Alex moved this to In progress". [uid] is
/// the reader, who is "You".
String describeActivity(
  TaskActivity entry, {
  required String? uid,
  required MaterialLocalizations localizations,
  required DateTime now,
  Map<String, String>? members,
}) {
  final byYou = entry.authorId == uid;
  final who = byYou ? 'You' : _authorName(entry);
  final value = entry.value;
  return switch (entry.kind) {
    ActivityKind.comment => '$who commented',
    ActivityKind.created => '$who created this task',
    ActivityKind.title => '$who renamed this to "$value"',
    ActivityKind.description => '$who changed the description',
    ActivityKind.status =>
      '$who moved this to ${TaskStatus.fromName(value).label}',
    ActivityKind.priority =>
      '$who set the priority to ${Priority.fromName(value).label}',
    ActivityKind.assignee => switch (value) {
      '' => '$who unassigned this',
      _ when value == uid =>
        byYou ? 'You assigned this to yourself' : '$who assigned this to you',
      _ when value == entry.authorId => '$who assigned this to themselves',
      // Listed away from its project, where the members aren't known.
      _ when members == null => '$who changed the assignee',
      _ => switch (members[value]) {
        final name? => '$who assigned this to $name',
        null => '$who assigned this to someone no longer in the project',
      },
    },
    ActivityKind.dueDate => switch (DateTime.tryParse(value)) {
      _ when value.isEmpty => '$who removed the due date',
      final due? =>
        '$who set the due date to ${formatDueDate(localizations, due, now)}',
      null => '$who changed the due date',
    },
  };
}

String _authorName(TaskActivity entry) =>
    entry.authorName.isEmpty ? 'Someone' : entry.authorName;

/// "Just now", "5 min ago", "3 hr ago", "Yesterday", "4 days ago", then the
/// date. Null is a comment still on its way to the server.
String timeAgo(
  MaterialLocalizations localizations,
  DateTime? at,
  DateTime now,
) {
  if (at == null) return 'Just now';
  final since = now.difference(at);
  if (since.inMinutes < 1) return 'Just now';
  if (since.inHours < 1) return '${since.inMinutes} min ago';
  if (since.inHours < 24) return '${since.inHours} hr ago';
  return switch (-daysUntil(at, now)) {
    <= 1 => 'Yesterday',
    final days when days < 7 => '$days days ago',
    _ => formatDueDate(localizations, at, now, weekday: false),
  };
}

class TaskActivitySheet extends ConsumerStatefulWidget {
  const TaskActivitySheet({
    super.key,
    required this.task,
    this.members,
    this.canModerate = false,
  });

  /// A project task. Personal tasks have no comments.
  final Task task;

  /// The project's members, as user ID → name. Null where they aren't
  /// known (the Tasks page).
  final Map<String, String>? members;

  /// Whether the user may delete anyone's comment: owners and editors.
  /// Everyone can delete their own.
  final bool canModerate;

  @override
  ConsumerState<TaskActivitySheet> createState() => _TaskActivitySheetState();
}

class _TaskActivitySheetState extends ConsumerState<TaskActivitySheet> {
  final _comment = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  /// Clears the box straight away: the comment shows up in the list at once
  /// (and is sent when the connection is back, if there isn't one).
  void _send() {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    _comment.clear();
    setState(() => _error = null);
    unawaited(_add(text));
  }

  Future<void> _add(String text) async {
    try {
      await ref.read(taskRepositoryProvider).addComment(widget.task, text);
    } on FirebaseException {
      if (!mounted) return;
      // Give the text back, unless they've started another.
      if (_comment.text.isEmpty) _comment.text = text;
      setState(() => _error = "Couldn't send your comment. Try again.");
    }
  }

  Future<void> _delete(TaskActivity comment) async {
    final repository = ref.read(taskRepositoryProvider);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this comment?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await repository.deleteComment(widget.task, comment);
    } on FirebaseException {
      if (mounted) setState(() => _error = "Couldn't delete the comment.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
    final activity = ref.watch(
      taskActivityProvider((projectId: task.projectId!, taskId: task.id)),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: math.min(640, MediaQuery.sizeOf(context).height * 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleLarge,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Comments and activity',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: switch (activity) {
                AsyncData(value: []) => Text(
                  'No comments yet. Changes to the task will show here too.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                // Newest at the bottom, next to the box, and in view when
                // the sheet opens.
                AsyncData(value: final entries) => ListView.separated(
                  reverse: true,
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return entry.isComment
                        ? _Comment(
                            key: ValueKey(entry.id),
                            entry: entry,
                            byYou: entry.authorId == uid,
                            onDelete:
                                entry.authorId == uid || widget.canModerate
                                ? () => _delete(entry)
                                : null,
                          )
                        : _Change(
                            key: ValueKey(entry.id),
                            entry: entry,
                            uid: uid,
                            members: widget.members,
                          );
                  },
                ),
                AsyncError() => Text(
                  "Couldn't load the comments.",
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                _ => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: CircularProgressIndicator(),
                  ),
                ),
              },
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              FormError(error),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _comment,
                    decoration: const InputDecoration(
                      labelText: 'Add a comment',
                      // The limit is enforced; a counter isn't worth the
                      // space.
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    // Wraps as it grows, but Enter sends.
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    // Instead of the default, which also leaves the box.
                    onEditingComplete: _send,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Level with a one-line box, and with its last line when it
                // has grown.
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: IconButton.filled(
                    tooltip: 'Send',
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({
    super.key,
    required this.entry,
    required this.byYou,
    required this.onDelete,
  });

  final TaskActivity entry;
  final bool byYou;

  /// Null if the user may not delete it.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = _authorName(entry);
    final when = timeAgo(
      MaterialLocalizations.of(context),
      entry.createdAt,
      DateTime.now(),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 16,
            child: Text(name.characters.first.toUpperCase()),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: byYou ? 'You' : name,
                      style: theme.textTheme.labelLarge,
                    ),
                    TextSpan(
                      text: ' · $when',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(entry.value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        if (onDelete != null)
          IconButton(
            tooltip: 'Delete comment',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
      ],
    );
  }
}

/// A change to the task, quieter than a comment.
class _Change extends StatelessWidget {
  const _Change({
    super.key,
    required this.entry,
    required this.uid,
    required this.members,
  });

  final TaskActivity entry;
  final String? uid;
  final Map<String, String>? members;

  static IconData _iconFor(ActivityKind kind) => switch (kind) {
    ActivityKind.comment => Icons.chat_bubble_outline,
    ActivityKind.created => Icons.add_circle_outline,
    ActivityKind.title => Icons.edit_outlined,
    ActivityKind.description => Icons.notes,
    ActivityKind.status => Icons.swap_horiz,
    ActivityKind.priority => Icons.flag_outlined,
    ActivityKind.assignee => Icons.person_outline,
    ActivityKind.dueDate => Icons.event_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    final localizations = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final what = describeActivity(
      entry,
      uid: uid,
      members: members,
      localizations: localizations,
      now: now,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // As wide as a comment's avatar, so the text lines up.
        SizedBox(
          width: 32,
          child: Icon(_iconFor(entry.kind), size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            '$what · ${timeAgo(localizations, entry.createdAt, now)}',
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
