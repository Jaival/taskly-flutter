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
  'operation-not-allowed' =>
    "That way of signing in isn't enabled for this app yet.",
  'popup-blocked' =>
    'Your browser blocked the sign-in window. Allow pop-ups for this site '
        'and try again.',
  'account-exists-with-different-credential' =>
    'An account already exists for that email. Log in with your password '
        'instead.',
  'user-mismatch' =>
    "That's a different account. Sign in with the one you're using here.",
  'requires-recent-login' => 'Please log in again to do that.',
  _ => 'Something went wrong. Please try again.',
});

/// The codes for "the user closed Google's sign-in window". Not a failure
/// worth a message.
const authCancelledCodes = {
  'popup-closed-by-user',
  'cancelled-popup-request',
  'web-context-cancelled',
  'web-context-canceled',
};
