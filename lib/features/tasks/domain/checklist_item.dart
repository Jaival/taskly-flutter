import 'package:flutter/foundation.dart';

/// One line of a task's checklist. Stored inside the task document, so a
/// task and its checklist are always read and written together.
@immutable
class ChecklistItem {
  const ChecklistItem(this.text, {this.done = false});

  final String text;
  final bool done;

  ChecklistItem copyWith({String? text, bool? done}) =>
      ChecklistItem(text ?? this.text, done: done ?? this.done);

  @override
  bool operator ==(Object other) =>
      other is ChecklistItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);

  @override
  String toString() => 'ChecklistItem($text, done: $done)';
}

/// The most items a checklist can have. The security rules enforce it too.
const maxChecklistItems = 50;
