import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/forms/validators.dart';
import '../../../core/widgets/form_error.dart';
import '../../../core/widgets/progress_button.dart';
import '../../profile/data/user_profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import 'widgets/auth_layout.dart';
import 'widgets/google_sign_in_button.dart';
import 'widgets/password_field.dart';
import 'widgets/switch_auth_page_link.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
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

    // Read both repositories before awaiting anything. As soon as the account
    // exists the user is signed in, the router leaves this page, and `ref`
    // can no longer be used.
    // Same for the controllers, which are disposed with the page.
    final auth = ref.read(authRepositoryProvider);
    final profiles = ref.read(userProfileRepositoryProvider);
    final name = _name.text.trim();
    final email = _email.text.trim();

    try {
      final user = await auth.signUp(
        displayName: name,
        email: email,
        password: _password.text,
      );
      TextInput.finishAutofillContext();
      await _createProfile(
        profiles,
        UserProfile(
          uid: user.uid,
          displayName: name,
          email: user.email ?? email,
        ),
      );
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The account already exists at this point, so a failure here mustn't
  /// block sign-up. The profile page creates a missing profile later.
  static Future<void> _createProfile(
    UserProfileRepository profiles,
    UserProfile profile,
  ) async {
    try {
      await profiles.createProfile(profile);
    } on FirebaseException catch (e) {
      debugPrint('Could not create profile for ${profile.uid}: ${e.code}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Plan projects and share them with your team.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Your name'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                validator: (value) =>
                    Validators.required(value, field: 'Your name') ??
                    Validators.maxLength(value, 100),
              ),
              const SizedBox(height: AppSpacing.md),
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
              PasswordField(
                controller: _password,
                isNewPassword: true,
                helperText:
                    'At least ${Validators.minPasswordLength} characters',
                onSubmitted: _submit,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_error case final error?) ...[
                FormError(error),
                const SizedBox(height: AppSpacing.md),
              ],
              ProgressButton(
                label: 'Create account',
                busy: _submitting,
                onPressed: _submit,
              ),
              GoogleSignInButton(
                onError: (message) => setState(() => _error = message),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SwitchAuthPageLink(
                prompt: 'Already have an account?',
                action: 'Log in',
                path: Routes.login,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
