import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/app/theme/app_palette.dart';
import 'package:taskly/app/theme/device_colors.dart';
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

  ThemeData shownTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).last));

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

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

    await tapText(tester, 'Calendar');
    await tapText(tester, 'Due date');
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

  testWidgets('the theme and mode are saved, and used', (tester) async {
    final preferences = MemoryPreferences();
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      preferences: preferences,
      location: Routes.settings,
    );
    // Taskly Violet, following the system, which is light in tests.
    expect(
      shownTheme(tester).colorScheme.primary,
      AppPalette.taskly.tokens(Brightness.light).primary,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Taskly Violet theme')),
      matchesSemantics(
        label: 'Taskly Violet theme',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );

    await tapText(tester, 'Ocean');
    expect(
      shownTheme(tester).colorScheme.primary,
      AppPalette.ocean.tokens(Brightness.light).primary,
    );

    await tapText(tester, 'Dark');
    expect(shownTheme(tester).brightness, Brightness.dark);
    expect(
      shownTheme(tester).colorScheme.primary,
      AppPalette.ocean.tokens(Brightness.dark).primary,
    );

    expect(preferences.values, {
      'appearance.palette': 'ocean',
      'appearance.mode': 'dark',
    });

    // Opening the app again, it looks the same.
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      preferences: preferences,
      location: Routes.home,
    );
    expect(shownTheme(tester).brightness, Brightness.dark);
    expect(
      shownTheme(tester).colorScheme.primary,
      AppPalette.ocean.tokens(Brightness.dark).primary,
    );
  });

  group('device colours', () {
    const colors = DeviceColors(
      light: Color(0xFF006A60),
      onLight: Color(0xFFFFFFFF),
      dark: Color(0xFF53DBC9),
      onDark: Color(0xFF003731),
    );

    testWidgets('are offered first when the device has some', (tester) async {
      final preferences = MemoryPreferences();
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        preferences: preferences,
        deviceColors: colors,
        location: Routes.settings,
      );
      final tiles = find.textContaining(RegExp(r'^(Device colours|Taskly)'));
      expect(
        tester.getTopLeft(tiles.first).dx,
        lessThan(tester.getTopLeft(tiles.last).dx),
      );
      expect(tester.widget<Text>(tiles.first).data, 'Device colours');

      await tapText(tester, 'Device colours');
      expect(shownTheme(tester).colorScheme.primary, colors.light);
      expect(preferences.values['appearance.palette'], 'device');

      await tapText(tester, 'Dark');
      expect(shownTheme(tester).colorScheme.primary, colors.dark);
    });

    testWidgets('are not offered when it has none', (tester) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.settings,
      );
      expect(find.text('Device colours'), findsNothing);
      expect(find.text('Taskly Violet'), findsOneWidget);
    });

    testWidgets('picked before, still show when the device has none', (
      tester,
    ) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        preferences: MemoryPreferences({'appearance.palette': 'device'}),
        location: Routes.settings,
      );
      expect(find.text('Device colours'), findsOneWidget);
      // With Taskly Violet's accent in the meantime.
      expect(
        shownTheme(tester).colorScheme.primary,
        AppPalette.taskly.tokens(Brightness.light).primary,
      );
    });
  });
}
