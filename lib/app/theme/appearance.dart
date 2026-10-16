import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/preferences.dart';
import 'app_palette.dart';

/// How the app looks: its colour theme, and light or dark.
typedef Appearance = ({AppPalette palette, ThemeMode mode});

/// The appearance chosen in Settings, kept on the device. Taskly Violet,
/// following the system's light or dark, until the saved one has been read.
final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>(
  AppearanceNotifier.new,
);

class AppearanceNotifier extends Notifier<Appearance> {
  static const _paletteKey = 'appearance.palette';
  static const _modeKey = 'appearance.mode';

  /// Whether one has been chosen here, which a slow read mustn't undo.
  bool _changed = false;

  @override
  Appearance build() {
    unawaited(_load());
    return (palette: AppPalette.taskly, mode: ThemeMode.system);
  }

  Future<void> _load() async {
    try {
      final prefs = ref.read(preferencesProvider);
      final (palette, mode) = (
        await prefs.read(_paletteKey),
        await prefs.read(_modeKey),
      );
      if (!ref.mounted || _changed) return;
      state = (
        palette: AppPalette.values.asNameMap()[palette] ?? state.palette,
        mode: ThemeMode.values.asNameMap()[mode] ?? state.mode,
      );
    } on Object {
      // Nothing saved that can be read: the defaults will do.
    }
  }

  void setPalette(AppPalette palette) {
    _changed = true;
    state = (palette: palette, mode: state.mode);
    _save(_paletteKey, palette.name);
  }

  void setMode(ThemeMode mode) {
    _changed = true;
    state = (palette: state.palette, mode: mode);
    _save(_modeKey, mode.name);
  }

  /// If it can't be stored, it still holds until the app closes.
  void _save(String key, String value) {
    try {
      unawaited(
        ref.read(preferencesProvider).write(key, value).catchError((_) {}),
      );
    } on Object {
      // As above.
    }
  }
}
