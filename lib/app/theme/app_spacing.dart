import 'package:flutter/widgets.dart';

/// Spacing scale. Use these instead of literal padding and gap values.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radius scale, from shadcn's: chips 6, controls 8, lists 10, cards
/// and panels 14.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double lg = 14;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}

/// Window-width breakpoints, following the Material 3 window size classes.
abstract final class Breakpoints {
  /// Below this width: phone layout with a bottom navigation bar.
  static const double medium = 600;

  /// At or above this width: desktop layout with a permanent navigation drawer.
  static const double expanded = 1200;
}
