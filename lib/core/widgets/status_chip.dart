import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/status_colors.dart';
import '../domain/task_status.dart';

/// A status label with a coloured dot, used on project and task cards.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final TaskStatus status;

  static IconData iconFor(TaskStatus status) => switch (status) {
    TaskStatus.notStarted => Icons.radio_button_unchecked,
    TaskStatus.inProgress => Icons.timelapse,
    TaskStatus.complete => Icons.check_circle,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.statusColor(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon shape, not just colour, tells the statuses apart.
        Icon(iconFor(status), size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            status.label,
            style: theme.textTheme.labelMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
