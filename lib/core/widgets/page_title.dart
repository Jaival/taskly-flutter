import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Sets the browser tab's title to "[title] · Taskly" while [child] is the
/// page on screen. Pass null for plain "Taskly".
///
/// Flutter's own `Title` widget sets the title whenever it builds, which
/// includes pages in tabs you aren't looking at (the shell keeps them alive
/// offstage) and pages covered by another route. This one only sets it for
/// the visible page: tickers are off offstage, and a covered route isn't
/// current. Both are dependencies, so switching back re-applies the title.
///
/// Only on the web; on Android this text would label the app in the recent
/// apps list.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, required this.child});

  final String? title;
  final Widget child;

  static String format(String? title) =>
      title == null ? 'Taskly' : '$title · Taskly';

  /// The title most recently applied, on any platform, for tests.
  @visibleForTesting
  static String? get current => _current;
  static String? _current;

  @override
  Widget build(BuildContext context) {
    final visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (!visible) return child;
    _current = format(title);
    if (kIsWeb) {
      unawaited(
        SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(label: _current),
        ),
      );
    }
    return child;
  }
}
