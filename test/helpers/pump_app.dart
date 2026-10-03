import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/app.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/app/theme/app_theme.dart';
import 'package:taskly/core/data/connection.dart';
import 'package:taskly/core/data/firestore_provider.dart';
import 'package:taskly/core/data/web_app.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/app_user.dart';

import 'fake_auth_repository.dart';

const testUser = AppUser(
  uid: 'uid-1',
  email: 'ada@example.com',
  displayName: 'Ada Lovelace',
  emailVerified: true,
);

TextTheme _defaultFont(TextTheme base) => base;

/// Sizes the test window. Resets automatically at the end of the test.
void setWindowSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pumps the full app at [location] with fake auth and an in-memory
/// Firestore. Pass [auth] or [firestore] to set them up or inspect them,
/// [online] to take the device offline (it's online until told otherwise),
/// and [webApp] to play the browser offering an update or to install the app.
Future<FakeAuthRepository> pumpApp(
  WidgetTester tester, {
  AppUser? user,
  FakeAuthRepository? auth,
  FakeFirebaseFirestore? firestore,
  Stream<bool>? online,
  WebApp? webApp,
  String location = Routes.landing,
  Size size = const Size(400, 800),
}) async {
  setWindowSize(tester, size);
  // A test that pumps the app twice: take the first one down, and let its
  // providers finish disposing (Riverpod schedules that), before the next.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  final fakeAuth = auth ?? FakeAuthRepository(currentUser: user);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(fakeAuth),
      firestoreProvider.overrideWithValue(firestore ?? FakeFirebaseFirestore()),
      // The real one asks the platform, which tests don't have.
      connectivityProvider.overrideWithValue(online ?? const Stream.empty()),
      if (webApp != null) webAppProvider.overrideWithValue(webApp),
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
  return fakeAuth;
}
