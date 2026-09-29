import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<void> seedTask(
    String path, {
    required String title,
    String? ownerId,
    String status = 'notStarted',
    String? assigneeId,
    double order = 1,
  }) => firestore.doc(path).set({
    'ownerId': ownerId ?? testUser.uid,
    'title': title,
    'description': '',
    'priority': 'medium',
    'status': status,
    'assigneeId': assigneeId,
    'order': order,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  Future<void> pumpTasks(
    WidgetTester tester, {
    String location = Routes.tasks,
  }) =>
      pumpApp(tester, user: testUser, firestore: firestore, location: location);

  Finder cardFor(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(TaskCard));

  Finder checkboxFor(String title) =>
      find.descendant(of: cardFor(title), matching: find.byType(Checkbox));

  TextDecoration? decorationOf(WidgetTester tester, String title) => tester
      .widget<AnimatedDefaultTextStyle>(
        find
            .ancestor(
              of: find.text(title),
              matching: find.byType(AnimatedDefaultTextStyle),
            )
            .first, // The card's own, not the Material's around it.
      )
      .style
      .decoration;

  Future<Map<String, Object?>> onlyTaskIn(String collection) async =>
      (await firestore.collection(collection).get()).docs.single.data();

  group('personal tasks', () {
    testWidgets('with no tasks, invites the user to add one', (tester) async {
      await pumpTasks(tester);
      expect(find.text('No tasks yet'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets("shows only the user's own tasks, in order", (tester) async {
      await seedTask('tasks/b', title: 'Second', order: 2);
      await seedTask('tasks/a', title: 'First', order: 1);
      await seedTask('tasks/c', title: 'Not mine', ownerId: 'someone-else');
      await pumpTasks(tester);

      expect(find.byType(TaskCard), findsNWidgets(2));
      expect(find.text('Not mine'), findsNothing);
      expect(
        tester.getTopLeft(find.text('First')).dy,
        lessThan(tester.getTopLeft(find.text('Second')).dy),
      );
    });

    testWidgets('adding a task', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Buy milk',
      );
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TaskCard, 'Buy milk'), findsOneWidget);
      final saved = await onlyTaskIn('tasks');
      expect(saved['ownerId'], testUser.uid);
      expect(saved['status'], 'notStarted');
    });

    testWidgets('a task needs a title', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      expect(find.text('Title is required.'), findsOneWidget);
      expect((await firestore.collection('tasks').get()).docs, isEmpty);
    });

    testWidgets('choosing a priority keeps what was typed', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Buy milk',
      );
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immediate').last);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Buy milk'), findsOneWidget);
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      expect((await onlyTaskIn('tasks'))['priority'], 'immediate');
    });

    testWidgets('ticking a task completes it, unticking reopens it', (
      tester,
    ) async {
      await seedTask('tasks/t1', title: 'Buy milk', status: 'inProgress');
      await pumpTasks(tester);
      expect(decorationOf(tester, 'Buy milk'), TextDecoration.none);

      await tester.tap(checkboxFor('Buy milk'));
      await tester.pumpAndSettle();
      expect((await onlyTaskIn('tasks'))['status'], 'complete');
      expect(decorationOf(tester, 'Buy milk'), TextDecoration.lineThrough);

      await tester.tap(checkboxFor('Buy milk'));
      await tester.pumpAndSettle();
      expect((await onlyTaskIn('tasks'))['status'], 'notStarted');
      expect(decorationOf(tester, 'Buy milk'), TextDecoration.none);
    });

    testWidgets('tapping a task edits it', (tester) async {
      await seedTask('tasks/t1', title: 'Buy milk');
      await pumpTasks(tester);

      await tester.tap(find.text('Buy milk'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Buy milk'),
        'Buy oat milk',
      );
      await tester.tap(find.text('Not started').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('In progress').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = await onlyTaskIn('tasks');
      expect(saved['title'], 'Buy oat milk');
      expect(saved['status'], 'inProgress');
      expect(find.widgetWithText(TaskCard, 'Buy oat milk'), findsOneWidget);
    });

    testWidgets('deleting hides the task, then deletes it', (tester) async {
      await seedTask('tasks/t1', title: 'Buy milk');
      await pumpTasks(tester);

      await tester.tap(find.byTooltip('Delete "Buy milk"'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsNothing);
      expect(find.text('Deleted "Buy milk".'), findsOneWidget);
      expect((await firestore.doc('tasks/t1').get()).exists, isTrue);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect((await firestore.doc('tasks/t1').get()).exists, isFalse);
      expect(find.text('No tasks yet'), findsOneWidget);
    });

    testWidgets('Undo brings a deleted task back', (tester) async {
      await seedTask('tasks/t1', title: 'Buy milk');
      await pumpTasks(tester);

      await tester.tap(find.byTooltip('Delete "Buy milk"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskCard), findsOneWidget);
      expect((await firestore.doc('tasks/t1').get()).exists, isTrue);
    });
  });

  group('project tasks', () {
    Future<void> seedProject({required String role}) async {
      const ownerId = 'owner-1';
      await firestore.doc('projects/p1').set({
        'ownerId': role == 'owner' ? testUser.uid : ownerId,
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'notStarted',
        'memberIds': [if (role != 'owner') ownerId, testUser.uid],
        'roles': {if (role != 'owner') ownerId: 'owner', testUser.uid: role},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }

    testWidgets('editors add tasks from the project page', (tester) async {
      await seedProject(role: 'editor');
      await pumpTasks(tester, location: Routes.project('p1'));

      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Write copy',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TaskCard, 'Write copy'), findsOneWidget);
      expect((await onlyTaskIn('projects/p1/tasks'))['title'], 'Write copy');
      // Personal tasks are separate.
      expect((await firestore.collection('tasks').get()).docs, isEmpty);
    });

    testWidgets('viewers can only tick off tasks assigned to them', (
      tester,
    ) async {
      await seedProject(role: 'viewer');
      await seedTask(
        'projects/p1/tasks/mine',
        title: 'Mine',
        ownerId: 'owner-1',
        assigneeId: testUser.uid,
      );
      await seedTask(
        'projects/p1/tasks/theirs',
        title: 'Theirs',
        ownerId: 'owner-1',
        order: 2,
      );
      await pumpTasks(tester, location: Routes.project('p1'));

      expect(find.text('Add task'), findsNothing);
      expect(find.byTooltip('Delete "Mine"'), findsNothing);
      expect(tester.widget<Checkbox>(checkboxFor('Theirs')).onChanged, isNull);

      await tester.tap(checkboxFor('Mine'));
      await tester.pumpAndSettle();
      expect(
        (await firestore.doc('projects/p1/tasks/mine').get())['status'],
        'complete',
      );

      // Tapping doesn't open the editor either.
      await tester.tap(find.text('Theirs'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
    });
  });
}
