import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_spacing.dart';
import 'label_colors.dart';
import 'priority_colors.dart';

/// The Taskly brand purple, carried over from v1.
const brandSeedColor = Color(0xFF54458D);

typedef TextThemeBuilder = TextTheme Function(TextTheme base);

/// Builds the light and dark Material 3 themes.
class AppTheme {
  const AppTheme({this.textThemeBuilder = GoogleFonts.montserratTextTheme});

  /// Applies the app font. Tests replace this to avoid fetching fonts over the
  /// network.
  final TextThemeBuilder textThemeBuilder;

  ThemeData get light => _build(Brightness.light);
  ThemeData get dark => _build(Brightness.dark);

  ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandSeedColor,
      brightness: brightness,
    );
    final base = ThemeData(colorScheme: colorScheme);

    return base.copyWith(
      textTheme: textThemeBuilder(base.textTheme),
      extensions: [
        brightness == Brightness.light
            ? PriorityColors.light
            : PriorityColors.dark,
        brightness == Brightness.light ? LabelColors.light : LabelColors.dark,
      ],
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: AppRadius.smAll),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

final appThemeProvider = Provider<AppTheme>((ref) => const AppTheme());
