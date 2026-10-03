import 'package:flutter/foundation.dart';

import '../../../core/domain/project_role.dart';

enum InviteStatus {
  pending,
  accepted,
  declined;

  static InviteStatus fromName(Object? name) =>
      values.asNameMap()[name] ?? pending;
}

/// An invitation to join a project, stored at `invites/{id}`.
///
/// The ID is always [idFor] the project and email. That makes invites unique
/// per person and project, and lets security rules look an invite up directly
/// when the invitee joins the project.
@immutable
class Invite {
  const Invite({
    required this.projectId,
    required this.projectName,
    required this.email,
    required this.role,
    required this.invitedBy,
    this.status = InviteStatus.pending,
    this.createdAt,
  });

  final String projectId;

  /// Copied from the project, because the invitee can't read the project
  /// until they've joined it.
  final String projectName;

  /// Lowercase email of the person invited.
  final String email;

  /// [ProjectRole.editor] or [ProjectRole.viewer]. Never owner.
  final ProjectRole role;

  /// User ID of the person who sent the invite.
  final String invitedBy;

  final InviteStatus status;
  final DateTime? createdAt;

  String get id => idFor(projectId: projectId, email: email);

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String idFor({required String projectId, required String email}) =>
      '${projectId}_${normalizeEmail(email)}';

  @override
  bool operator ==(Object other) =>
      other is Invite &&
      other.projectId == projectId &&
      other.projectName == projectName &&
      other.email == email &&
      other.role == role &&
      other.invitedBy == invitedBy &&
      other.status == status &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    projectId,
    projectName,
    email,
    role,
    invitedBy,
    status,
    createdAt,
  );

  @override
  String toString() => 'Invite($id, ${status.name})';
}
