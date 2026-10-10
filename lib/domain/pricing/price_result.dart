/// What a price is made of, and what came of working it out.
///
/// Nothing here knows about a design. A [PriceResult] is a set of lines and
/// the sums of them, so it can be kept — a quotation's price as it stood the
/// day it was given ([PriceSnapshot]) — and read back after the price list
/// has changed, without being worked out again.
library;

import 'extra_charge.dart';
import 'measurement.dart';
import 'price_list.dart';

/// How a price came out.
enum PriceStatus {
  /// Every part was priced; [PriceResult.total] is the price.
  priced,

  /// Nothing to price yet: no outline has been read into a frame.
  nothingToPrice,

  /// The drawing has changes the geometry has not been read from: what is
  /// on the screen is not what would be priced.
  notRead,

  /// The width or the height has not been given. A sketch has proportions
  /// and no scale, so a price read off it would be a guess at a number.
  needsSizes,

  /// The design's category is one this version does not know how to price —
  /// a category from a later version, or one with no pricing of its own.
  unsupportedCategory,

  /// The price list has no price for something the design is made of.
  notConfigured,

  /// The geometry cannot be measured: a size of nothing, or not a number.
  invalid,

  /// Something the price depends on has not been said yet: what a door is
  /// built of, which parts are glass and which panel, or what an opening
  /// is. See `PriceReadiness`.
  incomplete,
}

/// Which part of the breakdown a line belongs to.
enum PriceGroup {
  /// The frame's border and every line cut from the same profile.
  normalProfile('Normal profile'),

  /// The profile round each opening.
  openingProfile('Opening profile'),

  /// Any other profile by the metre — a sliding track.
  otherProfile('Other profile'),

  /// What a colour adds to the profile it is on.
  colour('Colour'),
  glass('Glass'),
  panel('Panel'),
  hardware('Hardware'),
  labour('Labour'),
  installation('Installation');

  const PriceGroup(this.label);
  final String label;
}

/// What a line's quantity counts.
enum PriceUnit {
  each('each'),
  metre('m'),
  squareMetre('m²'),
  percent('%'),
  fixed('');

  const PriceUnit(this.symbol);
  final String symbol;
}

/// One line of a breakdown: so much of something at so much each.
class PriceLine {
  final PriceGroup group;

  /// What it is, in words: *uPVC frame*, *Frosted glass*, *Hinges*.
  final String label;
  final double quantity;
  final PriceUnit unit;

  /// The price of one [unit] — or, for [PriceUnit.percent], the percentage.
  final double rate;

  /// What the line comes to, in whole cents: money is charged to the cent,
  /// and every sum of lines is a sum of cents, so a total never differs by
  /// a cent from the lines written above it.
  final int amountCents;

  /// What the line comes to, in the list's currency.
  double get amount => amountCents / 100;

  /// The part of the design the line is for, where it is one part.
  final String? partId;

  PriceLine({
    required this.group,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.rate,
    required double amount,
    this.partId,
  }) : amountCents = Money.cents(amount);

  Map<String, Object?> toJson() => {
    'group': group.name,
    'label': label,
    'quantity': quantity,
    'unit': unit.name,
    'rate': rate,
    'amount': amount,
    if (partId != null) 'partId': partId,
  };

  static PriceLine fromJson(Map<String, Object?> map) => PriceLine(
    group: PriceGroup.values.byName(map['group']! as String),
    label: map['label']! as String,
    quantity: (map['quantity']! as num).toDouble(),
    unit: PriceUnit.values.byName(map['unit']! as String),
    rate: (map['rate']! as num).toDouble(),
    amount: (map['amount']! as num).toDouble(),
    partId: map['partId'] as String?,
  );

  @override
  String toString() => '$label: $quantity ${unit.symbol} × $rate = $amount';
}

/// Something about the design or the price list that kept it from being
/// priced, or that the price should be read with.
class PriceIssue {
  final String message;

  /// True when it stops the price being given at all.
  final bool blocking;

  const PriceIssue(this.message, {this.blocking = true});

  Map<String, Object?> toJson() => {
    'message': message,
    if (!blocking) 'blocking': false,
  };

