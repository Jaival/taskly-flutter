import 'package:flutter/foundation.dart';

/// The colours a label can be. The shades come from the theme
/// (`LabelColors`), so they suit light and dark mode.
///
/// Stored in Firestore by [name], so renaming a value is a data migration.
enum LabelColor {
  grey('Grey'),
  red('Red'),
  orange('Orange'),
  yellow('Yellow'),
  green('Green'),
  teal('Teal'),
  blue('Blue'),
  purple('Purple'),
  pink('Pink');

  const LabelColor(this.label);

  final String label;

  /// Grey for a colour this version of the app doesn't know.
  static LabelColor fromName(Object? name) => values.asNameMap()[name] ?? grey;
}

/// A label on a task ("Design", "Waiting on others"), with a colour.
///
/// Stored inside the task, like its checklist: there's no list of labels
/// anywhere else. The labels of a project (or of someone's personal tasks)
/// are the ones its tasks use, and two labels with the same name, ignoring
/// case, are the same label.
@immutable
class TaskLabel {
  const TaskLabel(this.name, {this.color = LabelColor.grey});

  final String name;
  final LabelColor color;

  /// What makes two labels the same one.
  String get key => labelKey(name);

  TaskLabel copyWith({String? name, LabelColor? color}) =>
      TaskLabel(name ?? this.name, color: color ?? this.color);

  @override
  bool operator ==(Object other) =>
      other is TaskLabel && other.name == name && other.color == color;

  @override
  int get hashCode => Object.hash(name, color);

  @override
  String toString() => 'TaskLabel($name, ${color.name})';
}

/// [name] as it's compared: trimmed, ignoring case.
String labelKey(String name) => name.trim().toLowerCase();

/// The most labels a task can have. The security rules enforce it too.
const maxTaskLabels = 10;

/// The longest a label's name can be.
const maxLabelLength = 30;

/// [labels] ready to store: names trimmed, without blank ones or a label
/// twice (the first is kept), and no more than [maxTaskLabels].
List<TaskLabel> tidyLabels(Iterable<TaskLabel> labels) {
  final byKey = <String, TaskLabel>{};
  for (final label in labels) {
    final name = label.name.trim();
    if (name.isEmpty) continue;
    byKey.putIfAbsent(labelKey(name), () => label.copyWith(name: name));
  }
  return byKey.values.take(maxTaskLabels).toList();
}

/// [labels] with [from] changed to [to], or taken off if [to] is null.
/// One already named like [to] merges into it.
List<TaskLabel> replaceLabel(
  List<TaskLabel> labels,
  TaskLabel from,
  TaskLabel? to,
) {
  final keys = {from.key, ?to?.key};
  return tidyLabels([
    for (final label in labels)
      if (!keys.contains(label.key)) label else ?to,
  ]);
}

/// The labels [tasks] use, each once, A to Z. Where tasks disagree on a
/// label's colour or capitals, the first task in the list wins.
List<TaskLabel> labelsInUse(Iterable<List<TaskLabel>> tasks) {
  final byKey = <String, TaskLabel>{};
  for (final labels in tasks) {
    for (final label in labels) {
      byKey.putIfAbsent(label.key, () => label);
    }
  }
  return byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
}

/// A colour for a new label: the first one none of [existing] has, so
/// labels look different until all the colours are taken.
LabelColor unusedLabelColor(Iterable<TaskLabel> existing) {
  final used = {for (final label in existing) label.color};
  // Grey last: it's the least like a colour.
  final choices = [...LabelColor.values.skip(1), LabelColor.grey];
  return choices.firstWhere(
    (color) => !used.contains(color),
    orElse: () => choices[existing.length % choices.length],
  );
}
