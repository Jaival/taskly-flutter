import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';
import 'package:taskly/features/auth/domain/auth_failure.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/home/presentation/home_page.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

/// Someone who has only ever signed in with Google.
const googleUser = AppUser(
  uid: 'g-1',
  email: 'grace@example.com',
  displayName: 'Grace Hopper',
  emailVerified: true,
  hasPassword: false,
);

void main() {
  group('AuthRepository', () {
    // A user of their own for each test: the mock remembers what it was
    // told to throw, even across tests.
    (MockFirebaseAuth, AuthRepository) setUpAuth(MockUser user) {
      final firebaseAuth = MockFirebaseAuth(mockUser: user);
      return (firebaseAuth, AuthRepository(firebaseAuth));
    }

    test('signInWithGoogle returns who signed in', () async {
      final (_, repository) = setUpAuth(
        MockUser(
          uid: 'g-1',
          email: 'grace@example.com',
          displayName: 'Grace Hopper',
          isEmailVerified: true,
          providerData: [
            UserInfo.fromJson({
              'providerId': 'google.com',
              'uid': 'google-uid',
              'email': 'grace@example.com',
              'isAnonymous': false,
              'isEmailVerified': true,
            }),
          ],
        ),
      );

      final user = await repository.signInWithGoogle();

      expect(user?.uid, 'g-1');
      expect(user?.displayName, 'Grace Hopper');
      expect(user?.hasPassword, isFalse);
      expect(repository.currentUser?.uid, 'g-1');
    });

    test('closing the window is not an error', () async {
      final (firebaseAuth, repository) = setUpAuth(MockUser(uid: 'g-2'));
      whenCalling(Invocation.method(#signInWithPopup, null))
          .on(firebaseAuth)
          .thenThrow(FirebaseAuthException(code: 'popup-closed-by-user'));

      expect(await repository.signInWithGoogle(), isNull);
      expect(repository.currentUser, isNull);
    });

    test('a blocked window says how to fix it', () async {
      final (firebaseAuth, repository) = setUpAuth(MockUser(uid: 'g-3'));
      whenCalling(Invocation.method(#signInWithPopup, null))
          .on(firebaseAuth)
          .thenThrow(FirebaseAuthException(code: 'popup-blocked'));

      await expectLater(
        repository.signInWithGoogle,
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            contains('Allow pop-ups'),
          ),
        ),
      );
    });

    test('someone with a password has one', () async {
      final (_, repository) = setUpAuth(
        MockUser(
          uid: 'p-1',
          email: 'ada@example.com',
          providerData: [
            UserInfo.fromJson({
              'providerId': 'password',
              'uid': 'ada@example.com',
              'isAnonymous': false,
              'isEmailVerified': true,
            }),
            UserInfo.fromJson({
              'providerId': 'google.com',
              'uid': 'google-uid',
              'isAnonymous': false,
              'isEmailVerified': true,
            }),
          ],
        ),
      );

      final user = await repository.signIn(
        email: 'ada@example.com',
        password: 'password1',
      );
      expect(user.hasPassword, isTrue);
    });
  });

  group('on the login page', () {
    late FakeAuthRepository auth;
    late FakeFirebaseFirestore firestore;

    setUp(() {
      auth = FakeAuthRepository();
      firestore = FakeFirebaseFirestore();
    });

    Future<void> pump(WidgetTester tester, {String location = Routes.login}) =>
        pumpApp(tester, auth: auth, firestore: firestore, location: location);

    Future<void> tapGoogle(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Continue with Google'));
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
    }

    testWidgets('signs in, and creates the profile the first time', (
      tester,
    ) async {
      auth.googleUser = googleUser;
      await pump(tester);

      await tapGoogle(tester);

      expect(find.byType(HomePage), findsOneWidget);
      final profile = (await firestore.doc('users/g-1').get()).data()!;
      expect(profile['displayName'], 'Grace Hopper');
      expect(profile['email'], 'grace@example.com');
    });

    testWidgets('closing the window leaves the page as it was', (tester) async {
      await pump(tester);

      await tapGoogle(tester);

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('a failure shows its message', (tester) async {
      auth.failNextWith = const AuthFailure('Your browser blocked it.');
      await pump(tester);

      await tapGoogle(tester);

      expect(find.text('Your browser blocked it.'), findsOneWidget);
    });

    testWidgets('is on the sign-up page too', (tester) async {
      auth.googleUser = googleUser;
      await pump(tester, location: Routes.signUp);

      await tapGoogle(tester);

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets("isn't offered where it doesn't work", (tester) async {
      auth.supportsGoogleSignIn = false;
      await pump(tester);

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('or'), findsNothing);
    });
  });

  group('someone without a password', () {
    late FakeFirebaseFirestore firestore;

    setUp(() => firestore = FakeFirebaseFirestore());

    testWidgets('has no password to change', (tester) async {
      await pumpApp(
        tester,
        user: googleUser,
        firestore: firestore,
        location: Routes.profile,
      );

      expect(find.text('Signed in with Google'), findsOneWidget);
      expect(find.text('Change password'), findsNothing);
    });

    testWidgets('deletes their account by signing in with Google again', (
      tester,
    ) async {
      await firestore.doc('tasks/t1').set({'ownerId': 'g-1', 'title': 'x'});
      final auth = await pumpApp(
        tester,
        user: googleUser,
        firestore: firestore,
        location: Routes.profile,
      );
      await tester.ensureVisible(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Your password'), findsNothing);
      expect(
        find.text("You'll be asked to sign in with Google again to confirm."),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(auth.googleReauthentications, 1);
      expect(auth.accountDeleted, isTrue);
      expect((await firestore.doc('tasks/t1').get()).exists, isFalse);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets("keeps their account if they don't confirm", (tester) async {
      final auth = await pumpApp(
        tester,
        user: googleUser,
        firestore: firestore,
        location: Routes.profile,
      );
      await tester.ensureVisible(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      auth.failNextWith = const AuthFailure(
        'Sign in with Google again to confirm.',
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sign in with Google again to confirm.'),
        findsOneWidget,
      );
      expect(auth.accountDeleted, isFalse);
    });
  });
}
