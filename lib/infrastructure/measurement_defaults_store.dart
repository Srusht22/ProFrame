import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dimensions/measurement_defaults.dart';
import '../domain/pricing/pricing_access.dart';
import 'keep_failed.dart';

/// Keeps the factory's usual sizes (`MeasurementDefaults`) on the device.
///
/// One record, under [key], apart from the price list: a size is not a
/// rate, and setting the usual border of a uPVC frame must not make every
/// price already calculated *need recalculation*. Nothing in a design is
/// read from here once it has been applied, so changing a default changes
/// no design kept.
///
/// **Everybody may read it; only whoever holds `pricing.edit` may change
/// it** — the factory's own figures, checked here and not only on the
/// screen.
class MeasurementDefaultsStore {
  static const key = 'proframe.measurement-defaults.v1';

  /// What is kept, or nothing said where nothing is kept or it cannot be
  /// read; reading writes nothing.
  Future<MeasurementDefaults> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return MeasurementDefaults.none;
    try {
      return MeasurementDefaults.fromJson(jsonDecode(text));
    } on Object {
      return MeasurementDefaults.none;
    }
  }

  /// Keeps [defaults], as asked [by]: refused with [AccessDenied] — and
  /// nothing written — for anybody without `pricing.edit`, and
  /// [KeepFailed] where the device does not keep it.
  Future<MeasurementDefaults> save(
    MeasurementDefaults defaults, {
    required Authority by,
  }) async {
    by.require(Capability.pricingEdit);
    final prefs = await SharedPreferences.getInstance();
    final kept = await prefs.setString(key, jsonEncode(defaults.toJson()));
    if (!kept) throw const KeepFailed(key);
    return load();
  }
}
