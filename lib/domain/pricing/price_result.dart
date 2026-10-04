/// What a price is made of, and what came of working it out.
///
/// Nothing here knows about a design. A [PriceResult] is a set of lines and
/// the sums of them, so it can be kept — a quotation's price as it stood the
/// day it was given ([PriceSnapshot]) — and read back after the price list
/// has changed, without being worked out again.
library;

import 'measurement.dart';

/// How a price came out.
enum PriceStatus {
  /// Every part was priced; [PriceResult.total] is the price.
  priced,

  /// Nothing to price yet: no outline has been read into a frame.
  nothingToPrice,

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
  final double amount;

  /// The part of the design the line is for, where it is one part.
  final String? partId;

  const PriceLine({
    required this.group,
    required this.label,
    required this.quantity,
    required this.unit,
    required this.rate,
    required this.amount,
    this.partId,
  });

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

  const Discount({this.percent = 0, this.amount = 0});

  bool get isNone => percent <= 0 && amount <= 0;

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
  };

  static Discount? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    double read(Object? v) =>
        v is num && v.isFinite && v >= 0 ? v.toDouble() : 0;
    final d = Discount(
      percent: read(json['percent']),
      amount: read(json['amount']),
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

  const PriceResult({
    required this.status,
    required this.currency,
    required this.category,
    this.lines = const [],
    this.issues = const [],
    this.priceListVersion = 0,
    this.discount,
    this.measurements = MeasurementSummary.none,
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

  double sumOf(PriceGroup group) => _sum([
    for (final l in lines)
      if (l.group == group) l.amount,
  ]);

  /// Everything before the discount, installation included.
  double get subtotal => isPriced ? _sum([for (final l in lines) l.amount]) : 0;

  double get discountAmount => isPriced ? (discount?.off(subtotal) ?? 0) : 0;

  /// What the design comes to, or null where it could not be priced.
  double? get total => isPriced ? subtotal - discountAmount : null;

  static double _sum(Iterable<double> amounts) =>
      amounts.fold(0, (a, b) => a + b);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'currency': currency,
    'category': category,
    'priceListVersion': priceListVersion,
    'lines': [for (final l in lines) l.toJson()],
    'issues': [for (final i in issues) i.toJson()],
    if (discount != null) 'discount': discount!.toJson(),
    'measurements': measurements.toJson(),
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
  );
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
  final Discount? discount;
  final PriceSnapshot? snapshot;

  const PricingChoices({
    this.installation = false,
    this.discount,
    this.snapshot,
  });

  static const none = PricingChoices();

  bool get isNone => !installation && discount == null && snapshot == null;

  PricingChoices copyWith({
    bool? installation,
    Discount? discount,
    bool clearDiscount = false,
    PriceSnapshot? snapshot,
    bool clearSnapshot = false,
  }) => PricingChoices(
    installation: installation ?? this.installation,
    discount: clearDiscount ? null : (discount ?? this.discount),
    snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
  );

  Map<String, Object?> toJson() => {
    if (installation) 'installation': true,
    if (discount != null) 'discount': discount!.toJson(),
    if (snapshot != null) 'snapshot': snapshot!.toJson(),
  };

  static PricingChoices fromJson(Object? json) {
    if (json is! Map<String, Object?>) return none;
    return PricingChoices(
      installation: json['installation'] == true,
      discount: Discount.fromJson(json['discount']),
      snapshot: PriceSnapshot.fromJson(json['snapshot']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PricingChoices &&
      other.installation == installation &&
      other.discount == discount &&
      identical(other.snapshot, snapshot);

  @override
  int get hashCode => Object.hash(installation, discount, snapshot);
}
