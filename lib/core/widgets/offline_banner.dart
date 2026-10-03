import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../data/connection.dart';
import 'top_banner.dart';

/// Says so above [child] while the device is offline. The app keeps
/// working: Firestore shows what it has on the device and queues changes.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  /// The page below the banner.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    return ListenableBuilder(
      listenable: connection,
      builder: (context, child) => TopBanner(
        banner: connection.isOnline ? null : const _OfflineNotice(),
        child: child!,
      ),
      child: child,
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      // Announced when it appears, without taking the focus.
      liveRegion: true,
      container: true,
      child: ColoredBox(
        color: colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  "You're offline. Changes are saved on this device and "
                  "sent when you're back online.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
