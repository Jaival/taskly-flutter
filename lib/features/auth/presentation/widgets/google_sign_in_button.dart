import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../profile/data/user_profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../data/auth_repository.dart';
import '../../domain/app_user.dart';
import '../../domain/auth_failure.dart';

/// Creates the user's profile if it's missing: the first time they sign in
/// with Google, or if the connection dropped right after they signed up.
/// Failing here mustn't stop them signing in.
Future<void> ensureProfileFor(
  UserProfileRepository profiles,
  AppUser user,
) async {
  try {
    await profiles.ensureProfile(
      UserProfile(
        uid: user.uid,
        displayName: user.displayName ?? '',
        email: user.email ?? '',
      ),
    );
  } on FirebaseException catch (e) {
    debugPrint('Could not check profile for ${user.uid}: ${e.code}');
  }
}

/// "or" and "Continue with Google", under the login and sign-up forms. It
/// signs in, or creates the account the first time.
///
/// Builds nothing where Google sign-in isn't available (see
/// [AuthRepository.supportsGoogleSignIn]).
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, required this.onError});

  /// Called with what went wrong, to show with the form's other errors, and
  /// with null when a new attempt starts.
  final ValueChanged<String?> onError;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    if (_busy) return;
    // Read providers before awaiting: once signed in, the router leaves the
    // page and `ref` can't be used any more.
    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    setState(() => _busy = true);
    widget.onError(null);
    try {
      // Null if they closed Google's window: nothing to report.
      final user = await auth.signInWithGoogle();
      if (user != null) await ensureProfileFor(profiles, user);
    } on AuthFailure catch (failure) {
      if (mounted) widget.onError(failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(authRepositoryProvider).supportsGoogleSignIn) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                'or',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton(
          onPressed: _busy ? null : _signIn,
          child: const Text('Continue with Google'),
        ),
      ],
    );
  }
}
