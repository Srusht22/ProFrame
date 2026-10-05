import '../model/customer_discount.dart';
import 'design_price_state.dart';
import 'price_result.dart';

/// Where a quotation stands.
enum QuotationStatus {
  draft('Draft'),
  issued('Issued'),
  accepted('Accepted'),
  rejected('Rejected'),
  expired('Expired');

  const QuotationStatus(this.label);
  final String label;

  /// What it may become next. A draft is issued; an issued quotation is
  /// accepted, rejected or lets expire; those three are where it ends.
  /// Nothing goes back, and nothing is deleted — a quotation is a record of
  /// what was offered.
  List<QuotationStatus> get next => switch (this) {
    draft => const [issued],
    issued => const [accepted, rejected, expired],
    accepted || rejected || expired => const [],
  };

  static QuotationStatus? byName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// One design on a quotation, as it was priced when the quotation was
/// made.
class QuotationLine {
  final String designId;
  final String designName;
  final String category;
  final String material;
  final String colour;

  /// The design's price, in whole cents of the quotation's currency.
  final int totalCents;

  /// The whole price as it was worked out — every line, rate and
  /// measurement — kept, never worked out again.
  final PriceResult result;

  /// The design as it was (`PriceInputs.ofDesign`), to tell later whether
  /// it has changed since.
  final String designKey;

  const QuotationLine({
    required this.designId,
    required this.designName,
    required this.category,
    required this.material,
    required this.colour,
    required this.totalCents,
    required this.result,
    required this.designKey,
  });

  Map<String, Object?> toJson() => {
    'designId': designId,
    'designName': designName,
    'category': category,
    'material': material,
    'colour': colour,
    'totalCents': totalCents,
    'result': result.toJson(),
    'designKey': designKey,
  };

  static QuotationLine? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      return QuotationLine(
        designId: json['designId']! as String,
        designName: json['designName']! as String,
        category: json['category'] as String? ?? '',
        material: json['material'] as String? ?? '',
        colour: json['colour'] as String? ?? '',
        totalCents: json['totalCents']! as int,
        result: PriceResult.fromJson(json['result']! as Map<String, Object?>),
        designKey: json['designKey'] as String? ?? '',
      );
    } on Object {
      return null;
    }
  }
}

/// A change of a quotation's status, and who made it when.
class QuotationStatusChange {
  final QuotationStatus status;
  final DateTime at;
  final String by;

  const QuotationStatusChange(this.status, this.at, this.by);

  Map<String, Object?> toJson() => {
    'status': status.name,
    'at': at.toIso8601String(),
    'by': by,
  };

  static QuotationStatusChange? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final status = QuotationStatus.byName(json['status']);
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (status == null || at == null) return null;
    return QuotationStatusChange(status, at, json['by'] as String? ?? '');
  }
}

/// What the workshop offered a customer, at the moment it offered it.
///
/// ```
/// designs' current prices ─ subtotal ─ discount ─ final total
///                    └──────── kept as they were ────────┘
///                               Quotation
/// ```
///
/// **A quotation is a snapshot, never a live figure.** Each design's whole
/// price result is kept in it ([QuotationLine.result]), with the subtotal,
/// the discount as it was given and what it took off, and the final total.
/// Nothing in it is worked out again: when the factory's rates change, or a
/// design is edited, an old quotation still says what was offered, and a
/// new quotation is how a new figure is given. It can say that a design has
/// changed since ([changedDesigns]); it never rewrites itself to match.
///
/// **A quotation is not a charge.** What a customer owes is their designs'
/// current prices less their discount (`CustomerFinance`); a quotation adds
/// nothing to it, and is never added to a payment.
///
/// Only designs with a current price go on one: an incomplete design, or
/// one that cannot be priced, stops it being made ([build]) — the same
/// completeness every price button reads (`PriceReadiness`). Nothing is
/// deleted: a quotation ends accepted, rejected or expired.
class Quotation {
  /// Stable, with its number: `Q-000001`.
  final String id;
  final int number;
  final String customerId;

  /// Who it was for, as they were called then.
  final String customerName;

  final DateTime createdAt;
  final DateTime updatedAt;
  final QuotationStatus status;
  final String currency;
  final List<QuotationLine> lines;
  final int subtotalCents;

  /// The customer's discount as it stood when it was made, if any.
  final CustomerDiscount? discount;
  final int discountCents;
  final int totalCents;

  /// The price list its prices came from, by version.
  final int priceListVersion;

  final String notes;
  final String createdBy;
  final List<QuotationStatusChange> history;

  const Quotation({
    required this.id,
    required this.number,
    required this.customerId,
    required this.customerName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.currency,
    required this.lines,
    required this.subtotalCents,
    required this.discountCents,
    required this.totalCents,
    required this.priceListVersion,
    this.discount,
    this.notes = '',
    this.createdBy = '',
    this.history = const [],
  });

  /// [number] as it is written: `Q-000001`.
  static String numbered(int number) =>
      'Q-${number.toString().padLeft(6, '0')}';

  String get label => numbered(number);

  /// The message given where a design chosen for a quotation cannot be on
  /// one.
  static const incompleteMessage =
      'Please complete all selected designs before creating the quotation.';

