import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/empty_state.dart';
import 'router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.explore_off_outlined,
        title: 'Page not found',
        message: "The page you're looking for doesn't exist or has moved.",
        action: FilledButton(
          onPressed: () => context.go(Routes.landing),
          child: const Text('Go home'),
        ),
      ),
    );
  }
}
