/// The factory's own list of the extras it charges again and again —
/// silicone by the bottle, labour by the hour, a delivery by the trip —
/// each with the price the owner sets.
///
/// ```
/// ExtraItem (catalog, the owner's)  ──chosen, a quantity──►  ExtraCharge
///   name, category, unit, unit price                          on a design or
///                                                             a customer's job
/// ```
///
/// **An item is a template, never a charge.** Choosing one writes an
/// [ExtraCharge] with the item's name, category, unit, unit price and
/// currency copied into it as they are at that moment, and the item's id
/// beside them. So changing or retiring an item afterwards reprices no
/// design, no customer and no quotation: what was added stays what it was.
/// A one-time charge typed in full is still an [ExtraCharge] with no item.
///
/// **Nothing here knows of silicone.** Every item is the same shape, typed
/// in by the factory; no name, unit or price is written in the code.
library;

import '../text/numerals.dart';
import '../text/words.dart';
import 'extra_charge.dart';

/// One extra the factory charges, as it keeps it in its list.
class ExtraItem {
  /// Stable, made from the name once: `item-silicone`. It outlives a
  /// rename, so an extra added from it still says which item it was.
  final String id;
  final String name;
  final ExtraCategory category;

  /// What one of it is — one of [ExtraUnit]'s labels, or what was typed.
  final String unit;

  /// One unit's price, in whole cents of [currency].
  final int unitPriceCents;

  /// The currency the price is in: the price list's when it was written.
  final String currency;

  /// A short explanation, shown with it.
  final String note;

  /// Whether it is still offered. A retired item is kept, never deleted.
  final bool active;
  final DateTime updatedAt;

  /// Who wrote it last.
  final String by;

  const ExtraItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.unitPriceCents,
    required this.currency,
    required this.updatedAt,
    this.note = '',
    this.active = true,
    this.by = '',
  });

  /// The extra this item adds: [quantityMilli] of it, at its own price,
  /// copied — see the library's note.
  ExtraCharge chargeOf({
    required String id,
    required int quantityMilli,
    required ExtraScope scope,
    required DateTime now,
    String note = '',
    String by = '',
    DateTime? createdAt,
  }) => ExtraCharge(
    id: id,
    name: name,
    category: category,
    quantityMilli: quantityMilli,
    unit: unit,
    unitPriceCents: unitPriceCents,
    currency: currency,
    scope: scope,
    createdAt: createdAt ?? now,
    updatedAt: now,
    note: note,
    by: by,
    itemId: this.id,
  );

  ExtraItem copyWith({
    String? name,
    ExtraCategory? category,
    String? unit,
    int? unitPriceCents,
    String? note,
    bool? active,
    DateTime? updatedAt,
    String? by,
  }) => ExtraItem(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    currency: currency,
    updatedAt: updatedAt ?? this.updatedAt,
    note: note ?? this.note,
    active: active ?? this.active,
    by: by ?? this.by,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'unit': unit,
    'unitPriceCents': unitPriceCents,
    'currency': currency,
    'updatedAt': updatedAt.toIso8601String(),
    if (note.isNotEmpty) 'note': note,
    if (!active) 'active': false,
    if (by.isNotEmpty) 'by': by,
  };

  /// An item as kept, or null where the record is not one — never an
  /// item made up from a broken record.
  static ExtraItem? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final unit = json['unit'];
    final price = json['unitPriceCents'];
    final currency = json['currency'];
    final at = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        unit is! String ||
        unit.trim().isEmpty ||
        price is! int ||
        price < 0 ||
        currency is! String ||
        currency.isEmpty ||
        at == null) {
      return null;
    }
    return ExtraItem(
      id: id,
      name: name,
      category: ExtraCategory.byName(json['category']),
      unit: unit,
      unitPriceCents: price,
      currency: currency,
      updatedAt: at,
      note: json['note'] as String? ?? '',
      active: json['active'] != false,
      by: json['by'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExtraItem &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.unit == unit &&
      other.unitPriceCents == unitPriceCents &&
      other.currency == currency &&
      other.note == note &&
      other.active == active;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    unit,
    unitPriceCents,
    currency,
    note,
    active,
  );
}

/// The operations on the factory's list of extras. Each one checks first
/// and changes nothing on a problem; the store that keeps the list is the
/// one that asks whether the person may (`pricing.edit`).
abstract final class ExtraCatalog {
  /// The items offered for a charge in [currency]: active, in the order
  /// they were added. An item in another currency is never offered, since
  /// an extra is only ever added to a price in its own currency.
  static List<ExtraItem> offeredIn(List<ExtraItem> items, String currency) => [
    for (final i in items)
      if (i.active && i.currency == currency) i,
  ];

  /// An id for an item called [name], unique among [items] — retired ones
  /// included, so an id is never given twice.
  static String idFor(String name, List<ExtraItem> items) {
    final slug = Numerals.latin(name)
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = 'item-${slug.isEmpty ? 'unnamed' : slug}';
    final taken = {for (final i in items) i.id};
    var id = base;
    for (var n = 2; taken.contains(id); n++) {
      id = '$base-$n';
    }
    return id;
  }

  /// Why [item] cannot stand in [items] as it is, or null where it can:
  /// a name, a unit, a price of nothing or more, and no other active item
  /// called the same, whatever the case.
  static String? problemWith(
    ExtraItem item,
    List<ExtraItem> items, [
    Words w = const EnglishWords(),
  ]) {
    final name = item.name.trim();
    if (name.isEmpty) return w.xNameNeeded;
    if (item.unit.trim().isEmpty) return w.xUnitNeeded;
    if (item.unitPriceCents < 0) return w.xPriceNotBelow;
    if (item.active &&
        items.any(
          (i) =>
              i.active &&
              i.id != item.id &&
              i.name.trim().toLowerCase() == name.toLowerCase(),
        )) {
      return w.xiNameTaken(name);
    }
    return null;
  }

  /// [items] with [item] added, or put in place of the one with its id —
  /// or why it cannot be.
  static ({List<ExtraItem>? items, String? problem}) put(
    List<ExtraItem> items,
    ExtraItem item, [
    Words w = const EnglishWords(),
  ]) {
    final trimmed = item.copyWith(
      name: item.name.trim(),
      unit: item.unit.trim(),
      note: item.note.trim(),
    );
    final problem = problemWith(trimmed, items, w);
    if (problem != null) return (items: null, problem: problem);
    final exists = items.any((i) => i.id == item.id);
    return (
      items: exists
          ? [
              for (final i in items) i.id == item.id ? trimmed : i,
            ]
          : [...items, trimmed],
      problem: null,
    );
  }

  /// [items] with the one called [id] no longer offered. Nothing is
  /// removed, and no extra already added from it changes.
  static List<ExtraItem> retire(List<ExtraItem> items, String id) => [
    for (final i in items) i.id == id ? i.copyWith(active: false) : i,
  ];

  /// [items] with the one called [id] offered again — or why it cannot
  /// be, where an active item has taken its name meanwhile.
  static ({List<ExtraItem>? items, String? problem}) restore(
    List<ExtraItem> items,
    String id, [
    Words w = const EnglishWords(),
  ]) {
    final item = items.where((i) => i.id == id).firstOrNull;
    if (item == null) return (items: items, problem: null);
    return put(items, item.copyWith(active: true), w);
  }
}
