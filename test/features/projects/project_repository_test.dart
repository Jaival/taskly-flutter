import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/projects/domain/project.dart';
import 'package:taskly/features/sharing/data/invite_repository.dart';

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

  Future<Project> projectWithBob() async {
    final id = await repository.createProject(ownerId: 'alice', name: 'x');
    await db.doc('projects/$id').update({
      'memberIds': ['alice', 'bob'],
      'roles.bob': 'viewer',
    });
    return (await repository.watchProject(id).first)!;
  }

  test('the owner can change a role', () async {
    final project = await projectWithBob();
    await repository.changeRole(
      project.id,
      uid: 'bob',
      role: ProjectRole.editor,
    );

    final saved = (await repository.watchProject(project.id).first)!;
    expect(saved.roleOf('bob'), ProjectRole.editor);
    expect(saved.memberIds, ['alice', 'bob']);
  });

  test('removing a member takes them out of both lists', () async {
    final project = await projectWithBob();
    await repository.removeMember(project.id, uid: 'bob');

    final saved = (await repository.watchProject(project.id).first)!;
    expect(saved.memberIds, ['alice']);
    expect(saved.roles, {'alice': ProjectRole.owner});
  });

  test("deleting a project deletes its tasks, and nobody else's", () async {
    final id = await repository.createProject(ownerId: 'alice', name: 'x');
    for (var i = 0; i < 3; i++) {
      await db.collection('projects/$id/tasks').add({'title': 'task $i'});
    }
    await db.collection('projects/other/tasks').add({'title': 'keep me'});

    await repository.deleteProject((await repository.watchProject(id).first)!);

    expect((await db.doc('projects/$id').get()).exists, isFalse);
    expect((await db.collection('projects/$id/tasks').get()).docs, isEmpty);
    expect(
      (await db.collection('projects/other/tasks').get()).docs,
      hasLength(1),
    );
  });

  test('deleting a project withdraws its invites', () async {
    final project = await projectWithBob();
    final invites = InviteRepository(db);
    for (final (projectId, email) in [
      (project.id, 'carol@example.com'),
      ('other', 'dave@example.com'),
    ]) {
      await invites.sendInvite(
        projectId: projectId,
        projectName: 'x',
        email: email,
        role: ProjectRole.viewer,
        invitedBy: 'alice',
      );
    }

    await repository.deleteProject(project);

    final left = await db.collection('invites').get();
    expect([for (final doc in left.docs) doc.id], ['other_dave@example.com']);
  });
}
