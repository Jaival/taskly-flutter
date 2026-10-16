import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/theme/app_palette.dart';
import 'package:taskly/app/theme/priority_colors.dart';
import 'package:taskly/core/domain/priority.dart';
import 'package:taskly/core/domain/task_status.dart';

void main() {
  group('Priority', () {
    test('parses stored names', () {
      for (final priority in Priority.values) {
        expect(Priority.fromName(priority.name), priority);
      }
    });

    test('falls back to medium for unknown or missing values', () {
      expect(Priority.fromName('urgent'), Priority.medium);
      expect(Priority.fromName(null), Priority.medium);
      expect(Priority.fromName(3), Priority.medium);
    });

    test('is ordered from most to least urgent', () {
      expect(Priority.values, [
        Priority.immediate,
        Priority.high,
        Priority.medium,
        Priority.low,
      ]);
    });

    test('every priority has its own colour, in every palette', () {
      for (final palette in AppPalette.values) {
        for (final brightness in Brightness.values) {
          final colors = PriorityColors.fromTokens(palette.tokens(brightness));
          expect(
            Priority.values.map(colors.of).toSet(),
            hasLength(Priority.values.length),
            reason: '${palette.name}, ${brightness.name}',
          );
        }
      }
    });
  });

  group('TaskStatus', () {
    test('parses stored names', () {
      for (final status in TaskStatus.values) {
        expect(TaskStatus.fromName(status.name), status);
      }
    });

    test('falls back to notStarted for unknown values', () {
      expect(TaskStatus.fromName('done'), TaskStatus.notStarted);
    });
  });
}
