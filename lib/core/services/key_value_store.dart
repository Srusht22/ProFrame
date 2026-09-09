import 'package:shared_preferences/shared_preferences.dart';

/// Minimal storage seam. Everything the app persists goes through this, so
/// tests run against an in-memory implementation and a future server-backed
/// store can be dropped in without touching feature code.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPreferencesStore implements KeyValueStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _instance).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await _instance).setString(key, value);

  @override
  Future<void> delete(String key) async => (await _instance).remove(key);
}

class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  InMemoryKeyValueStore([Map<String, String>? seed]) {
    if (seed != null) _values.addAll(seed);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
