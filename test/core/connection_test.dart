import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/data/connection.dart';
import 'package:taskly/core/domain/project_role.dart';
import 'package:taskly/core/widgets/offline_banner.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/profile/data/user_profile_repository.dart';
import 'package:taskly/features/profile/domain/user_profile.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/sharing/data/invite_repository.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';

import '../helpers/pump_app.dart';

void main() {
  group('Connection', () {
    late StreamController<bool> online;
    late Connection connection;

    setUp(() {
      online = StreamController<bool>();
      connection = Connection(online.stream);
      addTearDown(connection.dispose);
    });

    /// Lets the stream deliver what was added to it.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('is online until told otherwise, then follows the device', () async {
      expect(connection.isOnline, isTrue);

      online.add(false);
      await settle();
      expect(connection.isOnline, isFalse);

      online.add(true);
      await settle();
      expect(connection.isOnline, isTrue);
    });

    test("stays online if the platform can't say", () async {
      online.addError(StateError('no plugin'));
      await settle();

      expect(connection.isOnline, isTrue);
    });

    test('online, a write is waited for', () async {
      final write = Completer<void>();
      var done = false;
      unawaited(connection.sentOrQueued(write.future).then((_) => done = true));

      await settle();
      expect(done, isFalse);

      write.complete();
      await settle();
      expect(done, isTrue);
    });

    test('online, a write that fails says so', () async {
      await expectLater(
        connection.sentOrQueued(Future.error(StateError('denied'))),
        throwsStateError,
      );
    });

    test('offline, a write is not waited for', () async {
      online.add(false);
      await settle();

      // Would never complete: the server can't be reached.
      await connection.sentOrQueued(Completer<void>().future);
    });

    test('a write stops being waited for when the connection drops', () async {
      final write = Completer<void>();
      var done = false;
      unawaited(connection.sentOrQueued(write.future).then((_) => done = true));
      await settle();
      expect(done, isFalse);

      online.add(false);
      await settle();
      expect(done, isTrue);

      // Refused once the device is back online. Nobody is waiting to hear
      // it, and it mustn't surface as an unhandled error.
      write.completeError(StateError('denied'));
      await settle();
    });
  });

  group('repositories wait for their writes through it', () {
    late FakeFirebaseFirestore db;
    late int writes;

    Future<void> counting(Future<void> write) {
      writes++;
      return write;
    }

    setUp(() {
      db = FakeFirebaseFirestore();
      writes = 0;
    });

    test('tasks', () async {
      final repository = TaskRepository(db, saved: counting);

      await repository.createTask(ownerId: 'alice', title: 'Buy milk');
      expect(writes, 1);

      final task = (await repository.watchPersonalTasks('alice').first).single;
      await repository.deleteTask(task);
      expect(writes, 2);
    });

    test('projects, and the invites deleted with them', () async {
      final repository = ProjectRepository(db, saved: counting);

      final id = await repository.createProject(
        ownerId: 'alice',
        name: 'Launch',
      );
      expect(writes, 1);

      final project = (await repository.watchProject(id).first)!;
      await repository.deleteProject(project);
      // The invites, then the project.
      expect(writes, 3);
    });

    test('invites', () async {
      await InviteRepository(db, saved: counting).sendInvite(
        projectId: 'p1',
        projectName: 'Launch',
        email: 'bob@example.com',
        role: ProjectRole.viewer,
        invitedBy: 'alice',
      );

      expect(writes, 1);
    });

    test('profiles', () async {
      await UserProfileRepository(db, saved: counting).createProfile(
        const UserProfile(
          uid: 'alice',
          displayName: 'Alice',
          email: 'alice@example.com',
        ),
      );

      expect(writes, 1);
    });
  });

  group('the offline banner', () {
    const notice = "You're offline.";
    late FakeFirebaseFirestore firestore;
    late StreamController<bool> online;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      online = StreamController<bool>();
    });

    Future<void> goOffline(WidgetTester tester, {bool offline = true}) async {
      online.add(!offline);
      await tester.pumpAndSettle();
    }

    testWidgets('shows while the device is offline, and goes when it is back', (
      tester,
    ) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        online: online.stream,
        location: '/home',
      );
      expect(find.textContaining(notice), findsNothing);

      await goOffline(tester);
      expect(find.textContaining(notice), findsOneWidget);
      // Above the page, not over it.
      expect(
        tester.getBottomLeft(find.byType(OfflineBanner)).dy,
        greaterThan(tester.getBottomLeft(find.textContaining(notice)).dy),
      );
      expect(find.byType(HomePage), findsOneWidget);

      await goOffline(tester, offline: false);
      expect(find.textContaining(notice), findsNothing);
    });

    testWidgets('is on every signed-in page, wide or narrow', (tester) async {
      await firestore.doc('projects/p1').set({
        'ownerId': testUser.uid,
        'name': 'Launch',
        'description': '',
        'priority': 'high',
        'status': 'inProgress',
        'memberIds': [testUser.uid],
        'roles': {testUser.uid: 'owner'},
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
      for (final size in [const Size(400, 800), const Size(1400, 900)]) {
        await pumpApp(
          tester,
          user: testUser,
          firestore: firestore,
          online: Stream.value(false),
          // A nested page, which has its own app bar.
          location: '/projects/p1',
          size: size,
        );

        expect(find.textContaining(notice), findsOneWidget);
        expect(find.text('Launch'), findsOneWidget);
      }
    });

    testWidgets('a task can still be added', (tester) async {
      await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        online: Stream.value(false),
        location: '/tasks',
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Buy milk',
      );
      await tester.tap(find.text('Add task'));
      await tester.pumpAndSettle();

      // The form has closed.
      expect(find.text('Add task'), findsNothing);
      expect(find.text('Buy milk'), findsOneWidget);
    });

    testWidgets("isn't shown to someone signed out", (tester) async {
      await pumpApp(tester, online: Stream.value(false));

      expect(find.textContaining(notice), findsNothing);
    });
  });
}
