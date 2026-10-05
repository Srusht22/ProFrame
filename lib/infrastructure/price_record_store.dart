import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing/design_price_state.dart';

/// Keeps each design's calculated price on the device, by the design's id.
///
/// **Beside the design, never in it.** Calculating a price writes nothing
/// to the design — not its geometry, not its materials, not when it was
/// last edited — so a price is kept here, one record a design, and the
/// design's own record is untouched. A record says what it was calculated
/// from (`PriceRecord.inputs`), so whether it is still the price is
/// worked out each time it is read, never stored.
///
/// A design deleted takes its record with it (`DesignStore.remove`), and a
/// record left by a delete made before that is swept when the app starts
/// (`DesignStore.sweepOrphanPrices`).
class PriceRecordStore {
  static const keyPrefix = 'proframe.price.v1.';

  static String keyOf(String designId) => '$keyPrefix$designId';

  /// The price kept for [designId], or null where none is — or where what
  /// is kept cannot be read, which is no price at all.
  Future<PriceRecord?> load(String designId) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(keyOf(designId));
    if (text == null) return null;
    try {
      return PriceRecord.fromJson(jsonDecode(text));
    } on Object {
      return null;
    }
  }

  /// Keeps [record] as [designId]'s price.
  Future<void> save(String designId, PriceRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOf(designId), jsonEncode(record.toJson()));
  }
}
