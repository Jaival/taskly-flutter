import 'package:flutter/material.dart';

import 'device_colors.dart';

/// The colours of one palette in one brightness, named as in shadcn/ui:
/// mostly greys, with [primary] for actions and selections.
@immutable
class PaletteTokens {
  const PaletteTokens({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.sidebar,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.input,
    required this.outline,
    required this.primary,
    required this.onPrimary,
    required this.destructive,
    required this.onDestructive,
    required this.success,
    required this.urgent,
    required this.high,
    required this.medium,
  });

  final Brightness brightness;

  /// The page, and the default text on it.
  final Color background;
  final Color foreground;

  /// Cards, dialogs, sheets and menus.
  final Color card;

  /// The navigation rail and drawer.
  final Color sidebar;

  /// Quiet surfaces (hovered and selected rows, segmented controls), and the
  /// secondary text that sits on any surface.
  final Color muted;
  final Color mutedForeground;

  /// Dividers and the edges of cards, and of form fields.
  final Color border;
  final Color input;

  /// Icons and text that should recede, like days outside the month.
  final Color outline;

  /// Buttons, checked boxes, the selected destination, focus.
  final Color primary;
  final Color onPrimary;

  final Color destructive;
  final Color onDestructive;
  final Color success;

  /// Priority colours. Low priority has none of its own: it's grey.
  final Color urgent;
  final Color high;
  final Color medium;

  bool get isDark => brightness == Brightness.dark;

  /// A faint wash of [primary] for selected things.
  Color get primarySoft => Color.alphaBlend(
    primary.withValues(alpha: isDark ? 0.2 : 0.12),
    background,
  );

  /// The focus ring.
  Color get ring =>
      Color.alphaBlend(primary.withValues(alpha: 0.55), background);
}

/// A shadcn base colour: the steps of a Tailwind grey that the tokens use.
class _Grey {
  const _Grey(
    this.s50,
    this.s100,
    this.s200,
    this.s400,
    this.s500,
    this.s800,
    this.s900,
    this.s950,
  );

  final Color s50, s100, s200, s400, s500, s800, s900, s950;
}

const _zinc = _Grey(
  Color(0xFFFAFAFA),
  Color(0xFFF4F4F5),
  Color(0xFFE4E4E7),
  Color(0xFF9F9FA9),
  Color(0xFF71717B),
  Color(0xFF27272A),
  Color(0xFF18181B),
  Color(0xFF09090B),
);

const _neutral = _Grey(
  Color(0xFFFAFAFA),
  Color(0xFFF5F5F5),
  Color(0xFFE5E5E5),
  Color(0xFFA1A1A1),
  Color(0xFF737373),
  Color(0xFF262626),
  Color(0xFF171717),
  Color(0xFF0A0A0A),
);

const _slate = _Grey(
  Color(0xFFF8FAFC),
  Color(0xFFF1F5F9),
  Color(0xFFE2E8F0),
  Color(0xFF90A1B9),
  Color(0xFF62748E),
  Color(0xFF1D293D),
  Color(0xFF0F172B),
  Color(0xFF020618),
);

const _stone = _Grey(
  Color(0xFFFAFAF9),
  Color(0xFFF5F5F4),
  Color(0xFFE7E5E4),
  Color(0xFFA6A09B),
  Color(0xFF79716B),
  Color(0xFF292524),
  Color(0xFF1C1917),
  Color(0xFF0C0A09),
);

/// The colour themes the user can pick from in Settings. Each pairs a grey
/// with one accent, in light and dark.
enum AppPalette {
  taskly(
    'Taskly Violet',
    _zinc,
    lightPrimary: Color(0xFF6148D1),
    darkPrimary: Color(0xFF968DFD),
  ),
  mono(
    'Mono',
    _neutral,
    lightPrimary: Color(0xFF171717),
    darkPrimary: Color(0xFFE5E5E5),
  ),
  // Blue is the accent here, so medium priority is violet instead.
  ocean(
    'Ocean',
    _slate,
    lightPrimary: Color(0xFF155DFC),
    darkPrimary: Color(0xFF51A2FF),
    lightMedium: Color(0xFF8E51FF),
    darkMedium: Color(0xFFA684FF),
  ),
  emerald(
    'Emerald',
    _zinc,
    lightPrimary: Color(0xFF007A55),
    darkPrimary: Color(0xFF00D492),
  ),
  // The light accent is a shade darker than shadcn's, so text on it is
  // readable.
  rose(
    'Rose',
    _stone,
    lightPrimary: Color(0xFFC70036),
    darkPrimary: Color(0xFFFF637E),
  ),
  // Orange is the accent here, so high priority is amber instead. The light
  // accent is a shade darker than shadcn's, so white text on it is readable.
  ember(
    'Ember',
    _stone,
    lightPrimary: Color(0xFFCA3500),
    darkPrimary: Color(0xFFFF8904),
    lightHigh: Color(0xFFFE9A00),
    darkHigh: Color(0xFFFFB900),
  ),
  // The accent of the device's own theme (see [DeviceColors]), with zinc
  // greys. Taskly Violet's accent where the device has none.
  device(
    'Device colours',
    _zinc,
    lightPrimary: Color(0xFF6148D1),
    darkPrimary: Color(0xFF968DFD),
  );

