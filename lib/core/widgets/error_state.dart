import 'package:flutter/material.dart';

import 'empty_state.dart';

/// Shown when loading data fails, with an optional retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.message = 'Please check your connection and try again.',
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
    );
  }
}
