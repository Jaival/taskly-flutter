import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/verify_email_banner.dart';
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

/// Signed-in layout. The navigation adapts to the window width:
/// bottom bar on phones, rail on tablets, permanent drawer on desktop.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    this.showAppBar = true,
  });

  final StatefulNavigationShell navigationShell;

  /// False on nested pages, which show their own app bar.
  final bool showAppBar;

  void _onSelect(int index) => navigationShell.goBranch(
    index,
    // Tapping the current destination again returns to its first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
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
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
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
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
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
              for (final d in _destinations)
                NavigationDrawerDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
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
