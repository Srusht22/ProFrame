import 'package:shared_preferences/shared_preferences.dart';

/// Thin key/value persistence seam. Every repository in `data/repositories`
/// is written against this interface (not `SharedPreferences` directly) so
/// swapping local storage for a real backend later means writing one new
/// [IKeyValueStore] (or, more likely, replacing the repository's internals
/// with HTTP calls) — never touching UI or domain code.
abstract class IKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SharedPreferencesKeyValueStore implements IKeyValueStore {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async => _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _instance).getString(key);

  @override
  Future<void> write(String key, String value) async {
    await (await _instance).setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await (await _instance).remove(key);
  }
}
