import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/project_role.dart';
import 'package:taskly/features/sharing/data/invite_repository.dart';
import 'package:taskly/features/sharing/domain/invite.dart';

void main() {
  late FakeFirebaseFirestore db;
  late InviteRepository repository;

  setUp(() {
    db = FakeFirebaseFirestore();
    repository = InviteRepository(db);
  });

  Future<void> invite(
    String email, {
    String projectId = 'p1',
    ProjectRole role = ProjectRole.viewer,
  }) => repository.sendInvite(
    projectId: projectId,
    projectName: 'Launch',
    email: email,
    role: role,
    invitedBy: 'alice',
  );

  test('an invite is stored under {projectId}_{email}, lowercased', () async {
    await invite('  Erin@Example.com ', role: ProjectRole.editor);

    final saved = (await db.doc('invites/p1_erin@example.com').get()).data()!;
    expect(saved['email'], 'erin@example.com');
    expect(saved['role'], 'editor');
    expect(saved['status'], 'pending');
    expect(saved['invitedBy'], 'alice');
  });

  test('inviting someone again replaces a declined invite', () async {
    await invite('erin@example.com');
    final first =
        (await repository.watchReceivedInvites('erin@example.com').first)
            .single;
    await repository.decline(first);
    expect(
      await repository.watchReceivedInvites('erin@example.com').first,
      isEmpty,
    );

    await invite('erin@example.com', role: ProjectRole.editor);
    final again = await repository
        .watchReceivedInvites('erin@example.com')
        .first;
    expect(again.single.role, ProjectRole.editor);
  });

  test('the sender sees what is not yet accepted, by email', () async {
    await invite('zoe@example.com');
    await invite('erin@example.com');
    await invite('other@example.com', projectId: 'p2');
    await db.doc('invites/p1_zoe@example.com').update({'status': 'declined'});

    final sent = await repository
        .watchSentInvites(projectId: 'p1', invitedBy: 'alice')
        .first;
    expect(
      [for (final i in sent) i.email],
      ['erin@example.com', 'zoe@example.com'],
    );
    expect(sent.last.status, InviteStatus.declined);
  });

  test('accepting joins the project with the invited role', () async {
    await db.doc('projects/p1').set({
      'ownerId': 'alice',
      'memberIds': ['alice'],
      'roles': {'alice': 'owner'},
    });
    await invite('erin@example.com', role: ProjectRole.editor);
    final received =
        (await repository.watchReceivedInvites('erin@example.com').first)
            .single;

    await repository.accept(received, uid: 'erin');

    final project = (await db.doc('projects/p1').get()).data()!;
    expect(project['memberIds'], ['alice', 'erin']);
    expect(project['roles'], {'alice': 'owner', 'erin': 'editor'});
    expect(
      (await db.doc('invites/${received.id}').get()).data()!['status'],
      'accepted',
    );
  });

  test('cancelling deletes the invite', () async {
    await invite('erin@example.com');
    final sent = await repository
        .watchSentInvites(projectId: 'p1', invitedBy: 'alice')
        .first;

    await repository.cancel(sent.single);

    expect((await db.collection('invites').get()).docs, isEmpty);
  });
}
