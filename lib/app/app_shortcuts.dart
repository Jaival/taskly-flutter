import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme/app_spacing.dart';

class NewTaskIntent extends Intent {
  const NewTaskIntent();
}

class SearchTasksIntent extends Intent {
  const SearchTasksIntent();
}

class ShowShortcutsIntent extends Intent {
  const ShowShortcutsIntent();
}

/// What the keyboard shortcuts dialog lists. Esc isn't one of ours: Flutter
/// closes dialogs, sheets and menus with it already.
const _help = [
  ('N', 'New task'),
  ('/', 'Search tasks'),
  ('?', 'Show these shortcuts'),
  ('Esc', 'Close a form, dialog or menu, or clear the search'),
];

/// Single-key shortcuts for the signed-in pages: N for a new task, / to
/// search, ? for the list of them.
///
/// They work wherever the focus is inside [child], except in a text field,
/// where the keys are typed instead. Forms and dialogs open above the
/// shell, outside [child], so the shortcuts are off while one is open.
class AppShortcuts extends StatelessWidget {
  const AppShortcuts({
    super.key,
    required this.onNewTask,
    required this.onSearch,
    required this.child,
  });

  final VoidCallback onNewTask;
  final VoidCallback onSearch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyN): NewTaskIntent(),
        // By the character typed, not the key: "/" and "?" sit on different
        // keys on different keyboard layouts.
        CharacterActivator('/'): SearchTasksIntent(),
        CharacterActivator('?'): ShowShortcutsIntent(),
      },
      child: Actions(
        actions: {
          NewTaskIntent: _UnlessTyping<NewTaskIntent>(onNewTask),
          SearchTasksIntent: _UnlessTyping<SearchTasksIntent>(onSearch),
          ShowShortcutsIntent: _UnlessTyping<ShowShortcutsIntent>(
            () => showShortcutsHelp(context),
          ),
        },
        // Keys go to whatever has the focus, then up through its parents.
        // This scope keeps the focus inside the shell when the thing that
        // had it goes away (a tab is left, a card is deleted). Without it,
        // the focus would fall back to the route above the shell, and the
        // keys would never pass through here.
        child: FocusScope(autofocus: true, child: child),
      ),
    );
  }
}

/// Runs [run], unless the focus is in a text field. A disabled action lets
/// the key through, so "n" is typed rather than opening a form.
class _UnlessTyping<T extends Intent> extends CallbackAction<T> {
  _UnlessTyping(VoidCallback run)
    : super(
        onInvoke: (_) {
          run();
          return null;
        },
      );

  @override
  bool isEnabled(T intent) {
    final focused = FocusManager.instance.primaryFocus?.context;
    return focused == null ||
        !(focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }
}

/// Lists the keyboard shortcuts.
Future<void> showShortcutsHelp(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Keyboard shortcuts'),
    scrollable: true,
    content: Table(
      columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (final (key, what) in _help)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  right: AppSpacing.md,
                  top: AppSpacing.xs,
                  bottom: AppSpacing.xs,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _KeyCap(key),
                ),
              ),
              Text(what),
            ],
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);

/// A key's name, drawn like a key.
class _KeyCap extends StatelessWidget {
  const _KeyCap(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(AppSpacing.xs)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge,
      ),
    );
  }
}
