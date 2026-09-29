import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/firestore_provider.dart';
import '../domain/task.dart';
import 'task_firestore.dart';

class TaskRepository {
  TaskRepository(this._db);

  final FirebaseFirestore _db;

  /// A project's tasks in list order.
  Stream<List<Task>> watchProjectTasks(String projectId) =>
      projectTasksCollection(_db, projectId)
          .orderBy('order')
          .snapshots()
          .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(firestoreProvider)),
);

final projectTasksProvider = StreamProvider.family<List<Task>, String>(
  (ref, projectId) =>
      ref.watch(taskRepositoryProvider).watchProjectTasks(projectId),
);