  /// A new draft quotation for [chosen] — a customer's designs, each with
  /// where its price stands — numbered [number], made at [now] by [by]; or
  /// why it cannot be made.
  ///
  /// Every design chosen must have a current price: one incomplete, not
  /// calculated, changed since it was calculated, or that cannot be priced
  /// at all stops it, and is named. [discount] — the customer's in force —
  /// is taken off the subtotal of the designs chosen; a fixed amount more
  /// than that subtotal stops it too, never giving a figure below nothing.
  static ({Quotation? quotation, String? problem}) build({
    required String customerId,
    required String customerName,
    required List<CustomerDesignPrice> chosen,
    required String currency,
    required int number,
    required DateTime now,
    required String by,
    required String Function(int cents) money,
    CustomerDiscount? discount,
    String notes = '',
  }) {
    if (chosen.isEmpty) {
      return (quotation: null, problem: 'Choose at least one design.');
    }
    final notReady = [
      for (final d in chosen)
        if (!d.state.isCurrent) d.name,
    ];
    if (notReady.isNotEmpty) {
      return (
        quotation: null,
        problem: '$incompleteMessage Not ready: ${notReady.join(', ')}.',
      );
    }
    final lines = [
      for (final d in chosen)
        QuotationLine(
          designId: d.designId,
          designName: d.name,
          category: d.kind.label,
          material: d.profile.materialName,
          colour: d.colourName,
          totalCents: d.state.record!.result.totalCents!,
          result: d.state.record!.result,
          designKey: d.designKey,
        ),
    ];
    final subtotal = lines.fold(0, (s, l) => s + l.totalCents);
    if (discount != null && discount.exceeds(subtotal)) {
      return (
        quotation: null,
        problem:
            'The discount of ${discount.describe(money)} is more than this '
            "quotation's subtotal, ${money(subtotal)}.",
      );
    }
    final off = discount?.offCents(subtotal, currency) ?? 0;
    final versions = {
      for (final d in chosen) d.state.record!.result.priceListVersion,
    };
    return (
      quotation: Quotation(
        id: numbered(number),
        number: number,
        customerId: customerId,
        customerName: customerName,
        createdAt: now,
        updatedAt: now,
        status: QuotationStatus.draft,
        currency: currency,
        lines: lines,
        subtotalCents: subtotal,
        discount: discount,
        discountCents: off,
        totalCents: subtotal - off,
        priceListVersion: versions.reduce((a, b) => a > b ? a : b),
        notes: notes.trim(),
        createdBy: by,
        history: [QuotationStatusChange(QuotationStatus.draft, now, by)],
      ),
      problem: null,
    );
  }

  /// This quotation become [next] at [at] by [by] — or why it cannot.
  /// Only the status changes: every figure stays as it was offered.
  ({Quotation? quotation, String? problem}) become(
    QuotationStatus next, {
    required DateTime at,
    required String by,
  }) {
    if (!status.next.contains(next)) {
      return (
        quotation: null,
        problem:
            'A quotation that is ${status.label.toLowerCase()} cannot become '
            '${next.label.toLowerCase()}.',
      );
    }
    return (
      quotation: Quotation(
        id: id,
        number: number,
        customerId: customerId,
        customerName: customerName,
        createdAt: createdAt,
        updatedAt: at,
        status: next,
        currency: currency,
        lines: lines,
        subtotalCents: subtotalCents,
        discount: discount,
        discountCents: discountCents,
        totalCents: totalCents,
        priceListVersion: priceListVersion,
        notes: notes,
        createdBy: createdBy,
        history: [...history, QuotationStatusChange(next, at, by)],
      ),
      problem: null,
    );
  }

  /// The designs on it that have changed since — edited, by
  /// [currentDesignKeys] (`designId` → `PriceInputs.ofDesign`), or gone,
  /// where a design is no longer there. It is said; nothing is rewritten.
  List<QuotationLine> changedDesigns(Map<String, String> currentDesignKeys) => [
    for (final l in lines)
      if (currentDesignKeys[l.designId] != l.designKey) l,
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'customerId': customerId,
    'customerName': customerName,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.name,
    'currency': currency,
    'lines': [for (final l in lines) l.toJson()],
    'subtotalCents': subtotalCents,
    if (discount != null) 'discount': discount!.toJson(),
    'discountCents': discountCents,
    'totalCents': totalCents,
    'priceListVersion': priceListVersion,
    if (notes.isNotEmpty) 'notes': notes,
    if (createdBy.isNotEmpty) 'createdBy': createdBy,
    'history': [for (final h in history) h.toJson()],
  };

  /// A quotation as kept, or null where the record is not one.
  static Quotation? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    try {
      final number = json['number']! as int;
      final status = QuotationStatus.byName(json['status']);
      if (status == null) return null;
      final lines = [
        for (final l in json['lines']! as List<Object?>)
          ?QuotationLine.fromJson(l),
      ];
      return Quotation(
        id: numbered(number),
        number: number,
        customerId: json['customerId']! as String,
        customerName: json['customerName'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt']! as String),
        updatedAt: DateTime.parse(json['updatedAt']! as String),
        status: status,
        currency: json['currency']! as String,
        lines: lines,
        subtotalCents: json['subtotalCents']! as int,
        discount: CustomerDiscount.fromJson(json['discount']),
        discountCents: json['discountCents'] as int? ?? 0,
        totalCents: json['totalCents']! as int,
        priceListVersion: json['priceListVersion'] as int? ?? 0,
        notes: json['notes'] as String? ?? '',
        createdBy: json['createdBy'] as String? ?? '',
        history: [
          if (json['history'] case final List<Object?> h)
            for (final c in h) ?QuotationStatusChange.fromJson(c),
        ],
      );
    } on Object {
      return null;
    }
  }
}
