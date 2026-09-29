import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/projects/domain/project.dart';
import 'package:taskly/features/sharing/data/invite_firestore.dart';
import 'package:taskly/features/sharing/domain/invite.dart';

void main() {
  const invite = Invite(
    projectId: 'p1',
    projectName: 'Launch',
    email: '  Erin@Example.com ',
    role: ProjectRole.editor,
    invitedBy: 'alice',
  );

  test('the ID combines project and normalised email', () {
    expect(invite.id, 'p1_erin@example.com');
    expect(Invite.idFor(projectId: 'p1', email: 'ERIN@example.com'), invite.id);
  });

  test('round-trips through Firestore with a lowercase email', () async {
    final db = FakeFirebaseFirestore();
    final ref = invitesCollection(db).doc(invite.id);
    await ref.set(invite);

    final saved = (await ref.get()).data()!;
    expect(saved.email, 'erin@example.com');
    expect(saved.id, invite.id);
    expect(saved.role, ProjectRole.editor);
    expect(saved.status, InviteStatus.pending);
    expect(saved.createdAt, isNotNull);
  });
}
