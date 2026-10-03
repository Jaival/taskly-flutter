import 'package:flutter/material.dart';

import '../../features/tasks/domain/task_label.dart';

/// The shades of each [LabelColor], tuned for light and dark mode.
///
/// A label is drawn as a dot of its colour on a faint tint of it, with the
/// usual text colour, so the text is as easy to read whatever the colour.
///
/// Read with `Theme.of(context).extension<LabelColors>()!`.
@immutable
class LabelColors extends ThemeExtension<LabelColors> {
  const LabelColors(this._colors);

  /// One for each [LabelColor], in order.
  final List<Color> _colors;

  Color of(LabelColor color) => _colors[color.index];

  /// The background for a label of [color], over [surface].
  Color tint(LabelColor color, Color surface) =>
      Color.alphaBlend(of(color).withValues(alpha: 0.16), surface);

  static const light = LabelColors([
    Color(0xFF757575), // grey
    Color(0xFFD32F2F), // red
    Color(0xFFEF6C00), // orange
    Color(0xFFF9A825), // yellow
    Color(0xFF2E7D32), // green
    Color(0xFF00897B), // teal
    Color(0xFF1E88E5), // blue
    Color(0xFF8E24AA), // purple
    Color(0xFFD81B60), // pink
  ]);

  static const dark = LabelColors([
    Color(0xFFBDBDBD),
    Color(0xFFEF9A9A),
    Color(0xFFFFB74D),
    Color(0xFFFFF176),
    Color(0xFF81C784),
    Color(0xFF4DB6AC),
    Color(0xFF64B5F6),
    Color(0xFFCE93D8),
    Color(0xFFF48FB1),
  ]);

  @override
  LabelColors copyWith({List<Color>? colors}) => LabelColors(colors ?? _colors);

  @override
  LabelColors lerp(LabelColors? other, double t) {
    if (other == null) return this;
    return LabelColors([
      for (final color in LabelColor.values)
        Color.lerp(of(color), other.of(color), t)!,
    ]);
  }
}
