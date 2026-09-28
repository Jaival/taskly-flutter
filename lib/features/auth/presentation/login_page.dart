import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: const EmptyState(
        icon: Icons.lock_outline,
        title: 'Log in',
        message: 'Sign-in is being rebuilt and will be back soon.',
      ),
    );
  }
}
