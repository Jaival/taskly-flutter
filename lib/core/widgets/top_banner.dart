import 'package:flutter/material.dart';

/// Shows [banner] above [child], or just [child] when it's null.
///
/// The same widgets either way, so a banner coming or going doesn't rebuild
/// the page under it. Banners can be nested: the outer one is on top.
class TopBanner extends StatelessWidget {
  const TopBanner({super.key, required this.banner, required this.child});

  /// Null to show nothing.
  final Widget? banner;

  /// The page below the banner.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final show = banner != null;
    return Column(
      children: [
        // With no app bar above it (nested pages bring their own), the
        // banner is at the top of the screen and must clear the status bar.
        // The page below then shouldn't leave room for it again.
        SafeArea(
          top: show,
          bottom: false,
          child: banner ?? const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: show,
            child: child,
          ),
        ),
      ],
    );
  }
}
