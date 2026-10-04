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

  /// What the customer has paid towards their designs, in the price list's
  /// currency — the one money figure kept on a customer. What their designs
  /// come to is never kept: it is worked out from the designs
  /// (`CustomerPricing`), so it cannot go out of date, and what is due is
  /// that total less this (`CustomerFinance`). A customer kept before
  /// payments were recorded has paid nothing recorded.
  final double paid;

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
    this.paid = 0,
  });

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
    double? paid,
    DateTime? updatedAt,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    paid: paid ?? this.paid,
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
    if (paid != 0) 'paid': paid,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Customer fromJson(Map<String, Object?> map) => Customer(
    id: map['id']! as String,
    name: map['name']! as String,
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    paid: _paidOf(map['paid']),
    createdAt: DateTime.parse(map['createdAt']! as String),
    updatedAt: DateTime.parse(map['updatedAt']! as String),
  );

  /// A paid figure as kept: a number no less than nothing, or nothing paid
  /// for a record without one or with one that is not a figure.
  static double _paidOf(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : 0;
}
