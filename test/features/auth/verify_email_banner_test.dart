import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/auth/domain/app_user.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/pump_app.dart';

void main() {
  const unverified = AppUser(uid: 'u1', email: 'new@example.com');

  testWidgets('verified users see no banner', (tester) async {
    await pumpApp(tester, user: testUser);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('unverified users can resend the email', (tester) async {
    final auth = await pumpApp(tester, user: unverified);
    expect(find.textContaining('Verify new@example.com'), findsOneWidget);

    await tester.tap(find.text('Resend'));
    await tester.pumpAndSettle();

    expect(auth.verificationEmailsSent, ['new@example.com']);
    expect(find.text('Verification email sent.'), findsOneWidget);
  });

  testWidgets('"I\'ve verified" hides the banner once verified', (
    tester,
  ) async {
    final auth = FakeAuthRepository(currentUser: unverified);
    await pumpApp(tester, auth: auth);

    await tester.tap(find.text("I've verified"));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not verified yet'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsOneWidget);

    auth.verifiedOnReload = true;
    await tester.tap(find.text("I've verified"));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialBanner), findsNothing);
  });

  group('on a page with its own app bar', () {
    const statusBar = 40.0;

    Future<void> pumpNestedPage(WidgetTester tester, AppUser user) async {
      tester.view.padding = const FakeViewPadding(top: statusBar);
      await pumpApp(tester, user: user, location: Routes.project('p1'));
    }

    testWidgets('the banner clears the status bar, once', (tester) async {
      await pumpNestedPage(tester, unverified);

      final banner = tester.getRect(find.byType(MaterialBanner));
      final appBar = tester.getRect(find.byType(AppBar));
      expect(banner.top, statusBar);
      // Directly below the banner, with no second status-bar gap.
      expect(appBar.top, banner.bottom);
      expect(appBar.height, kToolbarHeight);
    });

    testWidgets('without the banner, the app bar clears it', (tester) async {
      await pumpNestedPage(tester, testUser);

      final appBar = tester.getRect(find.byType(AppBar));
      expect(appBar.top, 0);
      expect(appBar.height, statusBar + kToolbarHeight);
    });
  });
}
