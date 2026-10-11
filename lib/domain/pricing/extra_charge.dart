/// A charge the factory adds to a job by hand: so much of something at so
/// much each.
///
/// ```
/// Design ─ automatic costs (profile, panel, glass, hardware … from the
///   │      canonical geometry, by the price list's rates)
///   ├─ extras: ExtraCharge, ExtraCharge, …   quantity × unit price
///   └─ discount
/// Customer ─ the designs' prices ─ extras ─ discount
/// ```
///
/// **The engine knows an extra, never a silicone.** Every extra is the same
/// thing — a name, a category, a quantity, a unit and a unit price — and its
/// total is always the quantity times the unit price. Silicone, labour,
/// transport, installation and a special aluminium accessory are all typed
/// in by the factory; nothing here, or anywhere else, has a field or a
/// price for any one of them.
///
/// **An extra is not geometry and not a payment.** Adding one moves no line
/// of the design, and it is never money received: it raises what is owed,
/// and a payment, with its receipt, is still how money comes in.
///
/// **Money is whole numbers.** A quantity is kept in thousandths
/// ([quantityMilli]) — *2.5 metres* is 2500 — and a unit price in whole
/// cents ([unitPriceCents]), so the total is worked out exactly, once,
/// half a cent up, and every sum after is a sum of cents.
library;

import '../text/names.dart';
import '../text/words.dart';
import 'price_result.dart';

/// What an extra is, for sorting it on a breakdown. The calculation is the
/// same for all of them: quantity × unit price.
enum ExtraCategory {
  material('Material'),
  labour('Labour'),
  service('Service'),
  transport('Transport'),
  installation('Installation'),
  other('Other');

  const ExtraCategory(this.label);
  final String label;

  static ExtraCategory byName(Object? name) =>
      values.where((c) => c.name == name).firstOrNull ?? other;

  /// [label], in [w].
  String labelIn(Words w) => switch (this) {
    material => w.xcMaterial,
    labour => w.xcLabour,
    service => w.xcService,
    transport => w.xcTransport,
    installation => w.xcInstallation,
    other => w.xcOther,
  };
}

/// The units offered when an extra is written. A unit only says what the
/// quantity counts; nothing about the arithmetic follows from it. Any other
/// unit can be typed in.
enum ExtraUnit {
  piece('piece', 'pieces'),
  bottle('bottle', 'bottles'),
  hour('hour', 'hours'),
  metre('metre', 'metres'),
  squareMetre('square metre', 'square metres'),
  kg('kg', 'kg'),
  set('set', 'sets'),
  roll('roll', 'rolls'),
  day('day', 'days'),
  trip('trip', 'trips');

  const ExtraUnit(this.label, this.plural);
  final String label;
  final String plural;

  static ExtraUnit? of(String unit) =>
      values.where((u) => u.label == unit.trim().toLowerCase()).firstOrNull;

  /// [label] — one — or [plural], in [w]. The unit is kept by its English
  /// [label]; only how it is shown changes.
  String sayIn(Words w, {bool one = true}) => switch (this) {
    piece => one ? w.xuPiece : w.xuPieces,
    bottle => one ? w.xuBottle : w.xuBottles,
    hour => one ? w.xuHour : w.xuHours,
    metre => one ? w.xuMetre : w.xuMetres,
    squareMetre => one ? w.xuSquareMetre : w.xuSquareMetres,
    kg => one ? w.xuKg : w.xuKgs,
    set => one ? w.xuSet : w.xuSets,
    roll => one ? w.xuRoll : w.xuRolls,
    day => one ? w.xuDay : w.xuDays,
    trip => one ? w.xuTrip : w.xuTrips,
  };
}

/// Whose an extra is: one design's, or the customer's whole job.
enum ExtraScope { design, customer }

class ExtraCharge {
  /// Stable: `EXT-20261005-0001`.
  final String id;
  final String name;
  final ExtraCategory category;

  /// The quantity in thousandths: 5 bottles is 5000, 2.5 metres 2500.
  final int quantityMilli;

  /// What the quantity counts — one of [ExtraUnit]'s, or what was typed.
  final String unit;

  /// One unit's price, in whole cents of [currency].
  final int unitPriceCents;

  /// The currency the unit price is in. An extra is only ever added to a
  /// price in its own currency.
  final String currency;

  final String note;
  final ExtraScope scope;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Who wrote it last: *Owner*, a member of staff's name.
  final String by;

  const ExtraCharge({
    required this.id,
    required this.name,
    required this.category,
    required this.quantityMilli,
    required this.unit,
    required this.unitPriceCents,
    required this.currency,
    required this.scope,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.by = '',
  });

  /// What it comes to, in whole cents: quantity × unit price, half a cent
  /// rounded up.
  int get totalCents => totalOf(quantityMilli, unitPriceCents);

  /// [quantityMilli] thousandths at [unitPriceCents] each, in whole cents.
  static int totalOf(int quantityMilli, int unitPriceCents) =>
      (quantityMilli * unitPriceCents + 500) ~/ 1000;

