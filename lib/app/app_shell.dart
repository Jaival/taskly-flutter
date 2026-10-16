import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/data/web_app.dart';
import '../core/widgets/offline_banner.dart';
import '../core/widgets/update_banner.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/presentation/verify_email_banner.dart';
import '../features/my_tasks/data/my_tasks_provider.dart';
import '../features/my_tasks/presentation/tasks_app_bar.dart';
import '../features/my_tasks/presentation/visible_tasks.dart';
import '../features/projects/data/project_repository.dart';
import '../features/projects/domain/project.dart';
import '../features/projects/presentation/project_form.dart';
import '../features/projects/presentation/new_project_task.dart';
import '../features/sharing/data/invite_repository.dart';
import '../features/tasks/data/task_repository.dart';
import '../features/tasks/presentation/task_form.dart';
import 'app_shortcuts.dart';
import 'router.dart';
import 'theme/app_spacing.dart';
import 'theme/priority_colors.dart';

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
/// bottom bar on phones, rail on tablets, and on desktop a sidebar that
/// also lists the projects.
/// The keyboard shortcuts work on every page inside it, and a banner says
/// when the device is offline.
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
    final body = OfflineBanner(
      child: UpdateBanner(child: VerifyEmailBanner(child: navigationShell)),
    );
    final appBar = !showAppBar
        ? null
        // On Tasks, the search box stands in for the title.
        : AppBar(
            title: selected == _tasksIndex
                ? const TaskSearchField()
                : Text(_destinations[selected].label),
            actions: [
              if (selected == _tasksIndex) const TasksAppBarActions(),
              const _AccountMenu(),
              const SizedBox(width: AppSpacing.sm),
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
        : _Sidebar(
            selected: selected,
            onSelect: _onSelect,
            projectId: projectId,
            invites: invites,
          );

    return Scaffold(
      body: Row(
        children: [
          navigation,
          const VerticalDivider(width: 1),
          Expanded(
            // Its own semantics container: the page's route blocks the
            // semantics of whatever was painted before it, which would
            // otherwise hide the navigation from screen readers.
            child: Semantics(
              container: true,
              child: Scaffold(appBar: appBar, body: body),
            ),
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
    final user = ref.watch(currentUserProvider);
    final webApp = ref.watch(webAppProvider);
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
          leadingIcon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(Routes.settings),
          child: const Text('Settings'),
        ),
        // Not on phones, which rarely have a keyboard.
        if (MediaQuery.sizeOf(context).width >= Breakpoints.medium)
          MenuItemButton(
            leadingIcon: const Icon(Icons.keyboard_outlined),
            onPressed: () => showShortcutsHelp(context),
            child: const Text('Keyboard shortcuts'),
          ),
        // Only while the browser is offering it.
        ListenableBuilder(
          listenable: webApp,
          builder: (context, _) => webApp.canInstall
              ? MenuItemButton(
                  leadingIcon: const Icon(Icons.install_desktop_outlined),
                  onPressed: webApp.install,
                  child: const Text('Install app'),
                )
              : const SizedBox.shrink(),
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

/// The navigation on wide windows, after shadcn's sidebar: the app's name,
/// its sections with how much is in each, and every project, so moving
/// between projects is one click.
class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.selected,
    required this.onSelect,
    required this.projectId,
    required this.invites,
  });

  /// The section showing, as an index into [_destinations].
  final int selected;
  final ValueChanged<int> onSelect;

  /// The project whose page is showing, if one is.
  final String? projectId;

  /// Invites waiting, shown on "Shared".
  final int invites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final openTasks = ref
        .watch(visibleTasksProvider)
        .value
        ?.where((item) => !item.task.isComplete)
        .length;
    // How much is in each section, where it's worth saying.
    final counts = [null, projects.length, openTasks, null];

    return Material(
      color: colors.surfaceContainerLow,
      child: SizedBox(
        width: 264,
        child: SafeArea(
          right: false,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.sm),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(
                        Icons.task_alt,
                        size: 20,
                        color: colors.onPrimary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md - 4),
                    Text(
                      'Taskly',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, d) in _destinations.indexed)
                _SidebarItem(
                  // On a project's page, the project is what's selected.
                  selected: i == selected && projectId == null,
                  leading: Icon(
                    i == selected ? d.selectedIcon : d.icon,
                    size: 20,
                  ),
                  label: d.label,
                  trailing: switch ((i, counts[i])) {
                    (_sharedIndex, _) when invites > 0 => Badge.count(
                      count: invites,
                    ),
                    (_, final count?) when count > 0 => _Count(count),
                    _ => null,
                  },
                  semanticsLabel: switch ((i, counts[i])) {
                    (_sharedIndex, _) when invites > 0 =>
                      '${d.label}, $invites waiting',
                    (_, final count?) when count > 0 => '${d.label}, $count',
                    _ => d.label,
                  },
                  onTap: () => onSelect(i),
                ),
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm + 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Projects',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'New project',
                      iconSize: 18,
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final id = await showProjectForm(context);
                        if (id != null && context.mounted) {
                          context.go(Routes.project(id));
                        }
                      },
                    ),
                  ],
                ),
              ),
              if (projects.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 4,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'None yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final project in projects)
                _ProjectItem(project, selected: project.id == projectId),
            ],
          ),
        ),
      ),
    );
  }
}

/// A project in the sidebar: a dot in its priority's colour, its name, and
/// how many of its tasks are still open.
class _ProjectItem extends ConsumerWidget {
  const _ProjectItem(this.project, {required this.selected});

  final Project project;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref
        .watch(projectTasksProvider(project.id))
        .value
        ?.where((task) => !task.isComplete)
        .length;
    final color = Theme.of(context)
        .extension<PriorityColors>()!
        .of(project.priority);
    return _SidebarItem(
      selected: selected,
      leading: SizedBox(
        width: 20,
        child: Center(
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
        ),
      ),
      label: project.name,
      trailing: open == null || open == 0 ? null : _Count(open),
      semanticsLabel: switch (open) {
        null || 0 => 'Project ${project.name}',
        1 => 'Project ${project.name}, 1 open task',
        final n => 'Project ${project.name}, $n open tasks',
      },
      onTap: () => context.go(Routes.project(project.id)),
    );
  }
}

/// A row in the sidebar: a grey wash and bolder text when it's the one
/// showing.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.selected,
    required this.leading,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.trailing,
  });

  final bool selected;
  final Widget leading;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // One node per item, with its own tap: the InkWell's is hidden with the
    // rest of what's inside.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          color: selected ? colors.surfaceContainerHigh : Colors.transparent,
          borderRadius: AppRadius.smAll,
          child: InkWell(
            borderRadius: AppRadius.smAll,
            onTap: onTap,
            child: ConstrainedBox(
              // The smallest comfortable tap target.
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 4,
                ),
                child: Row(
                  children: [
                    IconTheme.merge(
                      data: IconThemeData(
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      child: leading,
                    ),
                    const SizedBox(width: AppSpacing.md - 4),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// How many things are in a sidebar item.
class _Count extends StatelessWidget {
  const _Count(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '$count',
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
