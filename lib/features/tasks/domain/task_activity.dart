import 'package:flutter/foundation.dart';

/// What an entry in a task's activity log records: a comment, or a change
/// to one of the task's fields.
///
/// Stored in Firestore by [name], so renaming a value is a data migration.
enum ActivityKind {
  comment,
  created,
  title,
  description,
  status,
  priority,
  assignee,
  dueDate,
  labels;

  /// Null for a kind this version of the app doesn't know, written by a
  /// newer one. Those entries are skipped rather than shown wrongly.
  static ActivityKind? fromName(Object? name) => values.asNameMap()[name];
}

/// A comment on a project task, or a record of a change to it ("Alex moved
/// this to In progress"). Lives at
/// `projects/{projectId}/tasks/{taskId}/activity/{id}`.
///
/// Personal tasks have none: there's nobody else to tell.
@immutable
class TaskActivity {
  const TaskActivity({
    required this.id,
    required this.kind,
    required this.authorId,
    this.authorName = '',
    this.value = '',
    this.createdAt,
  });

  final String id;
  final ActivityKind kind;

  /// Who wrote the comment or made the change.
  final String authorId;

  /// Their name when they did. Kept with the entry, so it still has a name
  /// after they leave the project or delete their account.
  final String authorName;

  /// The comment's text, or what the field changed to: a status or priority
  /// by name, the assignee's user ID, the due date as `2026-10-03`, the new
  /// title, the labels' names a line each. Empty when the field was cleared, and for kinds with nothing
  /// more to say.
  final String value;

  /// Set by the server. Null until the write reaches it.
  final DateTime? createdAt;

  bool get isComment => kind == ActivityKind.comment;

  @override
  bool operator ==(Object other) =>
      other is TaskActivity &&
      other.id == id &&
      other.kind == kind &&
      other.authorId == authorId &&
      other.authorName == authorName &&
      other.value == value &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, kind, authorId, authorName, value, createdAt);

  @override
  String toString() => 'TaskActivity($id, ${kind.name}, $value)';
}