  /// The quantity as it is written: *5*, *2.5*, *1.125*.
  String get quantityText => quantityTextOf(quantityMilli);

  static String quantityTextOf(int milli) {
    final whole = milli ~/ 1000;
    final part = milli % 1000;
    if (part == 0) return '$whole';
    return '$whole.${part.toString().padLeft(3, '0').replaceAll(RegExp(r'0+$'), '')}';
  }

  /// The unit as the quantity reads it: *1 bottle*, *5 bottles*. A unit
  /// that was typed is written as it was typed.
  String get unitText => unitTextOf(unit, quantityMilli);

  static String unitTextOf(
    String unit,
    int quantityMilli, [
    Words w = const EnglishWords(),
  ]) {
    final known = ExtraUnit.of(unit);
    if (known == null) return unit.trim();
    return known.sayIn(w, one: quantityMilli == 1000);
  }

  /// How it is worked out, in words: *5 bottles × 3.00 USD*.
  String sum(
    String Function(int cents) money, [
    Words w = const EnglishWords(),
  ]) =>
      '$quantityText ${unitTextOf(unit, quantityMilli, w)} × '
      '${money(unitPriceCents)}';

  ExtraCharge copyWith({
    String? name,
    ExtraCategory? category,
    int? quantityMilli,
    String? unit,
    int? unitPriceCents,
    String? note,
    DateTime? updatedAt,
    String? by,
  }) => ExtraCharge(
    id: id,
    name: name ?? this.name,
    category: category ?? this.category,
    quantityMilli: quantityMilli ?? this.quantityMilli,
    unit: unit ?? this.unit,
    unitPriceCents: unitPriceCents ?? this.unitPriceCents,
    currency: currency,
    scope: scope,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    note: note ?? this.note,
    by: by ?? this.by,
  );

  /// Why an extra of this shape cannot be kept, or null where it can: a
  /// name, a quantity of more than nothing, a unit, and a unit price of
  /// nothing or more.
  static String? problemWith({
    required String name,
    required int? quantityMilli,
    required String unit,
    required int? unitPriceCents,
    Words words = const EnglishWords(),
  }) {
    final w = words;
    if (name.trim().isEmpty) return w.xNameNeeded;
    if (quantityMilli == null) return w.xQtyEnter;
    if (quantityMilli <= 0) return w.xQtyMore;
    if (unit.trim().isEmpty) return w.xUnitNeeded;
    if (unitPriceCents == null) return w.xPriceEnter;
    if (unitPriceCents < 0) return w.xPriceNotBelow;
    return null;
  }

  /// A quantity as typed — *5*, *2.5*, *1.125* — in thousandths, or why it
  /// is not one.
  static ({int? value, String? problem}) readQuantity(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim().replaceAll(',', '');
    if (words.isEmpty) return (value: null, problem: w.xQtyEnter);
    if (words.startsWith('-')) {
      return (value: null, problem: w.xQtyMore);
    }
    final m = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(words);
    if (m == null) {
      return (value: null, problem: w.xQtyNumber);
    }
    final part = m.group(2) ?? '';
    if (part.length > 3) {
      return (value: null, problem: w.xQtyPlaces);
    }
    final value =
        int.parse(m.group(1)!) * 1000 + int.parse(part.padRight(3, '0'));
    if (value <= 0) {
      return (value: null, problem: w.xQtyMore);
    }
    return (value: value, problem: null);
  }

