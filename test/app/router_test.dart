import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/landing/presentation/landing_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';

import '../helpers/pump_app.dart';

void main() {
  group('authRedirect', () {
    String? redirect(String location, {required bool signedIn}) =>
        authRedirect(signedIn: signedIn, uri: Uri.parse(location));

    test('sends signed-out users to login, remembering the target', () {
      expect(redirect('/projects', signedIn: false), '/login?from=%2Fprojects');
    });

    test('lets signed-out users see public pages', () {
      expect(redirect('/', signedIn: false), isNull);
      expect(redirect('/login', signedIn: false), isNull);
      expect(redirect('/signup', signedIn: false), isNull);
    });

    test('sends signed-in users from public pages to home', () {
      expect(redirect('/', signedIn: true), Routes.home);
      expect(redirect('/login', signedIn: true), Routes.home);
    });

    test('returns signed-in users to where they were going', () {
      expect(redirect('/login?from=%2Ftasks', signedIn: true), '/tasks');
    });

    test('ignores unsafe return paths', () {
      for (final from in ['//evil.com', 'https://evil.com', '/login', '/']) {
        final location = Uri(
          path: '/login',
          queryParameters: {'from': from},
        ).toString();
        expect(redirect(location, signedIn: true), Routes.home, reason: from);
      }
    });

    test('leaves signed-in users on app pages', () {
      expect(redirect('/projects', signedIn: true), isNull);
    });
  });

  group('navigation', () {
    testWidgets('signed-out deep link lands on login', (tester) async {
      await pumpApp(tester, location: Routes.projects);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('signed-in user skips the landing page', (tester) async {
      await pumpApp(tester, user: testUser);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('signing in continues to the original deep link', (
      tester,
    ) async {
      final auth = await pumpApp(tester, location: Routes.projects);
      auth.emit(testUser);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsPage), findsOneWidget);
    });

    testWidgets('signing out from the account menu returns to login', (
      tester,
    ) async {
      await pumpApp(tester, user: testUser);
      await tester.tap(find.byTooltip('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('unknown routes show the not-found page', (tester) async {
      await pumpApp(tester, user: testUser, location: '/nope');
      expect(find.text('Page not found'), findsOneWidget);

      await tester.tap(find.text('Go home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('landing page links to sign up', (tester) async {
      await pumpApp(tester);
      expect(find.byType(LandingPage), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Get started'));
      await tester.pumpAndSettle();
      expect(find.text('Create your account'), findsOneWidget);
    });
  });
}
