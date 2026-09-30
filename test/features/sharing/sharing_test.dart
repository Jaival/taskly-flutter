import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/projects/presentation/project_detail_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  const desktop = Size(1400, 1000);

  Future<void> seedProfile(String uid, String name, String email) =>
      firestore.doc('users/$uid').set({
        'displayName': name,
        'email': email,
        'photoUrl': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  /// Project p1, "Launch", with the given members (user ID → role).
  Future<void> seedProject(Map<String, String> roles, {String id = 'p1'}) =>
      firestore.doc('projects/$id').set({
        'ownerId': roles.entries.firstWhere((e) => e.value == 'owner').key,
        'name': id == 'p1' ? 'Launch' : 'Project $id',
        'description': '',
        'priority': 'high',
        'status': 'notStarted',
        'memberIds': roles.keys.toList(),
        'roles': roles,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  Future<Map<String, Object?>> project([String id = 'p1']) async =>
      (await firestore.doc('projects/$id').get()).data()!;

  Future<void> pump(
    WidgetTester tester, {
    String location = '/projects/p1',
    AppUser user = testUser,
    Size size = desktop,
  }) => pumpApp(
    tester,
    user: user,
    firestore: firestore,
    location: location,
    size: size,
  );

  setUp(() async {
    await seedProfile(testUser.uid, 'Ada Lovelace', 'ada@example.com');
    await seedProfile('bob', 'Bob Byron', 'bob@example.com');
  });

  group('members', () {
    testWidgets('are listed by name with their roles', (tester) async {
      await seedProject({testUser.uid: 'owner', 'bob': 'viewer'});
      await pump(tester);

      expect(find.text('Ada Lovelace (you)'), findsOneWidget);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Bob Byron'), findsOneWidget);
      expect(find.text('Viewer'), findsOneWidget);
    });

    testWidgets('the owner can change a role', (tester) async {
      await seedProject({testUser.uid: 'owner', 'bob': 'viewer'});
      await pump(tester);

      await tester.tap(find.byTooltip('Actions for Bob Byron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make editor'));
      await tester.pumpAndSettle();

      expect((await project())['roles'], {
        testUser.uid: 'owner',
        'bob': 'editor',
      });
      expect(find.text('Editor'), findsOneWidget);
    });

    testWidgets('the owner can remove a member, after confirming', (
      tester,
    ) async {
      await seedProject({testUser.uid: 'owner', 'bob': 'editor'});
      await pump(tester);

      await tester.tap(find.byTooltip('Actions for Bob Byron'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from project'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect((await project())['memberIds'], [testUser.uid]);
      expect(find.text('Bob Byron'), findsNothing);
    });

    testWidgets("other members can't manage anyone", (tester) async {
      await seedProject({'bob': 'owner', testUser.uid: 'editor'});
      await pump(tester);

      expect(find.text('Bob Byron'), findsOneWidget);
      expect(find.byTooltip('Actions for Bob Byron'), findsNothing);
      expect(find.text('Invite'), findsNothing);
    });

    testWidgets('a member can leave, and is taken back to projects', (
      tester,
    ) async {
      await seedProject({'bob': 'owner', testUser.uid: 'viewer'});
      await pump(tester);

      await tester.tap(find.byTooltip('Actions for Launch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave project'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect((await project())['memberIds'], ['bob']);
      expect(find.byType(ProjectsPage), findsOneWidget);
      expect(find.text('You left "Launch".'), findsOneWidget);
    });
  });

  group('inviting', () {
    Future<void> openInviteForm(WidgetTester tester) async {
      await seedProject({testUser.uid: 'owner', 'bob': 'editor'});
      await pump(tester);
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();
    }

    Future<void> send(WidgetTester tester, String email) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        email,
      );
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();
    }

    testWidgets('the owner invites someone by email, with a role', (
      tester,
    ) async {
      await openInviteForm(tester);
      await tester.tap(
        find.descendant(of: find.byType(Dialog), matching: find.text('Editor')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Viewer').last);
      await tester.pumpAndSettle();
      await send(tester, ' Erin@Example.com ');

      final invite = (await firestore.doc('invites/p1_erin@example.com').get())
          .data()!;
      expect(invite['role'], 'viewer');
      expect(invite['projectName'], 'Launch');
      expect(invite['invitedBy'], testUser.uid);
      expect(find.text('erin@example.com'), findsOneWidget);
      expect(find.text('Invited · Viewer'), findsOneWidget);
    });

    testWidgets('checks the email, and that they are not a member yet', (
      tester,
    ) async {
      await openInviteForm(tester);

      await send(tester, 'not-an-email');
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await send(tester, 'BOB@example.com');
      expect(find.text("They're already in this project."), findsOneWidget);
      expect((await firestore.collection('invites').get()).docs, isEmpty);
    });

    testWidgets('an invite can be cancelled', (tester) async {
      await openInviteForm(tester);
      await send(tester, 'erin@example.com');

      await tester.tap(find.byTooltip('Cancel invite to erin@example.com'));
      await tester.pumpAndSettle();

      expect((await firestore.collection('invites').get()).docs, isEmpty);
      expect(find.text('erin@example.com'), findsNothing);
    });
  });

  group('the shared page', () {
    Future<void> seedInvite({String role = 'editor'}) =>
        firestore.doc('invites/p9_ada@example.com').set({
          'projectId': 'p9',
          'projectName': 'Project p9',
          'email': 'ada@example.com',
          'role': role,
          'invitedBy': 'bob',
          'status': 'pending',
          'createdAt': Timestamp.now(),
        });

    testWidgets('shows invites, and a badge counting them', (tester) async {
      await seedInvite();
      await pump(tester, location: Routes.shared, size: const Size(400, 800));

      expect(find.text('Project p9'), findsOneWidget);
      expect(
        find.textContaining('Bob Byron invited you as an editor'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget,
      );
    });

    testWidgets('accepting joins the project and opens it', (tester) async {
      await seedProject({'bob': 'owner'}, id: 'p9');
      await seedInvite();
      await pump(tester, location: Routes.shared);

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      final joined = await project('p9');
      expect(joined['memberIds'], ['bob', testUser.uid]);
      expect((joined['roles']! as Map)[testUser.uid], 'editor');
      expect(find.byType(ProjectDetailPage), findsOneWidget);
      expect(find.text('Ada Lovelace (you)'), findsOneWidget);
    });

    testWidgets('declining hides the invite', (tester) async {
      await seedInvite();
      await pump(tester, location: Routes.shared);

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();

      final invite = (await firestore.doc('invites/p9_ada@example.com').get())
          .data()!;
      expect(invite['status'], 'declined');
      expect(find.text('Nothing shared with you'), findsOneWidget);
    });

    testWidgets('lists projects shared with you, not your own', (tester) async {
      await seedProject({testUser.uid: 'owner'});
      await seedProject({'bob': 'owner', testUser.uid: 'viewer'}, id: 'p2');
      await pump(tester, location: Routes.shared);

      expect(find.text('Shared with me'), findsOneWidget);
      expect(find.text('Project p2'), findsOneWidget);
      expect(find.text('Launch'), findsNothing);
    });

    testWidgets('an unverified email sees no invites, and why', (tester) async {
      await seedInvite();
      await pump(
        tester,
        location: Routes.shared,
        user: const AppUser(
          uid: 'uid-1',
          email: 'ada@example.com',
          displayName: 'Ada Lovelace',
        ),
      );

      expect(find.text('Project p9'), findsNothing);
      expect(
        find.textContaining('Verify your email to see invites'),
        findsOneWidget,
      );
    });
  });

  group('assigning tasks', () {
    testWidgets('an editor picks an assignee from the members', (tester) async {
      await seedProject({testUser.uid: 'owner', 'bob': 'editor'});
      await pump(tester);

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Write copy',
      );
      await tester.tap(find.text('Unassigned'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob Byron').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      final saved = (await firestore.collection('projects/p1/tasks').get())
          .docs
          .single
          .data();
      expect(saved['assigneeId'], 'bob');
      expect(
        find.descendant(
          of: find.byType(TaskCard),
          matching: find.text('Bob Byron'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("a former member's task shows as unassigned", (tester) async {
      await seedProject({testUser.uid: 'owner'});
      await firestore.doc('projects/p1/tasks/t1').set({
        'ownerId': testUser.uid,
        'title': 'Old task',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'assigneeId': 'someone-who-left',
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await pump(tester);

      expect(find.textContaining('Assigned to'), findsNothing);
      await tester.tap(find.text('Old task'));
      await tester.pumpAndSettle();
      expect(find.text('Unassigned'), findsOneWidget);
    });
  });
}