  static PriceIssue fromJson(Map<String, Object?> map) =>
      PriceIssue(map['message']! as String, blocking: map['blocking'] != false);

  @override
  String toString() => message;
}

/// A reduction off the subtotal: a percentage, or an amount, or both.
///
/// Only the shape a discount needs is here — no promotions, no rules about
/// who may give one. Whatever it says, it never takes the total below zero.
class Discount {
  final double percent;
  final double amount;

  /// Who gave it and when — said with it, never part of what it takes off.
  final String by;
  final DateTime? at;

  const Discount({this.percent = 0, this.amount = 0, this.by = '', this.at});

  bool get isNone => percent <= 0 && amount <= 0;

  /// What it says, in words: *10%*, *45.00 USD* — [money] writes an amount.
  String describe(String Function(int cents) money) => percent > 0
      ? '${_trim(percent)}%'
      : money(Money.cents(amount));

  static String _trim(double v) => v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');

  /// How much it takes off [subtotal]: never less than nothing, never more
  /// than the whole.
  double off(double subtotal) {
    if (!subtotal.isFinite || subtotal <= 0) return 0;
    final p = percent.isFinite ? percent.clamp(0, 100) : 0;
    final a = amount.isFinite ? amount.clamp(0, double.infinity) : 0;
    return (subtotal * p / 100 + a).clamp(0, subtotal).toDouble();
  }

  Map<String, Object?> toJson() => {
    if (percent != 0) 'percent': percent,
    if (amount != 0) 'amount': amount,
    if (by.isNotEmpty) 'by': by,
    if (at != null) 'at': at!.toIso8601String(),
  };

  static Discount? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    double read(Object? v) =>
        v is num && v.isFinite && v >= 0 ? v.toDouble() : 0;
    final d = Discount(
      percent: read(json['percent']),
      amount: read(json['amount']),
      by: json['by'] as String? ?? '',
      at: DateTime.tryParse(json['at'] as String? ?? ''),
    );
    return d.isNone ? null : d;
  }

  @override
  bool operator ==(Object other) =>
      other is Discount && other.percent == percent && other.amount == amount;

  @override
  int get hashCode => Object.hash(percent, amount);
}

/// What a price came to: its lines, their sums, and what stood in its way.
class PriceResult {
  final PriceStatus status;
  final List<PriceLine> lines;
  final List<PriceIssue> issues;

  /// The currency the price list is kept in, as written: `IQD`, `USD`.
  final String currency;

  /// The category it was priced as, by name — the design's, or the name a
  /// later version saved.
  final String category;

  /// Which price list it was worked out from, so a kept price can say how
  /// old it is.
  final int priceListVersion;

  final Discount? discount;

  /// What the design measures — profile by the metre, glass and panel by
  /// the square metre — kept with the price so the two are read together,
  /// and so a kept price says what it was a price for. Nothing where the
  /// design could not be measured.
  final MeasurementSummary measurements;

  /// The profile it was priced in — the material and colour whose rates
  /// the profile lines were read at — so a kept price says what it was a
  /// price of. Null where nothing was priced.
  final PricedProfile? profile;

  /// The extras the factory added to the design by hand — silicone,
  /// labour, a trip — each quantity × unit price, kept apart from [lines],
  /// which are what the design's own geometry costs. Kept as they were, so
  /// a quotation still says *5 bottles × 3.00* after the extra changes.
  final List<ExtraCharge> extras;

  const PriceResult({
    required this.status,
    required this.currency,
    required this.category,
    this.lines = const [],
    this.issues = const [],
    this.priceListVersion = 0,
    this.discount,
    this.measurements = MeasurementSummary.none,
    this.profile,
    this.extras = const [],
  });

  /// A result with no price, for [status], saying why.
  factory PriceResult.unavailable(
    PriceStatus status,
    String why, {
    required String currency,
    required String category,
    int priceListVersion = 0,
    List<PriceIssue> more = const [],
  }) => PriceResult(
    status: status,
    currency: currency,
    category: category,
    priceListVersion: priceListVersion,
    issues: [PriceIssue(why), ...more],
  );

  bool get isPriced => status == PriceStatus.priced;

