import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/auth_failure.dart';
import '../data/user_profile_repository.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The router only shows this page to signed-in users, but for a moment
    // after signing out there's no user while the redirect happens.
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(
        // Opened directly by URL there's nothing to pop, so go home instead.
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.home),
        ),
        title: const Text('Profile'),
      ),
      body: user == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(user: user),
                        const SizedBox(height: AppSpacing.xl),
                        _NameCard(user: user),
                        const SizedBox(height: AppSpacing.md),
                        _AccountCard(user: user),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          child: Text(user.initials, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.displayName ?? '',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          user.email ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _NameCard extends ConsumerStatefulWidget {
  const _NameCard({required this.user});

  final AppUser user;

  @override
  ConsumerState<_NameCard> createState() => _NameCardState();
}

class _NameCardState extends ConsumerState<_NameCard> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Rebuild on typing, so Save is only enabled when there's a change.
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim() != (widget.user.displayName ?? '');

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // The profile is what teammates see; the auth account drives the
      // avatar in the app bar. Keep both in step.
      await ref
          .read(userProfileRepositoryProvider)
          .saveDisplayName(
            uid: widget.user.uid,
            email: widget.user.email ?? '',
            displayName: name,
          );
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      messenger.showSnackBar(const SnackBar(content: Text('Name updated.')));
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on FirebaseException {
      if (mounted) {
        setState(
          () => _error = "Couldn't save. Check your connection and try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your name', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              const Text('Shown to people you share projects with.'),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    Validators.required(value, field: 'Your name') ??
                    Validators.maxLength(value, 100),
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                FormError(error),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ProgressButton(
                  label: 'Save',
                  busy: _saving,
                  onPressed: _changed ? _save : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  Future<void> _sendPasswordReset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(user.email!);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'We sent a link to ${user.email} to set a new password.',
          ),
        ),
      );
    } on AuthFailure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(user.email ?? ''),
            trailing: user.emailVerified
                ? Tooltip(
                    message: 'Verified',
                    child: Icon(Icons.verified, color: colors.primary),
                  )
                : const Text('Not verified'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Change password'),
            subtitle: const Text("We'll email you a link to set a new one."),
            onTap: user.email == null
                ? null
                : () => _sendPasswordReset(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: colors.error),
            title: Text('Sign out', style: TextStyle(color: colors.error)),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
