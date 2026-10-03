import 'dart:convert';

import '../../tasks/domain/task.dart';
import 'my_task.dart';

/// [items] as a spreadsheet: one row per task under a header row, in the
/// CSV format every spreadsheet program opens (RFC 4180).
String tasksToCsv(Iterable<MyTask> items) {
  final rows = [
    const [
      'Title',
      'Description',
      'Status',
      'Priority',
      'Due date',
      'Project',
      'Checklist',
      'Created',
      'Completed',
    ],
    for (final MyTask(:task, :project) in items)
      [
        task.title,
        task.description,
        task.status.label,
        task.priority.label,
        _date(task.dueDate),
        project?.name ?? '',
        _checklist(task),
        _date(task.createdAt),
        _date(task.completedAt),
      ],
  ];
  return [for (final row in rows) '${row.map(_csvCell).join(',')}\r\n'].join();
}

/// "2 of 5" ticked, or nothing without a checklist.
String _checklist(Task task) => task.checklist.isEmpty
    ? ''
    : '${task.checklistDone} of ${task.checklist.length}';

/// 2026-10-03: sorts correctly, and no spreadsheet mistakes day for month.
String _date(DateTime? date) => date == null
    ? ''
    : '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-'
          '${_two(date.day)}';

String _two(int number) => number.toString().padLeft(2, '0');

String _csvCell(String text) {
  // A cell starting with one of these is run as a formula by spreadsheet
  // programs, and a task's title can be typed by anyone in the project. The
  // apostrophe makes it plain text.
  final safe = text.startsWith(RegExp(r'[=+\-@\t\r]')) ? "'$text" : text;
  final needsQuotes = safe.contains(RegExp('[",\r\n]')) || safe != safe.trim();
  return needsQuotes ? '"${safe.replaceAll('"', '""')}"' : safe;
}

/// The tasks in [items] that have a due date, as all-day events in the
/// iCalendar format calendar programs import (RFC 5545). Done tasks are
/// marked with a tick. [now] stamps the file.
///
/// Events rather than to-dos: Google Calendar and Outlook ignore to-dos in
/// an imported file.
String tasksToICal(Iterable<MyTask> items, {required DateTime now}) {
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Taskly//Tasks//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'X-WR-CALNAME:Taskly tasks',
    for (final MyTask(:task, :project) in items)
      if (task.dueDate case final due?) ...[
        'BEGIN:VEVENT',
        // The same task exported again replaces the event instead of
        // adding a second one, in calendars that match on this.
        'UID:${[?task.projectId, task.id].join('-')}@taskly',
        'DTSTAMP:${_utcStamp(now)}',
        'DTSTART;VALUE=DATE:${_day(due)}',
        // The end of an all-day event is the day after.
        'DTEND;VALUE=DATE:${_day(DateTime(due.year, due.month, due.day + 1))}',
        'SUMMARY:${_iCalText(task.isComplete ? '✓ ${task.title}' : task.title)}',
        if (task.description.isNotEmpty)
          'DESCRIPTION:${_iCalText(task.description)}',
        if (project != null) 'CATEGORIES:${_iCalText(project.name)}',
        // Doesn't mark the day as busy.
        'TRANSP:TRANSPARENT',
        'END:VEVENT',
      ],
    'END:VCALENDAR',
  ];
  return [for (final line in lines) '${_fold(line)}\r\n'].join();
}

String _day(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${_two(date.month)}'
    '${_two(date.day)}';

String _utcStamp(DateTime moment) {
  final utc = moment.toUtc();
  return '${_day(utc)}T${_two(utc.hour)}${_two(utc.minute)}'
      '${_two(utc.second)}Z';
}

String _iCalText(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp('\r\n|\r|\n'), r'\n');

/// Breaks a long line the way the format asks: at most 75 bytes each, the
/// continuations starting with a space. Never in the middle of a character.
String _fold(String line) {
  const limit = 75;
  final folded = StringBuffer();
  var length = 0;
  for (final rune in line.runes) {
    final character = String.fromCharCode(rune);
    final size = utf8.encode(character).length;
    if (length + size > limit) {
      folded.write('\r\n ');
      // The space counts.
      length = 1;
    }
    folded.write(character);
    length += size;
  }
  return folded.toString();
}
