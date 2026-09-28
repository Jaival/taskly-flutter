import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// A pulsing placeholder box shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.smAll,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the OS "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0.5;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
