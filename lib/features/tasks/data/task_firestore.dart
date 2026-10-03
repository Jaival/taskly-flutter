import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../domain/checklist_item.dart';
import '../domain/task.dart';
import '../domain/task_label.dart';
import '../domain/task_repeat.dart';

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
  return Task(
    id: snapshot.id,
    projectId: projectIdFromTaskPath(snapshot.reference.path),
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
    repeat: TaskRepeat.fromName(data['repeat']),
    checklist: checklistFromFirestore(data['checklist']),
    labels: labelsFromFirestore(data['labels']),
    order: data.number('order'),
    createdAt: data.dateTime('createdAt'),
    updatedAt: data.dateTime('updatedAt'),
    completedAt: data.dateTime('completedAt'),
  );
}

/// The project a task is in, from its path: `projects/{projectId}/tasks/{id}`,
/// or null for a personal task at `tasks/{id}`.
///
/// From the path rather than `reference.parent.parent`: on the web, asking
/// a top-level collection for its parent throws inside the Firestore
/// plugin, and personal tasks would never load.
String? projectIdFromTaskPath(String path) => switch (path.split('/')) {
  ['projects', final projectId, 'tasks', _] => projectId,
  _ => null,
};

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
  'repeat': task.repeat?.name,
  'checklist': checklistToFirestore(task.checklist),
  'labels': labelsToFirestore(task.labels),
  'order': task.order,
  'createdAt': createdAtValue(task.createdAt),
  'updatedAt': FieldValue.serverTimestamp(),
  'completedAt': timestampOrNull(task.completedAt),
};

/// A due date is a calendar day, stored as midnight UTC on that day. Read
/// back as that day in local time, it's the same day in every time zone.
Timestamp? dueDateToFirestore(DateTime? due) => due == null
    ? null
    : Timestamp.fromDate(DateTime.utc(due.year, due.month, due.day));

/// A checklist is stored as a list of `{text, done}` maps. Items that aren't
/// maps are skipped, and missing fields get defaults, as for every field.
List<ChecklistItem> checklistFromFirestore(Object? value) => switch (value) {
  final List<Object?> items => [
    for (final item in items)
      if (item case final Map<String, Object?> fields)
        ChecklistItem(fields.string('text'), done: fields['done'] == true),
  ],
  _ => const [],
};

List<Map<String, Object?>> checklistToFirestore(List<ChecklistItem> items) => [
  for (final item in items) {'text': item.text, 'done': item.done},
];

/// Labels are stored as a list of `{name, color}` maps. As for a checklist,
/// anything else in the list is skipped, and so are nameless labels.
List<TaskLabel> labelsFromFirestore(Object? value) => switch (value) {
  final List<Object?> labels => [
    for (final label in labels)
      if (label case final Map<String, Object?> fields
          when fields.string('name').trim().isNotEmpty)
        TaskLabel(
          fields.string('name'),
          color: LabelColor.fromName(fields['color']),
        ),
  ],
  _ => const [],
};

List<Map<String, Object?>> labelsToFirestore(List<TaskLabel> labels) => [
  for (final label in labels) {'name': label.name, 'color': label.color.name},
];
