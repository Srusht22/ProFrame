import 'dart:convert';

import '../model/design.dart';
import 'measurement.dart';
import 'price_list.dart';
import 'price_readiness.dart';
import 'price_result.dart';
import 'pricing_engine.dart';
import 'profile_selection.dart';

/// A price the user calculated, kept with what it was calculated from.
///
/// **A kept price is only a price while nothing it was worked out from has
/// changed.** [inputs] says exactly what that was — the design's geometry,
/// its sizes, materials, ironmongery and pricing choices, and the price
/// list — so a design edited afterwards, or a price list changed, makes it
/// a previous calculation and never the current price. See
/// [PriceInputs.of].
///
/// It is the price's, kept beside the design by its id and never in it:
/// calculating a price writes nothing to the design.
class PriceRecord {
  final String inputs;
  final DateTime calculatedAt;
  final PriceResult result;

  const PriceRecord({
    required this.inputs,
    required this.calculatedAt,
    required this.result,
  });

  /// [design] calculated now from [list] by [engine], or null where it
  /// cannot be priced — a calculation is only ever kept when it gave a
  /// price.
  static PriceRecord? calculate(
    Design design,
    PriceList list, {
    PricingEngine engine = const PricingEngine(),
    DateTime? at,
  }) {
    final result = engine.price(design, list);
    if (!result.isPriced) return null;
    return PriceRecord(
      inputs: PriceInputs.of(design, list),
      calculatedAt: at ?? DateTime.now(),
      result: result,
    );
  }

  double get total => result.total ?? 0;

  Map<String, Object?> toJson() => {
    'inputs': inputs,
    'calculatedAt': calculatedAt.toIso8601String(),
    'result': result.toJson(),
  };

  /// A record read back, or null where it cannot be: a record that cannot
  /// be read is no price at all, never a price of nothing.
  static PriceRecord? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      final result = PriceResult.fromJson(
        json['result']! as Map<String, Object?>,
      );
      if (!result.isPriced) return null;
      return PriceRecord(
        inputs: json['inputs']! as String,
        calculatedAt: DateTime.parse(json['calculatedAt']! as String),
        result: result,
      );
    } on Object {
      return null;
    }
  }
}

/// What a price is worked out from, as one short string.
///
/// The design as it is kept, less what a price never reads — who and what
/// it is called, when it was made and edited, the ink it was read from,
/// the notes and arrows written on it, and any price kept in it — and the
/// price list. Two designs that would be priced alike from the same list
/// give the same string; change a size, a line, a material, a colour, a
/// glass, a hinge or a rate and it changes.
abstract final class PriceInputs {
  static const _notRead = {
    'id',
    'name',
    'customer',
    'customerId',
    'createdAt',
    'updatedAt',
    'sketch',
    'sketchUnread',
    'texts',
    'arrows',
  };

  static String of(Design design, PriceList list) {
    final kept = Map<String, Object?>.of(design.toJson())
      ..removeWhere((key, _) => _notRead.contains(key));
    if (kept['pricing'] case final Map<String, Object?> choices) {
      kept['pricing'] = Map<String, Object?>.of(choices)..remove('snapshot');
    }
    final text = jsonEncode({'design': kept, 'list': list.toJson()});
    return '${_fnv(text, 0x811C9DC5)}${_fnv(text, 0x050C5D1F)}'
        '-${text.length}';
  }

  /// FNV-1a over the text's code units, 32 bits, written the same on every
  /// platform: the multiply is split so no step leaves the 53 bits a web
  /// number holds exactly.
  static String _fnv(String text, int seed) {
    var h = seed;
    for (final c in text.codeUnits) {
      h = (h ^ c) & 0xFFFFFFFF;
      h = (h * 0x193 + ((h & 0xFF) << 24)) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }
}

/// Where a design's price stands.
enum DesignPriceStatus {
  /// Calculated, and nothing it was calculated from has changed.
  current,

  /// Complete, and never calculated.
  notCalculated,

  /// Complete, and calculated before — but the design or the price list
  /// has changed since, so that figure is a previous calculation.
  needsRecalculation,

  /// Something the price depends on is still to be completed.
  incomplete,

  /// A category this version does not know.
  unsupported,

  /// Complete, but the price list has no price for something in it.
  unavailable;

  /// Whether the user can calculate it now.
  bool get canCalculate =>
      this == current || this == notCalculated || this == needsRecalculation;
}

/// A design's price as every screen shows it: the one answer the
/// workspace, its card and its customer's total all read.
///
/// ```
/// Design ─ PriceReadiness ─ PricingEngine ─ PriceRecord? ─ DesignPriceState
/// ```
class DesignPriceState {
  final DesignPriceStatus status;
  final PriceReadiness readiness;

