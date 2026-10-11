import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/staff.dart';
import '../domain/pricing/pricing_access.dart';
import '../domain/text/words.dart';
import 'owner_access_store.dart';

/// Keeps the workshop's staff and what each may do, on the device.
///
/// Adding a member, renaming one, making one inactive or setting their PIN
/// needs `users.manage`; giving or taking away capabilities needs
/// `permissions.manage`, and only what the one giving holds can be given
/// (`StaffMember.problemGiving`). Every change is asked [Authority] first,
/// here, so no screen — and no screen left out — can do more. Nobody is
/// removed: what a member recorded names them, so a member who leaves is
/// made inactive, and an inactive member cannot sign in and may do nothing.
///
/// A member's PIN is kept as a salted SHA-256, never the PIN, as the
/// owner's is. Like the owner's, it is a lock on the device and not
/// security against somebody who can clear its storage.
class StaffStore {
  static const key = 'proframe.staff.v1';

  /// Every member kept, in the order they were added. A list that cannot be
  /// read is no members at all — and is never written over by reading it.
  Future<List<StaffMember>> all() async =>
      _allNow(await SharedPreferences.getInstance());

  /// Whether the workshop has any active member of staff — after which the
  /// device with nobody signed in may only look (`NobodySignedIn`).
  Future<bool> hasAccounts() async => (await all()).any((m) => m.active);

  /// Why [name] cannot be a new member's name, or null where it can: it is
  /// needed, and no active member is already called it.
  static String? nameProblem(
    String name,
    List<StaffMember> members, {
    String? except,
    Words w = const EnglishWords(),
  }) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return w.staffNameNeeded;
    if (members.any(
      (m) => m.active && m.id != except && m.name.trim().toLowerCase() == n,
    )) {
      return w.staffNameTaken;
    }
    return null;
  }

  /// A new member called [name] with [pin], allowed [capabilities] — kept,
  /// as asked [by]. Needs `users.manage`; capabilities beyond what a new
  /// member starts with (`Capability.viewOnly`) need `permissions.manage`
  /// and may only be what [by] holds.
  Future<StaffMember> add({
    required String name,
    required String pin,
    required Set<Capability> capabilities,
    required Authority by,
    DateTime? now,
  }) async {
    by.require(Capability.usersManage);
    final prefs = await SharedPreferences.getInstance();
    final members = _allNow(prefs);
    final nameIssue = nameProblem(name, members);
    if (nameIssue != null) throw ArgumentError(nameIssue);
    final pinIssue = OwnerAccessStore.problemWith(pin);
    if (pinIssue != null) throw ArgumentError(pinIssue);
    final at = now ?? DateTime.now();
    final salt = _salt();
    final member = StaffMember(
      id: 'staff-${at.microsecondsSinceEpoch}-${members.length}',
      name: name.trim(),
      capabilities: const {},
      pinSalt: salt,
      pinHash: _hash(salt, pin),
      createdAt: at,
    );
    final given = capabilities.difference(Capability.viewOnly).isEmpty
        ? null
        : member.problemGiving(capabilities, by);
    if (given != null) throw AccessDenied(by, Capability.permissionsManage);
    final kept = member.copyWith(capabilities: {...capabilities});
    await _write(prefs, [...members, kept]);
    return kept;
  }

  /// Member [id] allowed exactly [capabilities] — asked [by] whoever holds
  /// `permissions.manage`, giving only what they hold.
  Future<StaffMember> setCapabilities(
    String id,
    Set<Capability> capabilities, {
    required Authority by,
  }) async {
    by.require(Capability.permissionsManage);
    final prefs = await SharedPreferences.getInstance();
    final members = _allNow(prefs);
    final member = members.firstWhere((m) => m.id == id);
    if (member.problemGiving(capabilities, by) != null) {
      throw AccessDenied(by, Capability.permissionsManage);
    }
    final changed = member.copyWith(capabilities: {...capabilities});
    await _write(prefs, [for (final m in members) m.id == id ? changed : m]);
    return changed;
  }

  /// Member [id] made active or inactive — `users.manage`.
  Future<StaffMember> setActive(
    String id, {
    required bool active,
    required Authority by,
  }) async {
    by.require(Capability.usersManage);
    final prefs = await SharedPreferences.getInstance();
    final members = _allNow(prefs);
    final member = members.firstWhere((m) => m.id == id);
    if (active) {
      final issue = nameProblem(member.name, members, except: id);
      if (issue != null) throw ArgumentError(issue);
    }
    final changed = member.copyWith(active: active);
    await _write(prefs, [for (final m in members) m.id == id ? changed : m]);
    return changed;
  }

  /// Member [id]'s PIN set to [pin] — `users.manage`.
  Future<StaffMember> setPin(
    String id,
    String pin, {
    required Authority by,
  }) async {
    by.require(Capability.usersManage);
    final issue = OwnerAccessStore.problemWith(pin);
    if (issue != null) throw ArgumentError(issue);
    final prefs = await SharedPreferences.getInstance();
    final members = _allNow(prefs);
    final salt = _salt();
    final changed = members
        .firstWhere((m) => m.id == id)
        .copyWith(pinSalt: salt, pinHash: _hash(salt, pin));
    await _write(prefs, [for (final m in members) m.id == id ? changed : m]);
    return changed;
  }

  /// Member [id], where [pin] is theirs and they are active; otherwise null.
  Future<StaffMember?> signIn(String id, String pin) async {
    final member = (await all()).where((m) => m.id == id).firstOrNull;
    if (member == null || !member.active) return null;
    return _hash(member.pinSalt, pin) == member.pinHash ? member : null;
  }

  List<StaffMember> _allNow(SharedPreferences prefs) {
    final text = prefs.getString(key);
    if (text == null) return const [];
    try {
      return [
        for (final entry in jsonDecode(text) as List<Object?>)
          ?StaffMember.fromJson(entry),
      ];
    } on Object {
      return const [];
    }
  }

  Future<bool> _write(SharedPreferences prefs, List<StaffMember> members) =>
      prefs.setString(key, jsonEncode([for (final m in members) m.toJson()]));

  static String _salt() {
    final random = Random.secure();
    return base64Url.encode([for (var i = 0; i < 16; i++) random.nextInt(256)]);
  }

  static String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();
}
