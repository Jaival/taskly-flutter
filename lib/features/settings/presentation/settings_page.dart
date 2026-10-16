import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_palette.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/appearance.dart';
import '../../../app/theme/device_colors.dart';
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
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AppearanceCard(),
                  SizedBox(height: AppSpacing.md),
                  _TasksCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Light or dark, and the colour theme.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final notifier = ref.read(appearanceProvider.notifier);
    final deviceColors = ref.watch(deviceColorsProvider).value;
    final theme = Theme.of(context);
    // Device colours first, where the device has some to offer (or if
    // they were picked before, so the choice still shows).
    final palettes = [
      if (deviceColors != null || appearance.palette == AppPalette.device)
        AppPalette.device,
      for (final palette in AppPalette.values)
        if (palette != AppPalette.device) palette,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text('How Taskly looks on this device.'),
            const SizedBox(height: AppSpacing.lg),
            Text('Mode', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('System'),
                ),
              ],
              selected: {appearance.mode},
              showSelectedIcon: false,
              onSelectionChanged: (selected) =>
                  notifier.setMode(selected.single),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Theme', style: theme.textTheme.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = AppSpacing.sm;
                final columns = constraints.maxWidth >= 420 ? 3 : 2;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final palette in palettes)
                      SizedBox(
                        width: width,
                        child: _PaletteTile(
                          palette,
                          deviceColors: deviceColors,
                          selected: palette == appearance.palette,
                          onTap: () => notifier.setPalette(palette),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A colour theme to pick: a small preview of the app in it, in the current
/// brightness, above its name.
class _PaletteTile extends StatelessWidget {
  const _PaletteTile(
    this.palette, {
    required this.deviceColors,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final DeviceColors? deviceColors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = palette.tokens(theme.brightness, deviceColors: deviceColors);

    Widget task(Color priority, double width) => Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            border: Border.all(color: priority, width: 1.5),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),
        Container(
          width: width,
          height: 6,
          decoration: BoxDecoration(
            color: t.muted,
            borderRadius: const BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      label: '${palette.label} theme',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: selected
              ? BorderSide(color: colors.primary, width: 2)
              : BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The preview is drawn in the palette's own colours.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: t.background,
                    borderRadius: AppRadius.smAll,
                    border: Border.all(color: t.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: t.primary,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(3),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: 28,
                            height: 12,
                            decoration: BoxDecoration(
                              color: t.primary,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      task(t.urgent, 48),
                      const SizedBox(height: AppSpacing.xs + 2),
                      task(t.high, 36),
                      const SizedBox(height: AppSpacing.xs + 2),
                      task(t.medium, 42),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        palette.label,
                        style: theme.textTheme.labelLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, size: 18, color: colors.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
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
