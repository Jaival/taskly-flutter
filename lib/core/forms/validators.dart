/// Form field validators. Each returns an error message, or null if valid,
/// which is what `TextFormField.validator` expects.
abstract final class Validators {
  static const minPasswordLength = 8;

  // Deliberately loose: the only real test of an email is sending to it.
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? required(String? value, {String field = 'This field'}) =>
      (value == null || value.trim().isEmpty) ? '$field is required.' : null;

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a password.';
    if (text.length < minPasswordLength) {
      return 'Use at least $minPasswordLength characters.';
    }
    return null;
  }

  static String? maxLength(String? value, int max) =>
      (value?.trim().length ?? 0) > max
      ? 'Keep it under $max characters.'
      : null;
}
