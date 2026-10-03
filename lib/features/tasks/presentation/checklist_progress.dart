import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../domain/task.dart';

/// "2/5" with a checklist icon, for a task card. Nothing without a
/// checklist.
class ChecklistProgress extends StatelessWidget {
  const ChecklistProgress(this.task, {super.key});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final total = task.checklist.length;
    if (total == 0) return const SizedBox.shrink();
    final done = task.checklistDone;
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$done of $total checklist items done',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done == total ? Icons.checklist : Icons.checklist_rtl,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$done/$total',
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
