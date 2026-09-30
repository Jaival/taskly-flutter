import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../domain/task.dart';

/// Tasks in one project: `projects/{projectId}/tasks`.
CollectionReference<Task> projectTasksCollection(
  FirebaseFirestore db,
  String projectId,
) => _typed(db.collection('projects').doc(projectId).collection('tasks'));

/// Personal tasks: `tasks`.
CollectionReference<Task> personalTasksCollection(FirebaseFirestore db) =>
    _typed(db.collection('tasks'));

CollectionReference<Task> _typed(
  CollectionReference<Map<String, Object?>> collection,
) => collection.withConverter(
  fromFirestore: taskFromFirestore,
  toFirestore: taskToFirestore,
);

Task taskFromFirestore(
  DocumentSnapshot<Map<String, Object?>> snapshot,
  SnapshotOptions? _,
) {
  final data = snapshot.data() ?? const {};
  // projects/{projectId}/tasks/{id} has a grandparent; tasks/{id} doesn't.
  final project = snapshot.reference.parent.parent;
  return Task(
    id: snapshot.id,
    projectId: project?.id,
    ownerId: data.string('ownerId'),
    title: data.string('title'),
    description: data.string('description'),
    priority: Priority.fromName(data['priority']),
    status: TaskStatus.fromName(data['status']),
    assigneeId: data.stringOrNull('assigneeId'),
    dueDate: switch (data.dateTime('dueDate')?.toUtc()) {
      null => null,
      final utc => DateTime(utc.year, utc.month, utc.day),
    },
    order: data.number('order'),
    createdAt: data.dateTime('createdAt'),
    updatedAt: data.dateTime('updatedAt'),
  );
}

/// `projectId` isn't written: it comes from the path, so it can't disagree
/// with where the task actually lives.
Map<String, Object?> taskToFirestore(Task task, SetOptions? _) => {
  'ownerId': task.ownerId,
  'title': task.title,
  'description': task.description,
  'priority': task.priority.name,
  'status': task.status.name,
  'assigneeId': task.assigneeId,
  'dueDate': dueDateToFirestore(task.dueDate),
  'order': task.order,
  'createdAt': createdAtValue(task.createdAt),
  'updatedAt': FieldValue.serverTimestamp(),
};

/// A due date is a calendar day, stored as midnight UTC on that day. Read
/// back as that day in local time, it's the same day in every time zone.
Timestamp? dueDateToFirestore(DateTime? due) => due == null
    ? null
    : Timestamp.fromDate(DateTime.utc(due.year, due.month, due.day));
