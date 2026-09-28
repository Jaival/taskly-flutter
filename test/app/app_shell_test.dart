import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/features/home/presentation/home_page.dart';
import 'package:taskly/features/profile/presentation/profile_page.dart';
import 'package:taskly/features/projects/presentation/projects_page.dart';
import 'package:taskly/features/tasks/presentation/tasks_page.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('phones get a bottom navigation bar', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing);
  });

  testWidgets('tablets get a navigation rail', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(900, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktops get a permanent navigation drawer', (tester) async {
    await pumpApp(tester, user: testUser, size: const Size(1400, 900));
    expect(find.byType(NavigationDrawer), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  for (final size in const [Size(400, 800), Size(900, 800), Size(1400, 900)]) {
    testWidgets('destinations switch pages at ${size.width.toInt()}px', (
      tester,
    ) async {
      await pumpApp(tester, user: testUser, size: size);

      await tester.tap(find.text('Projects').last);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsPage), findsOneWidget);

      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();
      expect(find.byType(TasksPage), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
    });
  }

  testWidgets('account menu opens profile, and back returns', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.projects);
    expect(find.text('AL'), findsOneWidget);

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    expect(find.text('ada@example.com'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('profile opened by URL goes back to home', (tester) async {
    await pumpApp(tester, user: testUser, location: Routes.profile);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
