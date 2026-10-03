import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/core/data/file_export.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/my_tasks/domain/my_task.dart';
import 'package:taskly/features/my_tasks/domain/task_export.dart';
import 'package:taskly/features/projects/domain/project.dart';
import 'package:taskly/features/tasks/domain/checklist_item.dart';
import 'package:taskly/features/tasks/domain/task.dart';

import '../../helpers/due_dates.dart';
import '../../helpers/pump_app.dart';

MyTask _item(
  String title, {
  String id = 't1',
  String description = '',
  DateTime? due,
  TaskStatus status = TaskStatus.notStarted,
  Priority priority = Priority.medium,
  List<ChecklistItem> checklist = const [],
  DateTime? createdAt,
  DateTime? completedAt,
  Project? project,
}) => MyTask(
  Task(
    id: id,
    ownerId: 'ada',
    projectId: project?.id,
    title: title,
    description: description,
    dueDate: due,
    status: status,
    priority: priority,
    checklist: checklist,
    createdAt: createdAt,
    completedAt: completedAt,
  ),
  project: project,
);

const _launch = Project(
  id: 'p1',
  ownerId: 'ada',
  name: 'Launch',
  memberIds: ['ada'],
  roles: {'ada': ProjectRole.owner},
);

void main() {
  group('tasksToCsv', () {
    List<String> rows(Iterable<MyTask> items) =>
        const LineSplitter().convert(tasksToCsv(items));

    test('a header, then a row for each task', () {
      final csv = rows([
        _item(
          'Send the invoice',
          description: 'To the printer',
          due: DateTime(2026, 10, 3),
          status: TaskStatus.inProgress,
          priority: Priority.high,
          checklist: const [
            ChecklistItem('Find it', done: true),
            ChecklistItem('Send it'),
          ],
          createdAt: DateTime(2026, 9, 28, 14, 30),
          project: _launch,
        ),
        _item(
          'Pay the deposit',
          status: TaskStatus.complete,
          completedAt: DateTime(2026, 10, 1, 9),
        ),
      ]);

      expect(csv, [
        'Title,Description,Status,Priority,Due date,Project,Checklist,'
            'Created,Completed',
        'Send the invoice,To the printer,In progress,High,2026-10-03,'
            'Launch,1 of 2,2026-09-28,',
        'Pay the deposit,,Complete,Medium,,,,,2026-10-01',
      ]);
    });

    test('lines end the way spreadsheets expect', () {
      expect(
        tasksToCsv([_item('One')]),
        endsWith('One,,Not started,Medium,,,,,\r\n'),
      );
    });

    test('with no tasks there is still a header', () {
      expect(rows(const []), hasLength(1));
    });

    test('commas, quotes and line breaks stay inside their cell', () {
      final csv = tasksToCsv([
        _item('Milk, eggs', description: 'She said "today"\nor tomorrow'),
      ]);

      expect(
        csv,
        contains('"Milk, eggs","She said ""today""\nor tomorrow",Not started'),
      );
    });

    test('spaces at either end are kept', () {
      expect(tasksToCsv([_item(' padded ')]), contains('\r\n" padded ",'));
    });

    test('a title that looks like a formula is not run as one', () {
      for (final title in ['=1+1', '+44 20 7946', '-5 degrees', '@ada']) {
        expect(
          tasksToCsv([_item(title)]),
          contains("\r\n'$title,"),
          reason: title,
        );
      }
      // Quoting comes on top when it is needed too.
      expect(
        tasksToCsv([_item('=HYPERLINK("http://x","y")')]),
        contains('\r\n"\'=HYPERLINK(""http://x"",""y"")",'),
      );
    });
  });

  group('tasksToICal', () {
    final now = DateTime.utc(2026, 10, 2, 9, 5, 7);

    List<String> lines(Iterable<MyTask> items) =>
        const LineSplitter().convert(tasksToICal(items, now: now));

    test('each task with a due date is an all-day event', () {
      final ical = lines([
        _item(
          'Send the invoice',
          description: 'To the printer',
          due: DateTime(2026, 10, 3),
          project: _launch,
        ),
      ]);

      expect(ical, [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//Taskly//Tasks//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
        'X-WR-CALNAME:Taskly tasks',
        'BEGIN:VEVENT',
        'UID:p1-t1@taskly',
        'DTSTAMP:20261002T090507Z',
        'DTSTART;VALUE=DATE:20261003',
        'DTEND;VALUE=DATE:20261004',
        'SUMMARY:Send the invoice',
        'DESCRIPTION:To the printer',
        'CATEGORIES:Launch',
        'TRANSP:TRANSPARENT',
        'END:VEVENT',
        'END:VCALENDAR',
      ]);
    });

    test('lines end with a carriage return and a line feed', () {
      final ical = tasksToICal([
        _item('One', due: DateTime(2026, 10, 3)),
      ], now: now);

      expect(ical, endsWith('END:VCALENDAR\r\n'));
      expect('\r\n'.allMatches(ical), hasLength(ical.split('\n').length - 1));
    });

    test('tasks without a due date are left out', () {
      final ical = lines([
        _item('Sometime'),
        _item('Dated', id: 't2', due: DateTime(2026, 10, 3)),
      ]);

      expect(ical.where((line) => line == 'BEGIN:VEVENT'), hasLength(1));
      expect(ical, isNot(contains('SUMMARY:Sometime')));
    });

    test(
      'a personal task has no category, and an empty description no line',
      () {
        final ical = lines([_item('Dated', due: DateTime(2026, 10, 3))]);

        expect(ical, contains('UID:t1@taskly'));
        expect(ical.where((line) => line.startsWith('CATEGORIES')), isEmpty);
        expect(ical.where((line) => line.startsWith('DESCRIPTION')), isEmpty);
      },
    );

    test('a done task is ticked', () {
      final ical = lines([
        _item('Dated', due: DateTime(2026, 10, 3), status: TaskStatus.complete),
      ]);

      expect(ical, contains('SUMMARY:✓ Dated'));
    });

    test('the last day of a month ends on the first of the next', () {
      final ical = lines([_item('Dated', due: DateTime(2026, 12, 31))]);

      expect(ical, contains('DTSTART;VALUE=DATE:20261231'));
      expect(ical, contains('DTEND;VALUE=DATE:20270101'));
    });

    test('punctuation with a meaning in the format is escaped', () {
      final ical = lines([
        _item(
          r'Milk, eggs; a\b',
          description: 'First\nsecond\r\nthird',
          due: DateTime(2026, 10, 3),
        ),
      ]);

      expect(ical, contains(r'SUMMARY:Milk\, eggs\; a\\b'));
      expect(ical, contains(r'DESCRIPTION:First\nsecond\nthird'));
    });

    test('long lines are folded at 75 bytes, never inside a character', () {
      final title =
          'Überprüfung der Präsentation für die Geschäftsführung '
          'mit Änderungswünschen — 日本語のタイトル 🎉 and then some more';
      final ical = tasksToICal([
        _item(title, due: DateTime(2026, 10, 3)),
      ], now: now);

      for (final line in ical.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
      // Unfolding gives the title back whole.
      expect(ical.replaceAll('\r\n ', ''), contains('SUMMARY:$title\r\n'));
    });
  });

  group('exporting from the Tasks page', () {
    late FakeFirebaseFirestore firestore;
    late List<ExportFile> saved;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      saved = [];
    });

    Future<void> seedTask(
      String id, {
      required String title,
      int? dueInDays,
      String priority = 'medium',
    }) => firestore.doc('tasks/$id').set({
      'ownerId': testUser.uid,
      'title': title,
      'description': '',
      'priority': priority,
      'status': 'notStarted',
      'dueDate': dueInDays == null ? null : dueTimestamp(dueInDays),
      'order': 1,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    Future<void> pumpTasks(WidgetTester tester, {SaveFile? saveFile}) =>
        pumpApp(
          tester,
          user: testUser,
          firestore: firestore,
          location: Routes.tasks,
          saveFile:
              saveFile ??
              (file) async {
                saved.add(file);
                return true;
              },
        );

    Future<void> export(WidgetTester tester, String format) async {
      await tester.tap(find.byTooltip('Export these tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(format));
      await tester.pumpAndSettle();
    }

    testWidgets('as a spreadsheet', (tester) async {
      await seedTask('a', title: 'Send the invoice', dueInDays: 0);
      await seedTask('b', title: 'Sometime');
      await pumpTasks(tester);

      await export(tester, 'Spreadsheet (.csv)');

      final file = saved.single;
      expect(
        file.name,
        matches(RegExp(r'^taskly-tasks-\d{4}-\d\d-\d\d\.csv$')),
      );
      expect(file.mimeType, 'text/csv');
      // Marked as UTF-8 for Excel.
      expect(file.text, startsWith('﻿Title,'));
      expect(file.text, contains('\r\nSend the invoice,'));
      expect(file.text, contains('\r\nSometime,'));
      expect(find.text('Exported 2 tasks.'), findsOneWidget);
    });

    testWidgets('as a calendar, which says what it had to leave out', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', dueInDays: 0);
      await seedTask('b', title: 'Sometime');
      await pumpTasks(tester);

      await export(tester, 'Calendar (.ics)');

      final file = saved.single;
      expect(file.name, endsWith('.ics'));
      expect(file.mimeType, 'text/calendar');
      expect(file.text, contains('SUMMARY:Send the invoice'));
      expect(file.text, isNot(contains('Sometime')));
      expect(
        find.text('Exported 1 task. 1 without a due date was left out.'),
        findsOneWidget,
      );
    });

    testWidgets('a calendar of tasks without due dates is not made', (
      tester,
    ) async {
      await seedTask('a', title: 'Sometime');
      await pumpTasks(tester);

      await export(tester, 'Calendar (.ics)');

      expect(saved, isEmpty);
      expect(
        find.textContaining('None of these tasks has a due date'),
        findsOneWidget,
      );
    });

    testWidgets('only what the filters let through', (tester) async {
      await seedTask('a', title: 'Send the invoice', priority: 'high');
      await seedTask('b', title: 'Call the printer');
      await pumpTasks(tester);
      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();

      await export(tester, 'Spreadsheet (.csv)');

      expect(saved.single.text, contains('Send the invoice'));
      expect(saved.single.text, isNot(contains('Call the printer')));
      expect(find.text('Exported 1 task.'), findsOneWidget);
    });

    testWidgets('closing the share sheet says nothing', (tester) async {
      await seedTask('a', title: 'Send the invoice');
      await pumpTasks(tester, saveFile: (file) async => false);

      await export(tester, 'Spreadsheet (.csv)');

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a failure is reported', (tester) async {
      await seedTask('a', title: 'Send the invoice');
      await pumpTasks(
        tester,
        saveFile: (file) async => throw StateError('no share sheet'),
      );

      await export(tester, 'Spreadsheet (.csv)');

      expect(
        find.text("Couldn't export the tasks. Please try again."),
        findsOneWidget,
      );
    });
  });
}
