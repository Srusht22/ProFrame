import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The workshop owner's PIN, kept on the device — what lets the person at
/// the device change the factory's prices.
///
/// ProFrame has no sign-in, so this is the one thing that says who the
/// owner is: whoever set the PIN, and whoever knows it. The first time the
/// price editor is unlocked the PIN is set; after that it is asked for.
/// Only a salted hash of it is kept, never the PIN.
///
/// **It is a lock on a screen, not security.** Anyone who can clear this
/// device's storage can set a new PIN. It keeps a member of staff from
/// changing the factory's rates by a tap, which is what the workshop asked
/// for; real accounts would replace it and nothing that asks
/// `WorkshopRole` would change.
class OwnerAccessStore {
  static const key = 'proframe.owner-pin.v1';

  /// The shortest PIN that is taken.
  static const shortest = 4;

  /// Whether an owner PIN has been set on this device.
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs) != null;
  }

  /// Why [pin] cannot be an owner PIN, or null where it can.
  static String? problemWith(String pin) {
    if (pin.length < shortest || !RegExp(r'^\d+$').hasMatch(pin)) {
      return 'Use at least $shortest digits.';
    }
    return null;
  }

  /// Sets [pin] as the owner's, where none is set yet. False where one
  /// already is — it is changed only by somebody who knows it — or where
  /// [pin] cannot be one.
  Future<bool> setPin(String pin) async {
    if (problemWith(pin) != null) return false;
    final prefs = await SharedPreferences.getInstance();
    if (_read(prefs) != null) return false;
    final salt = _salt();
    await prefs.setString(
      key,
      jsonEncode({'salt': salt, 'hash': _hash(salt, pin)}),
    );
    return true;
  }

  /// Whether [pin] is the owner's.
  Future<bool> verify(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final kept = _read(prefs);
    if (kept == null) return false;
    return _hash(kept.salt, pin) == kept.hash;
  }

  static ({String salt, String hash})? _read(SharedPreferences prefs) {
    final text = prefs.getString(key);
    if (text == null) return null;
    try {
      final map = jsonDecode(text) as Map<String, Object?>;
      final salt = map['salt'];
      final hash = map['hash'];
      if (salt is String && hash is String) return (salt: salt, hash: hash);
    } on Object {
      // Not readable: as though none were set — but it is not written over
      // until somebody sets one.
    }
    return null;
  }

  static String _salt() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
