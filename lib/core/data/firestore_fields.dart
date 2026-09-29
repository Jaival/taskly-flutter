import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive readers for Firestore document data.
///
/// Firestore has no schema, so a field can be missing or hold the wrong type
/// (old data, a bug, a hand edit in the console). These readers return a
/// default instead of throwing, so one bad document can't crash a list.
extension FirestoreFields on Map<String, Object?> {
  String? stringOrNull(String field) => switch (this[field]) {
    final String value => value,
    _ => null,
  };

  String string(String field) => stringOrNull(field) ?? '';

  double number(String field) => switch (this[field]) {
    final num value => value.toDouble(),
    _ => 0,
  };

  /// Null while a server timestamp is still pending, or if missing.
  DateTime? dateTime(String field) => switch (this[field]) {
    final Timestamp value => value.toDate(),
    _ => null,
  };

  List<String> stringList(String field) => switch (this[field]) {
    final List<Object?> value => value.whereType<String>().toList(),
    _ => const [],
  };

  Map<String, String> stringMap(String field) => switch (this[field]) {
    final Map<Object?, Object?> value => {
      for (final MapEntry(:key, :value) in value.entries)
        if (key is String && value is String) key: value,
    },
    _ => const {},
  };
}

/// Value to write for a `createdAt` field: the existing time, or the server's
/// clock for a document that hasn't been saved yet.
Object createdAtValue(DateTime? createdAt) => createdAt == null
    ? FieldValue.serverTimestamp()
    : Timestamp.fromDate(createdAt);

/// Value to write for an optional date field.
Timestamp? timestampOrNull(DateTime? value) =>
    value == null ? null : Timestamp.fromDate(value);
