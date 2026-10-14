import '../pricing/extra_charge.dart';
import 'customer_discount.dart';
import 'payment.dart';
import 'receipt.dart';

/// A person the workshop draws for.
///
/// **A customer is not a design.** One customer has many designs — the
/// basement door, the front entrance, the kitchen window — and each design
/// belongs to exactly one customer, by `Design.customerId`. The customer
/// holds what is true of the person: how to reach them and what the
/// workshop needs to remember about them. None of it is geometry, so none of
/// it is in a design, and none of a design is in here: a customer's designs
/// are the designs naming its [id], found by asking for them, never a copy
/// kept on the customer.
///
/// ```
/// Customer                    Design
///   id  ◄──────────────────── customerId
///   name                        id
///   phone                       name
///   address                     kind  (door, window, door & window, sliding)
///   notes                       the drawing and its geometry
/// ```
class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;

  /// Every payment and refund recorded for the customer, in the order they
  /// were recorded — the one record of their money. What they have paid is
  /// worked out from it (`PaymentLedger`), never kept beside it; what their
  /// designs come to is worked out from the designs (`CustomerPricing`);
  /// and what is due or in credit is the one less the other
  /// (`CustomerFinance`). Nothing removes a transaction.
  ///
  /// A customer kept before the ledger carried one figure, `paid`. Read,
  /// it becomes one payment of that amount — [PaymentTransaction.legacyId],
  /// dated when the customer was last changed — so the money is never
  /// lost, and reading it again gives the same one payment, never a
  /// second. The next time the customer is kept, the ledger is written and
  /// the old figure is not.
  final List<PaymentTransaction> payments;

  /// Every discount given and taken away, oldest first — the one in force
  /// is the last, unless it was a removal (`DiscountLog.inForce`). Nothing
  /// is removed from it.
  final List<CustomerDiscount> discounts;

  /// The receipts issued for the customer's payments, one at most a
  /// payment. Nothing is removed from it.
  final List<Receipt> receipts;

  /// What the factory charges for the customer's whole job beyond their
  /// designs — a trip to deliver it all, say — each quantity × unit price
  /// (`ExtraCharge`). Belonging to no one design, they are added to the
  /// designs' prices before the customer's discount. Unlike money received,
  /// an extra can be changed or taken away while it is only a charge.
  final List<ExtraCharge> extras;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone = '',
    this.address = '',
    this.notes = '',
    this.payments = const [],
    this.discounts = const [],
    this.receipts = const [],
    this.extras = const [],
  });

  /// The customer's payments and refunds, and what they come to.
  PaymentLedger get ledger => PaymentLedger(payments);

  /// The discount in force, if any.
  CustomerDiscount? get discount => discounts.inForce;

  /// The receipt issued for the payment [transactionId], if one was.
  Receipt? receiptFor(String transactionId) =>
      receipts.where((r) => r.transactionId == transactionId).firstOrNull;

  /// [name] said the same way twice, whatever the spacing and the case —
  /// how the application recognises the person a design was typed as being
  /// for, while that name is all it has been told.
  static String keyOf(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// This customer with what was changed, and [updatedAt] stamped now
  /// unless given.
  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
    List<PaymentTransaction>? payments,
    List<CustomerDiscount>? discounts,
    List<Receipt>? receipts,
    List<ExtraCharge>? extras,
    DateTime? updatedAt,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    payments: payments ?? this.payments,
    discounts: discounts ?? this.discounts,
    receipts: receipts ?? this.receipts,
    extras: extras ?? this.extras,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  /// Whether a search for [query] finds this customer: by name or by phone
  /// number, whatever the case — and a number found however it was spaced.
  bool matches(String query) {
    final wanted = query.trim().toLowerCase();
    if (wanted.isEmpty) return true;
    if (name.toLowerCase().contains(wanted)) return true;
    // A phone number only when what was typed is one — figures, spaces and
    // the marks a number is written with — so a name with a figure in it
    // is not also found in everybody's phone number.
    if (!RegExp(r'^[0-9+\-().\s]+$').hasMatch(wanted)) return false;
    final digits = _significant(wanted);
    return digits.isNotEmpty && _significant(phone).contains(digits);
  }

  /// A phone number's digits without whatever only says how it is dialled:
  /// the `+` or `00` before a country code, and the `0` a number is dialled
  /// with at home. So `0750 123 4567` and `+964 750 123 4567` — the same
  /// number, written the local way and the international way — are both
  /// found by either.
  static String _significant(String number) {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) return digits.substring(2);
    if (digits.startsWith('0')) return digits.substring(1);
    return digits;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (phone.isNotEmpty) 'phone': phone,
    if (address.isNotEmpty) 'address': address,
    if (notes.isNotEmpty) 'notes': notes,
    if (payments.isNotEmpty) 'payments': [for (final t in payments) t.toJson()],
    if (discounts.isNotEmpty)
      'discounts': [for (final d in discounts) d.toJson()],
    if (receipts.isNotEmpty) 'receipts': [for (final r in receipts) r.toJson()],
    if (extras.isNotEmpty) 'extras': [for (final e in extras) e.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Customer fromJson(Map<String, Object?> map) {
    final id = map['id']! as String;
    final updatedAt = DateTime.parse(map['updatedAt']! as String);
    return Customer(
      id: id,
      name: map['name']! as String,
      phone: map['phone'] as String? ?? '',
      address: map['address'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      payments: switch (map['payments']) {
        final List<Object?> kept => _ledgerOf(kept, id),
        _ => _legacyOf(map['paid'], id, updatedAt),
      },
      discounts: [
        if (map['discounts'] case final List<Object?> kept)
          for (final d in kept) ?CustomerDiscount.fromJson(d),
      ],
      receipts: _receiptsOf(map['receipts'], id),
      extras: [
        if (map['extras'] case final List<Object?> kept)
          for (final e in kept) ?ExtraCharge.fromJson(e),
      ],
      createdAt: DateTime.parse(map['createdAt']! as String),
      updatedAt: updatedAt,
    );
  }

  /// The transactions kept, each one read — one that cannot be read, or
  /// repeats an id, is passed over — and each the customer's own.
  static List<PaymentTransaction> _ledgerOf(List<Object?> kept, String id) {
    final out = <PaymentTransaction>[];
    for (final raw in kept) {
      final t = PaymentTransaction.fromJson(raw, customerId: id);
      if (t != null && out.every((o) => o.id != t.id)) out.add(t);
    }
    return List.unmodifiable(out);
  }

  /// The receipts kept, each read — one that cannot be read, or repeats a
  /// number or a payment, is passed over.
  static List<Receipt> _receiptsOf(Object? kept, String id) {
    final out = <Receipt>[];
    if (kept is! List) return out;
    for (final raw in kept) {
      final r = Receipt.fromJson(raw, customerId: id);
      if (r == null) continue;
      if (out.any((o) => o.number == r.number)) continue;
      if (out.any((o) => o.transactionId == r.transactionId)) continue;
      out.add(r);
    }
    return List.unmodifiable(out);
  }

  /// The single paid figure a customer was kept with before the ledger, as
  /// the one payment it stands for: whole cents, half a cent up as every
  /// sum of money is, dated when the customer was last changed — the last
  /// time that figure could have been recorded — and always under the same
  /// id. Nothing where nothing was paid or the figure is not one.
  static List<PaymentTransaction> _legacyOf(
    Object? paid,
    String id,
    DateTime updatedAt,
  ) {
    if (paid is! num || !paid.isFinite || paid <= 0) return const [];
    final cents = (paid * 100 + 0.5).floor();
    if (cents <= 0) return const [];
    return [
      PaymentTransaction(
        id: PaymentTransaction.legacyId,
        customerId: id,
        type: PaymentType.payment,
        amountCents: cents,
        at: updatedAt,
        method: PaymentMethod.legacy,
        note: PaymentTransaction.legacyNote,
        createdAt: updatedAt,
      ),
    ];
  }
}
