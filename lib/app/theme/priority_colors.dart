import 'package:flutter/material.dart';

import '../../core/domain/priority.dart';
import 'app_palette.dart';

/// Colours for task and project priorities, from the current palette.
///
/// A priority is drawn as a dot of its colour on a faint tint of it, with
/// the usual text colour, so the text is as easy to read in every palette.
///
/// Read with `Theme.of(context).extension<PriorityColors>()!`.
@immutable
class PriorityColors extends ThemeExtension<PriorityColors> {
  const PriorityColors({
    required this.immediate,
    required this.high,
    required this.medium,
    required this.low,
  });

  /// Low priority is grey: only the others call for attention.
  PriorityColors.fromTokens(PaletteTokens tokens)
    : this(
        immediate: tokens.urgent,
        high: tokens.high,
        medium: tokens.medium,
        low: tokens.mutedForeground,
      );

  final Color immediate;
  final Color high;
  final Color medium;
  final Color low;

  /// The colour for [priority].
  Color of(Priority priority) => switch (priority) {
    Priority.immediate => immediate,
    Priority.high => high,
    Priority.medium => medium,
    Priority.low => low,
  };

  /// The background for a chip of [priority], over [surface].
  Color tint(Priority priority, Color surface) =>
      Color.alphaBlend(of(priority).withValues(alpha: 0.14), surface);

  @override
  PriorityColors copyWith({
    Color? immediate,
    Color? high,
    Color? medium,
    Color? low,
  }) {
    return PriorityColors(
      immediate: immediate ?? this.immediate,
      high: high ?? this.high,
      medium: medium ?? this.medium,
      low: low ?? this.low,
    );
  }

  @override
  PriorityColors lerp(PriorityColors? other, double t) {
    if (other == null) return this;
    return PriorityColors(
      immediate: Color.lerp(immediate, other.immediate, t)!,
      high: Color.lerp(high, other.high, t)!,
      medium: Color.lerp(medium, other.medium, t)!,
      low: Color.lerp(low, other.low, t)!,
    );
  }
}
