import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';
import 'app_spacing.dart';
import 'device_colors.dart';
import 'label_colors.dart';
import 'priority_colors.dart';

typedef TextThemeBuilder = TextTheme Function(TextTheme base);

/// Builds the app's themes, in the style of shadcn/ui: grey surfaces told
/// apart by thin borders rather than shadows, and the palette's accent kept
/// for actions and selections.
class AppTheme {
  const AppTheme({this.textThemeBuilder = GoogleFonts.interTextTheme});

  /// Applies the app font. Tests replace this to avoid fetching fonts over the
  /// network.
  final TextThemeBuilder textThemeBuilder;

  /// The themes for [palette]. [deviceColors] are for [AppPalette.device].
  ThemeData light(AppPalette palette, {DeviceColors? deviceColors}) =>
      build(palette.tokens(Brightness.light, deviceColors: deviceColors));
  ThemeData dark(AppPalette palette, {DeviceColors? deviceColors}) =>
      build(palette.tokens(Brightness.dark, deviceColors: deviceColors));

  ThemeData build(PaletteTokens t) {
    final colorScheme = ColorScheme(
      brightness: t.brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primarySoft,
      onPrimaryContainer: t.foreground,
      // Navigation indicators and selected segments use the secondary
      // colours: a wash of the accent, like a selected row.
      secondary: t.primary,
      onSecondary: t.onPrimary,
      secondaryContainer: t.primarySoft,
      onSecondaryContainer: t.foreground,
      // In-progress tasks.
      tertiary: t.medium,
      onTertiary: t.background,
      tertiaryContainer: Color.alphaBlend(
        t.medium.withValues(alpha: 0.14),
        t.background,
      ),
      onTertiaryContainer: t.foreground,
      error: t.destructive,
      onError: t.onDestructive,
      errorContainer: Color.alphaBlend(
        t.destructive.withValues(alpha: 0.12),
        t.background,
      ),
      onErrorContainer: t.foreground,
      surface: t.background,
      onSurface: t.foreground,
      onSurfaceVariant: t.mutedForeground,
      surfaceContainerLowest: t.isDark ? t.background : t.card,
      surfaceContainerLow: t.sidebar,
      surfaceContainer: t.sidebar,
      surfaceContainerHigh: t.muted,
      surfaceContainerHighest: t.muted,
      outline: t.outline,
      outlineVariant: t.border,
      inverseSurface: t.foreground,
      onInverseSurface: t.background,
      inversePrimary: t.primarySoft,
      shadow: Colors.black,
      scrim: Colors.black,
      // No tinting of raised surfaces: they're told apart by borders.
      surfaceTint: Colors.transparent,
    );
    final base = ThemeData(colorScheme: colorScheme);
    final border = BorderSide(color: t.border);
    RoundedRectangleBorder rounded(BorderRadius radius, [BorderSide? side]) =>
        RoundedRectangleBorder(
          borderRadius: radius,
          side: side ?? BorderSide.none,
        );
    final controlShape = WidgetStatePropertyAll<OutlinedBorder>(
      rounded(AppRadius.smAll),
    );

    return base.copyWith(
      textTheme: textThemeBuilder(base.textTheme),
      extensions: [
        PriorityColors.fromTokens(t),
        t.isDark ? LabelColors.dark : LabelColors.light,
      ],
      dividerTheme: DividerThemeData(color: t.border, space: 1),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: t.background,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: t.card,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: rounded(AppRadius.lgAll, border),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.card,
        shape: rounded(AppRadius.lgAll, border),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.card,
        modalBackgroundColor: t.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.card),
          shape: WidgetStatePropertyAll(rounded(AppRadius.smAll, border)),
          elevation: const WidgetStatePropertyAll(4),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.card,
        shape: rounded(AppRadius.smAll, border),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.card),
          shape: WidgetStatePropertyAll(rounded(AppRadius.smAll, border)),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: t.card,
        shape: rounded(AppRadius.lgAll, border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(borderRadius: AppRadius.smAll),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: t.input),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smAll,
          borderSide: BorderSide(color: t.ring, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(shape: controlShape),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(shape: controlShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: controlShape,
          side: WidgetStatePropertyAll(BorderSide(color: t.input)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: controlShape),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: controlShape,
          side: WidgetStatePropertyAll(BorderSide(color: t.input)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: rounded(AppRadius.smAll, BorderSide(color: t.input)),
      ),
      checkboxTheme: const CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primary,
        foregroundColor: t.onPrimary,
        shape: rounded(AppRadius.lgAll),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.background,
        indicatorColor: t.primarySoft,
        elevation: 0,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: t.sidebar,
        indicatorColor: t.primarySoft,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: t.sidebar,
        indicatorColor: t.muted,
        indicatorShape: rounded(AppRadius.smAll),
        elevation: 0,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: t.destructive,
        textColor: t.onDestructive,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

final appThemeProvider = Provider<AppTheme>((ref) => const AppTheme());
