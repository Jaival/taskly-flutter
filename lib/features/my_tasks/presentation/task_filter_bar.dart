import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import '../../projects/domain/project.dart';
import '../../tasks/domain/task_label.dart';
import '../data/my_tasks_provider.dart';
import '../domain/my_task.dart';
import '../domain/task_filter.dart';

/// The filter menus for the Tasks page, and how many tasks they let
/// through. Search, sort and the rest are in the app bar.
class TaskFilterBar extends ConsumerWidget {
  const TaskFilterBar({
    super.key,
    required this.projects,
    required this.labels,
    required this.shown,
    required this.total,
  });

  /// The user's projects, to filter by. The Project menu is hidden without
  /// any.
  final List<Project> projects;

  /// The labels on the user's tasks, to filter by. The Label menu is
  /// hidden without any.
  final List<TaskLabel> labels;

  /// The tasks the filters let through, of how many.
  final List<MyTask> shown;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterProvider);
    // A calendar is by due date already: no filtering by it.
    final calendar = ref.watch(tasksViewProvider) == TasksView.calendar;
    void change(TaskFilter filter) =>
        ref.read(taskFilterProvider.notifier).change(filter);
    final names = {for (final project in projects) project.id: project.name};
    final labelNames = {for (final label in labels) label.key: label.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One scrolling row of chips, so phones don't wrap them onto
        // several lines.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            spacing: AppSpacing.sm,
            children: [
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
              if (!calendar)
                _FilterMenu(
                  label: 'Due',
                  options: dueFilterGroups,
                  labelOf: (group) => group.label,
                  selected: filter.due,
                  onChanged: (selected) =>
                      change(filter.copyWith(due: selected)),
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
              // A label that's gone stays listed while it's ticked, so it
              // can be unticked.
              if (labelNames.isNotEmpty || filter.labels.isNotEmpty)
                _FilterMenu<String>(
                  label: 'Label',
                  options: {...labelNames.keys, ...filter.labels}.toList(),
                  labelOf: (key) => labelNames[key] ?? key,
                  selected: filter.labels,
                  onChanged: (selected) =>
                      change(filter.copyWith(labels: selected)),
                ),
            ],
          ),
        ),
        // Under the chips rather than at the end of their row, where it
        // could be scrolled out of sight on a phone.
        if (ref.watch(activeTaskFilterProvider).isFiltering)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    'Showing ${shown.length} of $total '
                    '${total == 1 ? 'task' : 'tasks'}',
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
