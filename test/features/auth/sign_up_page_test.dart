import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/presentation/sign_up_page.dart';
import 'package:taskly/features/home/presentation/home_page.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    auth = FakeAuthRepository()
      ..addAccount(testUser, password: 'correct-horse');
    firestore = FakeFirebaseFirestore();
  });

  Future<void> signUp(
    WidgetTester tester, {
    String name = 'Grace Hopper',
    String email = 'grace@example.com',
    String password = 'long-enough',
  }) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      name,
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
  }

  testWidgets('invalid input is caught before anything is sent', (
    tester,
  ) async {
    await pumpApp(tester, auth: auth, location: Routes.signUp);
    await signUp(tester, name: '  ', email: 'not-an-email', password: 'short');

    expect(find.text('Your name is required.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets(
    'signing up creates the profile, sends a verification email and opens '
    'the app',
    (tester) async {
      await pumpApp(
        tester,
        auth: auth,
        firestore: firestore,
        location: Routes.signUp,
      );
      await signUp(tester);

      expect(find.byType(HomePage), findsOneWidget);
      expect(auth.verificationEmailsSent, ['grace@example.com']);

      final uid = auth.currentUser!.uid;
      final profile = (await firestore.doc('users/$uid').get()).data();
      expect(profile?['displayName'], 'Grace Hopper');
      expect(profile?['email'], 'grace@example.com');
    },
  );

  testWidgets('an email that already has an account shows an error', (
    tester,
  ) async {
    await pumpApp(tester, auth: auth, location: Routes.signUp);
    await signUp(tester, email: testUser.email!);

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.byType(SignUpPage), findsOneWidget);
  });

  testWidgets('the log in link switches to the login page', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.signUp);
    await tester.tap(find.widgetWithText(TextButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
