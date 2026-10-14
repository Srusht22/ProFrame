import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import '../../domain/model/customer.dart';
import '../../domain/model/design.dart';
import '../customer_store.dart';
import '../design_store.dart';
import '../owner_access_store.dart';
import '../staff_store.dart';
import 'backend.dart';
import 'device_data.dart';

/// Keeps an owner's records on the backend, from the stores on the device.
///
/// The stores go on keeping records exactly as they always have. Every
/// write to the device is noticed ([WatchedPreferences]), and what changed
/// is sent to the backend through the owner's own functions, each with the
/// revision it was based on — so an edit made on top of an older version
/// (another device, an approved change) is a conflict there, never an
/// overwrite. Records the backend has that the device does not are brought
/// down by [pull].
///
/// Only the owner's records are sent, and only by the owner's session: the
/// functions refuse anybody else, so a worker's device running this would
/// send nothing that is kept.
///
/// What is sent: each customer and each design as its own record, and every
/// other record (the price list, prices worked out, quotations, sequences,
/// the factory's defaults) as a document. The two indexes are not sent —
/// they are worked out again from the records — and nor are the device's
/// PIN lock and its local staff list, which an account replaces.
class OwnerSync {
  final Backend backend;

  /// Told when records were brought down, so the lists read again.
  final VoidCallback? onPulled;

  OwnerSync(this.backend, {this.onPulled});

  static const syncedKey = 'proframe.cloud.synced.v1';

  static bool _local(String key) =>
      key == CustomerStore.indexKey ||
      key == DesignStore.indexKey ||
      key == DesignStore.legacyKey ||
      key == DesignStore.legacyUnreadKey ||
      key == StaffStore.key ||
      key == OwnerAccessStore.key;

  static bool syncs(String key) => DeviceData.isRecord(key) && !_local(key);

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  Map<String, ({int revision, String hash})> _synced(SharedPreferences prefs) {
    final text = prefs.getString(syncedKey);
    if (text == null) return {};
    try {
      final kept = <String, ({int revision, String hash})>{};
      for (final MapEntry(:key, :value)
          in (jsonDecode(text) as Map<String, Object?>).entries) {
        final pair = value! as List<Object?>;
        kept[key] = (
          revision: (pair[0]! as num).toInt(),
          hash: pair[1]! as String,
        );
      }
      return kept;
    } on Object {
      return {};
    }
  }

  Future<void> _keepSynced(
    SharedPreferences prefs,
    Map<String, ({int revision, String hash})> synced,
  ) => _quietly(
    () => prefs.setString(
      syncedKey,
      jsonEncode({
        for (final MapEntry(:key, :value) in synced.entries)
          key: [value.revision, value.hash],
      }),
    ),
  );

  /// Writes made here are the backend's own records arriving, not edits to
  /// send back.
  bool _applying = false;
  Future<T> _quietly<T>(Future<T> Function() write) async {
    _applying = true;
    try {
      return await write();
    } finally {
      _applying = false;
    }
  }

  // ------------------------------------------------------------- pushing

  Future<void>? _running;
  bool _again = false;

