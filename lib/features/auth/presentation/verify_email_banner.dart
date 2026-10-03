import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/top_banner.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';

/// Reminds signed-in users to verify their email, in a banner above
/// [child]. Invites are addressed to an email, so the security rules only let
/// verified users accept them.
class VerifyEmailBanner extends ConsumerStatefulWidget {
  const VerifyEmailBanner({super.key, required this.child});

  /// The page below the banner.
  final Widget child;

  @override
  ConsumerState<VerifyEmailBanner> createState() => _VerifyEmailBannerState();
}

class _VerifyEmailBannerState extends ConsumerState<VerifyEmailBanner> {
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(AuthRepository auth) action,
    String Function(AuthRepository auth) message,
  ) async {
    final auth = ref.read(authRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(auth);
      messenger.showSnackBar(SnackBar(content: Text(message(auth))));
    } on AuthFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final show = user != null && !user.emailVerified;

    return TopBanner(banner: show ? _banner(user) : null, child: widget.child);
  }

  Widget _banner(AppUser user) {
    return MaterialBanner(
      leading: const Icon(Icons.mark_email_unread_outlined),
      content: Text(
        'Verify ${user.email ?? 'your email'} to join projects '
        'other people share with you. Check your inbox for the link.',
      ),
      actions: [
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  (auth) => auth.sendEmailVerification(),
                  (_) => 'Verification email sent.',
                ),
          child: const Text('Resend'),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () => _run(
                  (auth) => auth.reloadUser(),
                  (auth) => (auth.currentUser?.emailVerified ?? false)
                      ? 'Thanks, your email is verified.'
                      : 'Not verified yet. Click the link in the email first.',
                ),
          child: const Text("I've verified"),
        ),
      ],
    );
  }
}