  double sumOf(PriceGroup group) => _cents([
    for (final l in lines)
      if (l.group == group) l,
  ]) / 100;

  /// What the design's own geometry costs, worked out from it by the price
  /// list's rates — profile, panel, glass, hardware, colour, labour and
  /// installation — in whole cents.
  int get designCostCents => isPriced ? _cents(lines) : 0;

  /// What the extras added by hand come to, in whole cents.
  int get extrasCents => isPriced ? extras.totalCentsIn(currency) : 0;

  int get _subtotalCents => designCostCents + extrasCents;

  int get _discountCents =>
      isPriced ? Money.cents(discount?.off(subtotal) ?? 0) : 0;

  /// Everything before the discount: the design's own cost and its extras.
  double get subtotal => _subtotalCents / 100;

  /// [subtotal] in whole cents.
  int get subtotalCents => _subtotalCents;

  /// [discountAmount] in whole cents.
  int get discountCents => _discountCents;

  double get discountAmount => _discountCents / 100;

  /// What the design comes to, in whole cents, or null where it could not
  /// be priced: the lines summed as cents, less the discount.
  int? get totalCents => isPriced ? _subtotalCents - _discountCents : null;

  /// What the design comes to, or null where it could not be priced.
  double? get total => switch (totalCents) {
    final c? => c / 100,
    null => null,
  };

  static int _cents(Iterable<PriceLine> lines) =>
      lines.fold(0, (sum, l) => sum + l.amountCents);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'currency': currency,
    'category': category,
    'priceListVersion': priceListVersion,
    'lines': [for (final l in lines) l.toJson()],
    'issues': [for (final i in issues) i.toJson()],
    if (discount != null) 'discount': discount!.toJson(),
    'measurements': measurements.toJson(),
    if (profile != null) 'profile': profile!.toJson(),
    if (extras.isNotEmpty) 'extras': [for (final e in extras) e.toJson()],
  };

  static PriceResult fromJson(Map<String, Object?> map) => PriceResult(
    status: PriceStatus.values.byName(map['status']! as String),
    currency: map['currency']! as String,
    category: map['category']! as String,
    priceListVersion: (map['priceListVersion'] as num?)?.toInt() ?? 0,
    lines: [
      for (final l in (map['lines'] as List<Object?>? ?? const []))
        PriceLine.fromJson(l! as Map<String, Object?>),
    ],
    issues: [
      for (final i in (map['issues'] as List<Object?>? ?? const []))
        PriceIssue.fromJson(i! as Map<String, Object?>),
    ],
    discount: Discount.fromJson(map['discount']),
    measurements: MeasurementSummary.fromJson(map['measurements']),
    profile: PricedProfile.fromJson(map['profile']),
    extras: [
      if (map['extras'] case final List<Object?> kept)
        for (final e in kept) ?ExtraCharge.fromJson(e),
    ],
  );
}

/// The profile a price was worked out in: its material, its colour and
/// what the colour is called, as they were when it was priced.
class PricedProfile {
  /// The material's name in the model, `upvc`, `aluminium`.
  final String material;

  /// What the material is called: *uPVC*, *Aluminium*.
  final String materialLabel;
  final int colour;

  /// What the colour was called when it was priced — kept as it was, so a
  /// colour renamed since still says its old name here.
  final String colourName;

  /// The catalog colour it was, where it was one: the id outlives a
  /// rename, so a price kept says which colour it was a price of.
  final String? colourId;

  /// What the colour added a metre and in a hundred when it was priced.
  final ColourSurcharge? colourRate;

  const PricedProfile({
    required this.material,
    required this.materialLabel,
    required this.colour,
    required this.colourName,
    this.colourId,
    this.colourRate,
  });

  Map<String, Object?> toJson() => {
    'material': material,
    'materialLabel': materialLabel,
    'colour': colour,
    'colourName': colourName,
    if (colourId != null) 'colourId': colourId,
    if (colourRate != null)
      'colourRate': {
        'perMetre': colourRate!.perMetre,
        'percent': colourRate!.percent,
      },
  };