  const AppPalette(
    this.label,
    this._grey, {
    required this.lightPrimary,
    required this.darkPrimary,
    this.lightHigh = const Color(0xFFFF6900),
    this.darkHigh = const Color(0xFFFF8904),
    this.lightMedium = const Color(0xFF2B7FFF),
    this.darkMedium = const Color(0xFF51A2FF),
  });

  /// Its name in Settings.
  final String label;

  final _Grey _grey;

  /// The accent, and the high and medium priority colours, in each
  /// brightness.
  final Color lightPrimary, darkPrimary;
  final Color lightHigh, darkHigh;
  final Color lightMedium, darkMedium;

  /// Its colours in [brightness]. The [device] palette takes its accent from
  /// [deviceColors], when there are some.
  PaletteTokens tokens(Brightness brightness, {DeviceColors? deviceColors}) {
    final g = _grey;
    final fromDevice = this == device ? deviceColors : null;
    final (lightPrimary, onLightPrimary) = fromDevice == null
        ? (this.lightPrimary, g.s50)
        : (fromDevice.light, fromDevice.onLight);
    final (darkPrimary, onDarkPrimary) = fromDevice == null
        ? (this.darkPrimary, g.s950)
        : (fromDevice.dark, fromDevice.onDark);
    // An accent from the device can be any colour. When it's close to a
    // priority's, that priority changes, as in Ocean and Ember.
    final (
      lightHigh,
      darkHigh,
    ) = fromDevice != null && _sameHue(fromDevice.light, this.lightHigh)
        ? (const Color(0xFFFE9A00), const Color(0xFFFFB900))
        : (this.lightHigh, this.darkHigh);
    final (
      lightMedium,
      darkMedium,
    ) = fromDevice != null && _sameHue(fromDevice.light, this.lightMedium)
        ? (const Color(0xFF8E51FF), const Color(0xFFA684FF))
        : (this.lightMedium, this.darkMedium);
    return switch (brightness) {
      Brightness.light => PaletteTokens(
        brightness: brightness,
        background: const Color(0xFFFFFFFF),
        foreground: g.s950,
        card: const Color(0xFFFFFFFF),
        sidebar: g.s50,
        muted: g.s100,
        mutedForeground: g.s500,
        border: g.s200,
        input: g.s200,
        outline: g.s400,
        primary: lightPrimary,
        onPrimary: onLightPrimary,
        destructive: const Color(0xFFE7000B),
        onDestructive: const Color(0xFFFFFFFF),
        success: const Color(0xFF00A63E),
        urgent: const Color(0xFFFB2C36),
        high: lightHigh,
        medium: lightMedium,
      ),
      Brightness.dark => PaletteTokens(
        brightness: brightness,
        background: g.s950,
        foreground: g.s50,
        card: g.s900,
        sidebar: g.s900,
        muted: g.s800,
        mutedForeground: g.s400,
        border: const Color(0x1AFFFFFF),
        input: const Color(0x26FFFFFF),
        outline: g.s500,
        primary: darkPrimary,
        onPrimary: onDarkPrimary,
        destructive: const Color(0xFFFF6467),
        onDestructive: g.s950,
        success: const Color(0xFF00C950),
        urgent: const Color(0xFFFF6467),
        high: darkHigh,
        medium: darkMedium,
      ),
    };
  }
}

/// Whether [a] and [b] are close enough in hue to be confused, as two
/// colourful (not grey) colours.
bool _sameHue(Color a, Color b) {
  final (x, y) = (HSVColor.fromColor(a), HSVColor.fromColor(b));
  if (x.saturation < 0.25 || y.saturation < 0.25) return false;
  final apart = (x.hue - y.hue).abs() % 360;
  return (apart > 180 ? 360 - apart : apart) < 30;
}
