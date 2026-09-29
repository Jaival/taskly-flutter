/// How urgent a project or task is, from most to least urgent.
///
/// Stored in Firestore by [name] (`'immediate'`, `'high'`…), so renaming a
/// value is a data migration.
enum Priority {
  immediate('Immediate'),
  high('High'),
  medium('Medium'),
  low('Low');

  const Priority(this.label);

  /// Text shown in the UI.
  final String label;

  /// Parses a stored value. Anything unknown becomes [medium], so data written
  /// by a newer version of the app can't crash an older one.
  static Priority fromName(Object? name) => values.asNameMap()[name] ?? medium;
}
