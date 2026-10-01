import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_provider.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/checklist_item.dart';
import '../domain/task.dart';
import 'task_firestore.dart';

class TaskRepository {
  TaskRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  /// Personal tasks when [projectId] is null, otherwise the project's.
  CollectionReference<Task> _collection(String? projectId) => projectId == null
      ? personalTasksCollection(_db)
      : projectTasksCollection(_db, projectId);

  DocumentReference<Task> _doc(Task task) =>
      _collection(task.projectId).doc(task.id);

  /// [uid]'s personal tasks in list order. The `ownerId` filter is required:
  /// the rules only allow queries that can't return other people's tasks.
  Stream<List<Task>> watchPersonalTasks(String uid) =>
      _watch(_collection(null).where('ownerId', isEqualTo: uid));

  /// A project's tasks in list order.
  Stream<List<Task>> watchProjectTasks(String projectId) =>
      _watch(_collection(projectId));

  /// The tasks in one project assigned to [uid], in list order. One query
  /// per project, rather than a collection-group query across all of them:
  /// the rules can only allow a query they can check, and "member of the
  /// project in this path" can't be checked across paths.
  Stream<List<Task>> watchAssignedTasks(String projectId, String uid) =>
      _watch(_collection(projectId).where('assigneeId', isEqualTo: uid));

  Stream<List<Task>> _watch(Query<Task> query) => query
      .orderBy('order')
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);

  /// Adds a task to the end of the list and returns its ID. A personal task
  /// if [projectId] is null.
  Future<String> createTask({
    String? projectId,
    required String ownerId,
    required String title,
    String description = '',
    Priority priority = Priority.medium,
    String? assigneeId,
    DateTime? dueDate,
    List<ChecklistItem> checklist = const [],
  }) async {
    final doc = _collection(projectId).doc();
    await doc.set(
      Task(
        id: doc.id,
        projectId: projectId,
        ownerId: ownerId,
        title: title.trim(),
        description: description.trim(),
        priority: priority,
        assigneeId: assigneeId,
        dueDate: dueDate,
        checklist: _tidy(checklist),
        // Later tasks sort after earlier ones, without reading the list to
        // find the current last position.
        order: _clock().millisecondsSinceEpoch.toDouble(),
      ),
    );
    return doc.id;
  }

  /// Changes the content fields only, so an out-of-date copy can't undo
  /// someone else's change to the other fields.
  Future<void> updateDetails(
    Task task, {
    required String title,
    required String description,
    required Priority priority,
    required TaskStatus status,
    required DateTime? dueDate,
    List<ChecklistItem>? checklist,
    ValueGetter<String?>? assigneeId,
  }) => _doc(task).update({
    'title': title.trim(),
    'description': description.trim(),
    'priority': priority.name,
    'status': status.name,
    'dueDate': dueDateToFirestore(dueDate),
    if (checklist != null) 'checklist': checklistToFirestore(_tidy(checklist)),
    // Only when given: personal tasks have no assignee field in the form.
    // `() => null` unassigns.
    if (assigneeId != null) 'assigneeId': assigneeId(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Changes only the status. The rules let viewers do this, but nothing
  /// else, on tasks assigned to them.
  Future<void> setStatus(Task task, TaskStatus status) => _doc(
    task,
  ).update({'status': status.name, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> deleteTask(Task task) => _doc(task).delete();

  /// Trimmed, without blank items.
  static List<ChecklistItem> _tidy(List<ChecklistItem> items) => [
    for (final item in items)
      if (item.text.trim() case final text when text.isNotEmpty)
        item.copyWith(text: text),
  ];
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's personal tasks.
final personalTasksProvider = StreamProvider<List<Task>>((ref) {
  final uid = ref.watch(authStateProvider.select((user) => user.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(taskRepositoryProvider).watchPersonalTasks(uid);
});

/// A project's tasks, in list order.
///
/// Disposed when nothing shows it, and restarted when the user changes, so a
/// listener the rules denied (after leaving, or signing out) isn't reused.
final projectTasksProvider = StreamProvider.autoDispose
    .family<List<Task>, String>((ref, projectId) {
      ref.watch(authStateProvider.select((user) => user.value?.uid));
      return ref.watch(taskRepositoryProvider).watchProjectTasks(projectId);
    });

/// The signed-in user's tasks in one project. For the Tasks page, which
/// shows these beside personal tasks.
///
/// `autoDispose` and restarted when the user changes, like
/// [projectTasksProvider].
final assignedTasksProvider = StreamProvider.autoDispose
    .family<List<Task>, String>((ref, projectId) {
      final uid = ref.watch(
        authStateProvider.select((user) => user.value?.uid),
      );
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(taskRepositoryProvider)
          .watchAssignedTasks(projectId, uid);
    });
