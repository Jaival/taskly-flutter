import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/projects/data/project_firestore.dart';
import 'package:taskly/features/projects/domain/project.dart';

void main() {
  group('Project', () {
    final project = Project.create(id: 'p1', ownerId: 'alice', name: 'Launch')
        .copyWith(
          memberIds: ['alice', 'bob', 'carol'],
          roles: {
            'alice': ProjectRole.owner,
            'bob': ProjectRole.editor,
            'carol': ProjectRole.viewer,
          },
        );

    test('create makes the owner the only member', () {
      final fresh = Project.create(id: 'p', ownerId: 'alice', name: 'x');
      expect(fresh.memberIds, ['alice']);
      expect(fresh.roles, {'alice': ProjectRole.owner});
    });

    test('permissions follow roles', () {
      expect(project.canEdit('alice'), isTrue);
      expect(project.canEdit('bob'), isTrue);
      expect(project.canEdit('carol'), isFalse);
      expect(project.canEdit('stranger'), isFalse);
      expect(project.isOwner('alice'), isTrue);
      expect(project.isOwner('bob'), isFalse);
    });

    test('equality compares members and roles by value', () {
      expect(project.copyWith(), project);
      expect(project.copyWith(memberIds: ['alice']), isNot(project));
    });

    test('unknown roles parse as viewer, the safest role', () {
      expect(ProjectRole.fromName('admin'), ProjectRole.viewer);
    });
  });

  group('projectsCollection', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    test('round-trips a project through Firestore', () async {
      final ref = projectsCollection(db).doc();
      final project =
          Project.create(
            id: ref.id,
            ownerId: 'alice',
            name: 'Launch',
            description: 'Ship it',
            priority: Priority.high,
          ).copyWith(
            status: TaskStatus.inProgress,
            memberIds: ['alice', 'bob'],
            roles: {'alice': ProjectRole.owner, 'bob': ProjectRole.editor},
          );

      await ref.set(project);
      final saved = (await ref.get()).data()!;

      expect(saved.id, ref.id);
      expect(saved.name, 'Launch');
      expect(saved.description, 'Ship it');
      expect(saved.priority, Priority.high);
      expect(saved.status, TaskStatus.inProgress);
      expect(saved.memberIds, ['alice', 'bob']);
      expect(saved.roles, {
        'alice': ProjectRole.owner,
        'bob': ProjectRole.editor,
      });
      expect(saved.createdAt, isNotNull);
      expect(saved.updatedAt, isNotNull);
    });

    test('stores enums by name', () async {
      final ref = projectsCollection(db).doc('p1');
      await ref.set(Project.create(id: 'p1', ownerId: 'alice', name: 'x'));

      final raw = (await db.doc('projects/p1').get()).data()!;
      expect(raw['priority'], 'medium');
      expect(raw['status'], 'notStarted');
      expect(raw['roles'], {'alice': 'owner'});
    });

    test('keeps the original createdAt on later writes', () async {
      final ref = projectsCollection(db).doc('p1');
      await ref.set(Project.create(id: 'p1', ownerId: 'alice', name: 'x'));
      final first = (await ref.get()).data()!;

      await ref.set(first.copyWith(name: 'y'));
      final second = (await ref.get()).data()!;

      expect(second.name, 'y');
      expect(second.createdAt, first.createdAt);
    });

    test('reads malformed documents without throwing', () async {
      await db.doc('projects/bad').set({
        'name': 42,
        'priority': 'urgent',
        'memberIds': ['alice', 7],
        'roles': {'alice': 'owner', 'bob': 3},
      });

      final project = (await projectsCollection(db).doc('bad').get()).data()!;

      expect(project.name, '');
      expect(project.ownerId, '');
      expect(project.priority, Priority.medium);
      expect(project.memberIds, ['alice']);
      expect(project.roles, {'alice': ProjectRole.owner});
      expect(project.createdAt, isNull);
    });
  });
}
