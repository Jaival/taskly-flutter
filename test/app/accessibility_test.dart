import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/home/presentation/home_page.dart';

import '../helpers/due_dates.dart';
import '../helpers/fake_auth_repository.dart';
import '../helpers/pump_app.dart';

/// Flutter's accessibility guidelines on every main page, in light and dark
/// mode: text contrast (v1's white-on-pastel failed it), tap targets at
/// least 48px, and a label on everything tappable. Then text at 200%, and
/// getting around with only a keyboard.
void main() {
  late FakeFirebaseFirestore firestore;

  Future<void> seed() async {
    firestore = FakeFirebaseFirestore();
    await firestore.doc('users/bob').set({
      'displayName': 'Bob Byron',
      'email': 'bob@example.com',
      'photoUrl': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    await firestore.doc('projects/p1').set({
      'ownerId': testUser.uid,
      'name': 'Launch',
      'description': 'Everything for the launch.',
      'priority': 'immediate',
      'status': 'inProgress',
      'memberIds': [testUser.uid, 'bob'],
      'roles': {testUser.uid: 'owner', 'bob': 'editor'},
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    var order = 0;
    for (final (path, status, priority, assignee) in [
      ('tasks/a', 'notStarted', 'high', null),
      ('tasks/b', 'inProgress', 'low', null),
      ('tasks/c', 'complete', 'medium', null),
      ('projects/p1/tasks/d', 'inProgress', 'immediate', 'bob'),
      ('projects/p1/tasks/e', 'complete', 'low', testUser.uid),
    ]) {
      await firestore.doc(path).set({
        'ownerId': testUser.uid,
        'title': 'Task $path',
        'description': 'Details',
        'priority': priority,
        'status': status,
        'assigneeId': assignee,
        'order': order++,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }
    // One overdue (in the error colour) and one upcoming.
    await firestore.doc('tasks/a').update({'dueDate': dueTimestamp(-2)});
    await firestore.doc('tasks/b').update({'dueDate': dueTimestamp(1)});
    await firestore.doc('invites/p9_ada@example.com').set({
      'projectId': 'p9',
      'projectName': 'Offsite',
      'email': 'ada@example.com',
      'role': 'viewer',
      'invitedBy': 'bob',
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });
  }

  const pages = {
    'landing': Routes.landing,
    'login': Routes.login,
    'sign up': Routes.signUp,
    'home': Routes.home,
    'projects': Routes.projects,
    'project': '/projects/p1',
    'tasks': Routes.tasks,
    'shared': Routes.shared,
    'profile': Routes.profile,
  };
  const publicPages = {Routes.landing, Routes.login, Routes.signUp};

  for (final brightness in Brightness.values) {
    for (final MapEntry(key: name, value: location) in pages.entries) {
      testWidgets('$name page meets the guidelines (${brightness.name})', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await seed();
        await pumpApp(
          tester,
          user: publicPages.contains(location) ? null : testUser,
          firestore: firestore,
          location: location,
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('a project as a board meets the guidelines '
        '(${brightness.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await seed();
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: '/projects/p1',
        size: const Size(1400, 1000),
      );
      await tester.tap(find.byTooltip('Show as a board'));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  for (final MapEntry(key: name, value: location) in pages.entries) {
    testWidgets('$name page fits with text at 200%', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seed();
      await pumpApp(
        tester,
        user: publicPages.contains(location) ? null : testUser,
        firestore: firestore,
        location: location,
      );

      expect(tester.takeException(), isNull);
    });
  }

  group('with only a keyboard', () {
    testWidgets('you can log in', (tester) async {
      final auth = FakeAuthRepository()
        ..addAccount(testUser, password: 'correct-horse');
      await pumpApp(tester, auth: auth, location: Routes.login);

      await tester.showKeyboard(find.widgetWithText(TextFormField, 'Email'));
      tester.testTextInput.enterText(testUser.email!);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      tester.testTextInput.enterText('correct-horse');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('Tab reaches a task, and Space ticks it off', (tester) async {
      await seed();
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.tasks,
      );
      final checkbox = find.bySemanticsLabel('Complete "Task tasks/a"');

      bool focused() =>
          isSemantics(isFocused: true)
              .matches(tester.getSemantics(checkbox), {});
      for (var i = 0; i < 30 && !focused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focused(), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect((await firestore.doc('tasks/a').get()).get('status'), 'complete');
    });
  });
}
