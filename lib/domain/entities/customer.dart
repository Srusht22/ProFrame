class Customer {
  final String id;
  final String fullName;
  final String? company;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? country;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.fullName,
    this.company,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.country,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? fullName,
    String? company,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? country,
    String? notes,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      fullName: fullName ?? this.fullName,
      company: company ?? this.company,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      country: country ?? this.country,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'company': company,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'country': country,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        company: json['company'] as String?,
        phone: json['phone'] as String? ?? '',
        email: json['email'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        country: json['country'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );
}
