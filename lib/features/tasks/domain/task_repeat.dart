/// How often a task comes round again. Completing a repeating task adds the
/// next one, due a step later.
enum TaskRepeat {
  daily('Every day'),
  weekly('Every week'),
  monthly('Every month');

  const TaskRepeat(this.label);

  /// Text shown in the UI.
  final String label;

  /// Parses a stored value. Anything unknown is null, "doesn't repeat", so
  /// a schedule added by a newer version of the app can't crash an older
  /// one.
  static TaskRepeat? fromName(Object? name) {
    for (final repeat in values) {
      if (repeat.name == name) return repeat;
    }
    return null;
  }

  /// [due] moved on by [steps] of this schedule.
  DateTime _after(DateTime due, int steps) => switch (this) {
    // By the calendar, not by adding hours: the day the clocks change is 23
    // or 25 hours long.
    daily => DateTime(due.year, due.month, due.day + steps),
    weekly => DateTime(due.year, due.month, due.day + 7 * steps),
    monthly => _sameDayOfMonth(due.year, due.month + steps, due.day),
  };

  /// When the next one is due, for a task due on [due] that was completed
  /// on [today]: the first date on the schedule after both.
  ///
  /// So a weekly task done two days early still comes back a week after it
  /// was due, and a daily task done three days late comes back tomorrow
  /// rather than three more times at once.
  DateTime next(DateTime due, DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    var steps = 1;
    while (!_after(due, steps).isAfter(day)) {
      steps++;
    }
    return _after(due, steps);
  }
}

/// The [day]th of a month, or its last day if it's shorter: the 31st of
/// January, then the 28th of February. [month] may run past 12.
DateTime _sameDayOfMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day < lastDay ? day : lastDay);
}
