import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/core/data/preferences.dart';
import 'package:taskly/features/my_tasks/presentation/task_calendar.dart';
import 'package:taskly/features/settings/presentation/settings_page.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/due_dates.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    for (final (id, title, priority, due) in [
      ('a', 'Buy milk', 'low', 1),
      ('b', 'Pay rent', 'immediate', 3),
    ]) {
      await firestore.doc('tasks/$id').set({
        'ownerId': testUser.uid,
        'title': title,
        'description': '',
        'priority': priority,
        'status': 'notStarted',
        'dueDate': dueTimestamp(due),
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }
  });

  List<String> shownTitles(WidgetTester tester) => [
    for (final card in tester.widgetList<TaskCard>(find.byType(TaskCard)))
      card.task.title,
  ];

  testWidgets('opens from the account menu', (tester) async {
    await pumpApp(tester, user: testUser, firestore: firestore);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('opens from the Tasks page menu', (tester) async {
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: Routes.tasks,
    );
    await tester.tap(find.byTooltip('View options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Default view and sort'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('the default view and sort are saved, and used', (tester) async {
    final preferences = MemoryPreferences();
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      preferences: preferences,
      location: Routes.settings,
    );

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Due date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priority').last);
    await tester.pumpAndSettle();

    expect(preferences.values, {
      'tasks.defaultView': 'calendar',
      'tasks.defaultSort': 'priority',
    });

    // Opening the app again, the Tasks page starts out that way.
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      preferences: preferences,
      location: Routes.tasks,
    );
    expect(find.byType(TaskCalendar), findsOneWidget);

    await tester.tap(find.byTooltip('Show as a list'));
    await tester.pumpAndSettle();
    expect(shownTitles(tester), ['Pay rent', 'Buy milk']);
  });

  testWidgets('without any saved, it is a list by due date', (tester) async {
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: Routes.tasks,
    );

    expect(find.byType(TaskCalendar), findsNothing);
    expect(shownTitles(tester), ['Buy milk', 'Pay rent']);
  });
}
