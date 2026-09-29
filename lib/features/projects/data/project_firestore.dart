import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/data/firestore_fields.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../domain/project.dart';

/// The `projects` collection, typed so reads return [Project]s.
CollectionReference<Project> projectsCollection(FirebaseFirestore db) => db
    .collection('projects')
    .withConverter(
      fromFirestore: projectFromFirestore,
      toFirestore: projectToFirestore,
    );

Project projectFromFirestore(
  DocumentSnapshot<Map<String, Object?>> snapshot,
  SnapshotOptions? _,
) {
  final data = snapshot.data() ?? const {};
  return Project(
    id: snapshot.id,
    ownerId: data.string('ownerId'),
    name: data.string('name'),
    description: data.string('description'),
    priority: Priority.fromName(data['priority']),
    status: TaskStatus.fromName(data['status']),
    memberIds: data.stringList('memberIds'),
    roles: data
        .stringMap('roles')
        .map((uid, role) => MapEntry(uid, ProjectRole.fromName(role))),
    createdAt: data.dateTime('createdAt'),
    updatedAt: data.dateTime('updatedAt'),
  );
}

/// Every write sets `updatedAt` to the server's clock; security rules check it.
Map<String, Object?> projectToFirestore(Project project, SetOptions? _) => {
  'ownerId': project.ownerId,
  'name': project.name,
  'description': project.description,
  'priority': project.priority.name,
  'status': project.status.name,
  'memberIds': project.memberIds,
  'roles': {
    for (final MapEntry(key: uid, value: role) in project.roles.entries)
      uid: role.name,
  },
  'createdAt': createdAtValue(project.createdAt),
  'updatedAt': FieldValue.serverTimestamp(),
};
