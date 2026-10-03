import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/domain/auth_failure.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/auth/presentation/sign_up_page.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/landing/presentation/landing_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() {
    auth = FakeAuthRepository()
      ..addAccount(testUser, password: 'correct-horse');
  });

  Future<void> fillIn(
    WidgetTester tester,
    String email,
    String password,
  ) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      password,
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
  }

  testWidgets('empty fields show validation errors', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.login);
    await submit(tester);

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(auth.currentUser, isNull);
  });

  testWidgets('a wrong password shows a readable error', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.login);
    await fillIn(tester, testUser.email!, 'wrong');
    await submit(tester);

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('other failures show their message too', (tester) async {
    auth.failNextWith = const AuthFailure('No connection.');
    await pumpApp(tester, auth: auth, location: Routes.login);
    await fillIn(tester, testUser.email!, 'correct-horse');
    await submit(tester);

    expect(find.text('No connection.'), findsOneWidget);
  });

  testWidgets('logging in opens the app', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.login);
    await fillIn(tester, testUser.email!, 'correct-horse');
    await submit(tester);

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('logging in continues to the page the user wanted', (
    tester,
  ) async {
    await pumpApp(tester, auth: auth, location: Routes.projects);
    await fillIn(tester, testUser.email!, 'correct-horse');
    await submit(tester);

    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('the password can be shown and hidden', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.login);
    EditableText password() => tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Password'),
        matching: find.byType(EditableText),
      ),
    );

    expect(password().obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(password().obscureText, isFalse);
  });

  testWidgets('forgot password sends a reset link', (tester) async {
    await pumpApp(tester, auth: auth, location: Routes.login);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'ada@example.com',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // The dialog starts with the email already typed on the page.
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    expect(auth.passwordResetsSent, ['ada@example.com']);
    expect(find.text('Check your email'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsNothing);
  });

  testWidgets('the sign-up link keeps where the user was going', (
    tester,
  ) async {
    await pumpApp(tester, auth: auth, location: Routes.projects);
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpPage), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your name'),
      'Bo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'bo@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'long-enough',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('Back from login returns to the landing page', (tester) async {
    await pumpApp(tester, auth: auth);
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LandingPage), findsOneWidget);
  });
}
