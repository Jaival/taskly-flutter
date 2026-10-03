import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/auth/presentation/login_page.dart';
import 'package:taskly/features/auth/presentation/sign_up_page.dart';

import '../../helpers/pump_app.dart';

void main() {
  Finder appBarButton(String label) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(label));

  testWidgets('"Log in" opens login, not sign up (v1 mixed them up)', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(appBarButton('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('"Get started" opens sign up', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpPage), findsOneWidget);
  });

  testWidgets('wide screens also get "Sign up" in the app bar', (tester) async {
    await pumpApp(tester, size: const Size(1400, 900));
    await tester.tap(appBarButton('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpPage), findsOneWidget);
  });

  testWidgets('phones keep the app bar to "Log in"', (tester) async {
    await pumpApp(tester);
    expect(appBarButton('Sign up'), findsNothing);
  });

  for (final size in const [Size(360, 640), Size(800, 1000), Size(1400, 900)]) {
    testWidgets('scrolls to the end without overflow at ${size.width}px', (
      tester,
    ) async {
      await pumpApp(tester, size: size);
      await tester.scrollUntilVisible(
        find.text('Create your free account'),
        300,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('screenshots describe themselves to screen readers', (
    tester,
  ) async {
    await pumpApp(tester, size: const Size(1400, 900));
    expect(
      find.bySemanticsLabel(RegExp('^The Taskly home screen')),
      findsOneWidget,
    );
  });
}
