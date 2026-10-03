import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/connection.dart';
import '../../../core/data/firestore_provider.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../auth/data/auth_repository.dart';
import '../../sharing/data/invite_repository.dart';
import '../domain/project.dart';
import 'project_firestore.dart';

class ProjectRepository {
  ProjectRepository(this._db, {AwaitWrite saved = untilSent})
    : _saved = saved,
      _invites = InviteRepository(_db, saved: saved);

  final FirebaseFirestore _db;
  final InviteRepository _invites;

  /// How long to wait for a write: not at all while offline, in the app.
  final AwaitWrite _saved;

  CollectionReference<Project> get _projects => projectsCollection(_db);

  /// Firestore allows at most 500 writes per batch.
  static const _maxBatchWrites = 500;

  /// Projects [uid] owns or was invited to, most recently changed first.
  /// The `memberIds` filter is required: the security rules only allow
  /// queries that can't return other people's projects.
  Stream<List<Project>> watchProjects(String uid) => _projects
      .where('memberIds', arrayContains: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);

  /// The project, or null if it doesn't exist.
  Stream<Project?> watchProject(String id) =>
      _projects.doc(id).snapshots().map((snapshot) => snapshot.data());

  /// Creates a project owned by [ownerId] and returns its ID.
  Future<String> createProject({
    required String ownerId,
    required String name,
    String description = '',
    Priority priority = Priority.medium,
  }) async {
    final doc = _projects.doc();
    await _saved(
      doc.set(
        Project.create(
          id: doc.id,
          ownerId: ownerId,
          name: name.trim(),
          description: description.trim(),
          priority: priority,
        ),
      ),
    );
    return doc.id;
  }

  /// Changes only the content fields. Uses `update()` rather than writing
  /// the whole project, so a member who joined meanwhile isn't removed by an
  /// out-of-date copy.
  Future<void> updateDetails(
    String id, {
    required String name,
    required String description,
    required Priority priority,
    required TaskStatus status,
  }) => _saved(
    _projects.doc(id).update({
      'name': name.trim(),
      'description': description.trim(),
      'priority': priority.name,
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Gives a member a different role. Only the owner may.
  Future<void> changeRole(
    String projectId, {
    required String uid,
    required ProjectRole role,
  }) => _saved(
    _projects.doc(projectId).update({
      'roles.$uid': role.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Takes a member out of the project: the owner removing someone, or a
  /// member leaving. Their tasks keep them as assignee until reassigned.
  Future<void> removeMember(String projectId, {required String uid}) => _saved(
    _projects.doc(projectId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      'roles.$uid': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );

  /// Deletes the project, all of its tasks (with their comments and
  /// activity) and the invites to it.
  ///
  /// Firestore doesn't delete subcollections with their parent, so the tasks
  /// are fetched once and deleted in batches first. (v1 used a live listener
  /// here that never stopped, and kept deleting tasks created later.)
  Future<void> deleteProject(Project project) async {
    final id = project.id;
    await _invites.deleteProjectInvites(
      projectId: id,
      invitedBy: project.ownerId,
    );
    final projectDoc = _db.collection('projects').doc(id);
    final tasks = await projectDoc.collection('tasks').get();
    final activity = await Future.wait([
      for (final task in tasks.docs)
        task.reference.collection('activity').get(),
    ]);
    final documents = [
      for (final entries in activity)
        for (final entry in entries.docs) entry.reference,
      for (final task in tasks.docs) task.reference,
    ];

    for (var i = 0; i < documents.length; i += _maxBatchWrites) {
      final batch = _db.batch();
      documents.skip(i).take(_maxBatchWrites).forEach(batch.delete);
      await _saved(batch.commit());
    }
    // Last, so the deletes above can still check membership.
    await _saved(projectDoc.delete());
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(
    ref.watch(firestoreProvider),
    saved: ref.watch(connectionProvider).sentOrQueued,
  ),
);

/// The signed-in user's projects.
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(authStateProvider.select((user) => user.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchProjects(uid);
});

/// One project by ID. Null if it doesn't exist or the user can't see it.
///
/// A denied listener is dead: Firestore doesn't retry it. So this starts a
/// new one when the user changes, and when they join or leave the project
/// (seen in [projectsProvider]); otherwise someone who opened a project
/// before being let in would keep seeing "not found".
final projectProvider = StreamProvider.autoDispose.family<Project?, String>((
  ref,
  id,
) {
  ref
    ..watch(authStateProvider.select((user) => user.value?.uid))
    ..watch(
      projectsProvider.select(
        (projects) => projects.value?.any((project) => project.id == id),
      ),
    );
  return ref
      .watch(projectRepositoryProvider)
      .watchProject(id)
      // A non-member gets "permission denied", which to them is the same as
      // the project not existing.
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stackTrace, sink) =>
              error is FirebaseException && error.code == 'permission-denied'
              ? sink.add(null)
              : sink.addError(error, stackTrace),
        ),
      );
});
