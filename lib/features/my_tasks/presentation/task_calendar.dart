import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../tasks/domain/due_date.dart';
import '../data/my_tasks_provider.dart';
import '../domain/my_task.dart';
import '../domain/task_calendar.dart';

/// A month of [items] by due date: a dot on each day for every task due
/// then, and the chosen day's tasks listed below.
class TaskCalendar extends ConsumerWidget {
  const TaskCalendar(this.items, {super.key, required this.card});

  final List<MyTask> items;

  /// Builds the card for a task in the day's list.
  final Widget Function(MyTask) card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final localizations = MaterialLocalizations.of(context);
    final selected = ref.watch(calendarDayProvider);
    final calendar = ref.read(calendarDayProvider.notifier);
    final today = dateOnly(DateTime.now());

    final byDay = groupByDay(items, (item) => item.task);
    final days = calendarDays(
      selected,
      firstDayOfWeek: localizations.firstDayOfWeekIndex,
    );
    final due = byDay[selected] ?? const [];
    final undated = items.where((item) => item.task.dueDate == null).length;

    return ListView(
      // Extra bottom padding so the button never covers the last task.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxl * 2,
      ),
      children: [
        _MonthHeader(
          title: localizations.formatMonthYear(selected),
          onPrevious: () => calendar.showMonth(-1),
          onNext: () => calendar.showMonth(1),
          onToday: selected == today ? null : calendar.showToday,
        ),
        _WeekdayNames(first: localizations.firstDayOfWeekIndex),
        for (var week = 0; week < days.length; week += 7)
          Row(
            children: [
              for (final day in days.sublist(week, week + 7))
                Expanded(
                  child: _Day(
                    day: day,
                    due: byDay[day] ?? const [],
                    today: today,
                    inMonth: sameMonth(day, selected),
                    selected: day == selected,
                    onTap: () => calendar.select(day),
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Semantics(
            header: true,
            // Read out when another day is chosen.
            liveRegion: true,
            child: Text(
              [
                if (selected == today)
                  'Today'
                else
                  localizations.formatFullDate(selected),
                if (due.isNotEmpty) '${due.length}',
              ].join(' · '),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (due.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Text('Nothing due.', style: theme.textTheme.bodyMedium),
          ),
        for (final item in due) ...[
          card(item),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (undated > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xs,
              0,
            ),
            child: Text(
              undated == 1
                  ? "1 task has no due date, so it isn't on the calendar."
                  : "$undated tasks have no due date, so they aren't on "
                        'the calendar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.title,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Null when today is already the chosen day.
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        TextButton(onPressed: onToday, child: const Text('Today')),
        IconButton(
          tooltip: 'Previous month',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next month',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

/// "M T W T F S S", starting with the locale's first day of the week.
class _WeekdayNames extends StatelessWidget {
  const _WeekdayNames({required this.first});

  /// 0 for Sunday.
  final int first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sunday first.
    final names = MaterialLocalizations.of(context).narrowWeekdays;
    // The days below say their weekday themselves.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Text(
                  names[(first + i) % 7],
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One day of the month: its number, and a dot for each task due.
class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.due,
    required this.today,
    required this.inMonth,
    required this.selected,
    required this.onTap,
  });

  /// Dots shown before "+" stands for the rest.
  static const _maxDots = 3;

  final DateTime day;
  final List<MyTask> due;
  final DateTime today;

  /// False for the days of the months before and after, which fill the
  /// first and last weeks.
  final bool inMonth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isToday = day == today;
    final foreground = selected
        ? colors.onPrimaryContainer
        : inMonth
        ? colors.onSurface
        : colors.outline;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      side: isToday ? BorderSide(color: colors.primary) : BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.all(1),
      child: Semantics(
        button: true,
        selected: selected,
        label: [
          MaterialLocalizations.of(context).formatFullDate(day),
          if (isToday) 'today',
          switch (due.length) {
            0 => 'nothing due',
            1 => '1 task due',
            final count => '$count tasks due',
          },
        ].join(', '),
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: selected ? colors.primaryContainer : Colors.transparent,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: isToday ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 3,
                      children: [
                        for (final item in due.take(_maxDots))
                          _Dot(
                            color: item.task.isComplete
                                ? colors.outlineVariant
                                : item.task.isOverdue(today)
                                ? colors.error
                                : colors.primary,
                          ),
                        if (due.length > _maxDots)
                          Text(
                            '+',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: foreground,
                              height: 0.8,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
