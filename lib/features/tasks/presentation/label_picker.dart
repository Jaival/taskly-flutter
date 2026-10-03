import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/label_colors.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/form_error.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import '../domain/task_label.dart';
import 'label_chip.dart';

/// Renames or recolours a label on every task that has it, or takes it off
/// them when `to` is null.
typedef EditLabel = Future<void> Function(TaskLabel from, TaskLabel? to);

/// A task's labels in the task form, and a button to add more.
class LabelsField extends StatelessWidget {
  const LabelsField({
    super.key,
    required this.labels,
    required this.projectId,
    required this.onChanged,
    required this.onEdit,
  });

  final List<TaskLabel> labels;

  /// Where the task is, for the labels already in use there: a project,
  /// or null for personal tasks.
  final String? projectId;

  final ValueChanged<List<TaskLabel>> onChanged;
  final EditLabel onEdit;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<List<TaskLabel>>(
      context: context,
      builder: (context) =>
          LabelPicker(selected: labels, projectId: projectId, onEdit: onEdit),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Labels', style: Theme.of(context).textTheme.titleSmall),
        if (labels.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final label in labels)
                LabelChip(
                  label,
                  onDeleted: () => onChanged([
                    for (final other in labels)
                      if (other.key != label.key) other,
                  ]),
                ),
            ],
          ),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.new_label_outlined),
            label: Text(labels.isEmpty ? 'Add a label' : 'Change labels'),
          ),
        ),
      ],
    );
  }
}

/// Picks a task's labels from the ones in use in the same place (the
/// project, or the user's personal tasks), or adds a new one. Each can be
/// renamed, recoloured or deleted from here too, on every task at once.
///
/// Resolves to the labels picked, or null if dismissed.
class LabelPicker extends ConsumerStatefulWidget {
  const LabelPicker({
    super.key,
    required this.selected,
    required this.projectId,
    required this.onEdit,
  });

  final List<TaskLabel> selected;
  final String? projectId;
  final EditLabel onEdit;

  @override
  ConsumerState<LabelPicker> createState() => _LabelPickerState();
}

class _LabelPickerState extends ConsumerState<LabelPicker> {
  late List<TaskLabel> _selected = widget.selected;
  final _name = TextEditingController();
  LabelColor? _color;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _full => _selected.length >= maxTaskLabels;

  bool _isSelected(TaskLabel label) =>
      _selected.any((other) => other.key == label.key);

  void _toggle(TaskLabel label) => setState(() {
    _selected = _isSelected(label)
        ? [
            for (final other in _selected)
              if (other.key != label.key) other,
          ]
        : [..._selected, label];
  });

  /// Adds the label typed: the one of that name if there is one, or a new
  /// one in the colour picked.
  void _add(List<TaskLabel> known, LabelColor color) {
    final name = _name.text.trim();
    if (name.isEmpty || _full) return;
    final label = known.firstWhere(
      (label) => label.key == labelKey(name),
      orElse: () => TaskLabel(name, color: color),
    );
    if (!_isSelected(label)) _toggle(label);
    _name.clear();
    setState(() => _color = null);
  }

