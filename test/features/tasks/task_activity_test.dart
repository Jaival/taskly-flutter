import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/projects/domain/project.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';
import 'package:taskly/features/tasks/domain/task.dart';
import 'package:taskly/features/tasks/domain/task_activity.dart';
import 'package:taskly/features/tasks/presentation/task_activity_sheet.dart';

import '../../helpers/pump_app.dart';

const _alex = AppUser(uid: 'alex', displayName: 'Alex Kim');

void main() {
  late FakeFirebaseFirestore db;

  setUp(() => db = FakeFirebaseFirestore());

  group('the log', () {
    late TaskRepository repository;
    AppUser? signedIn;

    setUp(() {
      signedIn = _alex;
      repository = TaskRepository(db, currentUser: () => signedIn);
    });

    Future<Task> createTask({String? assigneeId, DateTime? dueDate}) async {
      await repository.createTask(
        projectId: 'p1',
        ownerId: 'alex',
        title: 'Write copy',
        assigneeId: assigneeId,
        dueDate: dueDate,
      );
      return (await repository.watchProjectTasks('p1').first).single;
    }

    Future<List<TaskActivity>> activityOf(Task task) =>
        repository.watchActivity('p1', task.id).first;

    /// What was logged after the task was created, as kind → value.
    Future<Map<ActivityKind, String>> changesTo(Task task) async => {
      for (final entry in await activityOf(task))
        if (entry.kind != ActivityKind.created) entry.kind: entry.value,
    };

    test('starts with who created the task', () async {
      final task = await createTask();

      final entry = (await activityOf(task)).single;
      expect(entry.kind, ActivityKind.created);
      expect(entry.authorId, 'alex');
      expect(entry.authorName, 'Alex Kim');
      expect(entry.createdAt, isNotNull);
    });

    test('records each field an edit changed, and only those', () async {
      final task = await createTask();

      await repository.updateDetails(
        task,
        title: 'Write the copy',
        description: 'For the landing page',
        priority: Priority.high,
        status: TaskStatus.inProgress,
        dueDate: DateTime(2026, 10, 3),
        assigneeId: () => 'bob',
      );

      expect(await changesTo(task), {
        ActivityKind.title: 'Write the copy',
        ActivityKind.description: '',
        ActivityKind.priority: 'high',
        ActivityKind.status: 'inProgress',
        ActivityKind.dueDate: '2026-10-03',
        ActivityKind.assignee: 'bob',
      });
    });

    test('records nothing for an edit that changed nothing', () async {
      final task = await createTask(
        assigneeId: 'bob',
        dueDate: DateTime(2026, 10, 3),
      );

      await repository.updateDetails(
        task,
        title: ' Write copy ',
        description: '',
        priority: task.priority,
        status: task.status,
        dueDate: DateTime(2026, 10, 3),
        assigneeId: () => 'bob',
      );

      expect(await changesTo(task), isEmpty);
    });

    test('records clearing the assignee and the due date', () async {
      final task = await createTask(
        assigneeId: 'bob',
        dueDate: DateTime(2026, 10, 3),
      );

      await repository.updateDetails(
        task,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: task.status,
        dueDate: null,
        assigneeId: () => null,
      );

      expect(await changesTo(task), {
        ActivityKind.assignee: '',
        ActivityKind.dueDate: '',
      });
    });

    test('records a status change, but not setting the same status', () async {
      final task = await createTask();

      await repository.setStatus(task, TaskStatus.notStarted);
      expect(await changesTo(task), isEmpty);

      await repository.setStatus(task, TaskStatus.complete);
      expect(await changesTo(task), {ActivityKind.status: 'complete'});
    });

    test('comments are trimmed, and listed oldest first', () async {
      final task = await createTask();

      await repository.addComment(task, '  Looks good  ');
      signedIn = const AppUser(uid: 'bob', email: 'bob@example.com');
      await repository.addComment(task, 'Thanks');

      final comments = [
        for (final entry in await activityOf(task))
          if (entry.isComment) entry,
      ];
      expect([for (final c in comments) c.value], ['Looks good', 'Thanks']);
      // No display name: the email stands in.
      expect(comments.last.authorId, 'bob');
      expect(comments.last.authorName, 'bob@example.com');
    });

    test('a comment can be deleted', () async {
      final task = await createTask();
      await repository.addComment(task, 'Oops');
      final comment = (await activityOf(task)).last;

      await repository.deleteComment(task, comment);

      expect((await activityOf(task)).where((e) => e.isComment), isEmpty);
    });

    test('an entry of a kind this version does not know is skipped', () async {
      final task = await createTask();
      await db.collection('projects/p1/tasks/${task.id}/activity').add({
        'kind': 'reaction',
        'authorId': 'bob',
        'authorName': 'Bob',
        'value': 'thumbs-up',
        'createdAt': Timestamp.now(),
      });

      expect((await activityOf(task)).single.kind, ActivityKind.created);
    });

    test('personal tasks have no log', () async {
      final id = await repository.createTask(ownerId: 'alex', title: 'Mine');
      final task = (await repository.watchPersonalTasks('alex').first).single;
      await repository.setStatus(task, TaskStatus.complete);
      await repository.addComment(task, 'To myself');

      expect((await db.collection('tasks/$id/activity').get()).docs, isEmpty);
      expect((await db.doc('tasks/$id').get()).get('status'), 'complete');
    });

    test('nothing is logged without someone signed in', () async {
      signedIn = null;
      final task = await createTask();

      await repository.setStatus(task, TaskStatus.complete);

      expect(await activityOf(task), isEmpty);
      expect(
        (await db.doc('projects/p1/tasks/${task.id}').get()).get('status'),
        'complete',
      );
    });

    test('deleting a task deletes its comments and activity', () async {
      final task = await createTask();
      await repository.addComment(task, 'Looks good');

      await repository.deleteTask(task);

      final path = 'projects/p1/tasks/${task.id}';
      expect((await db.doc(path).get()).exists, isFalse);
      expect((await db.collection('$path/activity').get()).docs, isEmpty);
    });

    test('deleting a project deletes the activity of its tasks', () async {
      final task = await createTask();
      await repository.addComment(task, 'Looks good');
      await db.doc('projects/p1').set({'ownerId': 'alex'});

      await ProjectRepository(db).deleteProject(
        const Project(
          id: 'p1',
          ownerId: 'alex',
          name: 'Launch',
          memberIds: ['alex'],
          roles: {'alex': ProjectRole.owner},
        ),
      );

      final path = 'projects/p1/tasks/${task.id}';
      expect((await db.doc('projects/p1').get()).exists, isFalse);
      expect((await db.doc(path).get()).exists, isFalse);
      expect((await db.collection('$path/activity').get()).docs, isEmpty);
    });
  });

  group('in words', () {
    const localizations = DefaultMaterialLocalizations();
    final now = DateTime(2026, 10, 1, 12);

    String describe(
      ActivityKind kind,
      String value, {
      String authorId = 'alex',
      String authorName = 'Alex',
      String? uid = 'me',
      Map<String, String>? members = const {'bob': 'Bob', 'me': 'Me (you)'},
    }) => describeActivity(
      TaskActivity(
        id: 'e1',
        kind: kind,
        authorId: authorId,
        authorName: authorName,
        value: value,
      ),
      uid: uid,
      members: members,
      localizations: localizations,
      now: now,
    );

    test('says who did what', () {
      expect(describe(ActivityKind.created, ''), 'Alex created this task');
      expect(
        describe(ActivityKind.status, 'inProgress'),
        'Alex moved this to In progress',
      );
      expect(
        describe(ActivityKind.priority, 'high'),
        'Alex set the priority to High',
      );
      expect(
        describe(ActivityKind.title, 'Write the copy'),
        'Alex renamed this to "Write the copy"',
      );
      expect(
        describe(ActivityKind.description, ''),
        'Alex changed the description',
      );
    });

    test('your own changes are by "You"', () {
      expect(
        describe(ActivityKind.status, 'complete', authorId: 'me'),
        'You moved this to Complete',
      );
    });

    test('someone without a name is "Someone"', () {
      expect(
        describe(ActivityKind.created, '', authorName: ''),
        'Someone created this task',
      );
    });

    test('names the assignee', () {
      expect(
        describe(ActivityKind.assignee, 'bob'),
        'Alex assigned this to Bob',
      );
      expect(
        describe(ActivityKind.assignee, 'me'),
        'Alex assigned this to you',
      );
      expect(
        describe(ActivityKind.assignee, 'me', authorId: 'me'),
        'You assigned this to yourself',
      );
      expect(
        describe(ActivityKind.assignee, 'alex'),
        'Alex assigned this to themselves',
      );
      expect(describe(ActivityKind.assignee, ''), 'Alex unassigned this');
      expect(
        describe(ActivityKind.assignee, 'gone'),
        'Alex assigned this to someone no longer in the project',
      );
      // Away from the project page, where the members aren't known.
      expect(
        describe(ActivityKind.assignee, 'bob', members: null),
        'Alex changed the assignee',
      );
    });

    test('spells out the due date', () {
      expect(
        describe(ActivityKind.dueDate, '2026-10-03'),
        'Alex set the due date to Sat, Oct 3',
      );
      expect(describe(ActivityKind.dueDate, ''), 'Alex removed the due date');
      expect(
        describe(ActivityKind.dueDate, 'soon'),
        'Alex changed the due date',
      );
    });

    test('says how long ago', () {
      String ago(Duration since) =>
          timeAgo(localizations, now.subtract(since), now);

      expect(timeAgo(localizations, null, now), 'Just now');
      expect(ago(const Duration(seconds: 30)), 'Just now');
      expect(ago(const Duration(minutes: 5)), '5 min ago');
      expect(ago(const Duration(hours: 3)), '3 hr ago');
      expect(ago(const Duration(hours: 30)), 'Yesterday');
      expect(ago(const Duration(days: 4)), '4 days ago');
      expect(ago(const Duration(days: 20)), 'Sep 11');
    });
  });

  group('on a project page', () {
    Future<void> seedProject({String role = 'owner'}) async {
      await db.doc('projects/p1').set({
        'ownerId': role == 'owner' ? testUser.uid : 'bob',
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'inProgress',
        'memberIds': [testUser.uid, 'bob'],
        'roles': {
          testUser.uid: role,
          'bob': role == 'owner' ? 'editor' : 'owner',
        },
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await db.doc('users/bob').set({
        'displayName': 'Bob Byron',
        'email': 'bob@example.com',
      });
      await db.doc('projects/p1/tasks/t1').set({
        'ownerId': 'bob',
        'title': 'Write copy',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'assigneeId': null,
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }

    Future<void> seedEntry(
      String id, {
      String kind = 'comment',
      String authorId = 'bob',
      String value = '',
      Duration ago = Duration.zero,
    }) => db.doc('projects/p1/tasks/t1/activity/$id').set({
      'kind': kind,
      'authorId': authorId,
      'authorName': authorId == 'bob' ? 'Bob Byron' : 'Ada Lovelace',
      'value': value,
      'createdAt': Timestamp.fromDate(DateTime.now().subtract(ago)),
    });

    Future<List<Map<String, Object?>>> comments() async => [
      for (final doc
          in (await db.collection('projects/p1/tasks/t1/activity').get()).docs)
        if (doc.data()['kind'] == 'comment') doc.data(),
    ];

    Future<void> openComments(
      WidgetTester tester, {
      Size size = const Size(400, 800),
    }) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: db,
        location: '/projects/p1',
        size: size,
      );
      await tester.ensureVisible(find.byTooltip('Comments on "Write copy"'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Comments on "Write copy"'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows comments and changes, oldest first', (tester) async {
      await seedProject();
      await seedEntry('e1', kind: 'created', ago: const Duration(days: 2));
      await seedEntry(
        'e2',
        kind: 'assignee',
        value: testUser.uid,
        ago: const Duration(hours: 3),
      );
      await seedEntry('e3', value: 'Can you take this?');

      await openComments(tester);

      expect(find.text('Comments and activity'), findsOneWidget);
      expect(
        find.text('Bob Byron created this task · 2 days ago'),
        findsOneWidget,
      );
      expect(
        find.text('Bob Byron assigned this to you · 3 hr ago'),
        findsOneWidget,
      );
      expect(find.text('Can you take this?'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('created this task')).dy,
        lessThan(tester.getTopLeft(find.text('Can you take this?')).dy),
      );
    });

    testWidgets('a task without any says so', (tester) async {
      await seedProject();

      await openComments(tester);

      expect(find.textContaining('No comments yet.'), findsOneWidget);
    });

    testWidgets('adding a comment shows it, and empties the box', (
      tester,
    ) async {
      await seedProject();
      await openComments(tester);

      await tester.enterText(find.byType(TextField), 'On it');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect(find.text('On it'), findsOneWidget);
      expect(find.textContaining('You · Just now'), findsOneWidget);
      expect(find.textContaining('No comments yet.'), findsNothing);
      final saved = (await comments()).single;
      expect(saved['value'], 'On it');
      expect(saved['authorId'], testUser.uid);
      expect(saved['authorName'], 'Ada Lovelace');
    });

    testWidgets('Enter sends too, and an empty comment is not sent', (
      tester,
    ) async {
      await seedProject();
      await openComments(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(await comments(), isEmpty);

      await tester.enterText(find.byType(TextField), 'Done');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect((await comments()).single['value'], 'Done');
    });

    testWidgets('changes made in the app are logged', (tester) async {
      await seedProject();
      await pumpApp(
        tester,
        user: testUser,
        firestore: db,
        location: '/projects/p1',
      );

      await tester.tap(find.bySemanticsLabel('Complete "Write copy"'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Comments on "Write copy"'));
      await tester.pumpAndSettle();

      expect(
        find.text('You moved this to Complete · Just now'),
        findsOneWidget,
      );
    });

    testWidgets('you can delete your own comment, after confirming', (
      tester,
    ) async {
      await seedProject(role: 'viewer');
      await seedEntry('e1', value: "Bob's");
      await seedEntry('e2', authorId: testUser.uid, value: 'Mine');
      await openComments(tester);

      // A viewer can't delete someone else's.
      expect(find.byTooltip('Delete comment'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete comment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Mine'), findsNothing);
      expect((await comments()).single['value'], "Bob's");
    });

    testWidgets("an editor can delete anyone's comment", (tester) async {
      await seedProject();
      await seedEntry('e1', value: "Bob's");
      await openComments(tester);

      await tester.tap(find.byTooltip('Delete comment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await comments(), isEmpty);
    });

    testWidgets('a viewer can comment', (tester) async {
      await seedProject(role: 'viewer');
      await openComments(tester);

      await tester.enterText(find.byType(TextField), 'Looks good');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      expect((await comments()).single['value'], 'Looks good');
    });

    testWidgets('the board card menu opens them too', (tester) async {
      await seedProject();
      await seedEntry('e1', value: 'Can you take this?');
      await pumpApp(
        tester,
        user: testUser,
        firestore: db,
        location: '/projects/p1',
        size: const Size(1400, 1000),
      );
      await tester.tap(find.byTooltip('Show as a board'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actions for "Write copy"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comments and activity'));
      await tester.pumpAndSettle();

      expect(find.text('Can you take this?'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Can you take this?'), findsNothing);
    });
  });

  testWidgets('personal tasks have no comments button', (tester) async {
    await db.doc('tasks/t1').set({
      'ownerId': testUser.uid,
      'title': 'Buy milk',
      'description': '',
      'priority': 'medium',
      'status': 'notStarted',
      'order': 1,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    await pumpApp(tester, user: testUser, firestore: db, location: '/tasks');

    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byTooltip('Comments on "Buy milk"'), findsNothing);
  });
}
