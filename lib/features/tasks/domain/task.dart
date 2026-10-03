import 'package:flutter/foundation.dart';

import '../../../core/domain/priority.dart';
import '../../../core/domain/task_status.dart';
import 'checklist_item.dart';
import 'task_label.dart';
import 'task_repeat.dart';

/// A task, either in a project (`projects/{projectId}/tasks/{id}`) or
/// personal (`tasks/{id}`).
@immutable
class Task {
  const Task({
    required this.id,
    required this.ownerId,
    required this.title,
    this.projectId,
    this.description = '',
    this.priority = Priority.medium,
    this.status = TaskStatus.notStarted,
    this.assigneeId,
    this.dueDate,
    this.repeat,
    this.checklist = const [],
    this.labels = const [],
    this.order = 0,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  final String id;

  /// The project this task belongs to, or null for a personal task. Comes
  /// from the document's path, not from a field.
  final String? projectId;

  /// Who created the task. For personal tasks, the only person who can see it.
  final String ownerId;

  final String title;
  final String description;
  final Priority priority;
  final TaskStatus status;
  final String? assigneeId;
  final DateTime? dueDate;

  /// How often the task comes round again, or null if it doesn't. Counted
  /// from [dueDate], so it means nothing without one: see [repeats].
  final TaskRepeat? repeat;

  /// Whether completing the task adds the next one.
  bool get repeats => repeat != null && dueDate != null;

  /// Smaller steps inside the task, in order.
  final List<ChecklistItem> checklist;

  /// How many [checklist] items are ticked.
  int get checklistDone => checklist.where((item) => item.done).length;

  /// Its labels, in the order they were added.
  final List<TaskLabel> labels;

  /// Sort position within a list. A double, so a task dragged between two
  /// others can take the midpoint without renumbering the rest.
  final double order;

  /// Set by the server. Null until the first write reaches it.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// When the status last became complete; null for an open task. Also
  /// null for tasks completed before this was recorded, and until the
  /// write reaches the server.
  final DateTime? completedAt;

  bool get isPersonal => projectId == null;

  bool get isComplete => status == TaskStatus.complete;

  /// Copies the task. Pass `assigneeId: () => null` to unassign, since a plain
  /// null means "keep the current value".
  Task copyWith({
    String? title,
    String? description,
    Priority? priority,
    TaskStatus? status,
    ValueGetter<String?>? assigneeId,
    ValueGetter<DateTime?>? dueDate,
    ValueGetter<TaskRepeat?>? repeat,
    List<ChecklistItem>? checklist,
    List<TaskLabel>? labels,
    double? order,
  }) => Task(
    id: id,
    projectId: projectId,
    ownerId: ownerId,
    title: title ?? this.title,
    description: description ?? this.description,
    priority: priority ?? this.priority,
    status: status ?? this.status,
    assigneeId: assigneeId != null ? assigneeId() : this.assigneeId,
    dueDate: dueDate != null ? dueDate() : this.dueDate,
    repeat: repeat != null ? repeat() : this.repeat,
    checklist: checklist ?? this.checklist,
    labels: labels ?? this.labels,
    order: order ?? this.order,
    createdAt: createdAt,
    updatedAt: updatedAt,
    completedAt: completedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Task &&
      other.id == id &&
      other.projectId == projectId &&
      other.ownerId == ownerId &&
      other.title == title &&
      other.description == description &&
      other.priority == priority &&
      other.status == status &&
      other.assigneeId == assigneeId &&
      other.dueDate == dueDate &&
      other.repeat == repeat &&
      listEquals(other.checklist, checklist) &&
      listEquals(other.labels, labels) &&
      other.order == order &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.completedAt == completedAt;

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    ownerId,
    title,
    description,
    priority,
    status,
    assigneeId,
    dueDate,
    repeat,
    Object.hashAll(checklist),
    Object.hashAll(labels),
    order,
    createdAt,
    updatedAt,
    completedAt,
  );

  @override
  String toString() => 'Task($id, $title)';
}