  /// The price kept for the design, current or not. Only [current] is a
  /// price; anything else is a previous calculation.
  final PriceRecord? record;

  /// Why it cannot be calculated, where it cannot.
  final String reason;

  /// Where the profile's colour stops the price and is for the user to
  /// choose again — a colour not sold in the material now chosen, or a
  /// retired one no longer priced on it. The price sheet is where it is
  /// chosen, so its button opens it to choose one.
  final bool needsColour;

  const DesignPriceState._(
    this.status,
    this.readiness, {
    this.record,
    this.reason = '',
    this.needsColour = false,
  });

  static DesignPriceState of(
    Design design,
    PriceList list,
    PriceRecord? record, {
    PricingEngine engine = const PricingEngine(),
  }) {
    final readiness = PriceReadiness.of(design);
    if (design.isUnsupported) {
      return DesignPriceState._(
        DesignPriceStatus.unsupported,
        readiness,
        record: record,
        reason: 'Unsupported category. Price unavailable.',
      );
    }
    if (!readiness.isPriceCalculable) {
      return DesignPriceState._(
        DesignPriceStatus.incomplete,
        readiness,
        record: record,
        reason: readiness.message,
      );
    }
    // The profile's colour, by material and colour together. One the user
    // has to choose again is the design still to be completed; one the
    // list does not price is the list's to put right.
    if (ProfileSelection.of(design).colourIn(list) case final colour?
        when !colour.isPriced && colour.state != ColourPricingState.noProfile) {
      return DesignPriceState._(
        colour.needsSelection
            ? DesignPriceStatus.incomplete
            : DesignPriceStatus.unavailable,
        readiness,
        record: record,
        reason: colour.problem!,
        needsColour: colour.needsSelection,
      );
    }
    final result = engine.price(design, list);
    if (!result.isPriced) {
      return DesignPriceState._(
        DesignPriceStatus.unavailable,
        readiness,
        record: record,
        reason: result.issues.isEmpty
            ? 'The price list cannot price this design.'
            : result.issues.first.message,
      );
    }
    if (record == null) {
      return DesignPriceState._(DesignPriceStatus.notCalculated, readiness);
    }
    if (record.inputs == PriceInputs.of(design, list)) {
      return DesignPriceState._(
        DesignPriceStatus.current,
        readiness,
        record: record,
      );
    }
    return DesignPriceState._(
      DesignPriceStatus.needsRecalculation,
      readiness,
      record: record,
    );
  }

  bool get canCalculate => status.canCalculate;
  bool get isCurrent => status == DesignPriceStatus.current;

  /// The price, only while it is current.
  double? get total => isCurrent ? record!.total : null;

  /// A price calculated before that is no longer the price, if there is
  /// one — shown only as that.
  double? get previous => !isCurrent ? record?.result.total : null;

  /// The design's state in a word or two, for its card.
  /// Whether what stops it is only that the drawing has not been read.
  bool get notRead =>
      status == DesignPriceStatus.incomplete &&
      readiness.missing.firstOrNull?.kind == PriceRequirementKind.notRead;

  /// Whether what stops it is only that nobody has chosen its profile's
  /// material and colour, or a colour it can be priced in — which the
  /// price sheet itself is where they are chosen, so its button opens it to
  /// choose them.
  bool get needsOnlyProfile =>
      needsColour ||
      status == DesignPriceStatus.incomplete &&
          readiness.missing.length == 1 &&
          readiness.missing.single.kind == PriceRequirementKind.profile;

  String get label => switch (status) {
    _ when notRead => 'Drawing not read',
    DesignPriceStatus.current => 'Complete',
    DesignPriceStatus.notCalculated => 'Complete',
    DesignPriceStatus.needsRecalculation => 'Complete',
    DesignPriceStatus.incomplete => 'Incomplete',
    DesignPriceStatus.unsupported => 'Unsupported category',
    DesignPriceStatus.unavailable => 'Complete',
  };

  /// What the price line says where there is no current price.
  String get note => switch (status) {
    _ when notRead => 'Price unavailable until drawing is read',
    DesignPriceStatus.current => '',
    DesignPriceStatus.notCalculated => 'Not calculated yet',
    DesignPriceStatus.needsRecalculation => 'Price needs recalculation',
    DesignPriceStatus.incomplete =>
      'Price unavailable until design is completed',
    DesignPriceStatus.unsupported => 'Price unavailable',
    DesignPriceStatus.unavailable => 'Price unavailable',
  };

