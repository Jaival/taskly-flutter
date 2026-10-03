import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../auth/domain/app_user.dart';
import '../domain/task_activity.dart';

/// The comments and changes on one project task:
/// `projects/{projectId}/tasks/{taskId}/activity`.
CollectionReference<Map<String, Object?>> taskActivityCollection(
  FirebaseFirestore db,
  String projectId,
  String taskId,
) => db
    .collection('projects')
    .doc(projectId)
    .collection('tasks')
    .doc(taskId)
    .collection('activity');

/// Null for an entry of a kind this version doesn't know.
TaskActivity? activityFromFirestore(
  DocumentSnapshot<Map<String, Object?>> snapshot,
) {
  final data = snapshot.data() ?? const {};
  final kind = ActivityKind.fromName(data['kind']);
  if (kind == null) return null;
  return TaskActivity(
    id: snapshot.id,
    kind: kind,
    authorId: data.string('authorId'),
    authorName: data.string('authorName'),
    value: data.string('value'),
    createdAt: data.dateTime('createdAt'),
  );
}

/// A new entry by [author]. The rules only accept entries in the caller's
/// own name, stamped with the server's time.
Map<String, Object?> newActivityToFirestore({
  required ActivityKind kind,
  required AppUser author,
  String value = '',
}) => {
  'kind': kind.name,
  'authorId': author.uid,
  'authorName': _nameOf(author),
  'value': value,
  'createdAt': FieldValue.serverTimestamp(),
};

/// The rules allow 100 characters, as for a profile's display name.
String _nameOf(AppUser author) {
  final name = switch (author.displayName?.trim()) {
    final name? when name.isNotEmpty => name,
    _ => author.email ?? '',
  };
  return name.length <= 100 ? name : name.substring(0, 100);
}

/// A due date in the log: `2026-10-03`, or empty for none.
String dueDateActivityValue(DateTime? due) => due == null
    ? ''
    : '${due.year.toString().padLeft(4, '0')}-'
          '${due.month.toString().padLeft(2, '0')}-'
          '${due.day.toString().padLeft(2, '0')}';
