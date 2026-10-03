import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/my_tasks/presentation/tasks_page.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';
import 'package:taskly/features/tasks/presentation/task_form.dart';

import '../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    // One task, so Home is the dashboard and the Tasks page has its search.
    await firestore.doc('tasks/a').set({
      'ownerId': testUser.uid,
      'title': 'Buy milk',
      'description': '',
      'priority': 'medium',
      'status': 'notStarted',
      'order': 1,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  });

  Future<void> seedProject({required String role}) =>
      firestore.doc('projects/p1').set({
        'ownerId': role == 'owner' ? testUser.uid : 'bob',
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'notStarted',
        'memberIds': [if (role != 'owner') 'bob', testUser.uid],
        'roles': {if (role != 'owner') 'bob': 'owner', testUser.uid: role},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  Future<void> pump(
    WidgetTester tester, {
    String location = Routes.home,
    Size size = const Size(1000, 800),
  }) => pumpApp(
    tester,
    user: testUser,
    firestore: firestore,
    location: location,
    size: size,
  );

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    String? character,
  }) async {
    await tester.sendKeyEvent(key, character: character);
    await tester.pumpAndSettle();
  }

  Future<void> pressN(WidgetTester tester) =>
      press(tester, LogicalKeyboardKey.keyN, character: 'n');
  Future<void> pressSlash(WidgetTester tester) =>
      press(tester, LogicalKeyboardKey.slash, character: '/');
  Future<void> pressEsc(WidgetTester tester) =>
      press(tester, LogicalKeyboardKey.escape);

  final search = find.widgetWithText(TextField, 'Search tasks');
  bool searchHasFocus(WidgetTester tester) =>
      tester.widget<TextField>(search).focusNode!.hasFocus;

  group('N', () {
    testWidgets('opens the new-task form, and Esc closes it', (tester) async {
      await pump(tester);

      await pressN(tester);
      expect(find.text('New task'), findsOneWidget);
      // The title has the cursor: the key wasn't typed into it.
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Title'))
            .controller!
            .text,
        isEmpty,
      );

      await pressEsc(tester);
      expect(find.byType(TaskForm), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('adds a personal task from any page', (tester) async {
      await pump(tester, location: Routes.projects);

      await pressN(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Call Bob',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      final titles = [
        for (final doc in (await firestore.collection('tasks').get()).docs)
          doc['title'],
      ];
      expect(titles, containsAll(['Buy milk', 'Call Bob']));
    });

    testWidgets('is typed, not run, in a text field', (tester) async {
      await pump(tester, location: Routes.tasks);
      await tester.tap(search);
      await tester.pumpAndSettle();

      await pressN(tester);
      await pressSlash(tester);

      expect(find.byType(TaskForm), findsNothing);
      expect(searchHasFocus(tester), isTrue);
    });

    testWidgets('does nothing more while a form is open', (tester) async {
      await pump(tester);
      await pressN(tester);
      // Off the title field, onto the Cancel button.
      await tester.tap(find.text('New task'));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await pressN(tester);

      expect(find.byType(TaskForm), findsOneWidget);
    });

    testWidgets('on a project page, adds the task to the project', (
      tester,
    ) async {
      await seedProject(role: 'editor');
      await pump(tester, location: Routes.project('p1'));

      await pressN(tester);
      // Project tasks can be assigned; personal ones can't.
      expect(find.text('Assignee'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Write copy',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      final saved = await firestore.collection('projects/p1/tasks').get();
      expect(saved.docs.single['title'], 'Write copy');
      expect(find.widgetWithText(TaskCard, 'Write copy'), findsOneWidget);
    });

    testWidgets("does nothing on a project a viewer can't add to", (
      tester,
    ) async {
      await seedProject(role: 'viewer');
      await pump(tester, location: Routes.project('p1'));

      await pressN(tester);

      expect(find.byType(TaskForm), findsNothing);
    });
  });

  group('/', () {
    testWidgets('puts the cursor in the search box', (tester) async {
      await pump(tester, location: Routes.tasks);
      expect(searchHasFocus(tester), isFalse);

      await pressSlash(tester);

      expect(searchHasFocus(tester), isTrue);
      await tester.enterText(search, 'milk');
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 1 task'), findsOneWidget);
    });

    testWidgets('opens the Tasks page first, from another page', (
      tester,
    ) async {
      await pump(tester);

      await pressSlash(tester);

      expect(find.byType(TasksPage), findsOneWidget);
      expect(searchHasFocus(tester), isTrue);
    });

    testWidgets('works again after the Tasks page has been left', (
      tester,
    ) async {
      await pump(tester, location: Routes.tasks);
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      await pressSlash(tester);

      expect(find.byType(TasksPage), findsOneWidget);
      expect(searchHasFocus(tester), isTrue);
    });
  });

  testWidgets('Esc clears the search and leaves it', (tester) async {
    await firestore.doc('tasks/b').set({
      'ownerId': testUser.uid,
      'title': 'Walk the dog',
      'order': 2,
    });
    await pump(tester, location: Routes.tasks);
    await pressSlash(tester);
    await tester.enterText(search, 'milk');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TaskCard, 'Walk the dog'), findsNothing);

    await pressEsc(tester);

    expect(find.widgetWithText(TaskCard, 'Walk the dog'), findsOneWidget);
    expect(searchHasFocus(tester), isFalse);
    // Out of the text field, the shortcuts work again.
    await pressN(tester);
    expect(find.byType(TaskForm), findsOneWidget);
  });

  group('the list of shortcuts', () {
    testWidgets('opens with ?, and closes with Esc', (tester) async {
      await pump(tester);

      await press(tester, LogicalKeyboardKey.slash, character: '?');
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.text('Search tasks'), findsOneWidget);

      await pressEsc(tester);
      expect(find.text('Keyboard shortcuts'), findsNothing);
    });

    testWidgets('is in the account menu, except on phones', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keyboard shortcuts'));
      await tester.pumpAndSettle();
      expect(find.text('Show these shortcuts'), findsOneWidget);

      await pump(tester, size: const Size(400, 800));
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Keyboard shortcuts'), findsNothing);
    });
  });
}
