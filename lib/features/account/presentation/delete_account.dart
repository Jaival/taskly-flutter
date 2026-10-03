import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/presentation/widgets/password_field.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/domain/project.dart';
import '../data/account_deletion.dart';

/// "Delete account" at the bottom of the Profile page.
class DeleteAccountCard extends StatelessWidget {
  const DeleteAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.delete_forever_outlined, color: colors.error),
        title: Text('Delete account', style: TextStyle(color: colors.error)),
        subtitle: const Text('Your account, projects and tasks, for good.'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => const _DeleteAccountDialog(),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_deleting || !_formKey.currentState!.validate()) return;
    // The page is gone once the account is: signing out redirects to login.
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(accountDeletionProvider)
          .deleteAccount(password: _password.text);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account was deleted.')),
      );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } on FirebaseException {
      if (mounted) {
        setState(
          () => _error =
              "Couldn't delete everything. Check your connection and try "
              'again.',
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final uid = ref.watch(authStateProvider).value?.uid;
    final owned = [
      for (final project
          in ref.watch(projectsProvider).value ?? const <Project>[])
        if (project.ownerId == uid) project,
    ];
    final shared = owned.where((p) => p.memberIds.length > 1).length;

    return AlertDialog(
      title: const Text('Delete your account?'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This deletes your account, your personal tasks and '
              '${switch (owned.length) {
                0 => 'any projects you own',
                1 => 'the 1 project you own',
                final count => 'the $count projects you own',
              }}, with their tasks. '
              "Projects shared with you stay, without you. It can't be "
              'undone.',
            ),
            if (shared > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                shared == 1
                    ? '1 of your projects is shared: the people in it will '
                          'lose it too.'
                    : '$shared of your projects are shared: the people in '
                          'them will lose them too.',
                style: TextStyle(color: colors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PasswordField(
              controller: _password,
              label: 'Your password',
              onSubmitted: _delete,
            ),
            if (_error case final error?) ...[
              const SizedBox(height: AppSpacing.md),
              FormError(error),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButtonTheme(
          data: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
          ),
          child: ProgressButton(
            label: 'Delete account',
            busy: _deleting,
            onPressed: _delete,
          ),
        ),
      ],
    );
  }
}
