import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/theme/app_palette.dart';
import 'package:taskly/app/theme/app_theme.dart';
import 'package:taskly/core/widgets/taskly_logo.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('is drawn at the size asked for, in any theme', (tester) async {
    for (final palette in AppPalette.values) {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme(textThemeBuilder: (base) => base)
                .build(palette.tokens(brightness)),
            home: const Center(child: TasklyLogo(size: 48)),
          ),
        );
        expect(tester.getSize(find.byType(TasklyLogo)), const Size(48, 48));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('is beside the name on the landing page', (tester) async {
    await pumpApp(tester);
    expect(find.byType(TasklyLogo), findsOneWidget);
    expect(find.text('Taskly'), findsWidgets);
  });
}
