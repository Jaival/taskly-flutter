import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/tasks/domain/task_repeat.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/due_dates.dart';
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
    int? dueInDays,
    String priority = 'medium',
    String? repeat,
    List<Map<String, String>>? labels,
  }) => firestore.doc(path).set({
    'ownerId': ownerId ?? testUser.uid,
    'title': title,
    'description': '',
    'priority': priority,
    'status': status,
    'assigneeId': assigneeId,
    'dueDate': dueInDays == null ? null : dueTimestamp(dueInDays),
    'repeat': repeat,
    'labels': ?labels,
    'order': order,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  Future<void> seedProject(String id, {required String role}) =>
      firestore.doc('projects/$id').set({
        'ownerId': 'bob',
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'notStarted',
        'memberIds': ['bob', testUser.uid],
        'roles': {'bob': 'owner', testUser.uid: role},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  Future<void> pumpTasks(
    WidgetTester tester, {
    String location = Routes.tasks,
  }) =>
      pumpApp(tester, user: testUser, firestore: firestore, location: location);

  // The list of tasks, not the row of filter chips, which scrolls too.
  final taskList = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;

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

  group('due dates', () {
    Future<void> openNewTask(WidgetTester tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Pay rent',
      );
    }

    testWidgets('a new task can be given a due date', (tester) async {
      await openNewTask(tester);
      await tester.tap(find.byTooltip('Pick a due date'));
      await tester.pumpAndSettle();
      // The picker opens on today.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['dueDate'], dueTimestamp(0));
      expect(find.text('Today · 1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TaskCard),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the due date can be cleared', (tester) async {
      await seedTask('tasks/a', title: 'Pay rent', dueInDays: 3);
      await pumpTasks(tester);
      expect(find.text('In 3 days'), findsOneWidget);

      await tester.tap(find.text('Pay rent'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear the due date'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['dueDate'], isNull);
      expect(find.text('In 3 days'), findsNothing);
    });

    testWidgets('tasks are grouped by when they are due', (tester) async {
      await seedTask('tasks/a', title: 'Someday', order: 1);
      await seedTask('tasks/b', title: 'Next week', dueInDays: 7, order: 2);
      await seedTask('tasks/c', title: 'Late', dueInDays: -2, order: 3);
      await seedTask('tasks/d', title: 'Now', dueInDays: 0, order: 4);
      await seedTask('tasks/e', title: 'Soon', dueInDays: 1, order: 5);
      await seedTask(
        'tasks/f',
        title: 'Finished',
        dueInDays: -5,
        status: 'complete',
        order: 6,
      );
      await pumpTasks(tester);

      // Only unfinished tasks count as overdue.
      expect(
        find.bySemanticsLabel(RegExp('Overdue: due 2 days ago')),
        findsOneWidget,
      );
      double top(String text) => tester.getTopLeft(find.text(text)).dy;
      final order = [
        'Overdue · 1',
        'Late',
        'Today · 1',
        'Now',
        'Upcoming · 2',
        'Soon',
        'Next week',
        'No due date · 1',
        'Someday',
        'Done · 1',
        'Finished',
      ];
      for (var i = 1; i < order.length; i++) {
        await tester.scrollUntilVisible(
          find.text(order[i]),
          100,
          scrollable: taskList,
        );
        expect(top(order[i - 1]), lessThan(top(order[i])), reason: order[i]);
      }
      expect(
        find.bySemanticsLabel(RegExp(r'(?<!Overdue: )Due 5 days ago')),
        findsOneWidget,
      );
    });

    testWidgets('no headings when nothing has a due date', (tester) async {
      await seedTask('tasks/a', title: 'Someday');
      await pumpTasks(tester);

      expect(find.textContaining('No due date'), findsNothing);
    });
  });

  /// Opens [menu], ticks [option], and closes the menu again (it stays
  /// open for ticking more).
  Future<void> tick(WidgetTester tester, String menu, String option) async {
    // The chips scroll sideways on a phone.
    await tester.ensureVisible(find.byTooltip(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxMenuButton, option));
    await tester.pumpAndSettle();
    // Tap outside it: the app bar, which does nothing itself.
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();
  }

  List<String> shownTitles(WidgetTester tester) => [
    for (final card in tester.widgetList<TaskCard>(find.byType(TaskCard)))
      card.task.title,
  ];

  group('search, filter and sort', () {
    Future<void> seedThree() async {
      await seedTask('tasks/a', title: 'Buy milk', priority: 'low', order: 1);
      await seedTask('tasks/b', title: 'Pay rent', priority: 'high', order: 2);
      await seedTask(
        'tasks/c',
        title: 'Call mum',
        priority: 'immediate',
        status: 'complete',
        order: 3,
      );
    }

    final search = find.widgetWithText(TextField, 'Search tasks');

    testWidgets('searching narrows the list', (tester) async {
      await seedThree();
      await pumpTasks(tester);

      await tester.enterText(search, 'MILK');
      await tester.pumpAndSettle();

      expect(shownTitles(tester), ['Buy milk']);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(shownTitles(tester), hasLength(3));
    });

    testWidgets('filtering by priority, then clearing', (tester) async {
      await seedThree();
      await pumpTasks(tester);

      await tick(tester, 'Filter by priority', 'High');
      await tick(tester, 'Filter by priority', 'Immediate');

      expect(shownTitles(tester), ['Pay rent', 'Call mum']);
      expect(find.text('Priority · 2'), findsOneWidget);
      expect(find.text('Showing 2 of 3 tasks'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(shownTitles(tester), hasLength(3));
      expect(find.text('Priority'), findsOneWidget);
    });

    testWidgets('nothing matching says so, and offers to clear', (
      tester,
    ) async {
      await seedThree();
      await pumpTasks(tester);

      await tester.enterText(search, 'zebra');
      await tester.pumpAndSettle();
      expect(find.text('No matching tasks'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Clear filters'));
      await tester.pumpAndSettle();
      expect(shownTitles(tester), hasLength(3));
      // The search box empties too.
      expect(find.text('zebra'), findsNothing);
    });

    testWidgets('sorting by priority lists them without groups', (
      tester,
    ) async {
      await seedThree();
      await seedTask('tasks/d', title: 'Soon', dueInDays: 1, order: 4);
      await pumpTasks(tester);
      expect(find.text('Upcoming · 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Priority'));
      await tester.pumpAndSettle();

      expect(shownTitles(tester), ['Call mum', 'Pay rent', 'Soon', 'Buy milk']);
      expect(find.text('Upcoming · 1'), findsNothing);
      expect(find.text('Sort: Priority'), findsOneWidget);
    });

    testWidgets('filters are kept when you come back to the page', (
      tester,
    ) async {
      await seedThree();
      await pumpTasks(tester);
      await tick(tester, 'Filter by status', 'Complete');

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();

      expect(shownTitles(tester), ['Call mum']);
    });
  });

  group('project tasks assigned to you', () {
    testWidgets('are listed with their project, and filtered by it', (
      tester,
    ) async {
      await seedProject('p1', role: 'editor');
      await seedTask('tasks/a', title: 'Buy milk');
      await seedTask(
        'projects/p1/tasks/t1',
        title: 'Write copy',
        ownerId: 'bob',
        assigneeId: testUser.uid,
      );
      await seedTask(
        'projects/p1/tasks/t2',
        title: 'For Bob',
        ownerId: 'bob',
        assigneeId: 'bob',
      );
      await pumpTasks(tester);

      expect(shownTitles(tester), ['Buy milk', 'Write copy']);
      expect(
        find.descendant(
          of: cardFor('Write copy'),
          matching: find.text('Launch'),
        ),
        findsOneWidget,
      );

      await tick(tester, 'Filter by project', 'Personal');
      expect(shownTitles(tester), ['Buy milk']);
    });

    testWidgets('a viewer can tick theirs off but not edit it', (tester) async {
      await seedProject('p1', role: 'viewer');
      await seedTask(
        'projects/p1/tasks/t1',
        title: 'Proofread',
        ownerId: 'bob',
        assigneeId: testUser.uid,
      );
      await pumpTasks(tester);

      expect(find.byTooltip('Delete "Proofread"'), findsNothing);
      await tester.tap(find.text('Proofread'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);

      await tester.tap(checkboxFor('Proofread'));
      await tester.pumpAndSettle();
      expect(
        (await firestore.doc('projects/p1/tasks/t1').get()).get('status'),
        'complete',
      );
    });
  });

  group('checklists', () {
    testWidgets('items are added in the form and counted on the card', (
      tester,
    ) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Launch post',
      );

      await tester.tap(find.text('Add an item'));
      await tester.pumpAndSettle();
      // The new item has focus: type, and Enter adds the next.
      tester.testTextInput.enterText('Draft');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      tester.testTextInput.enterText('Publish');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Done: Draft'));
      await tester.pumpAndSettle();
      expect(find.text('Checklist · 1/2'), findsOneWidget);

      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add task'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['checklist'], [
        {'text': 'Draft', 'done': true},
        {'text': 'Publish', 'done': false},
      ]);
      expect(
        find.descendant(of: cardFor('Launch post'), matching: find.text('1/2')),
        findsOneWidget,
      );
    });

    testWidgets('an item can be removed', (tester) async {
      await firestore.doc('tasks/a').set({
        'ownerId': testUser.uid,
        'title': 'Launch post',
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'checklist': [
          {'text': 'Draft', 'done': false},
          {'text': 'Publish', 'done': false},
        ],
        'order': 1,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      await pumpTasks(tester);

      await tester.tap(find.text('Launch post'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove "Draft"'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['checklist'], [
        {'text': 'Publish', 'done': false},
      ]);
      expect(find.text('0/1'), findsOneWidget);
    });
  });

  group('repeating tasks', () {
    final repeatField = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<TaskRepeat?>,
    );

    Future<void> chooseRepeat(WidgetTester tester, String label) async {
      await tester.ensureVisible(repeatField);
      await tester.tap(repeatField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('a task with a due date can repeat', (tester) async {
      await seedTask('tasks/a', title: 'Water plants', dueInDays: 1);
      await pumpTasks(tester);
      await tester.tap(find.text('Water plants'));
      await tester.pumpAndSettle();

      await chooseRepeat(tester, 'Every week');
      expect(find.text('Completing it adds the next one.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['repeat'], 'weekly');
      expect(
        find.descendant(
          of: cardFor('Water plants'),
          matching: find.text('Every week'),
        ),
        findsOneWidget,
      );
    });

    testWidgets("without a due date it can't, and clearing one stops it", (
      tester,
    ) async {
      await seedTask(
        'tasks/a',
        title: 'Water plants',
        dueInDays: 1,
        repeat: 'daily',
      );
      await pumpTasks(tester);
      await tester.tap(find.text('Water plants'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Clear the due date'));
      await tester.pumpAndSettle();
      expect(find.text('Pick a due date to repeat the task.'), findsOneWidget);
      expect(
        tester
            .widget<DropdownButton<TaskRepeat?>>(
              find.byWidgetPredicate(
                (widget) => widget is DropdownButton<TaskRepeat?>,
              ),
            )
            .onChanged,
        isNull,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect((await onlyTaskIn('tasks'))['repeat'], isNull);
      expect(find.text('Every day'), findsNothing);
    });

    testWidgets('ticking one off adds the next, and says so', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Water plants',
        dueInDays: 0,
        repeat: 'daily',
      );
      await pumpTasks(tester);

      await tester.tap(checkboxFor('Water plants'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Next one added, due'), findsOneWidget);
      final tasks = (await firestore.collection('tasks').get()).docs;
      expect(tasks, hasLength(2));
      final next = tasks.singleWhere((doc) => doc.id != 'a').data();
      expect(next['status'], 'notStarted');
      expect(next['dueDate'], dueTimestamp(1));
      expect(next['repeat'], 'daily');
      expect(cardFor('Water plants'), findsNWidgets(2));
    });
  });

  group('labels', () {
    Map<String, String> label(String name, String color) => {
      'name': name,
      'color': color,
    };

    Future<List<Object?>?> labelsOf(String path) async =>
        (await firestore.doc(path).get()).data()!['labels'] as List<Object?>?;

    Future<void> openPicker(WidgetTester tester) async {
      final button = find.byIcon(Icons.new_label_outlined);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    Future<void> saveForm(WidgetTester tester, String label) async {
      final button = find.widgetWithText(FilledButton, label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    testWidgets('a new label, in the colour picked', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Buy stamps',
      );

      await openPicker(tester);
      expect(find.text('No labels yet. Type a name to add one.'), findsOne);
      await tester.enterText(find.byType(TextField).last, 'Errands ');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Teal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add "Errands"'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Label: Errands'), findsOneWidget);
      await saveForm(tester, 'Add task');

      expect((await onlyTaskIn('tasks'))['labels'], [label('Errands', 'teal')]);
      expect(
        find.descendant(
          of: cardFor('Buy stamps'),
          matching: find.text('Errands'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('picking one already in use keeps its colour', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Logo',
        labels: [label('Design', 'blue')],
      );
      await seedTask('tasks/b', title: 'Icons', order: 2);
      await pumpTasks(tester);
      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();

      await openPicker(tester);
      // Typing a name that's taken finds it rather than adding another.
      await tester.enterText(find.byType(TextField).last, 'design');
      await tester.pumpAndSettle();
      expect(find.textContaining('Add "'), findsNothing);
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Design'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'Save');

      expect(await labelsOf('tasks/b'), [label('Design', 'blue')]);
    });

    testWidgets('a label comes off with its button', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Logo',
        labels: [label('Design', 'blue'), label('Bug', 'red')],
      );
      await pumpTasks(tester);
      await tester.tap(find.text('Logo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove the label Design'));
      await tester.pumpAndSettle();
      await saveForm(tester, 'Save');

      expect(await labelsOf('tasks/a'), [label('Bug', 'red')]);
    });

    testWidgets('editing a label changes it on every task', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Logo',
        labels: [label('Design', 'blue')],
      );
      await seedTask(
        'tasks/b',
        title: 'Icons',
        order: 2,
        labels: [label('Design', 'blue')],
      );
      await pumpTasks(tester);
      await tester.tap(find.text('Logo'));
      await tester.pumpAndSettle();

      await openPicker(tester);
      await tester.tap(find.byTooltip('Edit the label Design'));
      await tester.pumpAndSettle();
      expect(find.text('Changes it on all your tasks.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'UX');
      await tester.tap(find.byTooltip('Purple'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Saving the form doesn't put the old one back.
      await saveForm(tester, 'Save');

      expect(await labelsOf('tasks/a'), [label('UX', 'purple')]);
      expect(await labelsOf('tasks/b'), [label('UX', 'purple')]);
    });

    testWidgets('deleting a label asks first', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Logo',
        labels: [label('Design', 'blue')],
      );
      await seedTask(
        'tasks/b',
        title: 'Icons',
        order: 2,
        labels: [label('Design', 'blue')],
      );
      await pumpTasks(tester);
      await tester.tap(find.text('Icons'));
      await tester.pumpAndSettle();

      await openPicker(tester);
      await tester.tap(find.byTooltip('Edit the label Design'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete "Design"?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('No labels yet. Type a name to add one.'), findsOne);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      // Closing the form without saving: it's gone all the same.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await labelsOf('tasks/a'), isEmpty);
      expect(await labelsOf('tasks/b'), isEmpty);
    });

    testWidgets('the Tasks page filters by label', (tester) async {
      await seedTask(
        'tasks/a',
        title: 'Logo',
        labels: [label('Design', 'blue')],
      );
      await seedTask(
        'tasks/b',
        title: 'Crash',
        order: 2,
        labels: [label('Bug', 'red')],
      );
      await seedTask('tasks/c', title: 'Plain', order: 3);
      await pumpTasks(tester);

      // At the end of a row of chips that scrolls sideways on a phone.
      await tester.ensureVisible(find.byTooltip('Filter by label'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter by label'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Design'));
      await tester.pumpAndSettle();
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('Showing 1 of 3 tasks'), findsOneWidget);
    });
  });
}
