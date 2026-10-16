import 'package:flutter/material.dart';

/// Taskly's logo: a short to-do list, the first row ticked, on a rounded
/// square. Drawn in the theme's accent, so it follows the colour theme
/// picked in Settings.
///
/// The app icons are drawn from the same shapes by `tool/make_icons.py`;
/// keep the two in step.
class TasklyLogo extends StatelessWidget {
  const TasklyLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Beside the name, it would only repeat it.
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(
          background: colors.primary,
          foreground: colors.onPrimary,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.background, required this.foreground});

  final Color background;
  final Color foreground;

  // The shapes on a 100-unit square, as in tool/make_icons.py: each row's
  // box, its line, and how strongly it's drawn.
  static const _rows = [
    (Rect.fromLTWH(22, 25, 15, 15), Rect.fromLTWH(44, 29, 34, 7), 1.0),
    (Rect.fromLTWH(23.5, 44.5, 12, 12), Rect.fromLTWH(44, 47, 28, 7), 0.75),
    (Rect.fromLTWH(23.5, 62.5, 12, 12), Rect.fromLTWH(44, 65, 22, 7), 0.5),
  ];

  /// Moves the rows down a little, to centre them.
  static const _nudge = Offset(0, 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(24),
      ),
      Paint()..color = background,
    );
    canvas.translate(_nudge.dx, _nudge.dy);
    for (final (i, (box, line, opacity)) in _rows.indexed) {
      final color = foreground.withValues(alpha: opacity);
      if (i == 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(4)),
          Paint()..color = color,
        );
        canvas.drawPath(
          Path()
            ..moveTo(25.5, 32.5)
            ..lineTo(28.5, 35.5)
            ..lineTo(34, 29.5),
          Paint()
            ..color = background
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(3)),
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(line, Radius.circular(line.height / 2)),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.background != background || old.foreground != foreground;
}
