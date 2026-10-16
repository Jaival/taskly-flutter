import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/priority_colors.dart';
import '../domain/priority.dart';

/// A small label for a priority, used on project and task cards: its name
/// beside a dot of its colour, on a tint of it.
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
          color: colors.tint(priority, theme.colorScheme.surface),
          borderRadius: AppRadius.xsAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.of(priority),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                priority.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
