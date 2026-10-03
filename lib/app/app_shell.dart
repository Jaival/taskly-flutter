import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/verify_email_banner.dart';
import '../features/my_tasks/data/my_tasks_provider.dart';
import '../features/projects/presentation/new_project_task.dart';
import '../features/sharing/data/invite_repository.dart';
import '../features/tasks/presentation/task_form.dart';
import 'app_shortcuts.dart';
import 'router.dart';
import 'theme/app_spacing.dart';

typedef _Destination = ({IconData icon, IconData selectedIcon, String label});

const List<_Destination> _destinations = [
  (
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard,
    label: 'Home',
  ),
  (icon: Icons.folder_outlined, selectedIcon: Icons.folder, label: 'Projects'),
  (icon: Icons.task_alt_outlined, selectedIcon: Icons.task_alt, label: 'Tasks'),
  (icon: Icons.group_outlined, selectedIcon: Icons.group, label: 'Shared'),
];

/// Index of "Tasks" in [_destinations], where the search box is.
const _tasksIndex = 2;

/// Index of "Shared" in [_destinations], which shows how many invites are
/// waiting.
const _sharedIndex = 3;

/// Signed-in layout. The navigation adapts to the window width:
/// bottom bar on phones, rail on tablets, permanent drawer on desktop.
/// The keyboard shortcuts work on every page inside it.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    this.showAppBar = true,
    this.projectId,
  });

  final StatefulNavigationShell navigationShell;

  /// False on nested pages, which show their own app bar.
  final bool showAppBar;

  /// The project whose page is showing, if one is: where "N" adds its task.
  final String? projectId;

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    // Tapping the current destination again returns to its first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppShortcuts(
      // In the project that's open, or a personal task anywhere else.
      onNewTask: () => switch (projectId) {
        final id? => showNewProjectTaskForm(context, ref, id),
        null => showTaskForm(context),
      },
      onSearch: () {
        ref.read(taskSearchRequestProvider.notifier).request();
        navigationShell.goBranch(_tasksIndex, initialLocation: true);
      },
      child: _layout(context, ref),
    );
  }

  Widget _layout(BuildContext context, WidgetRef ref) {
    final invites = ref.watch(receivedInvitesProvider).value?.length ?? 0;
    Widget icon(int index, {bool selected = false}) {
      final d = _destinations[index];
      final child = Icon(selected ? d.selectedIcon : d.icon);
      if (index != _sharedIndex || invites == 0) return child;
      return Badge.count(count: invites, child: child);
    }

    final width = MediaQuery.sizeOf(context).width;
    final selected = navigationShell.currentIndex;
    final body = VerifyEmailBanner(child: navigationShell);
    final appBar = !showAppBar
        ? null
        : AppBar(
            title: Text(_destinations[selected].label),
            actions: const [
              _AccountMenu(),
              SizedBox(width: AppSpacing.sm),
            ],
          );

    if (width < Breakpoints.medium) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: _onSelect,
          destinations: [
            for (final (i, d) in _destinations.indexed)
              NavigationDestination(
                icon: icon(i),
                selectedIcon: icon(i, selected: true),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final navigation = width < Breakpoints.expanded
        ? NavigationRail(
            selectedIndex: selected,
            onDestinationSelected: _onSelect,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final (i, d) in _destinations.indexed)
                NavigationRailDestination(
                  icon: icon(i),
                  selectedIcon: icon(i, selected: true),
                  label: Text(d.label),
                ),
            ],
          )
        : NavigationDrawer(
            selectedIndex: selected,
            onDestinationSelected: _onSelect,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Text(
                  'Taskly',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              for (final (i, d) in _destinations.indexed)
                NavigationDrawerDestination(
                  icon: icon(i),
                  selectedIcon: icon(i, selected: true),
                  label: Text(d.label),
                ),
            ],
          );

    return Scaffold(
      body: Row(
        children: [
          navigation,
          Expanded(
            child: Scaffold(appBar: appBar, body: body),
          ),
        ],
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final theme = Theme.of(context);

    return MenuAnchor(
      alignmentOffset: const Offset(0, AppSpacing.xs),
      menuChildren: [
        if (user?.email case final email?)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(email, style: theme.textTheme.bodySmall),
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.person_outline),
          onPressed: () => context.push(Routes.profile),
          child: const Text('Profile'),
        ),
        // Not on phones, which rarely have a keyboard.
        if (MediaQuery.sizeOf(context).width >= Breakpoints.medium)
          MenuItemButton(
            leadingIcon: const Icon(Icons.keyboard_outlined),
            onPressed: () => showShortcutsHelp(context),
            child: const Text('Keyboard shortcuts'),
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Account',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: CircleAvatar(
          radius: 16,
          child: Text(user?.initials ?? '', style: theme.textTheme.labelMedium),
        ),
      ),
    );
  }
}
