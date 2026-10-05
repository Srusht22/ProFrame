import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing/price_list.dart';
import '../domain/pricing/pricing_access.dart';

/// Keeps the workshop's price list on the device.
///
/// One record, under [key], beside the designs and the customers and
/// nothing to do with either: the list is the workshop's, not a design's,
/// so changing a price writes no design and reading a design reads no
/// price. Until the owner keeps a list of their own, the example list
/// (`PriceList.starter`) is what designs are priced by — and a record that
/// cannot be read is never written over by reading it: it stays where it
/// is, and the example list stands in until the owner keeps one.
class PriceListStore {
  static const key = 'proframe.pricelist.v2';

  /// Where the first engine kept its list (schema 1). Read, and migrated as
  /// it is read, only while nothing is kept under [key]; never written, and
  /// never removed — it is the owner's data.
  static const legacyKey = 'proframe.pricelist.v1';

  /// The list designs are priced by now: the one kept, migrated from an
  /// older schema where it was kept in one (`PriceList.fromJson`), or the
  /// example list where none is kept. Reading writes nothing: a migrated
  /// list is kept in the current schema only when the owner next keeps it.
  Future<PriceList> load() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(key) ?? prefs.getString(legacyKey);
    if (text == null) return PriceList.starter;
    try {
      return PriceList.fromJson(jsonDecode(text)) ?? PriceList.starter;
    } on Object {
      return PriceList.starter;
    }
  }

  /// Keeps [list] as the workshop's, as asked [by] — the owner, and nobody
  /// else ([WorkshopRole.canConfigurePrices]): anyone else is refused with
  /// [PricingAccessDenied] and nothing is written.
  ///
  /// Each keep is a new version of the list, so a price worked out from it
  /// can say which list it came from, and it is no longer the example list.
  Future<PriceList> save(PriceList list, {required WorkshopRole by}) async {
    if (!by.canConfigurePrices) throw PricingAccessDenied(by);
    final current = await load();
    final json = list
        .copyWith(
          version: (current.isStarter ? 0 : current.version) + 1,
          isStarter: false,
        )
        .toJson();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(json));
    // As kept — in the current schema, and no longer a migrated list.
    return PriceList.fromJson(json)!;
  }
}
