import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

/// The centred column shared by the login and sign-up pages: edge to edge on
/// phones, in a card on wider windows.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhone = MediaQuery.sizeOf(context).width < Breakpoints.medium;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        child,
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Taskly')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: isPhone
                  ? content
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: content,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
