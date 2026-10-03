import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'widgets/password_field.dart';

/// Asks for the current password and a new one, and changes it. Someone who
/// has forgotten the current one can have a reset link emailed instead.
Future<void> showChangePasswordDialog(
  BuildContext context, {
  required String email,
}) => showDialog<void>(
  context: context,
  builder: (context) => _ChangePasswordDialog(email: email),
);

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog({required this.email});

  final String email;

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    super.dispose();
  }

  /// Runs [action], then closes the dialog and says [done]. Shows the error
  /// and stays open if it fails.
  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    if (_new.text == _current.text) {
      setState(() => _error = 'Choose a password different from the old one.');
      return;
    }
    await _run(
      () => ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _new.text,
          ),
      'Password changed.',
    );
  }

  Future<void> _sendResetLink() => _run(
    () => ref.read(authRepositoryProvider).sendPasswordReset(widget.email),
    'We sent a link to ${widget.email} to set a new password.',
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(controller: _current, label: 'Current password'),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : _sendResetLink,
                  child: const Text('Forgot it? Email me a reset link'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PasswordField(
                controller: _new,
                label: 'New password',
                helperText:
                    'At least ${Validators.minPasswordLength} characters',
                isNewPassword: true,
                onSubmitted: _change,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: AppSpacing.md),
                FormError(error),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ProgressButton(
          label: 'Change password',
          busy: _busy,
          onPressed: _change,
        ),
      ],
    );
  }
}
