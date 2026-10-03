import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:taskly/features/auth/data/auth_failures.dart';
import 'package:taskly/features/auth/data/auth_repository.dart';
import 'package:taskly/features/auth/domain/auth_failure.dart';

void main() {
  group('authFailureFromCode', () {
    test('wrong password and unknown email read the same', () {
      final messages = {
        for (final code in [
          'invalid-credential',
          'wrong-password',
          'user-not-found',
        ])
          authFailureFromCode(code).message,
      };
      expect(messages, {'Email or password is incorrect.'});
    });

    test('known codes get specific messages', () {
      expect(
        authFailureFromCode('email-already-in-use').message,
        contains('already exists'),
      );
      expect(
        authFailureFromCode('network-request-failed').message,
        contains('connection'),
      );
    });

    test('unknown codes get a generic message', () {
      expect(
        authFailureFromCode('something-new').message,
        'Something went wrong. Please try again.',
      );
    });
  });

  group('AuthRepository', () {
    late MockFirebaseAuth firebaseAuth;
    late AuthRepository repository;

    setUp(() {
      firebaseAuth = MockFirebaseAuth(
        mockUser: MockUser(
          uid: 'ada',
          email: 'ada@example.com',
          displayName: 'Ada',
          isEmailVerified: true,
        ),
      );
      repository = AuthRepository(firebaseAuth);
    });

    test('signIn returns the signed-in user', () async {
      final user = await repository.signIn(
        email: ' ada@example.com ',
        password: 'password1',
      );
      expect(user.uid, 'ada');
      expect(user.emailVerified, isTrue);
      expect(repository.currentUser?.uid, 'ada');
    });

    test('Firebase errors become AuthFailures', () async {
      whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
          .on(firebaseAuth)
          .thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await expectLater(
        () => repository.signIn(email: 'ada@example.com', password: 'nope'),
        throwsA(
          isA<AuthFailure>().having(
            (f) => f.message,
            'message',
            'Email or password is incorrect.',
          ),
        ),
      );
    });

    test('signUp sets the display name', () async {
      final user = await repository.signUp(
        displayName: '  Grace Hopper ',
        email: 'grace@example.com',
        password: 'password1',
      );
      expect(user.displayName, 'Grace Hopper');
      expect(firebaseAuth.currentUser?.displayName, 'Grace Hopper');
    });

    group('changePassword', () {
      // A user of their own for each test: the mock remembers what it was
      // told to throw for a user, even across tests.
      Future<User> signedIn(String uid) async {
        firebaseAuth = MockFirebaseAuth(
          mockUser: MockUser(uid: uid, email: '$uid@example.com'),
        );
        repository = AuthRepository(firebaseAuth);
        await repository.signIn(
          email: '$uid@example.com',
          password: 'password1',
        );
        return firebaseAuth.currentUser!;
      }

      test('checks the current password, then sets the new one', () async {
        await signedIn('grace');
        // The mock accepts any password; the wrong one is tested below.
        await repository.changePassword(
          currentPassword: 'password1',
          newPassword: 'password2',
        );
      });

      test('says so when the current password is wrong', () async {
        final user = await signedIn('hedy');
        whenCalling(Invocation.method(#reauthenticateWithCredential, null))
            .on(user)
            .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

        await expectLater(
          () => repository.changePassword(
            currentPassword: 'nope',
            newPassword: 'password2',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.message,
              'message',
              'Your current password is incorrect.',
            ),
          ),
        );
      });

      test('other Firebase errors become AuthFailures', () async {
        final user = await signedIn('joan');
        whenCalling(Invocation.method(#updatePassword, null))
            .on(user)
            .thenThrow(FirebaseAuthException(code: 'weak-password'));

        await expectLater(
          () => repository.changePassword(
            currentPassword: 'password1',
            newPassword: 'password2',
          ),
          throwsA(
            isA<AuthFailure>().having(
              (f) => f.message,
              'message',
              'Choose a stronger password.',
            ),
          ),
        );
      });
    });

    test('userChanges reports sign-in and sign-out', () async {
      final events = repository.userChanges().map((u) => u?.uid);
      final expectation = expectLater(
        events,
        emitsInOrder([null, 'ada', null]),
      );

      await repository.signIn(email: 'ada@example.com', password: 'password1');
      await repository.signOut();
      await expectation;
    });
  });
}
