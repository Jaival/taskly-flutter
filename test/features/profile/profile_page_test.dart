import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/profile/data/user_profile_repository.dart';
import 'package:taskly/features/profile/domain/user_profile.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  Future<Map<String, Object?>?> storedProfile(String uid) async =>
      (await firestore.doc('users/$uid').get()).data();

  Finder saveButton() => find.widgetWithText(FilledButton, 'Save');

  Future<void> tapSave(WidgetTester tester) async {
    // Save enables itself on the frame after typing.
    await tester.pump();
    await tester.ensureVisible(saveButton());
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is signed in', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);

    expect(find.text('Ada Lovelace'), findsWidgets);
    expect(find.text('ada@example.com'), findsWidgets);
    expect(find.byTooltip('Verified'), findsOneWidget);
  });

  testWidgets('Save is disabled until the name changes', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Ada');
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets('renaming updates the profile and the account', (tester) async {
    await UserProfileRepository(firestore).createProfile(
      const UserProfile(
        uid: 'uid-1',
        displayName: 'Ada Lovelace',
        email: 'ada@example.com',
      ),
    );
    final auth = await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: Routes.profile,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      '  Countess Ada ',
    );
    await tapSave(tester);

    expect((await storedProfile('uid-1'))?['displayName'], 'Countess Ada');
    expect(auth.currentUser?.displayName, 'Countess Ada');
    expect(find.text('Name updated.'), findsOneWidget);
    // The header avatar follows the new name.
    expect(find.text('CA'), findsOneWidget);
  });

  testWidgets('saving creates a missing profile', (tester) async {
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: Routes.profile,
    );
    expect(await storedProfile('uid-1'), isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Ada');
    await tapSave(tester);

    final profile = await storedProfile('uid-1');
    expect(profile?['displayName'], 'Ada');
    expect(profile?['email'], 'ada@example.com');
  });

  testWidgets('an empty name is rejected', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), '   ');
    await tapSave(tester);

    expect(find.text('Your name is required.'), findsOneWidget);
  });

  group('change password', () {
    Future<FakeAuthRepository> openDialog(WidgetTester tester) async {
      final auth = await pumpApp(
        tester,
        user: testUser,
        location: Routes.profile,
      );
      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      return auth;
    }

    Future<void> submit(
      WidgetTester tester, {
      required String current,
      required String next,
    }) async {
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Current password'),
        current,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'New password'),
        next,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
    }

    testWidgets('sets the new one, given the current one', (tester) async {
      final auth = await openDialog(tester);

      await submit(
        tester,
        current: FakeAuthRepository.defaultPassword,
        next: 'a-better-password',
      );

      expect(auth.changedPassword, 'a-better-password');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Password changed.'), findsOneWidget);
    });

    testWidgets('refuses a wrong current password', (tester) async {
      final auth = await openDialog(tester);

      await submit(tester, current: 'a-guess', next: 'a-better-password');

      expect(find.text('Your current password is incorrect.'), findsOneWidget);
      expect(auth.changedPassword, isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('wants a new password that is long enough, and new', (
      tester,
    ) async {
      final auth = await openDialog(tester);

      await submit(
        tester,
        current: FakeAuthRepository.defaultPassword,
        next: 'short',
      );
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      await submit(
        tester,
        current: FakeAuthRepository.defaultPassword,
        next: FakeAuthRepository.defaultPassword,
      );
      expect(
        find.text('Choose a password different from the old one.'),
        findsOneWidget,
      );
      expect(auth.changedPassword, isNull);
    });

    testWidgets('or emails a reset link if the current one is forgotten', (
      tester,
    ) async {
      final auth = await openDialog(tester);

      await tester.tap(find.text('Forgot it? Email me a reset link'));
      await tester.pumpAndSettle();

      expect(auth.passwordResetsSent, ['ada@example.com']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('We sent a link to ada@example.com to set a new password.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('unverified emails are labelled', (tester) async {
    await pumpApp(
      tester,
      user: const AppUser(uid: 'u2', email: 'new@example.com'),
      location: Routes.profile,
    );
    expect(find.text('Not verified'), findsOneWidget);
  });

  testWidgets('sign out returns to login', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('logging in repairs a missing profile', (tester) async {
    final auth = FakeAuthRepository()
      ..addAccount(testUser, password: 'correct-horse');
    await pumpApp(
      tester,
      auth: auth,
      firestore: firestore,
      location: Routes.login,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'correct-horse',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();

    expect((await storedProfile('uid-1'))?['displayName'], 'Ada Lovelace');
  });

  group('UserProfileRepository.ensureProfile', () {
    test('leaves an existing profile alone', () async {
      final repository = UserProfileRepository(firestore);
      await firestore.doc('users/u1').set({
        'displayName': 'Original',
        'email': 'a@example.com',
        'createdAt': Timestamp.now(),
      });

      await repository.ensureProfile(
        const UserProfile(
          uid: 'u1',
          displayName: 'Replacement',
          email: 'a@example.com',
        ),
      );

      expect((await storedProfile('u1'))?['displayName'], 'Original');
    });
  });
}
