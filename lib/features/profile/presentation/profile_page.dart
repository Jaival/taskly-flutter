import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/widgets/empty_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Opened directly by URL there's nothing to pop, so go home instead.
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('Profile'),
      ),
      body: const EmptyState(
        icon: Icons.person_outline,
        title: 'Your profile',
        message: 'Profile settings are being rebuilt and will be back soon.',
      ),
    );
  }
}
