import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.task_alt_outlined,
      title: 'No tasks yet',
      message: 'Tasks are being rebuilt and will be back soon.',
    );
  }
}
