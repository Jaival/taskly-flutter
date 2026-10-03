import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../../profile/data/user_profile_repository.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'forgot_password_dialog.dart';
import 'widgets/auth_layout.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/password_field.dart';
import 'widgets/switch_auth_page_link.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    // Read providers before awaiting: once signed in, the router leaves this
    // page and `ref` can't be used any more.
    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    try {
      final user = await auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      // Offer to save the password.
      TextInput.finishAutofillContext();
      await ensureProfileFor(profiles, user);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Log in to see your projects and tasks.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(controller: _password, onSubmitted: _submit),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () =>
                      showForgotPasswordDialog(context, email: _email.text),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error case final error?) ...[
                FormError(error),
                const SizedBox(height: AppSpacing.md),
              ],
              ProgressButton(
                label: 'Log in',
                busy: _submitting,
                onPressed: _submit,
              ),
              GoogleSignInButton(
                onError: (message) => setState(() => _error = message),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SwitchAuthPageLink(
                prompt: 'New to Taskly?',
                action: 'Create an account',
                path: Routes.signUp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
