// The whole app against the Firebase emulators, on a real device or browser:
// sign up, create a project, add a task, complete it. Everything the widget
// tests fake (Firebase, the security rules, the platform) is real here.
//
// Start the emulators first (`firebase emulators:start --only
// auth,firestore`), then run on a device (devops.md 6):
//
//   flutter test integration_test -d emulator-5554 \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:taskly/core/data/firebase_emulators.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';
import 'package:taskly/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign up, create a project, add a task and complete it', (
    tester,
  ) async {
    // Never against the real project: this signs up a new user each run.
    expect(
      useFirebaseEmulators,
      isTrue,
      reason: 'Run with --dart-define=USE_FIREBASE_EMULATORS=true',
    );
    await app.main();
    await tester.pumpUntilFound(find.text('Get started'));

    // A new user each run, so runs don't depend on each other.
    final email =
        'journey-${DateTime.now().millisecondsSinceEpoch}@example.com';
    await tester.tap(find.text('Get started'));
    await tester.pumpUntilFound(find.text('Create account'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Grace Hopper',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct-horse-battery',
    );
    await tester.tapVisible(
      find.widgetWithText(FilledButton, 'Create account'),
    );
    await tester.pumpUntilFound(find.text('Hi, Grace'));

    await tester.tap(find.text('Projects').last);
    await tester.pumpUntilFound(find.text('New project'));
    await tester.tap(find.text('New project'));
    await tester.pumpUntilFound(find.text('Create project'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Launch day',
    );
    await tester.tapVisible(
      find.widgetWithText(FilledButton, 'Create project'),
    );
    // Opens the new project.
    await tester.pumpUntilFound(find.text('Add task'));

    await tester.tap(find.text('Add task'));
    await tester.pumpUntilFound(find.text('New task'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Write the press release',
    );
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Add task'));
    final card = find.widgetWithText(TaskCard, 'Write the press release');
    await tester.pumpUntilFound(card);

    await tester.tap(
      find.descendant(of: card, matching: find.byType(Checkbox)),
    );
    await tester.pumpUntilFound(
      find.descendant(of: card, matching: find.text('Complete')),
    );

    // On the server, not just on this device: the rules let it all through.
    final user = FirebaseAuth.instance.currentUser!;
    final projects = await FirebaseFirestore.instance
        .collection('projects')
        .where('memberIds', arrayContains: user.uid)
        .get(const GetOptions(source: Source.server));
    expect([for (final p in projects.docs) p['name']], ['Launch day']);
    final tasks = await projects.docs.single.reference
        .collection('tasks')
        .get(const GetOptions(source: Source.server));
    expect(tasks.docs.single['title'], 'Write the press release');
    expect(tasks.docs.single['status'], 'complete');
  });
}

extension on WidgetTester {
  /// Pumps frames until [finder] finds something. Unlike `pumpAndSettle`, it
  /// copes with real network calls and with animations that never settle
  /// (the loading skeletons).
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        throw TestFailure('Timed out waiting for $finder');
      }
      await pump(const Duration(milliseconds: 100));
    }
    await pump(const Duration(milliseconds: 300));
  }

  /// Scrolls [finder] into view first: forms are taller than a phone screen.
  Future<void> tapVisible(Finder finder) async {
    await ensureVisible(finder);
    await pump(const Duration(milliseconds: 300));
    await tap(finder);
  }
}
