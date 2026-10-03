import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_provider.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../domain/checklist_item.dart';
import '../domain/task.dart';
import '../domain/task_activity.dart';
import 'task_activity_firestore.dart';
import 'task_firestore.dart';

class TaskRepository {
  TaskRepository(
    this._db, {
    DateTime Function()? clock,
    AppUser? Function()? currentUser,
  }) : _clock = clock ?? DateTime.now,
       _currentUser = currentUser ?? _nobody;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  /// Who is making the changes, for the activity log. Without one, nothing
  /// is logged.
  final AppUser? Function() _currentUser;

  static AppUser? _nobody() => null;

  /// Firestore allows at most 500 writes per batch.
  static const _maxBatchWrites = 500;

  /// How many of a task's latest comments and changes are shown.
  static const _activityLimit = 100;

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
    final batch = _db.batch()
      ..set(
        doc,
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
    _log(batch, projectId, doc.id, {ActivityKind.created: ''});
    await batch.commit();
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
  }) {
    final newTitle = title.trim();
    final newDescription = description.trim();
    final batch = _db.batch()
      ..update(_doc(task), {
        'title': newTitle,
        'description': newDescription,
        'priority': priority.name,
        'status': status.name,
        ..._completedAt(task, status),
        'dueDate': dueDateToFirestore(dueDate),
        if (checklist != null)
          'checklist': checklistToFirestore(_tidy(checklist)),
        // Only when given: personal tasks have no assignee field in the
        // form. `() => null` unassigns.
        if (assigneeId != null) 'assigneeId': assigneeId(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    final newDue = dueDateActivityValue(dueDate);
    _log(batch, task.projectId, task.id, {
      if (newTitle != task.title) ActivityKind.title: newTitle,
      if (newDescription != task.description) ActivityKind.description: '',
      if (status != task.status) ActivityKind.status: status.name,
      if (priority != task.priority) ActivityKind.priority: priority.name,
      if (assigneeId case final assignee? when assignee() != task.assigneeId)
        ActivityKind.assignee: assignee() ?? '',
      if (newDue != dueDateActivityValue(task.dueDate))
        ActivityKind.dueDate: newDue,
    });
    return batch.commit();
  }

  /// Changes only the status. The rules let viewers do this, but nothing
  /// else, on tasks assigned to them.
  Future<void> setStatus(Task task, TaskStatus status) {
    final batch = _db.batch()
      ..update(_doc(task), {
        'status': status.name,
        ..._completedAt(task, status),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    if (status != task.status) {
      _log(batch, task.projectId, task.id, {ActivityKind.status: status.name});
    }
    return batch.commit();
  }

  /// Deletes the task, and its comments and activity with it: Firestore
  /// doesn't delete a subcollection with its parent.
  Future<void> deleteTask(Task task) async {
    final activity = switch (task.projectId) {
      null => null,
      final projectId => await taskActivityCollection(
        _db,
        projectId,
        task.id,
      ).get(),
    };
    await _deleteAll([
      if (activity != null)
        for (final entry in activity.docs) entry.reference,
      _doc(task),
    ]);
  }

  /// Deletes all of [uid]'s personal tasks, when their account is deleted.
  Future<void> deletePersonalTasks(String uid) async {
    final tasks = await _db
        .collection('tasks')
        .where('ownerId', isEqualTo: uid)
        .get();
    await _deleteAll([for (final task in tasks.docs) task.reference]);
  }

  Future<void> _deleteAll(List<DocumentReference<Object?>> documents) async {
    for (var i = 0; i < documents.length; i += _maxBatchWrites) {
      final batch = _db.batch();
      documents.skip(i).take(_maxBatchWrites).forEach(batch.delete);
      await batch.commit();
    }
  }

  /// The latest comments and changes on a project task, oldest first.
  Stream<List<TaskActivity>> watchActivity(String projectId, String taskId) =>
      taskActivityCollection(_db, projectId, taskId)
          .orderBy('createdAt')
          .limitToLast(_activityLimit)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs) ?activityFromFirestore(doc),
            ],
          );

  /// Adds a comment to a project task. Any member may, viewers included.
  Future<void> addComment(Task task, String text) async {
    final (projectId, author) = (task.projectId, _currentUser());
    if (projectId == null || author == null) return;
    await taskActivityCollection(_db, projectId, task.id).add(
      newActivityToFirestore(
        kind: ActivityKind.comment,
        author: author,
        value: text.trim(),
      ),
    );
  }

  /// Deletes a comment. The rules let its author, and the project's owner
  /// and editors.
  Future<void> deleteComment(Task task, TaskActivity comment) async {
    final projectId = task.projectId;
    if (projectId == null) return;
    await taskActivityCollection(
      _db,
      projectId,
      task.id,
    ).doc(comment.id).delete();
  }

  /// Records [changes] (what changed, and to what) in the task's activity
  /// log, in the same [batch] as the change itself, so the log can't say
  /// something that didn't happen. Only project tasks have a log.
  void _log(
    WriteBatch batch,
    String? projectId,
    String taskId,
    Map<ActivityKind, String> changes,
  ) {
    final author = _currentUser();
    if (projectId == null || author == null) return;
    final activity = taskActivityCollection(_db, projectId, taskId);
    for (final MapEntry(key: kind, :value) in changes.entries) {
      batch.set(
        activity.doc(),
        newActivityToFirestore(kind: kind, author: author, value: value),
      );
    }
  }

  /// What to write to `completedAt` when [task] moves to [status]: now when
  /// it becomes complete, nothing when it already was (so editing a done
  /// task doesn't move it to today), and null when it's open.
  static Map<String, Object?> _completedAt(Task task, TaskStatus status) => {
    if (status != TaskStatus.complete)
      'completedAt': null
    else if (!task.isComplete)
      'completedAt': FieldValue.serverTimestamp(),
  };

  /// Trimmed, without blank items.
  static List<ChecklistItem> _tidy(List<ChecklistItem> items) => [
    for (final item in items)
      if (item.text.trim() case final text when text.isNotEmpty)
        item.copyWith(text: text),
  ];
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    ref.watch(firestoreProvider),
    // Read when a change is made, not now: the repository outlives sign-ins.
    currentUser: () => ref.read(authRepositoryProvider).currentUser,
  ),
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

/// A project task, by where it lives.
typedef ProjectTaskRef = ({String projectId, String taskId});

/// The comments and changes on a project task, oldest first.
///
/// `autoDispose` and restarted when the user changes, like
/// [projectTasksProvider].
final taskActivityProvider = StreamProvider.autoDispose
    .family<List<TaskActivity>, ProjectTaskRef>((ref, task) {
      ref.watch(authStateProvider.select((user) => user.value?.uid));
      return ref
          .watch(taskRepositoryProvider)
          .watchActivity(task.projectId, task.taskId);
    });
