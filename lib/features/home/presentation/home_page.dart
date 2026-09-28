import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.space_dashboard_outlined,
      title: 'Your dashboard',
      message: 'An overview of your projects and tasks will appear here.',
    );
  }
}
