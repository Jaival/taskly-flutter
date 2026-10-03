import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/account/data/account_deletion.dart';
import 'package:taskly/features/auth/domain/auth_failure.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/profile/data/user_profile_repository.dart';
import 'package:taskly/features/profile/presentation/profile_page.dart';
import 'package:taskly/features/projects/data/project_repository.dart';
import 'package:taskly/features/tasks/data/task_repository.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  final me = testUser.uid;

  Future<void> seedProject(String id, {required String owner}) =>
      firestore.doc('projects/$id').set({
        'ownerId': owner,
        'name': id,
        'description': '',
        'priority': 'medium',
        'status': 'notStarted',
        'memberIds': {owner, me, 'bob'}.toList(),
        'roles': {
          for (final uid in {me, 'bob'}) uid: 'editor',
          owner: 'owner',
        },
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

  /// Ada owns `mine` and is a member of Bob's `theirs`. Both have tasks,
  /// and both people have personal tasks and a profile.
  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await seedProject('mine', owner: me);
    await seedProject('theirs', owner: 'bob');
    for (final path in [
      'projects/mine/tasks/t1',
      'projects/mine/tasks/t2',
      'projects/theirs/tasks/t1',
    ]) {
      await firestore.doc(path).set({'ownerId': me, 'title': 'x', 'order': 1});
    }
    await firestore.doc('invites/mine_eve@example.com').set({
      'projectId': 'mine',
      'invitedBy': me,
      'email': 'eve@example.com',
      'status': 'pending',
    });
    for (final uid in [me, 'bob']) {
      await firestore.doc('tasks/$uid-task').set({
        'ownerId': uid,
        'title': 'Personal',
        'order': 1,
      });
      await firestore.doc('users/$uid').set({'displayName': uid});
    }
  });

  Future<bool> exists(String path) async =>
      (await firestore.doc(path).get()).exists;

  Future<void> expectAdaGone() async {
    expect(await exists('projects/mine'), isFalse);
    expect(await exists('projects/mine/tasks/t1'), isFalse);
    expect(await exists('projects/mine/tasks/t2'), isFalse);
    expect(await exists('invites/mine_eve@example.com'), isFalse);
    expect(await exists('tasks/$me-task'), isFalse);
    expect(await exists('users/$me'), isFalse);

    // Bob's project stays, without Ada. The task she created there stays.
    final theirs = (await firestore.doc('projects/theirs').get()).data()!;
    expect(theirs['memberIds'], ['bob']);
    expect(theirs['roles'], {'bob': 'owner'});
    expect(await exists('projects/theirs/tasks/t1'), isTrue);
    expect(await exists('tasks/bob-task'), isTrue);
    expect(await exists('users/bob'), isTrue);
  }

  group('AccountDeletion', () {
    late FakeAuthRepository auth;
    late AccountDeletion deletion;

    setUp(() {
      auth = FakeAuthRepository(currentUser: testUser);
      deletion = AccountDeletion(
        auth: auth,
        projects: ProjectRepository(firestore),
        tasks: TaskRepository(firestore),
        profiles: UserProfileRepository(firestore),
      );
    });

    test('deletes what is yours, and leaves what is shared with you', () async {
      await deletion.deleteAccount(
        password: FakeAuthRepository.defaultPassword,
      );

      await expectAdaGone();
      expect(auth.accountDeleted, isTrue);
      expect(auth.currentUser, isNull);
    });

    test('deletes nothing if the password is wrong', () async {
      await expectLater(
        () => deletion.deleteAccount(password: 'a-guess'),
        throwsA(isA<AuthFailure>()),
      );

      expect(await exists('projects/mine'), isTrue);
      expect(await exists('tasks/$me-task'), isTrue);
      expect(await exists('users/$me'), isTrue);
      expect(auth.accountDeleted, isFalse);
    });

    test('deletes the data before the account', () async {
      // As if the connection dropped at the very end.
      auth.failAccountDeletion = true;

      await expectLater(
        () => deletion.deleteAccount(
          password: FakeAuthRepository.defaultPassword,
        ),
        throwsA(isA<AuthFailure>()),
      );
      await expectAdaGone();
      expect(auth.currentUser, isNotNull, reason: 'still there, to try again');

      auth.failAccountDeletion = false;
      await deletion.deleteAccount(
        password: FakeAuthRepository.defaultPassword,
      );
      expect(auth.accountDeleted, isTrue);
    });
  });

  group('on the Profile page', () {
    Future<FakeAuthRepository> openDialog(WidgetTester tester) async {
      final auth = await pumpApp(
        tester,
        user: testUser,
        firestore: firestore,
        location: Routes.profile,
      );
      await tester.ensureVisible(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> confirm(WidgetTester tester, String password) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your password'),
        password,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();
    }

    testWidgets('says what will go, and who else loses it', (tester) async {
      await openDialog(tester);

      expect(find.textContaining('the 1 project you own'), findsOneWidget);
      expect(
        find.text(
          '1 of your projects is shared: the people in it will lose it too.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('deletes the account and returns to login', (tester) async {
      final auth = await openDialog(tester);

      await confirm(tester, FakeAuthRepository.defaultPassword);

      expect(auth.accountDeleted, isTrue);
      await expectAdaGone();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('Your account was deleted.'), findsOneWidget);
    });

    testWidgets('a wrong password changes nothing', (tester) async {
      final auth = await openDialog(tester);

      await confirm(tester, 'a-guess');

      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(auth.accountDeleted, isFalse);
      expect(await exists('projects/mine'), isTrue);
      expect(find.byType(ProfilePage), findsOneWidget);
    });

    testWidgets('can be cancelled', (tester) async {
      final auth = await openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(auth.accountDeleted, isFalse);
    });
  });
}
