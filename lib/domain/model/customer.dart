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
    DateTime? updatedAt,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
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
    final digits = wanted.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.isNotEmpty &&
        phone.replaceAll(RegExp(r'[^0-9+]'), '').contains(digits);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (phone.isNotEmpty) 'phone': phone,
    if (address.isNotEmpty) 'address': address,
    if (notes.isNotEmpty) 'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static Customer fromJson(Map<String, Object?> map) => Customer(
    id: map['id']! as String,
    name: map['name']! as String,
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    notes: map['notes'] as String? ?? '',
    createdAt: DateTime.parse(map['createdAt']! as String),
    updatedAt: DateTime.parse(map['updatedAt']! as String),
  );
}