  /// Sends what changed — now, or straight after the send under way.
  Future<void> push() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _pushLoop();
    _running = run;
    return run.whenComplete(() => _running = null);
  }

  Future<void> _pushLoop() async {
    do {
      _again = false;
      await _pushOnce();
    } while (_again);
  }

  /// What the last push could not send, by key: a conflict, or the network.
  final unsent = <String, String>{};

  Future<void> _pushOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(DeviceData.markerKey) == null) return;
    final synced = _synced(prefs);
    final now = <String, String>{
      for (final key in prefs.getKeys().where(syncs))
        if (prefs.get(key) case final String value) key: value,
    };
    final changed = [
      for (final MapEntry(:key, :value) in now.entries)
        if (synced[key]?.hash != _hash(value)) key,
    ];
    final gone = [
      for (final key in synced.keys)
        if (!now.containsKey(key)) key,
    ];
    int order(String key) => key.startsWith(CustomerStore.customerKeyPrefix)
        ? 0
        : key.startsWith(DesignStore.designKeyPrefix)
        ? 1
        : 2;
    changed.sort((a, b) => order(a).compareTo(order(b)));
    gone.sort((a, b) => order(b).compareTo(order(a)));
    unsent.clear();
    for (final key in changed) {
      final value = now[key]!;
      final expected = synced[key]?.revision;
      try {
        final revision = await _put(key, value, expected);
        synced[key] = (revision: revision, hash: _hash(value));
      } on BackendError catch (e) {
        unsent[key] = e.code;
        if (e.code == 'network' || e.code == 'not_signed_in') break;
      }
    }
    for (final key in gone) {
      try {
        await _delete(key);
        synced.remove(key);
      } on BackendError catch (e) {
        unsent[key] = e.code;
      }
    }
    await _keepSynced(prefs, synced);
  }

  Future<int> _put(String key, String value, int? expected) {
    if (key.startsWith(CustomerStore.customerKeyPrefix)) {
      return backend.putCustomer(
        key.substring(CustomerStore.customerKeyPrefix.length),
        value,
        expected,
      );
    }
    if (key.startsWith(DesignStore.designKeyPrefix)) {
      return backend.putDesign(
        key.substring(DesignStore.designKeyPrefix.length),
        value,
        expected,
      );
    }
    return backend.putDocument(key, value, expected);
  }

  Future<void> _delete(String key) {
    if (key.startsWith(CustomerStore.customerKeyPrefix)) {
      return backend.deleteCustomer(
        key.substring(CustomerStore.customerKeyPrefix.length),
      );
    }
    if (key.startsWith(DesignStore.designKeyPrefix)) {
      return backend.deleteDesign(
        key.substring(DesignStore.designKeyPrefix.length),
      );
    }
    return backend.deleteDocument(key);
  }

  // ------------------------------------------------------------- pulling

  /// Sends what changed, then brings down everything the backend has.
  ///
  /// A record changed on the device and not yet sent is kept and sent. A
  /// record changed in both places is a conflict: the backend's version is
  /// taken — it is what the factory now has — and the device's is kept
  /// beside it under [DeviceData.keptLocalPrefix], never lost.
  Future<void> pull() async {
    await push();
    final records = await backend.records();
    final prefs = await SharedPreferences.getInstance();
    final synced = _synced(prefs);
    final server = <String, Kept>{
      for (final MapEntry(:key, :value) in records.customers.entries)
        '${CustomerStore.customerKeyPrefix}$key': value,
      for (final MapEntry(:key, :value) in records.designs.entries)
        '${DesignStore.designKeyPrefix}$key': value,
      ...records.documents,
    };
    var touched = false;
    await _quietly(() async {
      for (final MapEntry(:key, value: kept) in server.entries) {
        final local = prefs.get(key);
        final was = synced[key];
        if (was != null && was.revision == kept.revision) continue;
        final unchanged =
            local == null || (local is String && _hash(local) == was?.hash);
        if (!unchanged &&
            local is String &&
            _hash(local) != _hash(kept.value)) {
          await prefs.setString(
            '${DeviceData.keptLocalPrefix}'
            '${DateTime.now().toUtc().toIso8601String()}.$key',
            local,
          );
        }
        await prefs.setString(key, kept.value);
        synced[key] = (revision: kept.revision, hash: _hash(kept.value));
        touched = true;
      }
      for (final key in synced.keys.toList()) {
        if (server.containsKey(key)) continue;
        final local = prefs.get(key);
        if (local is String && _hash(local) == synced[key]!.hash) {
          await prefs.remove(key);
          synced.remove(key);
          touched = true;
        }
      }
    });
    await _keepSynced(prefs, synced);
    if (touched) {
      await rebuildIndexes();
      onPulled?.call();
    }
  }

  /// One design as the backend now has it — after an approval the owner
  /// made — kept on the device as synced.
  Future<void> adoptDesign(
    String id,
    Map<String, Object?> data,
    int revision,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${DesignStore.designKeyPrefix}$id';
    final value = jsonEncode(data);
    final synced = _synced(prefs);
    await _quietly(() => prefs.setString(key, value));
    synced[key] = (revision: revision, hash: _hash(value));
    await _keepSynced(prefs, synced);
    await rebuildIndexes();
    onPulled?.call();
  }

  /// The two indexes worked out again from the records on the device.
  static Future<void> rebuildIndexes() async {
    final prefs = await SharedPreferences.getInstance();
    final customers = <CustomerSummary>[];
    final designs = <DesignSummary>[];
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is! String) continue;
      try {
        if (key.startsWith(CustomerStore.customerKeyPrefix)) {
          customers.add(
            CustomerSummary.of(
              Customer.fromJson(jsonDecode(value) as Map<String, Object?>),
            ),
          );
        } else if (key.startsWith(DesignStore.designKeyPrefix)) {
          designs.add(
            DesignSummary.of(
              Design.fromJson(jsonDecode(value) as Map<String, Object?>),
            ),
          );
        }
      } on Object {
        // A record this version cannot read stays on the device unlisted,
        // as the stores themselves leave one.
        continue;
      }
    }
    customers.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    designs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await prefs.setString(
      CustomerStore.indexKey,
      jsonEncode([for (final c in customers) c.toJson()]),
    );
    await prefs.setString(
      DesignStore.indexKey,
      jsonEncode([for (final d in designs) d.toJson()]),
    );
  }

  // ----------------------------------------------------------- watching

  WatchedPreferences? _watch;

  /// Every write to the device's records sends what changed, from now on.
  void start() {
    if (_watch != null) return;
    final current = SharedPreferencesStorePlatform.instance;
    final watched = current is WatchedPreferences
        ? current
        : WatchedPreferences(current);
    SharedPreferencesStorePlatform.instance = watched;
    watched.listener = (key) {
      if (_applying || !syncs(key)) return;
      scheduleMicrotask(() => unawaited(push()));
    };
    _watch = watched;
  }

  void stop() {
    _watch?.listener = null;
    _watch = null;
  }
}

/// The device's storage, telling [listener] about every key written or
/// removed. It changes nothing about what is kept or how.
class WatchedPreferences extends SharedPreferencesStorePlatform {
  final SharedPreferencesStorePlatform inner;
  void Function(String key)? listener;

  WatchedPreferences(this.inner);

  static String _bare(String key) =>
      key.startsWith('flutter.') ? key.substring(8) : key;

  @override
  Future<bool> remove(String key) {
    final done = inner.remove(key);
    listener?.call(_bare(key));
    return done;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    final done = inner.setValue(valueType, key, value);
    listener?.call(_bare(key));
    return done;
  }

  @override
  Future<bool> clear() => inner.clear();

  @override
  Future<bool> clearWithParameters(ClearParameters parameters) =>
      inner.clearWithParameters(parameters);

  @override
  Future<Map<String, Object>> getAll() => inner.getAll();

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) => inner.getAllWithParameters(parameters);
}
