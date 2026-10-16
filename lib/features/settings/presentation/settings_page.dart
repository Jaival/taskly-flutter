import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../my_tasks/data/my_tasks_provider.dart';
import '../../my_tasks/domain/task_filter.dart';

/// `/settings`: how the app looks when it opens. Kept on this device.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        // Opened directly by URL there's nothing to pop, so go home instead.
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: const _TasksCard(),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Tasks page's default view and sort.
class _TasksCard extends ConsumerWidget {
  const _TasksCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaults = ref.watch(tasksDefaultsProvider);
    final notifier = ref.read(tasksDefaultsProvider.notifier);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tasks', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'How the Tasks page looks when you open the app. You can still '
              'change it on the page.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Default view', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<TasksView>(
              segments: const [
                ButtonSegment(
                  value: TasksView.list,
                  icon: Icon(Icons.view_agenda_outlined),
                  label: Text('List'),
                ),
                ButtonSegment(
                  value: TasksView.calendar,
                  icon: Icon(Icons.calendar_month_outlined),
                  label: Text('Calendar'),
                ),
              ],
              selected: {defaults.view},
              showSelectedIcon: false,
              onSelectionChanged: (selected) =>
                  notifier.setView(selected.single),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownMenu<TaskSort>(
              label: const Text('Default sort'),
              helperText: 'For the list. The calendar is always by date.',
              expandedInsets: EdgeInsets.zero,
              initialSelection: defaults.sort,
              // Rebuilt with the saved one once it has been read.
              key: ValueKey(defaults.sort),
              dropdownMenuEntries: [
                for (final sort in TaskSort.values)
                  DropdownMenuEntry(value: sort, label: sort.label),
              ],
              onSelected: (sort) {
                if (sort != null) notifier.setSort(sort);
              },
            ),
          ],
        ),
      ),
    );
  }
}