  /// What to tell the user who reaches for the price and cannot have it:
  /// the exact thing to complete, where it is known.
  String get message => switch (status) {
    DesignPriceStatus.incomplete ||
    DesignPriceStatus.unsupported ||
    DesignPriceStatus.unavailable => reason,
    DesignPriceStatus.needsRecalculation =>
      'The design or the prices changed since this price was calculated. '
          'Calculate it again.',
    DesignPriceStatus.notCalculated => 'Calculate the price.',
    DesignPriceStatus.current => '',
  };
}

/// One design among a customer's, with where its price stands.
class CustomerDesignPrice {
  final String designId;
  final String name;
  final DesignKind kind;
  final DesignPriceState state;

  /// What its profile is made of — the material and colour its price reads
  /// — so a summary says why two designs cost different amounts.
  final ProfileSelection profile;

  /// What the colour is called, by the price list it was priced from.
  final String colourName;

  const CustomerDesignPrice({
    required this.designId,
    required this.name,
    required this.kind,
    required this.state,
    this.profile = ProfileSelection.notChosen,
    this.colourName = 'Not selected',
  });
}

/// Whether a customer's total can be quoted.
enum CustomerTotalStatus {
  /// No designs, so nothing to price.
  noDesigns,

  /// Every design has a current price: the total is the price.
  isFinal,

  /// Every design is complete, but one or more has no current price.
  needsRecalculation,

  /// One or more designs is incomplete or cannot be priced at all.
  notFinal,
}

/// What a customer's designs come to: each design's own price, summed.
///
/// **Worked out from the designs, never kept on the customer.** A design
/// recalculated changes the total at once, and a design that has no
/// current price — incomplete, changed since it was calculated, or of a
/// category that cannot be priced — keeps the total from being final, so a
/// sum of some of the prices is never shown as the customer's price.
class CustomerPricing {
  final List<CustomerDesignPrice> designs;
  final String currency;

  const CustomerPricing(this.designs, this.currency);

  static CustomerPricing of(
    Iterable<(Design, PriceRecord?)> designs,
    PriceList list, {
    PricingEngine engine = const PricingEngine(),
  }) => CustomerPricing([
    for (final (d, record) in designs)
      CustomerDesignPrice(
        designId: d.id,
        name: d.shownName,
        kind: d.kind,
        state: DesignPriceState.of(d, list, record, engine: engine),
        profile: ProfileSelection.of(d),
        colourName: ProfileSelection.of(d).colourName(list),
      ),
  ], list.currency);

  Iterable<CustomerDesignPrice> _where(bool Function(DesignPriceStatus) is_) =>
      designs.where((d) => is_(d.state.status));

  List<CustomerDesignPrice> get priced =>
      _where((s) => s == DesignPriceStatus.current).toList();

  /// Designs still to be completed.
  int get incomplete => _where((s) => s == DesignPriceStatus.incomplete).length;

  /// Designs that cannot be priced at all: a category this version does
  /// not know, or something the price list has no price for.
  int get cannotBePriced => _where(
    (s) =>
        s == DesignPriceStatus.unsupported ||
        s == DesignPriceStatus.unavailable,
  ).length;

  /// Designs complete but without a current price.
  int get toCalculate => _where(
    (s) =>
        s == DesignPriceStatus.notCalculated ||
        s == DesignPriceStatus.needsRecalculation,
  ).length;

  CustomerTotalStatus get status {
    if (designs.isEmpty) return CustomerTotalStatus.noDesigns;
    if (incomplete > 0 || cannotBePriced > 0) {
      return CustomerTotalStatus.notFinal;
    }
    if (toCalculate > 0) return CustomerTotalStatus.needsRecalculation;
    return CustomerTotalStatus.isFinal;
  }

  bool get isFinal =>
      status == CustomerTotalStatus.isFinal ||
      status == CustomerTotalStatus.noDesigns;

  /// The sum of the current prices — the customer's total only where
  /// [isFinal]; otherwise what is priced so far, and never shown as more.
  double get pricedSoFar => pricedSoFarCents / 100;

  /// [pricedSoFar] in whole cents: each design's own total, as cents,
  /// summed — never a sum of rounded figures.
  int get pricedSoFarCents =>
      priced.fold(0, (sum, d) => sum + d.state.record!.result.totalCents!);

  /// [total] in whole cents, where it is final.
  int? get totalCents => isFinal ? pricedSoFarCents : null;

