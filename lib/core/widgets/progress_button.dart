import 'package:flutter/material.dart';

/// A [FilledButton] that shows a spinner and ignores taps while [busy], so a
/// form can't be submitted twice.
class ProgressButton extends StatelessWidget {
  const ProgressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: '$label in progress',
              ),
            )
          : Text(label),
    );
  }
}
