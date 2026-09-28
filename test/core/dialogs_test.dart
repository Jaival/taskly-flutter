import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/core/widgets/dialogs.dart';

import '../helpers/pump_app.dart';

Future<BuildContext> _pumpHost(WidgetTester tester, Size size) async {
  setWindowSize(tester, size);
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return hostContext;
}

void main() {
  group('showAdaptiveSheet', () {
    Widget form(BuildContext context) => const Text('form');

    testWidgets('uses a bottom sheet on phones', (tester) async {
      final context = await _pumpHost(tester, const Size(400, 800));
      showAdaptiveSheet<void>(context, builder: form).ignore();
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('form'), findsOneWidget);
    });

    testWidgets('uses a dialog on wider windows', (tester) async {
      final context = await _pumpHost(tester, const Size(1000, 800));
      showAdaptiveSheet<void>(context, builder: form).ignore();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('form'), findsOneWidget);
    });
  });

  group('showConfirmDialog', () {
    Future<bool?> run(WidgetTester tester, String tapLabel) async {
      final context = await _pumpHost(tester, const Size(800, 600));
      bool? result;
      showConfirmDialog(
        context,
        title: 'Delete project?',
        confirmLabel: 'Delete',
        destructive: true,
      ).then((value) => result = value).ignore();
      await tester.pumpAndSettle();
      await tester.tap(find.text(tapLabel));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('resolves true when confirmed', (tester) async {
      expect(await run(tester, 'Delete'), isTrue);
    });

    testWidgets('resolves false when cancelled', (tester) async {
      expect(await run(tester, 'Cancel'), isFalse);
    });
  });
}
