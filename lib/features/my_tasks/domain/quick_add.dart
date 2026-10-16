import 'package:flutter/foundation.dart';

import '../../../core/domain/priority.dart';
import '../../tasks/domain/due_date.dart';
import '../../tasks/domain/task_label.dart';

/// What a part of a quick-add line was read as.
enum QuickAddPart { date, priority, label }

/// A task typed on one line, like "Renew passport fri !high #errands", read
/// into its title and details.
@immutable
class QuickAdd {
  const QuickAdd({
    required this.title,
    this.dueDate,
    this.priority,
    this.labels = const [],
    this.parts = const [],
  });

  /// What's left once the details are taken out.
  final String title;
  final DateTime? dueDate;

  /// Null if none was given: the task gets the usual one.
  final Priority? priority;
  final List<TaskLabel> labels;

  /// Where in the line each detail was found, as (start, end) offsets, to
  /// highlight them as they're typed.
  final List<(int, int, QuickAddPart)> parts;
}

/// Reads [text] as a quick-add line, with dates counted from [today].
///
/// - **Dates:** "today", "tomorrow" (or "tmr"), a weekday ("friday",
///   "fri"), "next week", "next month", "in 3 days" (or weeks, months), and a
///   day of a month ("oct 23", "23 october"). A weekday or date that has
///   passed means the next one.
/// - **Priority:** "!urgent" (or "!immediate"), "!high", "!medium", "!low",
///   or "!1" to "!4" and "p1" to "p4".
/// - **Labels:** "#name". One of [knownLabels] with that name, ignoring
///   case, or a new one in a colour none of them has.
///
/// The last date and priority win. Words that aren't any of these are the
/// title. "sat", "sun" and "wed" aren't read as days, since they're words
/// too ("Buy sun cream").
QuickAdd parseQuickAdd(
  String text, {
  required DateTime today,
  List<TaskLabel> knownLabels = const [],
}) {
  today = dateOnly(today);
  final words = [
    for (final match in RegExp(r'\S+').allMatches(text))
      (match.start, match.end, match.group(0)!),
  ];
  final parts = <(int, int, QuickAddPart)>[];
  final titleWords = <String>[];
  DateTime? due;
  Priority? priority;
  final labels = <TaskLabel>[];

  var i = 0;
  while (i < words.length) {
    // The longest date starting here, if there's one.
    final date = _readDate(words, i, today);
    if (date != null) {
      final (day, length) = date;
      due = day;
      parts.add((words[i].$1, words[i + length - 1].$2, QuickAddPart.date));
      i += length;
      continue;
    }
    final (start, end, word) = words[i];
    if (_priorities[word.toLowerCase()] case final p?) {
      priority = p;
      parts.add((start, end, QuickAddPart.priority));
    } else if (RegExp(r'^#([\p{L}\p{N}_-]+)$', unicode: true).firstMatch(word)
        case final match?) {
      final name = match.group(1)!;
      final known = [...knownLabels, ...labels];
      final label =
          known.where((l) => l.key == labelKey(name)).firstOrNull ??
          TaskLabel(name, color: unusedLabelColor(known));
      if (!labels.any((l) => l.key == label.key) &&
          labels.length < maxTaskLabels) {
        labels.add(label);
      }
      parts.add((start, end, QuickAddPart.label));
    } else {
      titleWords.add(word);
    }
    i++;
  }

  return QuickAdd(
    title: titleWords.join(' '),
    dueDate: due,
    priority: priority,
    labels: labels,
    parts: parts,
  );
}

const _priorities = {
  '!urgent': Priority.immediate,
  '!immediate': Priority.immediate,
  '!1': Priority.immediate,
  'p1': Priority.immediate,
  '!high': Priority.high,
  '!2': Priority.high,
  'p2': Priority.high,
  '!medium': Priority.medium,
  '!med': Priority.medium,
  '!3': Priority.medium,
  'p3': Priority.medium,
  '!low': Priority.low,
  '!4': Priority.low,
  'p4': Priority.low,
};

