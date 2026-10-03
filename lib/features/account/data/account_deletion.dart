import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../projects/data/project_repository.dart';
import '../../tasks/data/task_repository.dart';

/// Deletes the signed-in user's account and everything that is theirs.
///
/// There's no server code to do this (no Cloud Functions), so the app does
/// it as the user, with what the security rules already allow them:
/// leaving projects, and deleting their own projects, tasks and profile.
class AccountDeletion {
  AccountDeletion({
    required this.auth,
    required this.projects,
    required this.tasks,
    required this.profiles,
  });

  final AuthRepository auth;
  final ProjectRepository projects;
  final TaskRepository tasks;
  final UserProfileRepository profiles;

  /// Throws an `AuthFailure` if [password] is wrong, before deleting
  /// anything. If the connection drops part-way, the account is still
  /// there, and deleting it again finishes the job.
  Future<void> deleteAccount({required String password}) async {
    final uid = auth.currentUser?.uid;
    if (uid == null) return;

    // First: Firebase only deletes an account soon after a sign-in. Finding
    // that out after the data was gone would leave an empty account behind.
    await auth.reauthenticate(password);

    for (final project in await projects.watchProjects(uid).first) {
      if (project.ownerId == uid) {
        // Their tasks and invites go with them.
        await projects.deleteProject(project);
      } else {
        await projects.removeMember(project.id, uid: uid);
      }
    }
    await tasks.deletePersonalTasks(uid);
    await profiles.deleteProfile(uid);

    // Last: without the account, the rules would refuse everything above.
    await auth.deleteAccount();
  }
}

final accountDeletionProvider = Provider<AccountDeletion>(
  (ref) => AccountDeletion(
    auth: ref.watch(authRepositoryProvider),
    projects: ref.watch(projectRepositoryProvider),
    tasks: ref.watch(taskRepositoryProvider),
    profiles: ref.watch(userProfileRepositoryProvider),
  ),
);
