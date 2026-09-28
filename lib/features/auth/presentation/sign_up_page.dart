import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: const EmptyState(
        icon: Icons.person_add_alt_outlined,
        title: 'Create your account',
        message: 'Sign-up is being rebuilt and will be back soon.',
      ),
    );
  }
}
