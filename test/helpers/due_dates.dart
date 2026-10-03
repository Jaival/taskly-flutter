import 'package:cloud_firestore/cloud_firestore.dart';

/// Today plus [days], as a due date is stored: midnight UTC on that day.
Timestamp dueTimestamp(int days) {
  final day = DateTime.now().add(Duration(days: days));
  return Timestamp.fromDate(DateTime.utc(day.year, day.month, day.day));
}
