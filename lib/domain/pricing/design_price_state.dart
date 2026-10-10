import 'dart:convert';

import '../model/customer_discount.dart';
import '../model/design.dart';
import '../model/payment.dart';
import 'extra_charge.dart';
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

  static String of(Design design, PriceList list) =>
      _key(jsonEncode({'design': _priced(design), 'list': list.toJson()}));

  /// The design alone, without the price list: what changes when the
  /// design is edited and never when the workshop's rates are — so a
  /// quotation can say *the design changed* apart from *the prices did*.
  static String ofDesign(Design design) =>
      _key(jsonEncode({'design': _priced(design)}));

  static Map<String, Object?> _priced(Design design) {
    final kept = Map<String, Object?>.of(design.toJson())
      ..removeWhere((key, _) => _notRead.contains(key));
    if (kept['pricing'] case final Map<String, Object?> choices) {
      final priced = Map<String, Object?>.of(choices)..remove('snapshot');
      // Who wrote an extra or gave the discount, and when, says nothing of
      // the price: only what each one charges is read.
      if (priced['extras'] case final List<Object?> extras) {
        priced['extras'] = [
          for (final e in extras)
            if (e is Map<String, Object?>)
              Map<String, Object?>.of(e)
                ..remove('createdAt')
                ..remove('updatedAt')
                ..remove('by')
                ..remove('note'),
        ];
      }
      if (priced['discount'] case final Map<String, Object?> d) {
        priced['discount'] = Map<String, Object?>.of(d)
          ..remove('by')
          ..remove('at');
      }
      kept['pricing'] = priced;
    }
    return kept;
  }

  static String _key(String text) =>
      '${_fnv(text, 0x811C9DC5)}${_fnv(text, 0x050C5D1F)}-${text.length}';

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

  /// The design as it now is, without the price list
  /// (`PriceInputs.ofDesign`) — what a quotation keeps to say later whether
  /// the design changed after it was quoted.
  final String designKey;

  const CustomerDesignPrice({
    required this.designId,
    required this.name,
    required this.kind,
    required this.state,
    this.profile = ProfileSelection.notChosen,
    this.colourName = 'Not selected',
    this.designKey = '',
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
        designKey: PriceInputs.ofDesign(d),
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
  /// No total to pay, and nothing paid.
  nothingToPay('Nothing to pay'),

  /// The total is not final yet — a design is incomplete or its price is
  /// not current — so what is due, or in credit, is not known.
  pricingIncomplete('Pricing incomplete'),

  /// Less paid, net, than the total: the rest is due.
  outstanding('Outstanding'),

  /// The whole total paid, net, and no more.
  paidInFull('Paid in full'),

  /// More paid, net, than the total — overpaid, or a design deleted or
  /// made cheaper since. The customer has that much in credit.
  credit('Credit');

  const PaymentStatus(this.label);
  final String label;
}

/// A customer's money: what their designs come to, less any discount, what
/// the ledger says they have paid, and what is due — or in credit.
///
/// ```
/// Design prices ─ CustomerPricing ─┐
/// Customer.extras ─────────────────┴─ subtotal ─ discount ─ final total ─┐
/// Customer.payments ─ PaymentLedger ─ net paid ───────────────────────────┴─
///                                      CustomerFinance (due or credit)
/// ```
///
/// **The order is fixed, and nothing is taken off twice.** Each design's
/// price is already its own cost, plus its own extras, less its own
/// discount (`PriceResult.total`). Here those prices are summed, the
/// customer's own extras — a delivery for the whole job — are added, and
/// the customer's discount is taken off that once.
///
/// - Designs = the designs' current prices, summed ([designsCents]).
/// - Extras = the customer's own extras in the customer's currency
///   ([extrasCents]). An extra in another currency is never added: while
///   there is one, the total is not final ([extrasInOtherCurrency]).
/// - Subtotal = designs + extras.
/// - Discount = what the customer's discount takes off the subtotal.
/// - Final total = subtotal − discount.
/// - Gross payments = every payment; gross refunds = every refund — each
///   counted in the customer's currency: recorded in it, or converted into
///   it at a rate kept with it. Money in another currency with no rate is
///   never added; it is listed in its own ([otherCurrencies]).
/// - Net paid = gross payments − gross refunds.
/// - Balance = final total − net paid: more than nothing is **due**, less
///   than nothing is **credit**, nothing is **paid in full**. Neither is
///   ever written as a negative figure.
///
/// A discount is not a payment and a payment is not a discount: one lowers
/// what is owed, the other is money received. A quotation is neither — it
/// is what was offered, kept as it was (`Quotation`), and adds nothing.
///
/// The total is never typed and never kept: it is [CustomerPricing]'s. What
/// was paid is never kept either: it is the ledger's, summed. Everything is
/// whole cents, never a figure rounded for the screen. Nothing here touches
/// a design or a price.
class CustomerFinance {
  final CustomerPricing pricing;
  final PaymentLedger ledger;

  /// The customer's discount in force, if any.
  final CustomerDiscount? discount;

  /// The customer's own extras — the whole job's, no one design's.
  final List<ExtraCharge> extras;

  const CustomerFinance._(
    this.pricing,
    this.ledger,
    this.discount,
    this.extras,
  );

  static CustomerFinance of(
    CustomerPricing pricing,
    PaymentLedger ledger, {
    CustomerDiscount? discount,
    List<ExtraCharge> extras = const [],
  }) => CustomerFinance._(pricing, ledger, discount, extras);

  /// The designs' current prices summed, where every one is current.
  int? get designsCents => pricing.totalCents;

  /// The customer's own extras in [currency], summed.
  int get extrasCents => extras.totalCentsIn(currency);

  /// The customer's extras written in another currency: never added to
  /// [currency], and keeping the total from being final until they are
  /// written in it.
  List<ExtraCharge> get extrasInOtherCurrency => extras.notIn(currency);

  /// The customer's currency: the one their designs are priced in.
  String get currency => pricing.currency;

  int get grossPaymentsCents => ledger.grossPaymentsCents(currency);
  int get grossRefundsCents => ledger.grossRefundsCents(currency);
  int get netPaidCents => ledger.netPaidCents(currency);

  double get grossPayments => grossPaymentsCents / 100;
  double get grossRefunds => grossRefundsCents / 100;
  double get netPaid => netPaidCents / 100;

  /// How many transactions are in a currency that cannot be counted in
  /// [currency] — recorded in another, with no rate. Not counted, and said.
  int get otherCurrency => ledger.otherCurrencyCount(currency);

  /// That money, currency by currency.
  List<CurrencyTotals> get otherCurrencies => ledger.uncountedIn(currency);

  /// The designs' prices and the customer's extras, summed, where final.
  int? get subtotalCents => switch (designsCents) {
    final d? when extrasInOtherCurrency.isEmpty => d + extrasCents,
    _ => null,
  };

  double? get subtotal => subtotalCents == null ? null : subtotalCents! / 100;

  /// Why the total is not final, in words, or empty where it is.
  String get notFinalReason {
    final other = extrasInOtherCurrency;
    return [
      if (pricing.notFinalReason.isNotEmpty) pricing.notFinalReason,
      if (other.isNotEmpty)
        '${other.length == 1 ? 'An extra charge is' : '${other.length} extra charges are'} '
            'in ${{for (final e in other) e.currency}.join(', ')}, not '
            '$currency.',
    ].join(' ');
  }

  /// What the discount takes off the subtotal, where it is final.
  int? get discountCents => switch (subtotalCents) {
    final s? => discount?.offCents(s, currency) ?? 0,
    null => null,
  };

  /// Whether a fixed discount is now more than the subtotal it was given
  /// against — it takes the whole subtotal and no more, and is said.
  bool get discountExceedsSubtotal => switch (subtotalCents) {
    final s? => discount?.exceeds(s) ?? false,
    null => false,
  };

  /// What the customer owes for their designs: the subtotal less the
  /// discount, where final.
  int? get totalCents => switch (subtotalCents) {
    final s? => s - discountCents!,
    null => null,
  };

  double? get total => totalCents == null ? null : totalCents! / 100;

  /// The final total less the net paid, in whole cents, where it is final.
  int? get balanceCents => switch (totalCents) {
    final t? => t - netPaidCents,
    null => null,
  };

  /// What is still owed, where the total is final: never below nothing.
  int? get dueCents => switch (balanceCents) {
    final b? => b > 0 ? b : 0,
    null => null,
  };

  /// What the customer has in credit, where the total is final: never below
  /// nothing.
  int? get creditCents => switch (balanceCents) {
    final b? => b < 0 ? -b : 0,
    null => null,
  };

  double? get due => switch (dueCents) {
    final c? => c / 100,
    null => null,
  };

  double? get credit => switch (creditCents) {
    final c? => c / 100,
    null => null,
  };

  PaymentStatus get status {
    final t = totalCents;
    if (t == null) return PaymentStatus.pricingIncomplete;
    final balance = t - netPaidCents;
    if (balance > 0) return PaymentStatus.outstanding;
    if (balance < 0) return PaymentStatus.credit;
    return t == 0 && netPaidCents == 0
        ? PaymentStatus.nothingToPay
        : PaymentStatus.paidInFull;
  }
}