  /// A unit price as typed — *3*, *3.25*, *1,200.00* — in whole cents, or
  /// why it is not one. Nothing is a price; below nothing is not.
  static ({int? value, String? problem}) readPrice(
    String text, [
    Words w = const EnglishWords(),
  ]) {
    final words = text.trim().replaceAll(',', '');
    if (words.isEmpty) return (value: null, problem: w.xPriceEnter);
    if (words.startsWith('-')) {
      return (value: null, problem: w.xPriceNotBelow);
    }
    final m = RegExp(r'^(\d+)(?:\.(\d*))?$').firstMatch(words);
    if (m == null) {
      return (value: null, problem: w.xPriceNumber);
    }
    final part = m.group(2) ?? '';
    if (part.length > 2) {
      return (value: null, problem: w.xPricePlaces);
    }
    return (
      value: int.parse(m.group(1)!) * 100 + int.parse(part.padRight(2, '0')),
      problem: null,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'quantityMilli': quantityMilli,
    'unit': unit,
    'unitPriceCents': unitPriceCents,
    'currency': currency,
    'scope': scope.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (note.isNotEmpty) 'note': note,
    if (by.isNotEmpty) 'by': by,
  };

  /// An extra as kept, or null where the record is not one — never a
  /// charge made up from a broken record.
  static ExtraCharge? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    final name = json['name'];
    final quantity = json['quantityMilli'];
    final unit = json['unit'];
    final price = json['unitPriceCents'];
    final currency = json['currency'];
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id is! String ||
        name is! String ||
        quantity is! int ||
        unit is! String ||
        price is! int ||
        currency is! String ||
        created == null ||
        quantity <= 0 ||
        price < 0) {
      return null;
    }
    return ExtraCharge(
      id: id,
      name: name,
      category: ExtraCategory.byName(json['category']),
      quantityMilli: quantity,
      unit: unit,
      unitPriceCents: price,
      currency: currency,
      scope: json['scope'] == ExtraScope.customer.name
          ? ExtraScope.customer
          : ExtraScope.design,
      createdAt: created,
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? created,
      note: json['note'] as String? ?? '',
      by: json['by'] as String? ?? '',
    );
  }

  /// The same charge — every figure that is priced alike. When it was
  /// written and by whom are not compared: they say nothing of the price.
  bool samePriceAs(ExtraCharge other) =>
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.quantityMilli == quantityMilli &&
      other.unit == unit &&
      other.unitPriceCents == unitPriceCents &&
      other.currency == currency;

  @override
  bool operator ==(Object other) =>
      other is ExtraCharge &&
      samePriceAs(other) &&
      other.note == note &&
      other.scope == scope;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    quantityMilli,
    unit,
    unitPriceCents,
    currency,
    note,
    scope,
  );

  @override
  String toString() =>
      '$name: $quantityText $unitText × $unitPriceCents¢ = $totalCents¢';

  /// The automatic costs [name] and [category] look like — glass where the
  /// design's glass is already priced, labour where the category's labour
  /// is — so a charge already worked out from the design is not added a
  /// second time by hand without the user saying it is an additional one.
  ///
  /// Only lines with something charged count: a design with no glass has
  /// no glass to duplicate.
  static List<PriceLine> alreadyCalculated(
    String name,
    ExtraCategory category,
    Iterable<PriceLine> lines,
  ) {
    final words = name.toLowerCase();
    bool says(List<String> any) => any.any(words.contains);
    final groups = <PriceGroup>{
      // In English and in Central Kurdish, since an extra is named in
      // whichever the user writes in.
      if (says(['glass', 'glazing', 'glazed unit', 'شووشە'])) PriceGroup.glass,
      if (says(['panel', 'پانێڵ'])) PriceGroup.panel,
      if (says([
        'profile',
        'frame',
        'mullion',
        'transom',
        'sash',
        'پرۆفایل',
        'چوارچێوە',
      ])) ...[
        PriceGroup.normalProfile,
        PriceGroup.openingProfile,
      ],
      if (says(['track', 'ڕێڕەو'])) PriceGroup.otherProfile,
      if (says([
        'hinge',
        'handle',
        'lever',
        'lock',
        'roller',
        'pull',
        'knob',
        'لولاو',
        'دەسک',
        'قفڵ',
        'تەگەرە',
      ]))
        PriceGroup.hardware,
      if (says(['colour', 'color', 'ڕەنگ'])) PriceGroup.colour,
      if (category == ExtraCategory.labour ||
          says(['labour', 'labor', 'making', 'کرێی کار', 'دروستکردن']))
        PriceGroup.labour,
      if (category == ExtraCategory.installation ||
          says(['install', 'fitting', 'دامەزراندن']))
        PriceGroup.installation,
    };
    return [
      for (final l in lines)
        if (groups.contains(l.group) && l.amountCents > 0) l,
    ];
  }

  /// What to tell the user about [lines] already worked out, where an extra
  /// would charge for them again: what each is and what it comes to.
  static String alreadyCalculatedMessage(
    List<PriceLine> lines,
    String Function(int cents) money, [
    Words w = const EnglishWords(),
  ]) {
    final named = {for (final l in lines) l.group.labelIn(w): 0};
    for (final l in lines) {
      named[l.group.labelIn(w)] = named[l.group.labelIn(w)]! + l.amountCents;
    }
    final said = [
      for (final MapEntry(key: what, value: cents) in named.entries)
        w.xAlreadyItem(what, money(cents)),
    ].join(w.listComma);
    return named.length == 1 ? w.xAlreadyOne(said) : w.xAlreadyMany(said);
  }
}

/// A list of extras, and what they come to.
extension ExtraCharges on List<ExtraCharge> {
  /// Every extra in [currency], summed in cents.
  int totalCentsIn(String currency) => [
    for (final e in this)
      if (e.currency == currency) e.totalCents,
  ].fold(0, (s, c) => s + c);

  /// Extras kept in a currency other than [currency]: never added to it.
  List<ExtraCharge> notIn(String currency) => [
    for (final e in this)
      if (e.currency != currency) e,
  ];

  /// An id no extra here has had, for one written at [at].
  String nextExtraId(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    final day = '${at.year}${two(at.month)}${two(at.day)}';
    var n = length + 1;
    String id() => 'EXT-$day-${n.toString().padLeft(4, '0')}';
    while (any((e) => e.id == id())) {
      n++;
    }
    return id();
  }

  /// This list with [extra] put in — in its place where it is already here
  /// by id, at the end where it is new.
  List<ExtraCharge> withExtra(ExtraCharge extra) {
    final at = indexWhere((e) => e.id == extra.id);
    if (at < 0) return [...this, extra];
    return [...this]..[at] = extra;
  }

  List<ExtraCharge> without(String id) => [
    for (final e in this)
      if (e.id != id) e,
  ];
}
