import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/priority_colors.dart';
import '../domain/priority.dart';

/// A small coloured label for a priority, used on project and task cards.
class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});

  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<PriorityColors>()!;
    return Semantics(
      label: '${priority.label} priority',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs / 2,
        ),
        decoration: BoxDecoration(
          color: colors.of(priority),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          priority.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onPriority,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
