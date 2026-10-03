import 'package:flutter/material.dart';

import '../../../../core/forms/validators.dart';

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.helperText,
    this.isNewPassword = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;

  /// Sign-up: tells password managers to suggest a new strong password, and
  /// enforces the length rule. Login only checks the field isn't empty, so
  /// accounts with older, shorter passwords can still sign in.
  final bool isNewPassword;

  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      autofillHints: [
        widget.isNewPassword
            ? AutofillHints.newPassword
            : AutofillHints.password,
      ],
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      validator: widget.isNewPassword
          ? Validators.password
          : (value) => (value ?? '').isEmpty ? 'Enter your password.' : null,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        suffixIcon: IconButton(
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}
