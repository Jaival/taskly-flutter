import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/theme/app_palette.dart';
import 'package:taskly/app/theme/app_theme.dart';
import 'package:taskly/app/theme/device_colors.dart';

/// The WCAG contrast ratio of [a] against [b].
double contrast(Color a, Color b) {
  final (x, y) = (a.computeLuminance(), b.computeLuminance());
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

/// Accents a device might have: a few hues, and a grey.
const accents = {
  'red': Color(0xFFE53935),
  'orange': Color(0xFFFF6D00),
  'yellow': Color(0xFFFFD600),
  'green': Color(0xFF2E7D32),
  'blue': Color(0xFF1E88E5),
  'purple': Color(0xFF8E24AA),
  'grey': Color(0xFF9E9E9E),
};

void main() {
  final cases = [
    for (final palette in AppPalette.values)
      (palette.label, palette, null as DeviceColors?),
    for (final MapEntry(key: name, value: accent) in accents.entries)
      (
        'Device colours from $name',
        AppPalette.device,
        DeviceColors.fromAccent(accent),
      ),
  ];
  for (final (label, palette, deviceColors) in cases) {
    for (final brightness in Brightness.values) {
      final t = palette.tokens(brightness, deviceColors: deviceColors);
      final name = '$label, ${brightness.name}';

      test('$name: text is readable on what it sits on', () {
        for (final (text, on, what) in [
          (t.foreground, t.background, 'text on the page'),
          (t.foreground, t.card, 'text on a card'),
          (t.mutedForeground, t.background, 'secondary text on the page'),
          (t.mutedForeground, t.card, 'secondary text on a card'),
          (t.onPrimary, t.primary, 'a button label'),
          (t.foreground, t.primarySoft, 'text on a selected item'),
          (t.onDestructive, t.destructive, 'a destructive button label'),
        ]) {
          expect(contrast(text, on), greaterThanOrEqualTo(4.5), reason: what);
        }
      });

      test('$name: builds a theme of that brightness', () {
        final theme = const AppTheme(textThemeBuilder: _same).build(t);
        expect(theme.brightness, brightness);
        expect(theme.colorScheme.primary, t.primary);
      });
    }
  }

  group('device colours', () {
    test('without any, are Taskly Violet', () {
      for (final brightness in Brightness.values) {
        expect(
          AppPalette.device.tokens(brightness).primary,
          AppPalette.taskly.tokens(brightness).primary,
        );
      }
    });

    test('use the accent and the text colour on it', () {
      const colors = DeviceColors(
        light: Color(0xFF006A60),
        onLight: Color(0xFFFFFFFF),
        dark: Color(0xFF53DBC9),
        onDark: Color(0xFF003731),
      );
      final light = AppPalette.device.tokens(
        Brightness.light,
        deviceColors: colors,
      );
      final dark = AppPalette.device.tokens(
        Brightness.dark,
        deviceColors: colors,
      );
      expect((light.primary, light.onPrimary), (colors.light, colors.onLight));
      expect((dark.primary, dark.onPrimary), (colors.dark, colors.onDark));
      // Other palettes ignore them.
      expect(
        AppPalette.rose.tokens(Brightness.light, deviceColors: colors).primary,
        AppPalette.rose.tokens(Brightness.light).primary,
      );
    });

    test('move a priority whose colour is close to the accent', () {
      final taskly = AppPalette.taskly.tokens(Brightness.light);
      PaletteTokens from(String accent) => AppPalette.device.tokens(
        Brightness.light,
        deviceColors: DeviceColors.fromAccent(accents[accent]!),
      );

      expect(from('blue').medium, isNot(taskly.medium));
      expect(from('blue').high, taskly.high);
      expect(from('orange').high, isNot(taskly.high));
      expect(from('orange').medium, taskly.medium);
      expect(from('green').high, taskly.high);
      expect(from('green').medium, taskly.medium);
    });
  });

  test('every palette has its own accent', () {
    // Not the device's, which is the device's to choose.
    final palettes = AppPalette.values.where((p) => p != AppPalette.device);
    for (final brightness in Brightness.values) {
      final primaries = {
        for (final palette in palettes) palette.tokens(brightness).primary,
      };
      expect(primaries, hasLength(palettes.length));
    }
  });
}

TextTheme _same(TextTheme base) => base;