const _weekdays = {
  'monday': DateTime.monday,
  'mon': DateTime.monday,
  'tuesday': DateTime.tuesday,
  'tue': DateTime.tuesday,
  'tues': DateTime.tuesday,
  'wednesday': DateTime.wednesday,
  'thursday': DateTime.thursday,
  'thu': DateTime.thursday,
  'thurs': DateTime.thursday,
  'friday': DateTime.friday,
  'fri': DateTime.friday,
  'saturday': DateTime.saturday,
  'sunday': DateTime.sunday,
};

const _months = {
  'january': 1,
  'jan': 1,
  'february': 2,
  'feb': 2,
  'march': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'may': 5,
  'june': 6,
  'jun': 6,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sep': 9,
  'sept': 9,
  'october': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'december': 12,
  'dec': 12,
};

/// A date that starts at word [i], and how many words it takes.
(DateTime, int)? _readDate(
  List<(int, int, String)> words,
  int i,
  DateTime today,
) {
  String word(int at) =>
      at < words.length ? words[at].$3.toLowerCase().replaceAll(',', '') : '';
  final first = word(i);

  switch (first) {
    case 'today' || 'tod':
      return (today, 1);
    case 'tomorrow' || 'tmr' || 'tmrw':
      return (_addDays(today, 1), 1);
    case 'next' when word(i + 1) == 'week':
      return (_addDays(today, 7), 2);
    case 'next' when word(i + 1) == 'month':
      return (_addMonths(today, 1), 2);
    case 'next' when _weekdays.containsKey(word(i + 1)):
      // "Next friday" said on a Friday is a week away.
      return (_nextWeekday(_addDays(today, 1), _weekdays[word(i + 1)]!), 2);
  }
  if (_weekdays[first] case final weekday?) {
    return (_nextWeekday(today, weekday), 1);
  }
  if (first == 'in') {
    final count = int.tryParse(word(i + 1));
    final unit = word(i + 2);
    if (count != null && count > 0 && count <= 365) {
      if (unit == 'day' || unit == 'days') {
        return (_addDays(today, count), 3);
      }
      if (unit == 'week' || unit == 'weeks') {
        return (_addDays(today, count * 7), 3);
      }
      if (unit == 'month' || unit == 'months') {
        return (_addMonths(today, count), 3);
      }
    }
  }
  // "oct 23" or "23 oct".
  final (month, day) = switch ((
    _months[first],
    _dayOfMonth(word(i + 1)),
    _dayOfMonth(first),
    _months[word(i + 1)],
  )) {
    (final m?, final d?, _, _) => (m, d),
    (_, _, final d?, final m?) => (m, d),
    _ => (null, null),
  };
  if (month != null && day != null) {
    var date = DateTime(today.year, month, day);
    // Not a real day (Feb 30): not a date after all.
    if (date.month != month) return null;
    if (date.isBefore(today)) date = DateTime(today.year + 1, month, day);
    return (date, 2);
  }
  return null;
}

/// 1 to 31 from "23" or "23rd".
int? _dayOfMonth(String word) {
  final match = RegExp(r'^(\d{1,2})(st|nd|rd|th)?$').firstMatch(word);
  final day = match == null ? null : int.parse(match.group(1)!);
  return day != null && day >= 1 && day <= 31 ? day : null;
}

DateTime _addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// The same day [months] later, or the last day of a shorter month.
DateTime _addMonths(DateTime day, int months) {
  final firstOfMonth = DateTime(day.year, day.month + months);
  final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
  return DateTime(
    firstOfMonth.year,
    firstOfMonth.month,
    day.day > lastDay ? lastDay : day.day,
  );
}

/// The next [weekday], counting today.
DateTime _nextWeekday(DateTime today, int weekday) =>
    _addDays(today, (weekday - today.weekday) % 7);
