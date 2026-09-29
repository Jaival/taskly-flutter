import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_provider.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/project.dart';
import 'project_firestore.dart';

class ProjectRepository {
  ProjectRepository(this._db);

  final FirebaseFirestore _db;

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
    await doc.set(
      Project.create(
        id: doc.id,
        ownerId: ownerId,
        name: name.trim(),
        description: description.trim(),
        priority: priority,
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
  }) => _projects.doc(id).update({
    'name': name.trim(),
    'description': description.trim(),
    'priority': priority.name,
    'status': status.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  /// Deletes the project and all of its tasks.
  ///
  /// Firestore doesn't delete subcollections with their parent, so the tasks
  /// are fetched once and deleted in batches first. (v1 used a live listener
  /// here that never stopped, and kept deleting tasks created later.)
  Future<void> deleteProject(String id) async {
    final project = _db.collection('projects').doc(id);
    final tasks = await project.collection('tasks').get();

    for (var i = 0; i < tasks.docs.length; i += _maxBatchWrites) {
      final batch = _db.batch();
      for (final task in tasks.docs.skip(i).take(_maxBatchWrites)) {
        batch.delete(task.reference);
      }
      await batch.commit();
    }
    // Last, so the task deletes above can still check membership.
    await project.delete();
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ref.watch(firestoreProvider)),
);

/// The signed-in user's projects.
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final uid = ref.watch(authStateProvider.select((user) => user.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(projectRepositoryProvider).watchProjects(uid);
});

/// One project by ID. Null if it doesn't exist or the user can't see it.
final projectProvider = StreamProvider.family<Project?, String>(
  (ref, id) => ref
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
      ),
);
