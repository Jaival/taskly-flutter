import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/profile/data/user_profile_firestore.dart';
import 'package:taskly/features/profile/domain/user_profile.dart';

void main() {
  test('round-trips through Firestore, keyed by uid', () async {
    final db = FakeFirebaseFirestore();
    const profile = UserProfile(
      uid: 'alice',
      displayName: 'Alice',
      email: 'alice@example.com',
    );

    await usersCollection(db).doc(profile.uid).set(profile);
    final saved = (await usersCollection(db).doc('alice').get()).data()!;

    expect(saved.uid, 'alice');
    expect(saved.displayName, 'Alice');
    expect(saved.email, 'alice@example.com');
    expect(saved.photoUrl, isNull);
    expect(saved.createdAt, isNotNull);
  });

  test('copyWith can clear the photo', () {
    const profile = UserProfile(
      uid: 'alice',
      displayName: 'Alice',
      email: 'alice@example.com',
      photoUrl: 'https://example.com/a.png',
    );
    expect(profile.copyWith(photoUrl: () => null).photoUrl, isNull);
    expect(profile.copyWith(displayName: 'Al').photoUrl, isNotNull);
  });
}
