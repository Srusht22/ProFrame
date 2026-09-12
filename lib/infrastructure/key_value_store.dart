import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere to keep strings between runs.
///
/// An interface, so the repository can be tested without a platform channel
/// and so the backing store can change — to a file, a database — without the
/// repository or anything above it noticing.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Every key currently held. Used to enumerate saved projects.
  Future<Set<String>> keys();
}

/// The real store: the device's own preferences file.
///
/// `shared_preferences` is used because it is the one storage plugin that
/// works on all three agreed platforms — Android, iOS and web — with no server
/// and no account, which is what keeps the app usable offline
/// (spec section 10).
class DevicePreferencesStore implements KeyValueStore {
  final SharedPreferences _preferences;

  const DevicePreferencesStore(this._preferences);

  static Future<DevicePreferencesStore> open() async =>
      DevicePreferencesStore(await SharedPreferences.getInstance());

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }

  @override
  Future<Set<String>> keys() async => _preferences.getKeys();
}

/// An in-memory store, for tests.
class InMemoryStore implements KeyValueStore {
  final Map<String, String> values;

  InMemoryStore([Map<String, String>? initial])
      : values = {...?initial};

  /// Makes the next write throw, to test recovery from an interrupted save.
  bool failNextWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const _StoreFailure();
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<Set<String>> keys() async => values.keys.toSet();
}

class _StoreFailure implements Exception {
  const _StoreFailure();

  @override
  String toString() => 'The store refused the write.';
}
