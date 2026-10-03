import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/label_colors.dart';
import '../domain/task_label.dart';

/// A task's label: its name beside a dot of its colour, on a tint of it.
/// With [onDeleted], it has a button to take it off.
class LabelChip extends StatelessWidget {
  const LabelChip(this.label, {super.key, this.onDeleted});

  final TaskLabel label;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<LabelColors>()!;
    final text = Text(
      label.name,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      overflow: TextOverflow.ellipsis,
    );
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.sm,
        right: onDeleted == null ? AppSpacing.sm : 0,
        top: AppSpacing.xs / 2,
        bottom: AppSpacing.xs / 2,
      ),
      decoration: ShapeDecoration(
        color: colors.tint(label.color, theme.colorScheme.surface),
        shape: const StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LabelDot(label.color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Semantics(
              label: 'Label: ${label.name}',
              excludeSemantics: true,
              child: text,
            ),
          ),
          if (onDeleted case final onDeleted?)
            IconButton(
              tooltip: 'Remove the label ${label.name}',
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              onPressed: onDeleted,
            ),
        ],
      ),
    );
  }
}

/// A small circle of a label's colour.
class LabelDot extends StatelessWidget {
  const LabelDot(this.color, {super.key, this.size = 8});

  final LabelColor color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).extension<LabelColors>()!.of(color),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A task's labels on a card, wrapping onto more lines if need be.
class TaskLabels extends StatelessWidget {
  const TaskLabels(this.labels, {super.key});

  final List<TaskLabel> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [for (final label in labels) LabelChip(label)],
    );
  }
}
