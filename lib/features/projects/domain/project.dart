import 'package:flutter/foundation.dart';

import '../../../core/domain/priority.dart';
import '../../../core/domain/project_role.dart';
import '../../../core/domain/task_status.dart';

export '../../../core/domain/project_role.dart';

/// A shared project, stored at `projects/{id}`.
///
/// [memberIds] and the keys of [roles] always hold the same user IDs. Both
/// exist because Firestore can query an array (`memberIds` array-contains
/// uid, for "my projects") but security rules look roles up in a map.
@immutable
class Project {
  const Project({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.memberIds,
    required this.roles,
    this.description = '',
    this.priority = Priority.medium,
    this.status = TaskStatus.notStarted,
    this.createdAt,
    this.updatedAt,
  });

  /// A new project whose only member is its owner.
  factory Project.create({
    required String id,
    required String ownerId,
    required String name,
    String description = '',
    Priority priority = Priority.medium,
  }) => Project(
    id: id,
    ownerId: ownerId,
    name: name,
    description: description,
    priority: priority,
    memberIds: [ownerId],
    roles: {ownerId: ProjectRole.owner},
  );

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final Priority priority;
  final TaskStatus status;
  final List<String> memberIds;
  final Map<String, ProjectRole> roles;

  /// Set by the server. Null until the first write reaches it.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProjectRole? roleOf(String uid) => roles[uid];

  bool isOwner(String uid) => uid == ownerId;

  bool canEdit(String uid) => roleOf(uid)?.canEdit ?? false;

  Project copyWith({
    String? name,
    String? description,
    Priority? priority,
    TaskStatus? status,
    List<String>? memberIds,
    Map<String, ProjectRole>? roles,
  }) => Project(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    memberIds: memberIds ?? this.memberIds,
    roles: roles ?? this.roles,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Project &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.name == name &&
      other.description == description &&
      other.priority == priority &&
      other.status == status &&
      listEquals(other.memberIds, memberIds) &&
      mapEquals(other.roles, roles) &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    name,
    description,
    priority,
    status,
    Object.hashAll(memberIds),
    Object.hashAllUnordered(roles.entries.map((e) => (e.key, e.value))),
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'Project($id, $name)';
}
