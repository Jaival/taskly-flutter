import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_spacing.dart';
import '../data/web_app.dart';
import 'top_banner.dart';

/// Offers to switch, above [child], once a newer version of the app has been
/// downloaded. Only ever shown in a browser; the app stores update the rest.
///
/// It asks rather than reloading by itself: there may be a half-written
/// task on the screen.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key, required this.child});

  /// The page below the banner.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(webAppProvider);
    return ListenableBuilder(
      listenable: app,
      builder: (context, child) => TopBanner(
        banner: app.updateReady
            ? _UpdateNotice(onReload: app.applyUpdate)
            : null,
        child: child!,
      ),
      child: child,
    );
  }
}

class _UpdateNotice extends StatelessWidget {
  const _UpdateNotice({required this.onReload});

  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Semantics(
      // Announced when it appears, without taking the focus.
      liveRegion: true,
      container: true,
      child: ColoredBox(
        color: colors.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.system_update_alt,
                size: 20,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'A new version of Taskly is ready.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
              ),
              TextButton(onPressed: onReload, child: const Text('Reload')),
            ],
          ),
        ),
      ),
    );
  }
}
