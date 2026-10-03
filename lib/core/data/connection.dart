import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How a repository waits for one of its writes. See
/// [Connection.sentOrQueued].
typedef AwaitWrite = Future<void> Function(Future<void> write);

/// The default: wait until the server has it.
Future<void> untilSent(Future<void> write) => write;

/// Whether the device has a network connection. Listen to it to follow
/// changes.
///
/// Starts out online, and stays that way if the platform can't say: showing
/// "offline" to someone who isn't would be worse than the reverse.
class Connection extends ValueNotifier<bool> {
  /// [online] reports the current state, then each change.
  Connection(Stream<bool> online) : super(true) {
    _subscription = online.listen(
      (online) => value = online,
      onError: (Object _) {},
    );
  }

  late final StreamSubscription<bool> _subscription;

  bool get isOnline => value;

  /// Waits for [write] to reach the server, but only while there's a
  /// connection.
  ///
  /// Firestore saves a write on the device first and shows it straight
  /// away; the future it returns only completes once the server has it.
  /// Offline that could be hours, and a form waiting on it would spin the
  /// whole time. So without a connection (or when it drops while waiting)
  /// this returns at once: the write is queued and sent when the device is
  /// back online.
  ///
  /// The cost: if the server then refuses a queued write, nobody is waiting
  /// to hear it. Firestore undoes the change on the device.
  Future<void> sentOrQueued(Future<void> write) {
    if (!isOnline) {
      write.ignore();
      return Future.value();
    }
    final wentOffline = Completer<void>();
    void check() {
      if (!isOnline && !wentOffline.isCompleted) wentOffline.complete();
    }

    addListener(check);
    // Whichever comes first; the other's result (or error) is dropped.
    return Future.any([write, wentOffline.future])
        .whenComplete(() => removeListener(check));
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Whether the device has a network: the state now, then each change. A
/// network isn't necessarily the internet (a Wi-Fi login page, say), but
/// it's what the platforms can tell us without sending anything.
///
/// Tests override this; the plugin behind it needs a real device.
final connectivityProvider = Provider<Stream<bool>>(
  (ref) => _deviceConnectivity(),
);

Stream<bool> _deviceConnectivity() async* {
  bool hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  final connectivity = Connectivity();
  try {
    yield hasNetwork(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(hasNetwork);
  } on Exception {
    // A platform that can't tell us. Assume there's a connection.
  }
}

final connectionProvider = Provider<Connection>((ref) {
  final connection = Connection(ref.watch(connectivityProvider));
  ref.onDispose(connection.dispose);
  return connection;
});
