import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/profile/presentation/profile_page.dart';
import 'package:taskly/features/projects/presentation/project_detail_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';
import 'package:taskly/features/my_tasks/presentation/tasks_page.dart';

import '../helpers/pump_app.dart';

/// A test with semantics on, as a screen reader would have them.
void testWithSemantics(String description, WidgetTesterCallback body) =>
    testWidgets(description, (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await body(tester);
      } finally {
        semantics.dispose();
      }
    });

void main() {
  testWidgets('phones get a bottom navigation bar', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing);
  });

  testWithSemantics('screen readers reach the rail and sidebar too', (
    tester,
  ) async {
    // The page's route hides what's painted before it from screen readers,
    // and the navigation is painted before the page on wide windows.
    for (final size in const [Size(900, 800), Size(1400, 900)]) {
      await pumpApp(tester, user: testUser, size: size);
      expect(
        find.bySemanticsLabel(RegExp(r'^Tasks')),
        findsOneWidget,
        reason: '${size.width}',
      );
    }
  });

  testWidgets('tablets get a navigation rail', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(900, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktops get a sidebar with the projects in it', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(1400, 900));
    expect(find.byTooltip('New project'), findsOneWidget);
    expect(find.text('None yet'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  group('the desktop sidebar', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      for (final (id, name, priority) in [
        ('p1', 'Website relaunch', 'high'),
        ('p2', 'Spring offsite', 'low'),
      ]) {
        await firestore.doc('projects/$id').set({
          'ownerId': testUser.uid,
          'name': name,
          'description': '',
          'priority': priority,
          'status': 'inProgress',
          'memberIds': [testUser.uid],
          'roles': {testUser.uid: 'owner'},
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }
      for (final (id, status) in [
        ('a', 'notStarted'),
        ('b', 'inProgress'),
        ('c', 'complete'),
      ]) {
        await firestore.doc('projects/p1/tasks/$id').set({
          'ownerId': testUser.uid,
          'title': 'Task $id',
          'description': '',
          'priority': 'medium',
          'status': status,
          'order': 1,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }
    });

    testWithSemantics('lists each project with its open tasks', (tester) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        size: const Size(1400, 900),
      );

      expect(
        find.bySemanticsLabel('Project Website relaunch, 2 open tasks'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Project Spring offsite'), findsOneWidget);
      expect(find.bySemanticsLabel('Projects, 2'), findsOneWidget);
    });

    testWithSemantics('opens a project, and shows it as the one selected', (
      tester,
    ) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        size: const Size(1400, 900),
      );

      await tester.tap(find.bySemanticsLabel(RegExp('^Project Website')));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Project Website'))),
        matchesSemantics(
          label: 'Project Website relaunch, 2 open tasks',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
    });
  });

  for (final size in const [Size(400, 800), Size(900, 800), Size(1400, 900)]) {
    testWidgets('destinations switch pages at ${size.width.toInt()}px', (
      tester,
    ) async {
      await pumpApp(tester, user: testUser, size: size);

      await tester.tap(find.text('Projects').first);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsPage), findsOneWidget);

      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      expect(find.byType(TasksPage), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });
  }

  testWidgets('account menu opens profile, and back returns', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.projects);
    expect(find.text('AL'), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('ada@example.com'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('profile opened by URL goes back to home', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
