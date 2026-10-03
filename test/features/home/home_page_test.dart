import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/projects/presentation/project_detail_page.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';
import 'package:taskly/features/my_tasks/presentation/tasks_page.dart';

import '../../helpers/due_dates.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> seedTask(
    String id, {
    required String title,
    String status = 'notStarted',
    double order = 1,
    int? dueInDays,
    int? doneDaysAgo,
  }) => firestore.doc('tasks/$id').set({
    'ownerId': testUser.uid,
    'title': title,
    'description': '',
    'priority': 'medium',
    'status': status,
    'assigneeId': null,
    'dueDate': dueInDays == null ? null : dueTimestamp(dueInDays),
    'order': order,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
    'completedAt': doneDaysAgo == null
        ? null
        : Timestamp.fromDate(
            DateTime.now().subtract(Duration(days: doneDaysAgo)),
          ),
  });

  Future<void> seedProject(String id, {required String name, int day = 1}) =>
      firestore.doc('projects/$id').set({
        'ownerId': testUser.uid,
        'name': name,
        'description': '',
        'priority': 'high',
        'status': 'inProgress',
        'memberIds': [testUser.uid],
        'roles': {testUser.uid: 'owner'},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.fromDate(DateTime(2026, 1, day)),
      });

  Future<void> pumpHome(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) => pumpApp(
    tester,
    user: testUser,
    firestore: firestore,
    location: Routes.home,
    size: size,
  );

  // The dashboard's list, not the navigation rail's.
  final homeScrollable = find
      .descendant(of: find.byType(HomePage), matching: find.byType(Scrollable))
      .first;

  Finder statCard(String label, int count) =>
      find.bySemanticsLabel('$label: $count');

  group('a new account is welcomed, and', () {
    testWidgets('can create a project right there', (tester) async {
      await pumpHome(tester);
      expect(find.text('Welcome to Taskly'), findsOneWidget);

      await tester.tap(find.text('Create a project'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name'),
        'Launch',
      );
      await tester.tap(find.text('Create project'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Launch'), findsOneWidget);
    });

    testWidgets('can add a task right there', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Buy milk',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.text('Welcome to Taskly'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TaskCard),
          matching: find.text('Buy milk'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cancelling a form leaves the welcome', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Create a project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Taskly'), findsOneWidget);
      expect((await firestore.collection('projects').get()).docs, isEmpty);
    });
  });

  testWidgets('greets the user and counts their work', (tester) async {
    await seedProject('p1', name: 'Launch');
    await seedTask('a', title: 'A');
    await seedTask('b', title: 'B');
    await seedTask('c', title: 'C', status: 'inProgress');
    await seedTask('d', title: 'D', status: 'complete');
    await pumpHome(tester);

    expect(find.text('Hi, Ada'), findsOneWidget);
    expect(statCard('Projects', 1), findsOneWidget);
    expect(statCard('To do', 2), findsOneWidget);
    expect(statCard('In progress', 1), findsOneWidget);
    expect(statCard('Done', 1), findsOneWidget);
  });

  testWidgets('up next lists the first open tasks in order', (tester) async {
    await seedTask('done', title: 'Already done', status: 'complete');
    for (var i = 1; i <= 7; i++) {
      await seedTask('t$i', title: 'Task $i', order: i.toDouble());
    }
    await pumpHome(tester);

    final titles = [
      for (final card in tester.widgetList<TaskCard>(find.byType(TaskCard)))
        card.task.title,
    ];
    expect(titles, ['Task 1', 'Task 2', 'Task 3', 'Task 4', 'Task 5']);
  });

  testWidgets('up next puts the most urgent first', (tester) async {
    await seedTask('a', title: 'Undated', order: 1);
    await seedTask('b', title: 'Next week', dueInDays: 7, order: 2);
    await seedTask('c', title: 'Late', dueInDays: -1, order: 3);
    await pumpHome(tester);

    final titles = [
      for (final card in tester.widgetList<TaskCard>(find.byType(TaskCard)))
        card.task.title,
    ];
    expect(titles, ['Late', 'Next week', 'Undated']);
  });

  testWidgets('ticking a task from home completes it', (tester) async {
    await seedTask('a', title: 'Buy milk');
    await pumpHome(tester);

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(TaskCard, 'Buy milk'),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (await firestore.doc('tasks/a').get()).data()!['status'],
      'complete',
    );
    expect(find.text("You're all done. Nice work!"), findsOneWidget);
    expect(statCard('Done', 1), findsOneWidget);
  });

  testWidgets('recent projects are the latest changed, and open', (
    tester,
  ) async {
    for (var day = 1; day <= 5; day++) {
      await seedProject('p$day', name: 'Project $day', day: day);
    }
    await pumpHome(tester);

    // The fourth and last of them, at the bottom of the page.
    await tester.scrollUntilVisible(
      find.text('Project 2'),
      100,
      scrollable: homeScrollable,
    );
    expect(find.text('Project 5'), findsOneWidget);
    expect(find.text('Project 1'), findsNothing);

    await tester.ensureVisible(find.text('Project 5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Project 5'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectDetailPage), findsOneWidget);
  });

  testWidgets('a stat card opens its list, filtered to it', (tester) async {
    await seedTask('a', title: 'A');
    await seedTask('b', title: 'B', status: 'complete');
    await pumpHome(tester);

    await tester.tap(statCard('Done', 1));
    await tester.pumpAndSettle();

    expect(find.byType(TasksPage), findsOneWidget);
    expect(find.text('Showing 1 of 2 tasks'), findsOneWidget);
    expect(find.widgetWithText(TaskCard, 'B'), findsOneWidget);
    expect(find.widgetWithText(TaskCard, 'A'), findsNothing);
  });

  group('progress', () {
    Future<void> seedDone(String id, {required int daysAgo}) => seedTask(
      id,
      title: 'Done $id',
      status: 'complete',
      doneDaysAgo: daysAgo,
    );

    testWidgets('counts what was done in the last 7 days, by day', (
      tester,
    ) async {
      await seedDone('a', daysAgo: 0);
      await seedDone('b', daysAgo: 0);
      await seedDone('c', daysAgo: 1);
      await seedDone('d', daysAgo: 30);
      await seedTask('e', title: 'Open');
      await pumpHome(tester);

      expect(
        find.bySemanticsLabel('3 tasks done in the last 7 days'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('1 yesterday, 2 today'), findsOneWidget);
      // All of them are still Done, however long ago.
      expect(statCard('Done', 4), findsOneWidget);
      expect(find.text('Nothing overdue'), findsOneWidget);
    });

    testWidgets('ticking a task off adds it to today', (tester) async {
      await seedTask('a', title: 'Buy milk');
      await pumpHome(tester);
      expect(
        find.bySemanticsLabel('0 tasks done in the last 7 days'),
        findsOneWidget,
      );

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(TaskCard, 'Buy milk'),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel('1 task done in the last 7 days'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('1 today'), findsOneWidget);
    });

    testWidgets('the overdue count opens the overdue tasks', (tester) async {
      await seedTask('a', title: 'Late', dueInDays: -2);
      await seedTask('b', title: 'Later', dueInDays: -9, order: 2);
      await seedTask('c', title: 'Soon', dueInDays: 3, order: 3);
      await seedTask(
        'd',
        title: 'Was late',
        dueInDays: -2,
        status: 'complete',
        doneDaysAgo: 0,
      );
      await pumpHome(tester);

      await tester.tap(find.text('2 overdue'));
      await tester.pumpAndSettle();

      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.text('Showing 2 of 4 tasks'), findsOneWidget);
      expect(find.widgetWithText(TaskCard, 'Late'), findsOneWidget);
      expect(find.widgetWithText(TaskCard, 'Soon'), findsNothing);
    });
  });

  for (final size in [const Size(360, 640), const Size(1400, 900)]) {
    testWidgets('lays out without overflow at ${size.width}px', (tester) async {
      await seedProject('p1', name: 'A project with a rather long name');
      await seedTask('a', title: 'A task with a rather long title too');
      await seedTask('late', title: 'Late', dueInDays: -1, order: 2);
      for (var day = 0; day < 7; day++) {
        await seedTask(
          'done$day',
          title: 'Done',
          status: 'complete',
          doneDaysAgo: day,
          order: 3,
        );
      }
      await pumpHome(tester, size: size);

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Recent projects'),
        100,
        scrollable: homeScrollable,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('on wide screens, up next and projects sit side by side', (
    tester,
  ) async {
    await seedProject('p1', name: 'Launch');
    await seedTask('a', title: 'A');
    await pumpHome(tester, size: const Size(1400, 900));

    expect(
      tester.getTopLeft(find.text('Up next')).dy,
      tester.getTopLeft(find.text('Recent projects')).dy,
    );
  });
}