  static PricedProfile? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final material = json['material'];
    final label = json['materialLabel'];
    final colour = json['colour'];
    final name = json['colourName'];
    if (material is! String ||
        label is! String ||
        colour is! int ||
        name is! String) {
      return null;
    }
    return PricedProfile(
      material: material,
      materialLabel: label,
      colour: colour,
      colourName: name,
      colourId: switch (json['colourId']) {
        final String id => id,
        _ => null,
      },
      colourRate: switch (json['colourRate']) {
        final Map<String, Object?> rate => ColourSurcharge.fromJson(rate),
        _ => null,
      },
    );
  }
}

/// A price as it stood when it was given — kept so a quotation or an order
/// still says what was quoted after the workshop's prices change.
///
/// It is the result itself, written down, and never worked out again: the
/// live price is the design priced from the price list as it is now, and
/// the two can differ, which is the point of keeping one.
class PriceSnapshot {
  final DateTime takenAt;
  final PriceResult result;

  const PriceSnapshot({required this.takenAt, required this.result});

  Map<String, Object?> toJson() => {
    'takenAt': takenAt.toIso8601String(),
    'result': result.toJson(),
  };

  static PriceSnapshot? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      return PriceSnapshot(
        takenAt: DateTime.parse(json['takenAt']! as String),
        result: PriceResult.fromJson(json['result']! as Map<String, Object?>),
      );
    } on Object {
      return null;
    }
  }
}

/// What the user has chosen about a design's price that is not its
/// geometry or what it is made of: whether it is fitted, any discount, and
/// a price kept from an earlier day. Kept in the design.
class PricingChoices {
  /// Whether installation is included. Never on unless the user says so.
  final bool installation;

  /// The design's own discount, off its cost and its extras together.
  final Discount? discount;
  final PriceSnapshot? snapshot;

  /// What the factory added to this design by hand — see [ExtraCharge].
  final List<ExtraCharge> extras;

  const PricingChoices({
    this.installation = false,
    this.discount,
    this.snapshot,
    this.extras = const [],
  });

  static const none = PricingChoices();

  bool get isNone =>
      !installation && discount == null && snapshot == null && extras.isEmpty;

  PricingChoices copyWith({
    bool? installation,
    Discount? discount,
    bool clearDiscount = false,
    PriceSnapshot? snapshot,
    bool clearSnapshot = false,
    List<ExtraCharge>? extras,
  }) => PricingChoices(
    installation: installation ?? this.installation,
    discount: clearDiscount ? null : (discount ?? this.discount),
    snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
    extras: extras ?? this.extras,
  );

  Map<String, Object?> toJson() => {
    if (installation) 'installation': true,
    if (discount != null) 'discount': discount!.toJson(),
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
    if (extras.isNotEmpty) 'extras': [for (final e in extras) e.toJson()],
  };

  static PricingChoices fromJson(Object? json) {
    if (json is! Map<String, Object?>) return none;
    return PricingChoices(
      installation: json['installation'] == true,
      discount: Discount.fromJson(json['discount']),
      snapshot: PriceSnapshot.fromJson(json['snapshot']),
      extras: [
        if (json['extras'] case final List<Object?> kept)
          for (final e in kept) ?ExtraCharge.fromJson(e),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PricingChoices &&
      other.installation == installation &&
      other.discount == discount &&
      identical(other.snapshot, snapshot) &&
      _sameExtras(other.extras, extras);

  static bool _sameExtras(List<ExtraCharge> a, List<ExtraCharge> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(installation, discount, snapshot, Object.hashAll(extras));
}

/// Money, as the application keeps it: whole cents.
///
/// Floating-point money drifts — 10.10 and 20.20 make 30.299999… — so an
/// amount is turned into cents once, where it is charged, and only cents are
/// added from then on. A value exactly half a cent is rounded up, away from
/// nothing, whatever binary fraction it was held as.
abstract final class Money {
  /// [amount] in whole cents.
  static int cents(double amount) {
    if (!amount.isFinite) return 0;
    final hundredths = amount * 100;
    // Lift a value a hair under a half-cent back to it before rounding.
    final nudge = hundredths >= 0 ? 1e-7 : -1e-7;
    return (hundredths + nudge).round();
  }

  /// [cents] as an amount.
  static double of(int cents) => cents / 100;
}
