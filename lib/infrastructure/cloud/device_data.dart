import 'package:shared_preferences/shared_preferences.dart';

/// What the device holds, once there are accounts.
///
/// The application's stores keep their records on the device under
/// `proframe.` keys. Signed in, those keys are **a cache of what the backend
/// gave this account**, and nothing more: [markerKey] names whose cache it
/// is, signing out clears it, and the next account starts from what the
/// backend gives it. Nothing in the cache is believed by the backend — a
/// worker editing it in the browser changes what their own screen shows,
/// and nothing else.
///
/// **What was on the device before anybody signed in is never deleted.**
/// It is not this account's cache, and it is not uploaded unasked: the
/// owner chooses to bring it into their factory, or it is moved aside under
/// [archivePrefix], exactly as it was, where an owner can bring it in later.
class DeviceData {
  /// Whose cache the device's records are: the signed-in user's id.
  static const markerKey = 'proframe.cloud.cache-of.v1';

  /// Where records from before sign-in are kept when they are moved aside:
  /// `proframe.device-archive.v1.<when>.<the key they had>`.
  static const archivePrefix = 'proframe.device-archive.v1.';

  /// Where an owner's own version of a record is kept when the backend's
  /// had moved on meanwhile — so a conflict never loses either.
  static const keptLocalPrefix = 'proframe.cloud.kept-local.v1.';

  /// The device's own settings, which belong to whoever holds it and are
  /// never cleared, archived or sent anywhere.
  static const deviceKeys = {
    'proframe.language',
    'proframe.appearance',
    'proframe.everything-shown',
  };

  /// Whether [key] is one of the application's records.
  static bool isRecord(String key) =>
      key.startsWith('proframe.') &&
      !deviceKeys.contains(key) &&
      !key.startsWith('proframe.cloud.') &&
      !key.startsWith(archivePrefix);

  static Iterable<String> _records(SharedPreferences prefs) =>
      prefs.getKeys().where(isRecord);

  /// Whose cache the records are, or null.
  static Future<String?> cacheOf() async =>
      (await SharedPreferences.getInstance()).getString(markerKey);

  /// Whether the device holds records that are nobody's cache — made before
  /// anybody signed in.
  static Future<bool> hasUnclaimed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(markerKey) == null && _records(prefs).isNotEmpty;
  }

  /// The records become [userId]'s: the owner bringing the device's records
  /// into their factory.
  static Future<void> claimFor(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(markerKey, userId);
  }

  /// The device's records, made before anybody signed in, moved aside
  /// exactly as they are. Returns how many.
  static Future<int> archive({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = (now ?? DateTime.now()).toUtc().toIso8601String();
    final keys = _records(prefs).toList();
    for (final key in keys) {
      final ok = await _put(prefs, '$archivePrefix$stamp.$key', prefs.get(key));
      // Removed only where the copy is kept.
      if (ok) await prefs.remove(key);
    }
    return keys.length;
  }

  /// When each set of records was moved aside, newest first.
  static Future<List<String>> archives() async {
    final prefs = await SharedPreferences.getInstance();
    final stamps = <String>{
      for (final key in prefs.getKeys())
        if (key.startsWith(archivePrefix))
          key.substring(archivePrefix.length).split('.proframe.').first,
    };
    return stamps.toList()..sort((a, b) => b.compareTo(a));
  }

  /// The records moved aside at [stamp] back where they were, for
  /// [userId] — only into a device holding no records of anybody's.
  /// The archive is kept until they are.
  static Future<bool> bringBack(String stamp, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (_records(prefs).isNotEmpty) return false;
    final prefix = '$archivePrefix$stamp.';
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _put(prefs, key.substring(prefix.length), prefs.get(key));
    }
    for (final key in keys) {
      await prefs.remove(key);
    }
    await prefs.setString(markerKey, userId);
    return true;
  }

  /// The cache cleared: every record and the marker, and nothing else.
  /// Only a cache is cleared — records nobody has claimed are archived,
  /// never cleared.
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(markerKey) == null) return;
    for (final key in _records(prefs).toList()) {
      await prefs.remove(key);
    }
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('proframe.cloud.') &&
          key != markerKey &&
          !key.startsWith('proframe.cloud.session.') &&
          !key.startsWith(keptLocalPrefix)) {
        await prefs.remove(key);
      }
    }
    await prefs.remove(markerKey);
  }

  static Future<bool> _put(
    SharedPreferences prefs,
    String key,
    Object? value,
  ) => switch (value) {
    final String s => prefs.setString(key, s),
    final bool b => prefs.setBool(key, b),
    final int i => prefs.setInt(key, i),
    final double d => prefs.setDouble(key, d),
    final List<Object?> l => prefs.setStringList(key, [
      for (final e in l) '$e',
    ]),
    _ => Future.value(false),
  };
}
