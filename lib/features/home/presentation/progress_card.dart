import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/skeleton.dart';
import '../../my_tasks/data/my_tasks_provider.dart';
import '../../my_tasks/domain/my_task.dart';
import '../../my_tasks/domain/task_filter.dart';
import '../../tasks/domain/due_date.dart';
import '../../tasks/domain/task_stats.dart';

/// How tall the busiest day's bar is.
const _barHeight = 48.0;

/// The narrowest the summary can be beside the chart, at normal text size:
/// room for "Nothing overdue" on one line.
const _summaryMinWidth = 136.0;

/// How the user is doing: tasks done in the last seven days, with a bar for
/// each day, and how many are overdue.
class ProgressCard extends ConsumerWidget {
  const ProgressCard({super.key, required this.tasks});

  final AsyncValue<List<MyTask>> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // "Up next" says so when the tasks can't be loaded.
    if (tasks is AsyncError) return const SizedBox.shrink();

    final today = DateTime.now();
    // Null while loading.
    final stats = switch (tasks) {
      AsyncData(:final value) => TaskStats.of(
        value.map((item) => item.task),
        today,
      ),
      _ => null,
    };

    if (stats == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Skeleton(height: 88),
        ),
      );
    }

    final summary = _Summary(
      stats: stats,
      // The Tasks page, showing only what's overdue.
      onOverdue: () {
        ref
            .read(taskFilterProvider.notifier)
            .change(const TaskFilter(due: {DueGroup.overdue}));
        context.go(Routes.tasks);
      },
    );
    final chart = _WeekChart(doneByDay: stats.doneByDay, today: today);
    final chartWidth = _WeekChart.widthFor(context, stats.doneByDay.length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Side by side when the summary still gets a usable width
            // beside the chart; otherwise the chart goes underneath.
            final beside =
                constraints.maxWidth - chartWidth - AppSpacing.md >=
                MediaQuery.textScalerOf(context).scale(_summaryMinWidth);
            return beside
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: AppSpacing.md),
                      chart,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: AppSpacing.md),
                      chart,
                    ],
                  );
          },
        ),
      ),
    );
  }
}

/// The number done, and what's overdue.
class _Summary extends StatelessWidget {
  const _Summary({required this.stats, required this.onOverdue});

  final TaskStats stats;
  final VoidCallback onOverdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          // Its own stop for a screen reader, not run together with the
          // rest of the card.
          container: true,
          label: stats.done == 1
              ? '1 task done in the last 7 days'
              : '${stats.done} tasks done in the last 7 days',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${stats.done}', style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Done in the last 7 days',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _Overdue(count: stats.overdue, onPressed: onOverdue),
      ],
    );
  }
}

/// "2 overdue", opening them; or a quiet "Nothing overdue".
class _Overdue extends StatelessWidget {
  const _Overdue({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (count == 0) {
      final color = theme.colorScheme.onSurfaceVariant;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'Nothing overdue',
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      );
    }
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.errorContainer,
        foregroundColor: theme.colorScheme.onErrorContainer,
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.event_busy),
      label: Text('$count overdue'),
    );
  }
}

/// A bar for each day, the last being today, under the day's count and over
/// its initial.
class _WeekChart extends StatelessWidget {
  const _WeekChart({required this.doneByDay, required this.today});

  final List<int> doneByDay;
  final DateTime today;

  /// Each day's column: wide enough for a two-digit count, at any text size.
  static double _dayWidth(BuildContext context) =>
      math.max(28.0, MediaQuery.textScalerOf(context).scale(18));

  /// How wide a chart of [days] days is.
  static double widthFor(BuildContext context, int days) =>
      days * _dayWidth(context);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final most = doneByDay.fold(0, math.max);
    final dayWidth = _dayWidth(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    DateTime dayAt(int index) => DateTime(
      today.year,
      today.month,
      today.day - (doneByDay.length - 1 - index),
    );
    String nameOf(int index) => switch (doneByDay.length - 1 - index) {
      0 => 'today',
      1 => 'yesterday',
      _ => localizations.formatMediumDate(dayAt(index)),
    };

    return Semantics(
      container: true,
      // Only the days something was done; the total is read out beside it.
      label: most == 0
          ? null
          : [
              for (final (index, count) in doneByDay.indexed)
                if (count > 0) '$count ${nameOf(index)}',
            ].join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, count) in doneByDay.indexed)
            SizedBox(
              width: dayWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (count > 0) Text('$count', style: labelStyle, maxLines: 1),
                  const SizedBox(height: 2),
                  Container(
                    width: 16,
                    // A stub for an empty day, so the week still reads as
                    // seven days.
                    height: count == 0
                        ? 4
                        : math.max(8, _barHeight * count / most),
                    decoration: BoxDecoration(
                      color: count == 0
                          ? theme.colorScheme.outlineVariant
                          : theme.colorScheme.primary,
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    localizations.narrowWeekdays[dayAt(index).weekday % 7],
                    maxLines: 1,
                    style: index == doneByDay.length - 1
                        ? labelStyle?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          )
                        : labelStyle,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
