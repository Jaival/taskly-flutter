import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the actions menu on the task row titled [title].
Future<void> openTaskActions(WidgetTester tester, String title) async {
  final button = find.byTooltip('Actions for "$title"');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// Picks [action] ("Edit", "Comments", "Delete") from the actions menu on
/// the task row titled [title].
Future<void> tapTaskAction(
  WidgetTester tester,
  String title,
  String action,
) async {
  await openTaskActions(tester, title);
  await tester.tap(find.text(action).last);
  await tester.pumpAndSettle();
}

/// The actions offered on the task row titled [title]. Leaves the menu
/// closed again.
Future<List<String>> taskActions(WidgetTester tester, String title) async {
  await openTaskActions(tester, title);
  final offered = [
    for (final action in ['Edit', 'Comments', 'Delete'])
      if (find.text(action).evaluate().isNotEmpty) action,
  ];
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  return offered;
}
