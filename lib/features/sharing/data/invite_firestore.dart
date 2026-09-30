import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/domain/project_role.dart';
import '../domain/invite.dart';

/// The `invites` collection, typed so reads return [Invite]s.
///
/// Write with `invitesCollection(db).doc(invite.id).set(invite)`, never
/// `add()`: the rules require the ID to be `Invite.idFor(...)`.
CollectionReference<Invite> invitesCollection(FirebaseFirestore db) => db
    .collection('invites')
    .withConverter(
      fromFirestore: inviteFromFirestore,
      toFirestore: inviteToFirestore,
    );

Invite inviteFromFirestore(
  DocumentSnapshot<Map<String, Object?>> snapshot,
  SnapshotOptions? _,
) {
  final data = snapshot.data() ?? const {};
  return Invite(
    projectId: data.string('projectId'),
    projectName: data.string('projectName'),
    email: data.string('email'),
    role: ProjectRole.fromName(data['role']),
    invitedBy: data.string('invitedBy'),
    status: InviteStatus.fromName(data['status']),
    createdAt: data.dateTime('createdAt'),
  );
}

Map<String, Object?> inviteToFirestore(Invite invite, SetOptions? _) => {
  'projectId': invite.projectId,
  'projectName': invite.projectName,
  'email': Invite.normalizeEmail(invite.email),
  'role': invite.role.name,
  'invitedBy': invite.invitedBy,
  'status': invite.status.name,
  'createdAt': createdAtValue(invite.createdAt),
};