  /// The customer's total, only where it is final.
  double? get total => isFinal ? pricedSoFar : null;

  /// What the currently priced designs measure, together — profile in
  /// metres, panel and glass in square metres, never added to each other.
  MeasurementSummary get measurements => priced.fold(
    MeasurementSummary.none,
    (sum, d) => sum + d.state.record!.result.measurements,
  );

  /// Why the total is not final, in words.
  String get notFinalReason {
    String designs_(int n) => n == 1 ? '1 design' : '$n designs';
    final parts = [
      if (incomplete > 0)
        '${designs_(incomplete)} ${incomplete == 1 ? 'is' : 'are'} '
            'incomplete',
      if (cannotBePriced > 0) '${designs_(cannotBePriced)} cannot be priced',
      if (toCalculate > 0)
        '${designs_(toCalculate)} ${toCalculate == 1 ? 'needs' : 'need'} '
            '${toCalculate == 1 ? 'its price' : 'their prices'} calculated',
    ];
    return parts.isEmpty ? '' : '${parts.join(', ')}.';
  }
}

/// How a customer stands with what they owe.
enum PaymentStatus {
  /// No designs, and nothing paid.
  nothingToPay('Nothing to pay'),

  /// The total is not final yet, so what is due is not known.
  totalNotFinal('Total not final'),

  /// Nothing paid against a final total.
  notPaid('Not paid'),

  /// Some paid; the rest is due.
  partiallyPaid('Amount due'),

  /// The whole total paid.
  paidInFull('Paid in full'),

  /// More recorded as paid than the total now comes to — a design deleted
  /// or made cheaper after the payment. Said, never turned into a debt
  /// below nothing.
  paidExceedsTotal('Paid exceeds total');

  const PaymentStatus(this.label);
  final String label;
}

/// A customer's money: what their designs come to, what they have paid,
/// and what is still due.
///
/// ```
/// Design prices ─ CustomerPricing ─ total ─┐
///                         Customer.paid ───┴─ CustomerFinance (due, status)
/// ```
///
/// The total is never typed and never kept: it is [CustomerPricing]'s. The
/// one figure kept is what was paid. Nothing here touches a design.
class CustomerFinance {
  final CustomerPricing pricing;

  /// What has been paid, in whole cents.
  final int paidCents;

  const CustomerFinance._(this.pricing, this.paidCents);

  /// [pricing] against [paid] in all. The customer's one kept figure is a
  /// running total paid (`Customer.paid`); a later history of payments —
  /// dates, methods, receipts — sums to the same figure, so nothing here
  /// changes when there is one.
  static CustomerFinance of(CustomerPricing pricing, double paid) =>
      CustomerFinance._(
        pricing,
        paid.isFinite && paid > 0 ? Money.cents(paid) : 0,
      );

  double get paid => paidCents / 100;

  double? get total => pricing.total;

  /// What is still owed, in whole cents, where the total is final: never
  /// below nothing.
  int? get dueCents {
    final t = pricing.totalCents;
    if (t == null) return null;
    return paidCents >= t ? 0 : t - paidCents;
  }

  double? get due => switch (dueCents) {
    final c? => c / 100,
    null => null,
  };

  /// How much more is recorded as paid than the total, where it is. Not
  /// credit — there is no credit yet — only said, so it is never a debt
  /// below nothing.
  double get excess {
    final t = pricing.totalCents;
    if (t == null || paidCents <= t) return 0;
    return (paidCents - t) / 100;
  }

  PaymentStatus get status {
    final t = pricing.totalCents;
    if (t == null) return PaymentStatus.totalNotFinal;
    if (paidCents > t) return PaymentStatus.paidExceedsTotal;
    if (t == 0) return PaymentStatus.nothingToPay;
    if (paidCents == 0) return PaymentStatus.notPaid;
    if (paidCents >= t) return PaymentStatus.paidInFull;
    return PaymentStatus.partiallyPaid;
  }

  /// Why [amount] cannot be recorded as paid against [pricing], or null
  /// where it can. Overpayment — credit — is not something this records:
  /// against a final total, more than it is refused.
  static String? problemWithPaid(double? amount, CustomerPricing pricing) {
    if (amount == null || !amount.isFinite) {
      return 'Enter the amount paid as a number.';
    }
    if (amount < 0) return 'The paid amount cannot be less than nothing.';
    final t = pricing.totalCents;
    if (t != null && Money.cents(amount) > t) {
      return 'Paid amount cannot exceed the total price.';
    }
    return null;
  }
}
