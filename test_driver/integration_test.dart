// Runs integration_test/ in a browser, which `flutter test` can't do:
//
//   chromedriver --port=4444 &
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart -d chrome \
//     --dart-define=USE_FIREBASE_EMULATORS=true
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
