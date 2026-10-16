import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/priority_colors.dart';
import '../../../core/domain/priority.dart';
import '../../auth/data/auth_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task_label.dart';
import '../../tasks/presentation/due_date_label.dart';
import '../../tasks/presentation/label_chip.dart';
import '../../tasks/presentation/task_form.dart';
import '../domain/quick_add.dart';

/// One line to add a personal task, with its details typed in: "Renew
/// passport fri !high #errands". What's recognised is highlighted as it's
/// typed, and shown under the box. Enter adds it and leaves the box ready
/// for the next one. The expand button opens the full form with what's
/// been typed so far.
class QuickAddField extends ConsumerStatefulWidget {
  const QuickAddField({
    super.key,
    this.knownLabels = const [],
    this.defaultDueDate,
  });

  /// The labels already on personal tasks, so "#design" picks the one there
  /// is, colour and all.
  final List<TaskLabel> knownLabels;

  /// The due date when none is typed (the chosen day, in the calendar).
  final DateTime? defaultDueDate;

  @override
  ConsumerState<QuickAddField> createState() => _QuickAddFieldState();
}

class _QuickAddFieldState extends ConsumerState<QuickAddField> {
  late final _controller = _HighlightingController(
    (text) => _parse(text).parts,
  );
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  QuickAdd _parse(String text) => parseQuickAdd(
    text,
    today: DateTime.now(),
    knownLabels: widget.knownLabels,
  );

  Future<void> _add() async {
    final typed = _controller.text;
    final parsed = _parse(typed);
    if (parsed.title.isEmpty) return;
    // Emptied straight away, ready for the next one, and put back if the
    // task couldn't be added.
    _controller.clear();
    _focus.requestFocus();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(taskRepositoryProvider)
          .createTask(
            ownerId: ref.read(authRepositoryProvider).currentUser!.uid,
            title: parsed.title,
            priority: parsed.priority ?? Priority.medium,
            dueDate: parsed.dueDate ?? widget.defaultDueDate,
            labels: parsed.labels,
          );
    } on FirebaseException {
      if (mounted && _controller.text.isEmpty) _controller.text = typed;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't add the task. Try again.")),
      );
    }
  }

  Future<void> _moreOptions() async {
    final parsed = _parse(_controller.text);
    final saved = await showTaskForm(
      context,
      title: parsed.title,
      priority: parsed.priority,
      dueDate: parsed.dueDate ?? widget.defaultDueDate,
      labels: parsed.labels,
    );
    if (saved) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final parsed = _parse(_controller.text);
        final canAdd = parsed.title.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              focusNode: _focus,
              textInputAction: TextInputAction.done,
              // Enter adds it; the box keeps the focus for the next one.
              onSubmitted: (_) => _add(),
              onTapOutside: (_) => _focus.unfocus(),
              decoration: InputDecoration(
                labelText: 'Quick add',
                hintText: 'Call Bob tomorrow !high #work',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: const Icon(Icons.add),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'More options',
                      icon: const Icon(Icons.open_in_full),
                      onPressed: _moreOptions,
                    ),
                    IconButton(
                      tooltip: 'Add task',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: canAdd ? _add : null,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
              ),
            ),
            if (parsed.parts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _Preview(parsed),
            ],
          ],
        );
      },
    );
  }
}

/// What the details typed in will be: the due date, priority and labels.
class _Preview extends StatelessWidget {
  const _Preview(this.parsed);

  final QuickAdd parsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final style = theme.textTheme.labelMedium?.copyWith(color: muted);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (parsed.dueDate case final due?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_outlined, size: 16, color: muted),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Due ${formatDueDate(MaterialLocalizations.of(context), due, DateTime.now())}',
                style: style,
              ),
            ],
          ),
        if (parsed.priority case final priority?)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag,
                size: 16,
                color: theme.extension<PriorityColors>()!.of(priority),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('${priority.label} priority', style: style),
            ],
          ),
        for (final label in parsed.labels) LabelChip(label),
      ],
    );
  }
}

/// Draws the recognised details in the accent colour, on a tint of it.
class _HighlightingController extends TextEditingController {
  _HighlightingController(this.partsOf);

  final List<(int, int, QuickAddPart)> Function(String text) partsOf;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final parts = partsOf(text);
    // While an IME is composing a word, leave the underline it draws alone.
    if (parts.isEmpty || (withComposing && value.isComposingRangeValid)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final colors = Theme.of(context).colorScheme;
    final highlight = style?.copyWith(
      color: colors.primary,
      backgroundColor: colors.primaryContainer,
      fontWeight: FontWeight.w600,
    );
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end, _) in parts) {
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(TextSpan(text: text.substring(start, end), style: highlight));
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}
