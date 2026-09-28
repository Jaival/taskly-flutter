import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/app.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/app/theme/app_theme.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';

import 'fake_auth_repository.dart';

const testUser = AppUser(
  uid: 'uid-1',
  email: 'ada@example.com',
  displayName: 'Ada Lovelace',
);

TextTheme _defaultFont(TextTheme base) => base;

/// Sizes the test window. Resets automatically at the end of the test.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps the full app at [location] with a fake auth backend.
Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  AppUser? user,
  String location = Routes.landing,
  Size size = const Size(400, 800),
}) async {
  setWindowSize(tester, size);
  final auth = FakeAuthRepository(currentUser: user);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      // Google Fonts would try to download fonts during tests.
      appThemeProvider.overrideWithValue(
        const AppTheme(textThemeBuilder: _defaultFont),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TasklyApp()),
  );
  container.read(routerProvider).go(location);
  await tester.pumpAndSettle();
  return auth;
}
