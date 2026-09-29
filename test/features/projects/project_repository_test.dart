import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/projects/domain/project.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProjectRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = ProjectRepository(db);
  });

  test('a new project is owned by its creator', () async {
    final id = await repository.createProject(
      ownerId: 'alice',
      name: '  Launch ',
      priority: Priority.high,
    );

    final project = await repository.watchProject(id).first;
    expect(project?.name, 'Launch');
    expect(project?.ownerId, 'alice');
    expect(project?.memberIds, ['alice']);
    expect(project?.roles, {'alice': ProjectRole.owner});
    expect(project?.priority, Priority.high);
  });

  test('lists only projects the user is a member of, newest first', () async {
    Future<void> seed(String id, List<String> members, int day) =>
        db.doc('projects/$id').set({
          'name': id,
          'memberIds': members,
          'updatedAt': Timestamp.fromDate(DateTime(2026, 1, day)),
        });
    await seed('old', ['alice'], 1);
    await seed('new', ['alice', 'bob'], 3);
    await seed('bobs', ['bob'], 2);

    final projects = await repository.watchProjects('alice').first;
    expect([for (final p in projects) p.id], ['new', 'old']);
  });

  test('editing details leaves the members alone', () async {
    final id = await repository.createProject(ownerId: 'alice', name: 'x');
    // Someone joins after the editor loaded the project.
    await db.doc('projects/$id').update({
      'memberIds': ['alice', 'bob'],
      'roles.bob': 'viewer',
    });

    await repository.updateDetails(
      id,
      name: 'Renamed',
      description: 'Now with a description',
      priority: Priority.low,
      status: TaskStatus.inProgress,
    );

    final project = (await repository.watchProject(id).first)!;
    expect(project.name, 'Renamed');
    expect(project.status, TaskStatus.inProgress);
    expect(project.memberIds, ['alice', 'bob']);
  });

  test("deleting a project deletes its tasks, and nobody else's", () async {
    final id = await repository.createProject(ownerId: 'alice', name: 'x');
    for (var i = 0; i < 3; i++) {
      await db.collection('projects/$id/tasks').add({'title': 'task $i'});
    }
    await db.collection('projects/other/tasks').add({'title': 'keep me'});

    await repository.deleteProject(id);

    expect((await db.doc('projects/$id').get()).exists, isFalse);
    expect((await db.collection('projects/$id/tasks').get()).docs, isEmpty);
    expect(
      (await db.collection('projects/other/tasks').get()).docs,
      hasLength(1),
    );
  });
}
