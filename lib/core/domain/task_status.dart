/// Progress of a project or task.
///
/// Stored in Firestore by [name], so renaming a value is a data migration.
enum TaskStatus {
  notStarted('Not started'),
  inProgress('In progress'),
  complete('Complete');

  const TaskStatus(this.label);

  /// Text shown in the UI.
  final String label;

  /// Parses a stored value. Anything unknown becomes [notStarted], so data
  /// written by a newer version of the app can't crash an older one.
  static TaskStatus fromName(Object? name) =>
      values.asNameMap()[name] ?? notStarted;
}
