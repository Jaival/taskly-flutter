import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.folder_outlined,
      title: 'No projects yet',
      message: 'Projects are being rebuilt and will be back soon.',
    );
  }
}
