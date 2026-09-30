import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../domain/due_date.dart';
import '../domain/task.dart';

/// "Today", "Tomorrow", "In 3 days", "2 days ago", or the date for anything
/// a week or more away.
String relativeDueLabel(
  MaterialLocalizations localizations,
  DateTime due,
  DateTime today,
) => switch (daysUntil(due, today)) {
  0 => 'Today',
  1 => 'Tomorrow',
  -1 => 'Yesterday',
  final days when days > 1 && days < 7 => 'In $days days',
  final days when days < -1 && days > -7 => '${-days} days ago',
  _ => formatDueDate(localizations, due, today, weekday: false),
};

/// The date itself: "Fri, Oct 2" this year, "Oct 2, 2027" in another, or
/// "Oct 2" without the [weekday].
String formatDueDate(
  MaterialLocalizations localizations,
  DateTime due,
  DateTime today, {
  bool weekday = true,
}) => switch (due.year == today.year) {
  false => localizations.formatShortDate(due),
  true when weekday => localizations.formatMediumDate(due),
  true => localizations.formatShortMonthDay(due),
};

/// A task's due date on its card, in the error colour when it's overdue.
class DueDateLabel extends StatelessWidget {
  const DueDateLabel(this.task, {super.key, required this.today});

  final Task task;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final due = task.dueDate!;
    final overdue = task.isOverdue(today);
    final color = overdue
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final label = relativeDueLabel(
      MaterialLocalizations.of(context),
      due,
      today,
    );
    return Semantics(
      label: overdue ? 'Overdue: due $label' : 'Due $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon shape, not just colour, marks it as overdue.
          Icon(
            overdue ? Icons.event_busy : Icons.event_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: overdue ? FontWeight.w600 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
