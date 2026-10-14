import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing/extra_catalog.dart';
import '../domain/pricing/pricing_access.dart';
import 'keep_failed.dart';

/// Keeps the factory's list of extras (`ExtraItem`) on the device.
///
/// One record, under [key], apart from the price list on purpose: an item
/// is a template for a charge, not a rate the engine reads, so adding
/// silicone to the list must not make every price already calculated
/// *need recalculation* — which keeping it in the price list would.
///
/// **Everybody may read it; only whoever holds `pricing.edit` may change
/// it**, checked here, so a screen cannot change the factory's prices by
/// another route. Holding `extras.create` — adding a charge to a design —
/// does not give it.
class ExtraCatalogStore {
  static const key = 'proframe.extra-items.v1';

  /// Every item kept, retired ones included, in the order they were added.
  /// An entry that cannot be read, or repeats an id, is passed over; a
  /// record that cannot be read at all is no items, and is never written
  /// over by reading it.
  Future<List<ExtraItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key);
    if (text == null) return const [];
    try {
      final raw = jsonDecode(text);
      if (raw is! List<Object?>) return const [];
      final seen = <String>{};
      return [
        for (final e in raw)
          if (ExtraItem.fromJson(e) case final item? when seen.add(item.id))
            item,
      ];
    } on Object {
      return const [];
    }
  }

  /// Keeps [items] as the factory's list, as asked [by]: refused with
  /// [AccessDenied] — and nothing written — for anybody without
  /// `pricing.edit`, and [KeepFailed] where the device does not keep it.
  Future<List<ExtraItem>> save(
    List<ExtraItem> items, {
    required Authority by,
  }) async {
    by.require(Capability.pricingEdit);
    final prefs = await SharedPreferences.getInstance();
    final kept = await prefs.setString(
      key,
      jsonEncode([for (final i in items) i.toJson()]),
    );
    if (!kept) throw const KeepFailed(key);
    return load();
  }
}