  Future<void> _edit(TaskLabel label, List<TaskLabel> known) async {
    final edit = await showDialog<_LabelEdit>(
      context: context,
      builder: (context) => _EditLabelDialog(
        label: label,
        others: [
          for (final other in known)
            if (other.key != label.key) other,
        ],
        personal: widget.projectId == null,
      ),
    );
    if (edit == null || !mounted) return;
    setState(() => _error = null);
    try {
      await widget.onEdit(label, edit.to);
      if (mounted) {
        setState(() => _selected = replaceLabel(_selected, label, edit.to));
      }
    } on FirebaseException {
      if (mounted) {
        setState(
          () => _error = "Couldn't change the label. Check your connection.",
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = switch (widget.projectId) {
      null => ref.watch(personalTasksProvider),
      final projectId => ref.watch(projectTasksProvider(projectId)),
    };
    // Saved in this place already; the rest were added in this form.
    final saved = labelsInUse([
      for (final task in tasks.value ?? const <Task>[]) task.labels,
    ]);
    final known = labelsInUse([saved, _selected]);
    final savedKeys = {for (final label in saved) label.key};

    final query = labelKey(_name.text);
    final shown = [
      for (final label in known)
        if (label.key.contains(query)) label,
    ];
    final isNew = query.isNotEmpty && !known.any((l) => l.key == query);
    final color = _color ?? unusedLabelColor(known);

    return AlertDialog(
      title: const Text('Labels'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: maxLabelLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: known.isEmpty ? 'New label' : 'Find or add a label',
                prefixIcon: const Icon(Icons.search),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _add(known, color),
            ),
            if (isNew) ...[
              const SizedBox(height: AppSpacing.md),
              LabelColorPicker(
                value: color,
                onChanged: (color) => setState(() => _color = color),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _full ? null : () => _add(known, color),
                  icon: const Icon(Icons.add),
                  label: Text('Add "${_name.text.trim()}"'),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (known.isEmpty)
              Text(
                'No labels yet. Type a name to add one.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (final label in shown)
              CheckboxListTile(
                value: _isSelected(label),
                onChanged: _isSelected(label) || !_full
                    ? (_) => _toggle(label)
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    LabelDot(label.color, size: 12),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(label.name, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                // Only labels already saved are on other tasks to change.
                secondary: savedKeys.contains(label.key)
                    ? IconButton(
                        tooltip: 'Edit the label ${label.name}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(label, known),
                      )
                    : null,
              ),
            if (_full) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'A task can have at most $maxTaskLabels labels.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.sm),
              FormError(error),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// What to do to a label everywhere: change it to [to], or delete it if
/// that's null.
typedef _LabelEdit = ({TaskLabel? to});

class _EditLabelDialog extends StatefulWidget {
  const _EditLabelDialog({
    required this.label,
    required this.others,
    required this.personal,
  });

  final TaskLabel label;

  /// The other labels in use, which a rename would merge with.
  final List<TaskLabel> others;

  final bool personal;

  @override
  State<_EditLabelDialog> createState() => _EditLabelDialogState();
}

class _EditLabelDialogState extends State<_EditLabelDialog> {
  late final _name = TextEditingController(text: widget.label.name);
  late LabelColor _color = widget.label.color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _where =>
      widget.personal ? 'all your tasks' : 'every task in this project';

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete "${widget.label.name}"?',
      message: 'It comes off $_where. The tasks themselves stay.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed && mounted) Navigator.pop<_LabelEdit>(context, (to: null));
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop<_LabelEdit>(context, (to: TaskLabel(name, color: _color)));
  }

  @override
  Widget build(BuildContext context) {
    final name = _name.text.trim();
    final merges = widget.others.where((other) => other.key == labelKey(name));
    return AlertDialog(
      title: const Text('Edit label'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: maxLabelLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: name.isEmpty ? 'Enter a name.' : null,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: AppSpacing.sm),
            LabelColorPicker(
              value: _color,
              onChanged: (color) => setState(() => _color = color),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              merges.isEmpty
                  ? 'Changes it on $_where.'
                  : 'There is a label called "${merges.first.name}" '
                        'already. Tasks with either will have this one.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _delete,
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: name.isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// A row of colours to pick one from.
class LabelColorPicker extends StatelessWidget {
  const LabelColorPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final LabelColor value;
  final ValueChanged<LabelColor> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<LabelColors>()!;
    final outline = Theme.of(context).colorScheme.onSurface;
    final surface = Theme.of(context).colorScheme.surface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Colour', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          children: [
            for (final color in LabelColor.values)
              Semantics(
                inMutuallyExclusiveGroup: true,
                checked: color == value,
                child: IconButton(
                  tooltip: color.label,
                  onPressed: () => onChanged(color),
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.of(color),
                      shape: BoxShape.circle,
                      border: color == value
                          ? Border.all(color: outline, width: 3)
                          : null,
                    ),
                    // The surface colour stands out on every label colour.
                    child: color == value
                        ? Icon(Icons.check, size: 16, color: surface)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
