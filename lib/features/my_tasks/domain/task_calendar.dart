import '../../tasks/domain/due_date.dart';
import '../../tasks/domain/task.dart';

/// The days a month view shows for the month [day] is in: whole weeks, so
/// it starts with the last days of the month before and ends with the first
/// of the next.
///
/// [firstDayOfWeek] is 0 for Sunday, 1 for Monday and so on, as in
/// `MaterialLocalizations.firstDayOfWeekIndex`.
List<DateTime> calendarDays(DateTime day, {required int firstDayOfWeek}) {
  final first = DateTime(day.year, day.month);
  final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
  // DateTime.weekday runs from 1 (Monday) to 7 (Sunday).
  final before = (first.weekday % 7 - firstDayOfWeek + 7) % 7;
  final cells = ((before + daysInMonth) / 7).ceil() * 7;
  return [
    // By day of the month, not by adding 24 hours: the day the clocks change
    // is 23 or 25 hours long.
    for (var i = 0; i < cells; i++)
      DateTime(day.year, day.month, 1 - before + i),
  ];
}

bool sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

/// [items] by the day their task is due, in the order they came in. Tasks
/// without a due date are left out. [taskOf] gets the task from an item.
Map<DateTime, List<T>> groupByDay<T>(
  Iterable<T> items,
  Task Function(T) taskOf,
) {
  final days = <DateTime, List<T>>{};
  for (final item in items) {
    if (taskOf(item).dueDate case final due?) {
      days.putIfAbsent(dateOnly(due), () => []).add(item);
    }
  }
  return days;
}
