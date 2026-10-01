import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/tasks/presentation/task_board.dart';
import 'package:taskly/features/tasks/presentation/task_card.dart';

import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  const desktop = Size(1400, 1000);

  Future<void> seedProject({String role = 'owner'}) =>
      firestore.doc('projects/p1').set({
        'ownerId': role == 'owner' ? testUser.uid : 'bob',
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'inProgress',
        'memberIds': [testUser.uid, 'bob'],
        'roles': {
          testUser.uid: role,
          if (role != 'owner') 'bob': 'owner' else 'bob': 'editor',
        },
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  Future<void> seedTask(
    String id, {
    required String title,
    String status = 'notStarted',
    String? assigneeId,
    double order = 1,
  }) => firestore.doc('projects/p1/tasks/$id').set({
    'ownerId': 'bob',
    'title': title,
    'description': '',
    'priority': 'medium',
    'status': status,
    'assigneeId': assigneeId,
    'order': order,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  Future<String> statusOf(String id) async =>
      (await firestore.doc('projects/p1/tasks/$id').get()).get('status')
          as String;

  Future<void> openBoard(WidgetTester tester, {Size size = desktop}) async {
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: '/projects/p1',
      size: size,
    );
    await tester.tap(find.byTooltip('Show as a board'));
    await tester.pumpAndSettle();
  }

  Finder boardCard(String title) => find.widgetWithText(BoardCard, title);

  testWidgets('shows a column per status, with counts', (tester) async {
    await seedProject();
    await seedTask('a', title: 'Write copy');
    await seedTask('b', title: 'Pick colours', status: 'inProgress');
    await seedTask('c', title: 'Buy domain', status: 'inProgress');
    await openBoard(tester);

    expect(find.text('Not started · 1'), findsOneWidget);
    expect(find.text('In progress · 2'), findsOneWidget);
    expect(find.text('Complete · 0'), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
    expect(
      tester.getTopLeft(boardCard('Write copy')).dx,
      lessThan(tester.getTopLeft(boardCard('Pick colours')).dx),
    );
  });

  testWidgets('dragging a card to another column changes its status', (
    tester,
  ) async {
    await seedProject();
    await seedTask('a', title: 'Write copy');
    await openBoard(tester);

    // On a touch screen a drag starts with a long press.
    final gesture = await tester.startGesture(
      tester.getCenter(boardCard('Write copy')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('In progress · 0')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(await statusOf('a'), 'inProgress');
    expect(find.text('In progress · 1'), findsOneWidget);
  });

  testWidgets("the card's menu moves it too, and can delete it", (
    tester,
  ) async {
    await seedProject();
    await seedTask('a', title: 'Write copy');
    await openBoard(tester);

    await tester.tap(find.byTooltip('Actions for "Write copy"'));
    await tester.pumpAndSettle();
    expect(find.text('Move to Not started'), findsNothing);
    await tester.tap(find.text('Move to Complete'));
    await tester.pumpAndSettle();
    expect(await statusOf('a'), 'complete');

    await tester.tap(find.byTooltip('Actions for "Write copy"'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(boardCard('Write copy'), findsNothing);
    expect(find.text('Deleted "Write copy".'), findsOneWidget);
  });

  testWidgets('a viewer can move only the tasks assigned to them', (
    tester,
  ) async {
    await seedProject(role: 'viewer');
    await seedTask('a', title: 'Mine', assigneeId: testUser.uid);
    await seedTask('b', title: 'Not mine', assigneeId: 'bob', order: 2);
    await openBoard(tester);

    expect(find.byTooltip('Actions for "Not mine"'), findsNothing);
    await tester.tap(find.byTooltip('Actions for "Mine"'));
    await tester.pumpAndSettle();
    expect(find.text('Delete'), findsNothing);
    await tester.tap(find.text('Move to In progress'));
    await tester.pumpAndSettle();
    expect(await statusOf('a'), 'inProgress');

    // Not draggable either.
    final gesture = await tester.startGesture(
      tester.getCenter(boardCard('Not mine')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('Complete · 0')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(await statusOf('b'), 'notStarted');
  });

  testWidgets('on a phone the columns scroll sideways', (tester) async {
    await seedProject();
    await seedTask('a', title: 'Write copy', status: 'complete');
    await openBoard(tester, size: const Size(400, 800));

    expect(tester.takeException(), isNull);
    final complete = find.text('Complete · 1');
    expect(tester.getTopLeft(complete).dx, greaterThan(400));

    await tester.drag(find.byType(TaskBoard), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(complete).dx, lessThan(400));
  });

  testWidgets('the board stays chosen for the next project', (tester) async {
    await seedProject();
    await seedTask('a', title: 'Write copy');
    await openBoard(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launch'));
    await tester.pumpAndSettle();

    expect(boardCard('Write copy'), findsOneWidget);
    await tester.tap(find.byTooltip('Show as a list'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
  });
}
