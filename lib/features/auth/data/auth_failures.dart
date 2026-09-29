import '../domain/auth_failure.dart';

/// Turns a `FirebaseAuthException.code` into a message people can act on.
///
/// Wrong password and unknown email deliberately get the same message.
/// Telling them apart would let anyone find out which emails have accounts
/// (Firebase's "email enumeration protection" returns `invalid-credential`
/// for both anyway).
AuthFailure authFailureFromCode(String code) => AuthFailure(switch (code) {
  'invalid-email' => "That email address doesn't look right.",
  'invalid-credential' ||
  'wrong-password' ||
  'user-not-found' ||
  'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect.',
  'user-disabled' => 'This account has been disabled.',
  'email-already-in-use' =>
    'An account already exists for that email. Try logging in instead.',
  'weak-password' => 'Choose a stronger password.',
  'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
  'network-request-failed' =>
    'No connection. Check your internet and try again.',
  'operation-not-allowed' => "Email sign-in isn't enabled for this app yet.",
  'requires-recent-login' => 'Please log in again to do that.',
  _ => 'Something went wrong. Please try again.',
});
