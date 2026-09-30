import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/projects/presentation/project_card.dart';
import 'package:taskly/features/projects/presentation/project_detail_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  /// A project testUser is in, with [role] ('owner', 'editor' or 'viewer').
  Future<void> seedProject(
    String id, {
    String name = 'Launch',
    String role = 'owner',
    int day = 1,
  }) async {
    final ownerId = role == 'owner' ? testUser.uid : 'someone-else';
    await firestore.doc('projects/$id').set({
      'ownerId': ownerId,
      'name': name,
      'description': '',
      'priority': 'high',
      'status': 'notStarted',
      'memberIds': {ownerId, testUser.uid}.toList(),
      'roles': {ownerId: 'owner', testUser.uid: role},
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, day)),
    });
  }

  Future<void> pumpProjects(
    WidgetTester tester, {
    String location = Routes.projects,
    Size size = const Size(400, 800),
  }) => pumpApp(
    tester,
    user: testUser,
    firestore: firestore,
    location: location,
    size: size,
  );

  Future<void> openMenu(WidgetTester tester, String projectName) async {
    await tester.tap(find.byTooltip('Actions for $projectName'));
    await tester.pumpAndSettle();
  }

  testWidgets('with no projects, invites the user to create one', (
    tester,
  ) async {
    await pumpProjects(tester);
    expect(find.text('No projects yet'), findsOneWidget);
    expect(find.text('Create a project'), findsOneWidget);
  });

  testWidgets('creating a project opens it', (tester) async {
    await pumpProjects(tester);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Launch',
    );
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectDetailPage), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Launch'), findsOneWidget);
    final saved = await firestore.collection('projects').get();
    expect(saved.docs.single.data()['ownerId'], testUser.uid);
  });

  testWidgets('a project needs a name', (tester) async {
    await pumpProjects(tester);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required.'), findsOneWidget);
    expect((await firestore.collection('projects').get()).docs, isEmpty);
  });

  testWidgets('the grid adds columns on wider windows', (tester) async {
    await seedProject('a', name: 'Alpha', day: 2);
    await seedProject('b', name: 'Beta');

    await pumpProjects(tester, size: const Size(400, 800));
    expect(
      tester.getTopLeft(find.byType(ProjectCard).at(1)).dy,
      greaterThan(tester.getTopLeft(find.byType(ProjectCard).first).dy),
      reason: 'one column on phones',
    );

    await pumpProjects(tester, size: const Size(1400, 900));
    expect(
      tester.getTopLeft(find.byType(ProjectCard).at(1)).dy,
      tester.getTopLeft(find.byType(ProjectCard).first).dy,
      reason: 'side by side on desktop',
    );
  });

  testWidgets('editing a project from its menu', (tester) async {
    await seedProject('p1');
    await pumpProjects(tester);

    await openMenu(tester, 'Launch');
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Launch v2',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Launch v2'), findsOneWidget);
  });

  testWidgets('viewers can only leave', (tester) async {
    await seedProject('p1', role: 'viewer');
    await pumpProjects(tester);

    await openMenu(tester, 'Launch');
    expect(find.text('Leave project'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });

  testWidgets('editors can edit but not delete', (tester) async {
    await seedProject('p1', role: 'editor');
    await pumpProjects(tester);

    await openMenu(tester, 'Launch');
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
  });

  group('deleting', () {
    Future<void> deleteLaunch(WidgetTester tester) async {
      await openMenu(tester, 'Launch');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Its tasks will be deleted too.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('hides the project, then deletes it with its tasks', (
      tester,
    ) async {
      await seedProject('p1');
      await firestore.collection('projects/p1/tasks').add({'title': 't'});
      await pumpProjects(tester);

      await deleteLaunch(tester);
      expect(find.byType(ProjectCard), findsNothing);
      expect(find.text('Deleted "Launch".'), findsOneWidget);
      // Nothing is deleted while Undo is still possible.
      expect((await firestore.doc('projects/p1').get()).exists, isTrue);

      // Let the snackbar time out.
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      expect((await firestore.doc('projects/p1').get()).exists, isFalse);
      expect(
        (await firestore.collection('projects/p1/tasks').get()).docs,
        isEmpty,
      );
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('Undo brings it back and deletes nothing', (tester) async {
      await seedProject('p1');
      await pumpProjects(tester);

      await deleteLaunch(tester);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCard), findsOneWidget);
      expect((await firestore.doc('projects/p1').get()).exists, isTrue);
    });

    testWidgets('cancelling the confirmation changes nothing', (tester) async {
      await seedProject('p1');
      await pumpProjects(tester);

      await openMenu(tester, 'Launch');
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectCard), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('from the detail page, returns to the list', (tester) async {
      await seedProject('p1');
      await pumpProjects(tester, location: Routes.project('p1'));

      await deleteLaunch(tester);
      expect(find.byType(ProjectsPage), findsOneWidget);
      expect(find.byType(ProjectCard), findsNothing);
    });
  });

  group('detail page', () {
    testWidgets('opens from the grid and lists tasks', (tester) async {
      await seedProject('p1');
      await firestore.collection('projects/p1/tasks').add({
        'title': 'Write copy',
        'order': 1,
      });
      await pumpProjects(tester);

      await tester.tap(find.text('Launch'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(find.text('Write copy'), findsOneWidget);
      // Its own app bar replaces the shell's, with a way back.
      expect(find.byType(AppBar), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsPage), findsOneWidget);
    });

    testWidgets('shows "not found" for an unknown project', (tester) async {
      await pumpProjects(tester, location: Routes.project('nope'));

      expect(find.text('Project not found'), findsOneWidget);
      await tester.tap(find.text('Back to projects'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsPage), findsOneWidget);
    });
  });
}
