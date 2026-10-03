import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../tasks/presentation/task_form.dart';
import '../data/project_repository.dart';
import 'project_members.dart';

/// Opens the form to add a task to the project, as its "Add task" button
/// does. For the keyboard shortcut, which has only the project's ID.
///
/// Does nothing for a viewer, who can't add tasks, or before the project
/// has loaded.
Future<void> showNewProjectTaskForm(
  BuildContext context,
  WidgetRef ref,
  String projectId,
) async {
  final uid = ref.read(authStateProvider).value?.uid ?? '';
  final project = ref.read(projectProvider(projectId)).value;
  if (project == null || !project.canEdit(uid)) return;
  await showTaskForm(
    context,
    projectId: projectId,
    members: memberNames(readMembers(ref, project), uid),
  );
}
