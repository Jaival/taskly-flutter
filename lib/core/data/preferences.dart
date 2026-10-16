import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small settings kept on this device, by key. Not synced: a phone and a
/// laptop can each have their own.
abstract interface class Preferences {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class _DevicePreferences implements Preferences {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// Held in memory only. For tests, which have no platform to store on.
class MemoryPreferences implements Preferences {
  MemoryPreferences([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final preferencesProvider = Provider<Preferences>(
  (ref) => _DevicePreferences(),
);
