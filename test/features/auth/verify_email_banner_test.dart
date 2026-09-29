import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
