import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/data/file_export.dart';
import '../data/my_tasks_provider.dart';
import '../domain/my_task.dart';
import '../domain/task_export.dart';
import '../domain/task_filter.dart';
import 'visible_tasks.dart';

/// The Tasks page's search box, which takes the place of the title in the
/// app bar. Keeps its text in step with the filter, which "Clear filters"
/// can empty from outside. The "/" shortcut puts the cursor here, and Esc
/// clears it and leaves.
class TaskSearchField extends ConsumerStatefulWidget {
  const TaskSearchField({super.key});

  @override
  ConsumerState<TaskSearchField> createState() => _TaskSearchFieldState();
}

class _TaskSearchFieldState extends ConsumerState<TaskSearchField> {
  late final _controller = TextEditingController(
    text: ref.read(taskFilterProvider).query,
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // "/" on another page, before this one was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _answerRequest());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String query) {
    final notifier = ref.read(taskFilterProvider.notifier);
    notifier.change(ref.read(taskFilterProvider).copyWith(query: query));
  }

  void _answerRequest() {
    if (!mounted) return;
    final request = ref.read(taskSearchRequestProvider.notifier);
    if (!request.isWaiting) return;
    // Asked for from another tab: this page can't take the focus until it
    // has come forward, a frame or two from now.
    if (!_focus.canRequestFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _answerRequest());
      return;
    }
    if (request.take()) _focus.requestFocus();
  }

  void _clear() {
    _controller.clear();
    _search('');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(taskFilterProvider.select((filter) => filter.query), (_, query) {
      if (query != _controller.text) _controller.text = query;
    });
    ref.listen(taskSearchRequestProvider, (_, requestedAt) {
      if (requestedAt != null) _answerRequest();
    });
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _clear();
          _focus.unfocus();
        },
      },
      // Not across the whole of a wide window.
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search tasks',
            prefixIcon: const Icon(Icons.search),
            // A rounded, filled box that sits in the bar, not an outline.
            filled: true,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(28)),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
            ),
            suffixIcon: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: _clear,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Tasks page's app bar buttons: the list/calendar switch, and a menu
/// to sort, export, or change the defaults.
class TasksAppBarActions extends ConsumerWidget {
  const TasksAppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendar = ref.watch(tasksViewProvider) == TasksView.calendar;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            calendar
                ? Icons.view_agenda_outlined
                : Icons.calendar_month_outlined,
          ),
          tooltip: calendar ? 'Show as a list' : 'Show as a calendar',
          onPressed: () => ref
              .read(tasksViewProvider.notifier)
              .show(calendar ? TasksView.list : TasksView.calendar),
        ),
        _OptionsMenu(calendar: calendar),
      ],
    );
  }
}

enum _ExportFormat {
  csv('Export spreadsheet (.csv)', Icons.table_chart_outlined),
  iCal('Export calendar (.ics)', Icons.event_outlined);

  const _ExportFormat(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Sort, export and the way to Settings, out of the page's way.
class _OptionsMenu extends ConsumerWidget {
  const _OptionsMenu({required this.calendar});

  /// A calendar is by due date already: there's no sorting it.
  final bool calendar;

  static String _count(int tasks) => tasks == 1 ? '1 task' : '$tasks tasks';

  /// Saves the tasks the page is showing: the filters apply to the export
  /// too.
  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    _ExportFormat format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String message) =>
        messenger.showSnackBar(SnackBar(content: Text(message)));

    final now = DateTime.now();
    final List<MyTask> items = ref
        .read(activeTaskFilterProvider)
        .apply(ref.read(visibleTasksProvider).value ?? const [], now);
    final name = 'taskly-tasks-${now.toIso8601String().substring(0, 10)}';
    final dated = items.where((item) => item.task.dueDate != null).length;
    final undated = items.length - dated;

    final ExportFile file;
    final String done;
    switch (format) {
      case _ExportFormat.csv:
        file = ExportFile(
          name: '$name.csv',
          mimeType: 'text/csv',
          // The mark at the start tells Excel the file is UTF-8; without
          // it, accented letters come out wrong.
          text: '﻿${tasksToCsv(items)}',
        );
        done = 'Exported ${_count(items.length)}.';
      case _ExportFormat.iCal when dated == 0:
        say(
          'None of these tasks has a due date, so there is nothing to put '
          'in a calendar.',
        );
        return;
      case _ExportFormat.iCal:
        file = ExportFile(
          name: '$name.ics',
          mimeType: 'text/calendar',
          text: tasksToICal(items, now: now),
        );
        done = undated == 0
            ? 'Exported ${_count(dated)}.'
            : 'Exported ${_count(dated)}. $undated without a due date '
                  '${undated == 1 ? 'was' : 'were'} left out.';
    }

    try {
      if (await ref.read(saveFileProvider)(file)) say(done);
    } on Object {
      say("Couldn't export the tasks. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(taskFilterProvider.select((filter) => filter.sort));
    final hasTasks = ref.watch(visibleTasksProvider).value?.isNotEmpty ?? false;
    final theme = Theme.of(context);

    return MenuAnchor(
      menuChildren: [
        if (!calendar) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              'Sort by',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final option in TaskSort.values)
            MenuItemButton(
              // A tick on the current one, and space for it on the others.
              leadingIcon: option == sort
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              onPressed: () => ref
                  .read(taskFilterProvider.notifier)
                  .change(ref.read(taskFilterProvider).copyWith(sort: option)),
              child: Text(option.label),
            ),
          const Divider(),
        ],
        for (final format in _ExportFormat.values)
          MenuItemButton(
            leadingIcon: Icon(format.icon),
            onPressed: hasTasks ? () => _export(context, ref, format) : null,
            child: Text(format.label),
          ),
        const Divider(),
        MenuItemButton(
          leadingIcon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(Routes.settings),
          child: const Text('Default view and sort'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.more_vert),
        tooltip: 'View options',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
