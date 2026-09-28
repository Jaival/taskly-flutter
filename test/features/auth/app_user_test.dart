import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/features/auth/domain/app_user.dart';

void main() {
  group('AppUser.initials', () {
    test('uses the first two words of the display name', () {
      const user = AppUser(uid: '1', displayName: 'ada byron lovelace');
      expect(user.initials, 'AB');
    });

    test('falls back to the email when there is no display name', () {
      const user = AppUser(uid: '1', displayName: '  ', email: 'jo.doe@x.io');
      expect(user.initials, 'JD');
    });

    test('shows a placeholder when nothing is known', () {
      expect(const AppUser(uid: '1').initials, '?');
    });
  });
}
