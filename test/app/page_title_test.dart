import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/core/widgets/page_title.dart';

import '../helpers/pump_app.dart';

void main() {
  Future<void> go(WidgetTester tester, Finder target) async {
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('each page names itself, and switching tabs follows', (
    tester,
  ) async {
    await pumpApp(tester, user: testUser);
    expect(PageTitle.current, 'Home · Taskly');

    await go(tester, find.text('Projects').last);
    expect(PageTitle.current, 'Projects · Taskly');

    // Home is kept alive offstage; it must not take the title back until
    // it's shown again.
    await go(tester, find.text('Home').last);
    expect(PageTitle.current, 'Home · Taskly');
  });

  testWidgets('a project page is named after the project, and Back restores '
      'the list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.doc('projects/p1').set({
      'ownerId': testUser.uid,
      'name': 'Launch',
      'description': '',
      'priority': 'high',
      'status': 'notStarted',
      'memberIds': [testUser.uid],
      'roles': {testUser.uid: 'owner'},
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
    await pumpApp(
      tester,
      user: testUser,
      firestore: firestore,
      location: Routes.projects,
    );

    await go(tester, find.text('Launch'));
    expect(PageTitle.current, 'Launch · Taskly');

    await go(tester, find.byType(BackButton));
    expect(PageTitle.current, 'Projects · Taskly');
  });

  testWidgets('closing a page pushed over the shell restores the title', (
    tester,
  ) async {
    await pumpApp(tester, user: testUser, location: Routes.tasks);
    await go(tester, find.byTooltip('Account'));
    await go(tester, find.text('Profile'));
    expect(PageTitle.current, 'Profile · Taskly');

    await go(tester, find.byType(BackButton));
    expect(PageTitle.current, 'Tasks · Taskly');
  });

  testWidgets('signed-out pages and unknown URLs have titles too', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(PageTitle.current, 'Taskly');

    await go(tester, find.text('Log in'));
    expect(PageTitle.current, 'Log in · Taskly');

    // Signed in: signed out, an unknown URL asks you to log in first.
    await pumpApp(tester, user: testUser, location: '/nowhere');
    expect(PageTitle.current, 'Page not found · Taskly');
  });
}
