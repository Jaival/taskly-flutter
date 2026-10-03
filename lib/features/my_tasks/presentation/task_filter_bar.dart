import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../projects/domain/project.dart';
import '../data/my_tasks_provider.dart';
import '../domain/task_filter.dart';

/// Search, filter menus and sort for the Tasks page.
class TaskFilterBar extends ConsumerWidget {
  const TaskFilterBar({
    super.key,
    required this.projects,
    required this.shown,
    required this.total,
  });

  /// The user's projects, to filter by. The Project menu is hidden without
  /// any.
  final List<Project> projects;

  /// How many tasks the filters let through, of how many.
  final int shown;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    void change(TaskFilter filter) =>
        ref.read(taskFilterProvider.notifier).change(filter);
    final names = {for (final project in projects) project.id: project.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SearchField(),
        const SizedBox(height: AppSpacing.sm),
        // One scrolling row of chips, so phones don't wrap them onto
        // several lines.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: AppSpacing.sm,
            children: [
              _SortMenu(
                sort: filter.sort,
                onChanged: (sort) => change(filter.copyWith(sort: sort)),
              ),
              _FilterMenu(
                label: 'Priority',
                options: Priority.values,
                labelOf: (priority) => priority.label,
                selected: filter.priorities,
                onChanged: (selected) =>
                    change(filter.copyWith(priorities: selected)),
              ),
              _FilterMenu(
                label: 'Status',
                options: TaskStatus.values,
                labelOf: (status) => status.label,
                selected: filter.statuses,
                onChanged: (selected) =>
                    change(filter.copyWith(statuses: selected)),
              ),
              _FilterMenu(
                label: 'Due',
                options: dueFilterGroups,
                labelOf: (group) => group.label,
                selected: filter.due,
                onChanged: (selected) => change(filter.copyWith(due: selected)),
              ),
              if (projects.isNotEmpty)
                _FilterMenu<String?>(
                  label: 'Project',
                  options: [null, ...names.keys],
                  labelOf: (id) => id == null ? 'Personal' : names[id] ?? '',
                  selected: filter.projectIds,
                  onChanged: (selected) =>
                      change(filter.copyWith(projectIds: selected)),
                ),
            ],
          ),
        ),
        // Under the chips rather than at the end of their row, where it
        // could be scrolled out of sight on a phone.
        if (filter.isFiltering)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Showing $shown of $total ${total == 1 ? 'task' : 'tasks'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => change(filter.cleared()),
                child: const Text('Clear filters'),
              ),
            ],
          ),
      ],
    );
  }
}

/// The search box. Keeps its text in step with the filter, which "Clear
/// filters" can empty from outside. The "/" shortcut puts the cursor here,
/// and Esc clears it and leaves.
class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
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
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        onChanged: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search tasks',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
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
    );
  }
}

/// A chip that opens a menu of options to tick. It shows the one chosen,
/// or how many.
class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<T> options;
  final String Function(T) labelOf;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in options)
          CheckboxMenuButton(
            value: selected.contains(option),
            // Stays open, to tick several.
            closeOnActivate: false,
            onChanged: (checked) => onChanged(
              checked ?? false
                  ? {...selected, option}
                  : ({...selected}..remove(option)),
            ),
            child: Text(labelOf(option)),
          ),
      ],
      builder: (context, controller, _) => FilterChip(
        selected: selected.isNotEmpty,
        showCheckmark: false,
        tooltip: 'Filter by ${label.toLowerCase()}',
        label: _ChipLabel(switch (selected.length) {
          0 => label,
          1 => labelOf(selected.single),
          final count => '$label · $count',
        }),
        onSelected: (_) =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.onChanged});

  final TaskSort sort;
  final ValueChanged<TaskSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        for (final option in TaskSort.values)
          MenuItemButton(
            // A tick on the current one, and space for it on the others.
            leadingIcon: option == sort
                ? const Icon(Icons.check)
                : const SizedBox(width: 24),
            onPressed: () => onChanged(option),
            child: Text(option.label),
          ),
      ],
      builder: (context, controller, _) => ActionChip(
        avatar: const Icon(Icons.swap_vert),
        tooltip: 'Sort',
        label: _ChipLabel('Sort: ${sort.label}'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

/// A chip's text with a drop-down arrow, since it opens a menu.
class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text(text), const Icon(Icons.arrow_drop_down, size: 18)],
    );
  }
}
