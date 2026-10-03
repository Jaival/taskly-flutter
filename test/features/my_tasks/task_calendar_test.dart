import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/my_tasks/domain/task_calendar.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/pump_app.dart';

Task _task(String id, {DateTime? due}) =>
    Task(id: id, ownerId: 'ada', title: id, dueDate: due);

/// As a due date is stored: midnight UTC on that day.
Timestamp _stored(DateTime day) =>
    Timestamp.fromDate(DateTime.utc(day.year, day.month, day.day));

void main() {
  group('calendarDays', () {
    List<int> numbers(DateTime month, int firstDayOfWeek) => [
      for (final day in calendarDays(month, firstDayOfWeek: firstDayOfWeek))
        day.day,
    ];

    test('fills the first and last weeks from the months around it', () {
      // October 2026 starts on a Thursday.
      final days = calendarDays(DateTime(2026, 10, 15), firstDayOfWeek: 0);

      expect(days.first, DateTime(2026, 9, 27));
      expect(days.last, DateTime(2026, 10, 31));
      expect(days, hasLength(35));
      expect(days[4], DateTime(2026, 10));
    });

    test('starts the week on the day asked for', () {
      // The same month from Monday.
      final days = calendarDays(DateTime(2026, 10), firstDayOfWeek: 1);

      expect(days.first, DateTime(2026, 9, 28));
      expect(days.last, DateTime(2026, 11));
      expect(days.first.weekday, DateTime.monday);
    });

    test('a month that fits its weeks exactly has nothing added', () {
      // February 2026: 28 days from a Sunday.
      expect(numbers(DateTime(2026, 2), 0), [for (var d = 1; d <= 28; d++) d]);
    });

    test('a long month starting late in the week needs six weeks', () {
      // August 2026 starts on a Saturday.
      expect(calendarDays(DateTime(2026, 8), firstDayOfWeek: 0), hasLength(42));
    });

    test('every day appears once, at midnight, whatever the clocks do', () {
      // March and October are when most places change them.
      for (final month in [DateTime(2026, 3), DateTime(2026, 10)]) {
        final days = calendarDays(month, firstDayOfWeek: 1);

        expect(days.toSet(), hasLength(days.length));
        expect(days.every((day) => day.hour == 0), isTrue);
        for (var i = 1; i < days.length; i++) {
          expect(
            days[i],
            DateTime(days[i - 1].year, days[i - 1].month, days[i - 1].day + 1),
          );
        }
      }
    });

    test('December runs into January', () {
      final days = calendarDays(DateTime(2026, 12), firstDayOfWeek: 0);

      expect(days.last, DateTime(2027, 1, 2));
    });
  });

  group('groupByDay', () {
    test('puts tasks under the day they are due, in the order given', () {
      final groups = groupByDay([
        _task('a', due: DateTime(2026, 10, 3)),
        _task('b', due: DateTime(2026, 10, 5)),
        _task('c', due: DateTime(2026, 10, 3)),
      ], (task) => task);

      expect(
        [for (final task in groups[DateTime(2026, 10, 3)]!) task.id],
        ['a', 'c'],
      );
      expect(groups[DateTime(2026, 10, 5)], hasLength(1));
      expect(groups[DateTime(2026, 10, 4)], isNull);
    });

    test('leaves out tasks without a due date', () {
      expect(groupByDay([_task('a')], (task) => task), isEmpty);
    });
  });

  group('the Tasks page as a calendar', () {
    late FakeFirebaseFirestore firestore;
    final today = DateTime.now();
    // A day that is always in another month than today.
    final nextMonth = DateTime(today.year, today.month + 1, 15);

    setUp(() => firestore = FakeFirebaseFirestore());

    Future<void> seedTask(
      String id, {
      required String title,
      DateTime? due,
      String status = 'notStarted',
      String priority = 'medium',
    }) => firestore.doc('tasks/$id').set({
      'ownerId': testUser.uid,
      'title': title,
      'description': '',
      'priority': priority,
      'status': status,
      'dueDate': due == null ? null : _stored(due),
      'order': 1,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    Future<void> pumpCalendar(WidgetTester tester) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.tasks,
      );
      await tester.tap(find.byTooltip('Show as a calendar'));
      await tester.pumpAndSettle();
    }

    String monthTitle(WidgetTester tester, DateTime day) =>
        MaterialLocalizations.of(tester.element(find.byTooltip('Next month')))
            .formatMonthYear(day);

    /// The cell for [day], found the way a screen reader names it.
    Finder dayCell(WidgetTester tester, DateTime day) {
      final date = MaterialLocalizations.of(
        tester.element(find.byTooltip('Next month')),
      ).formatFullDate(day);
      return find.bySemanticsLabel(RegExp('^${RegExp.escape(date)},'));
    }

    testWidgets('opens on this month, with what is due today below', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Book the venue', due: nextMonth);
      await pumpCalendar(tester);

      expect(find.text(monthTitle(tester, today)), findsOneWidget);
      expect(find.text('Today · 1'), findsOneWidget);
      expect(find.widgetWithText(TaskCard, 'Send the invoice'), findsOneWidget);
      expect(find.text('Book the venue'), findsNothing);
    });

    testWidgets('each day says how much is due on it', (tester) async {
      await seedTask('a', title: 'One', due: today);
      await seedTask('b', title: 'Two', due: today);
      await pumpCalendar(tester);
      final handle = tester.ensureSemantics();

      expect(
        tester.getSemantics(dayCell(tester, today)).label,
        endsWith(', today, 2 tasks due'),
      );
      handle.dispose();
    });

    testWidgets('another month, and a day in it', (tester) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Book the venue', due: nextMonth);
      await pumpCalendar(tester);

      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();

      expect(find.text(monthTitle(tester, nextMonth)), findsOneWidget);
      // On the 1st, where nothing is due.
      expect(find.text('Nothing due.'), findsOneWidget);

      await tester.tap(dayCell(tester, nextMonth));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TaskCard, 'Book the venue'), findsOneWidget);
      expect(find.text('Send the invoice'), findsNothing);
    });

    testWidgets('Today comes back from anywhere', (tester) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('Send the invoice'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await tester.pumpAndSettle();

      expect(find.text(monthTitle(tester, today)), findsOneWidget);
      expect(find.widgetWithText(TaskCard, 'Send the invoice'), findsOneWidget);
      // Nowhere to go from here.
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Today'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('tasks without a due date are counted, not lost', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Sometime');
      await seedTask('c', title: 'Whenever');
      await pumpCalendar(tester);

      expect(find.text('Sometime'), findsNothing);
      expect(find.textContaining('2 tasks have no due date'), findsOneWidget);
    });

    testWidgets('searching and filtering narrow the calendar too', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Call the printer', due: today);
      await pumpCalendar(tester);

      await tester.enterText(find.byType(TextField), 'invoice');
      await tester.pumpAndSettle();

      expect(find.text('Today · 1'), findsOneWidget);
      expect(find.text('Call the printer'), findsNothing);
      expect(find.text('Showing 1 of 2 tasks'), findsOneWidget);
    });

    testWidgets('there is no sorting or filtering by due date: the calendar '
        'is that already', (tester) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Book the venue', due: nextMonth);
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.tasks,
      );
      // Only what's due today, in the list.
      // The chips scroll sideways on a phone.
      await tester.ensureVisible(find.byTooltip('Filter by due'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter by due'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Today'));
      await tester.pumpAndSettle();
      // Tap outside the menu: the app bar, which does nothing itself.
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.text('Book the venue'), findsNothing);

      await tester.tap(find.byTooltip('Show as a calendar'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Sort'), findsNothing);
      expect(find.byTooltip('Filter by due'), findsNothing);
      expect(find.byTooltip('Filter by priority'), findsOneWidget);
      // The other day's task is on the calendar all the same.
      expect(find.textContaining('Showing'), findsNothing);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(dayCell(tester, nextMonth));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TaskCard, 'Book the venue'), findsOneWidget);

      // And the list still has its filter.
      await tester.tap(find.byTooltip('Show as a list'));
      await tester.pumpAndSettle();
      expect(find.text('Book the venue'), findsNothing);
      expect(find.widgetWithText(TaskCard, 'Send the invoice'), findsOneWidget);
    });

    testWidgets('a task added from the calendar is due on the chosen day', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(dayCell(tester, nextMonth));
      await tester.pumpAndSettle();

      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Book the venue',
      );
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TaskCard, 'Book the venue'), findsOneWidget);
      final saved = await firestore
          .collection('tasks')
          .where('title', isEqualTo: 'Book the venue')
          .get();
      expect(saved.docs.single['dueDate'], _stored(nextMonth));
    });

    testWidgets('ticking a task off keeps it on its day', (tester) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await pumpCalendar(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TaskCard, 'Send the invoice'), findsOneWidget);
      expect((await firestore.doc('tasks/a').get())['status'], 'complete');
    });

    testWidgets('the calendar is still there after visiting another page', (
      tester,
    ) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await seedTask('b', title: 'Book the venue', due: nextMonth);
      await pumpCalendar(tester);
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();

      expect(find.text(monthTitle(tester, nextMonth)), findsOneWidget);
    });

    testWidgets('fits a small phone', (tester) async {
      await seedTask('a', title: 'Send the invoice', due: today);
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.tasks,
        size: const Size(320, 568),
      );

      await tester.tap(find.byTooltip('Show as a calendar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Next month'), findsOneWidget);
    });
  });
}
