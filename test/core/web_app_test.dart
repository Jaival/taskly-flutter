import 'package:flutter_test/flutter_test.dart';
import 'package:taskly/app/router.dart';
import 'package:taskly/core/data/web_app.dart';
import 'package:taskly/features/home/presentation/home_page.dart';

import '../helpers/pump_app.dart';

const _updateReady = 'A new version of Taskly is ready.';

/// The browser, as far as the app can tell.
class _Browser extends WebApp {
  int reloads = 0;
  int installs = 0;

  void offerUpdate() => updateReady = true;

  void offerInstall() => canInstall = true;

  @override
  void applyUpdate() => reloads++;

  @override
  Future<void> install() async {
    installs++;
    // The offer can be used once.
    canInstall = false;
  }
}

Future<void> _openAccountMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
}

void main() {
  late _Browser browser;

  setUp(() => browser = _Browser());

  Future<void> pumpHome(WidgetTester tester) =>
      pumpApp(tester, user: testUser, webApp: browser, location: Routes.home);

  test('outside a browser there is nothing to update or install', () {
    final app = WebApp();
    addTearDown(app.dispose);

    expect(app.updateReady, isFalse);
    expect(app.canInstall, isFalse);
    // And asking anyway does no harm.
    app.applyUpdate();
    expect(app.install(), completes);
  });

  test('listeners hear about a change once', () {
    var changes = 0;
    browser
      ..addListener(() => changes++)
      ..offerUpdate()
      ..offerUpdate()
      ..offerInstall();
    addTearDown(browser.dispose);

    expect(changes, 2);
  });

  group('a new version', () {
    testWidgets('nothing is said until one is waiting', (tester) async {
      await pumpHome(tester);

      expect(find.text(_updateReady), findsNothing);
      expect(find.text('Reload'), findsNothing);
    });

    testWidgets('is offered above the page, which stays as it is', (
      tester,
    ) async {
      await pumpHome(tester);
      final home = tester.state(find.byType(HomePage, skipOffstage: false));

      browser.offerUpdate();
      await tester.pumpAndSettle();

      expect(find.text(_updateReady), findsOneWidget);
      expect(tester.state(find.byType(HomePage, skipOffstage: false)), home);
      // It waits to be asked: there may be something half-written below.
      expect(browser.reloads, 0);
    });

    testWidgets('Reload switches to it', (tester) async {
      await pumpHome(tester);
      browser.offerUpdate();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reload'));
      await tester.pump();

      expect(browser.reloads, 1);
    });

    testWidgets('is offered on the other pages too', (tester) async {
      await pumpHome(tester);
      browser.offerUpdate();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks').last);
      await tester.pumpAndSettle();

      expect(find.text(_updateReady), findsOneWidget);
    });
  });

  group('installing the app', () {
    testWidgets('is not in the account menu unless the browser offers it', (
      tester,
    ) async {
      await pumpHome(tester);

      await _openAccountMenu(tester);

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Install app'), findsNothing);
    });

    testWidgets('is in the account menu while it does', (tester) async {
      await pumpHome(tester);
      browser.offerInstall();

      await _openAccountMenu(tester);
      await tester.tap(find.text('Install app'));
      await tester.pumpAndSettle();

      expect(browser.installs, 1);

      await _openAccountMenu(tester);
      expect(find.text('Install app'), findsNothing);
    });
  });
}
