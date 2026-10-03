import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/connection.dart';
import '../../../core/data/firestore_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/domain/project_role.dart';
import '../domain/invite.dart';
import 'invite_firestore.dart';

/// Sends, answers and cancels project invites.
class InviteRepository {
  InviteRepository(this._db, {this._saved = untilSent});

  final FirebaseFirestore _db;

  /// How long to wait for a write: not at all while offline, in the app.
  final AwaitWrite _saved;

  CollectionReference<Invite> get _invites => invitesCollection(_db);

  /// Invites [email] to the project. Inviting someone again replaces their
  /// old invite, so a declined invite can be re-sent.
  Future<void> sendInvite({
    required String projectId,
    required String projectName,
    required String email,
    required ProjectRole role,
    required String invitedBy,
  }) {
    final invite = Invite(
      projectId: projectId,
      projectName: projectName,
      email: Invite.normalizeEmail(email),
      role: role,
      invitedBy: invitedBy,
    );
    return _saved(_invites.doc(invite.id).set(invite));
  }

  /// Invites [invitedBy] sent for the project that haven't been accepted.
  /// The `invitedBy` filter is required: the rules only let you list the
  /// invites you sent.
  Stream<List<Invite>> watchSentInvites({
    required String projectId,
    required String invitedBy,
  }) => _invites
      .where('projectId', isEqualTo: projectId)
      .where('invitedBy', isEqualTo: invitedBy)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            if (doc.data().status != InviteStatus.accepted) doc.data(),
        ]..sort((a, b) => a.email.compareTo(b.email)),
      );

  /// Pending invites addressed to [email], which must be the user's verified
  /// email or the rules refuse the query.
  Stream<List<Invite>> watchReceivedInvites(String email) => _invites
      .where('email', isEqualTo: Invite.normalizeEmail(email))
      .where('status', isEqualTo: InviteStatus.pending.name)
      .snapshots()
      .map((snapshot) => [for (final doc in snapshot.docs) doc.data()]);

  /// Joins the project with the invite's role.
  ///
  /// One batch marks the invite accepted and adds [uid] to the project; the
  /// rules only allow the second because of the first. The invitee can't
  /// read the project yet, so this writes the two membership fields
  /// directly. `arrayUnion` appends, which is what the rules expect.
  Future<void> accept(Invite invite, {required String uid}) async {
    final batch = _db.batch()
      ..update(_invites.doc(invite.id), {'status': InviteStatus.accepted.name})
      ..update(_db.collection('projects').doc(invite.projectId), {
        'memberIds': FieldValue.arrayUnion([uid]),
        'roles.$uid': invite.role.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await _saved(batch.commit());
  }

  Future<void> decline(Invite invite) => _saved(
    _invites.doc(invite.id).update({'status': InviteStatus.declined.name}),
  );

  /// Withdraws an invite (the sender) or clears it away (the invitee).
  Future<void> cancel(Invite invite) =>
      _saved(_invites.doc(invite.id).delete());

  /// Deletes every invite [invitedBy] sent for the project, e.g. because
  /// the project is being deleted.
  Future<void> deleteProjectInvites({
    required String projectId,
    required String invitedBy,
  }) async {
    final sent = await _invites
        .where('projectId', isEqualTo: projectId)
        .where('invitedBy', isEqualTo: invitedBy)
        .get();
    final batch = _db.batch();
    for (final doc in sent.docs) {
      batch.delete(doc.reference);
    }
    await _saved(batch.commit());
  }
}

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(
    ref.watch(firestoreProvider),
    saved: ref.watch(connectionProvider).sentOrQueued,
  ),
);

/// Invites waiting for the signed-in user's answer. Empty until they've
/// verified their email, since an unverified address can't claim invites.
final receivedInvitesProvider = StreamProvider<List<Invite>>((ref) {
  final email = ref.watch(
    currentUserProvider.select(
      (user) => switch (user) {
        final user? when user.emailVerified => user.email,
        _ => null,
      },
    ),
  );
  if (email == null) return Stream.value(const []);
  return ref.watch(inviteRepositoryProvider).watchReceivedInvites(email);
});

/// Invites the signed-in user sent for a project and nobody has accepted.
final sentInvitesProvider = StreamProvider.autoDispose
    .family<List<Invite>, String>((ref, projectId) {
      final uid = ref.watch(currentUserProvider.select((user) => user?.uid));
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(inviteRepositoryProvider)
          .watchSentInvites(projectId: projectId, invitedBy: uid);
    });
