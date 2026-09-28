import 'package:flutter/material.dart';

/// Brand colours for task and project priorities, tuned for light and dark mode.
///
/// Read with `Theme.of(context).extension<PriorityColors>()!`.
@immutable
class PriorityColors extends ThemeExtension<PriorityColors> {
  const PriorityColors({
    required this.immediate,
    required this.high,
    required this.medium,
    required this.low,
    required this.onPriority,
  });

  final Color immediate;
  final Color high;
  final Color medium;
  final Color low;

  /// Foreground colour for text and icons drawn on any priority colour.
  final Color onPriority;

  static const light = PriorityColors(
    immediate: Color(0xFFF05D5E),
    high: Color(0xFFFFBA49),
    medium: Color(0xFFFFE381),
    low: Color(0xFF61E294),
    onPriority: Color(0xFF1C1B1F),
  );

  static const dark = PriorityColors(
    immediate: Color(0xFFE57373),
    high: Color(0xFFE0A845),
    medium: Color(0xFFD9C36E),
    low: Color(0xFF5BC487),
    onPriority: Color(0xFF1C1B1F),
  );

  @override
  PriorityColors copyWith({
    Color? immediate,
    Color? high,
    Color? medium,
    Color? low,
    Color? onPriority,
  }) {
    return PriorityColors(
      immediate: immediate ?? this.immediate,
      high: high ?? this.high,
      medium: medium ?? this.medium,
      low: low ?? this.low,
      onPriority: onPriority ?? this.onPriority,
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
      onPriority: Color.lerp(onPriority, other.onPriority, t)!,
    );
  }
}
