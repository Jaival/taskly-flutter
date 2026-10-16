import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The accent of the device's own theme, in light and dark, with the colour
/// for text on it: on Android 12 and later, the colours it takes from the
/// wallpaper (Material You); on Windows, macOS and Linux, the accent colour.
@immutable
class DeviceColors {
  const DeviceColors({
    required this.light,
    required this.onLight,
    required this.dark,
    required this.onDark,
  });

  /// The primary colours of the device's light and dark schemes.
  DeviceColors.fromSchemes(ColorScheme light, ColorScheme dark)
    : this(
        light: light.primary,
        onLight: light.onPrimary,
        dark: dark.primary,
        onDark: dark.onPrimary,
      );

  /// Schemes made from one accent colour, as the system would.
  factory DeviceColors.fromAccent(Color accent) => DeviceColors.fromSchemes(
    ColorScheme.fromSeed(seedColor: accent),
    ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark),
  );

  final Color light, onLight, dark, onDark;

  @override
  bool operator ==(Object other) =>
      other is DeviceColors &&
      other.light == light &&
      other.onLight == onLight &&
      other.dark == dark &&
      other.onDark == onDark;

  @override
  int get hashCode => Object.hash(light, onLight, dark, onDark);
}

/// Asks the platform for its colours. Null where it has none: on the web,
/// on iOS, and on Android before 12.
Future<DeviceColors?> loadDeviceColors() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette != null) {
      // The tones Material You uses for the primary colour and the text on
      // it: 40 and 100 in light, 80 and 20 in dark.
      Color tone(int t) => Color(palette.primary.get(t));
      return DeviceColors(
        light: tone(40),
        onLight: tone(100),
        dark: tone(80),
        onDark: tone(20),
      );
    }
  } on PlatformException {
    // Try the accent colour instead.
  }
  try {
    final accent = await DynamicColorPlugin.getAccentColor();
    if (accent != null) return DeviceColors.fromAccent(accent);
  } on PlatformException {
    // None to be had.
  }
  return null;
}

/// The device's colours, read once when the app starts. Changing the
/// wallpaper restarts an Android app, which reads them again.
final deviceColorsProvider = FutureProvider<DeviceColors?>(
  (ref) => loadDeviceColors(),
);
