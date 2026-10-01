import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../domain/checklist_item.dart';

/// Edits a task's checklist in the task form: tick, rename, remove and add
/// items. Enter in an item adds a new one below it.
///
/// Reports every change through [onChanged]. Blank items are reported too;
/// the repository drops them when saving.
class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final List<ChecklistItem> initial;
  final ValueChanged<List<ChecklistItem>> onChanged;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

/// One item while it's being edited. Its own key, so removing an item
/// doesn't hand its text field to the next one.
class _Row {
  _Row(ChecklistItem item)
    : text = TextEditingController(text: item.text),
      done = item.done;

  final key = UniqueKey();
  final TextEditingController text;
  final focus = FocusNode();
  bool done;

  ChecklistItem get item => ChecklistItem(text.text, done: done);

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  late final List<_Row> _rows = [
    for (final item in widget.initial) _newRow(item),
  ];

  // Rebuilds on typing too: labels and tooltips name each item.
  _Row _newRow(ChecklistItem item) => _Row(item)..text.addListener(_changed);

  void _changed() {
    setState(() {});
    _report();
  }

  void _report() => widget.onChanged([for (final row in _rows) row.item]);

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _add({int? at}) {
    if (_rows.length >= maxChecklistItems) return;
    final row = _newRow(const ChecklistItem(''));
    setState(() => _rows.insert(at ?? _rows.length, row));
    _report();
    // Type straight into it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) row.focus.requestFocus();
    });
  }

  void _remove(_Row row) {
    setState(() => _rows.remove(row));
    row.dispose();
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _rows.where((row) => row.done).length;
    final full = _rows.length >= maxChecklistItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _rows.isEmpty ? 'Checklist' : 'Checklist · $done/${_rows.length}',
          style: theme.textTheme.titleSmall,
        ),
        for (final (index, row) in _rows.indexed)
          Row(
            key: row.key,
            children: [
              Checkbox(
                value: row.done,
                semanticLabel: row.text.text.isEmpty
                    ? 'Done'
                    : 'Done: ${row.text.text}',
                onChanged: (value) {
                  setState(() => row.done = value ?? false);
                  _report();
                },
              ),
              Expanded(
                child: TextField(
                  controller: row.text,
                  focusNode: row.focus,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _add(at: index + 1),
                  style: row.done
                      ? TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                  decoration: const InputDecoration(
                    hintText: 'Item',
                    isDense: true,
                    border: InputBorder.none,
                    // The 200-character limit, without a counter under
                    // every line.
                    counterText: '',
                  ),
                ),
              ),
              IconButton(
                tooltip: row.text.text.isEmpty
                    ? 'Remove item'
                    : 'Remove "${row.text.text}"',
                icon: const Icon(Icons.close),
                onPressed: () => _remove(row),
              ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: full ? null : _add,
            icon: const Icon(Icons.add),
            label: Text(
              full ? 'At most $maxChecklistItems items' : 'Add an item',
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
      ],
    );
  }
}
