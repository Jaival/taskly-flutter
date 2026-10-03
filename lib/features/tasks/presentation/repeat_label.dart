import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../domain/task.dart';
import 'due_date_label.dart';

/// "Every week" with a repeat icon, for a task card. Nothing if the task
/// doesn't repeat.
class RepeatLabel extends StatelessWidget {
  const RepeatLabel(this.task, {super.key});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final repeat = task.repeat;
    if (repeat == null || !task.repeats) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Repeats ${repeat.label.toLowerCase()}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            repeat.label,
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Says that completing a task that repeats added the next one, due [due].
void showNextTaskAdded(
  ScaffoldMessengerState messenger,
  MaterialLocalizations localizations,
  DateTime due,
) => messenger.showSnackBar(
  SnackBar(
    content: Text(
      'Next one added, due '
      '${formatDueDate(localizations, due, DateTime.now())}.',
    ),
  ),
);
