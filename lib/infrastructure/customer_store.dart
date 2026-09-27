import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/customer.dart';

/// What the list of customers needs to know about one customer: who, how
/// to reach them by phone, and when they were last changed. The address
/// and the notes are read with the customer itself, by [CustomerStore.load].
class CustomerSummary {
  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone = '',
  });

  factory CustomerSummary.of(Customer customer) => CustomerSummary(
    id: customer.id,
    name: customer.name,
    phone: customer.phone,
    createdAt: customer.createdAt,
    updatedAt: customer.updatedAt,
  );

  /// The same search as `Customer.matches`, on what the index holds.
  bool matches(String query) => Customer(
    id: id,
    name: name,
    phone: phone,
    createdAt: createdAt,
    updatedAt: updatedAt,
  ).matches(query);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (phone.isNotEmpty) 'phone': phone,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static CustomerSummary fromJson(Map<String, Object?> map) => CustomerSummary(
    id: map['id']! as String,
    name: map['name']! as String,
    phone: map['phone'] as String? ?? '',
    createdAt: DateTime.parse(map['createdAt']! as String),
    updatedAt: DateTime.parse(map['updatedAt']! as String),
  );
}

/// One page of the customers a search found, most recently changed first,
/// and how many it found in all.
class CustomerPage {
  final List<CustomerSummary> items;
  final int total;

  const CustomerPage(this.items, this.total);
}

/// Keeps the workshop's customers between sessions.
///
/// **A customer is kept on its own, apart from its designs.** A customer's
/// designs are the designs naming it — `DesignStore.page(customerId: …)` —
/// and nothing here holds a copy of any of them, so a customer with forty
/// designs is as small as one with none, and changing a phone number
/// touches no design.
///
/// Laid out as `DesignStore` is, for the same reason: one key a customer
/// and an index beside them, so [page] reads a line a customer and a whole
/// customer is read by [load] only when it is opened. A store kept on a
/// server can stand in for this one without the screens changing.
class CustomerStore {
  static const indexKey = 'proframe.customers.index.v1';
  static const customerKeyPrefix = 'proframe.customer.v1.';

  static String _customerKey(String id) => '$customerKeyPrefix$id';

  String? _indexText;
  List<CustomerSummary> _index = const [];

  int _made = 0;

  /// A new customer's id: the moment it was made, and a count, so two made
  /// in the same moment are still two.
  String _newId(DateTime at) =>
      'customer-${at.microsecondsSinceEpoch}-${_made++}';

  Future<List<CustomerSummary>> _read(SharedPreferences prefs) async {
    final text = prefs.getString(indexKey);
    if (text == null) return _index = const [];
    if (text == _indexText) return _index;
    final list = <CustomerSummary>[];
    try {
      for (final entry in jsonDecode(text) as List<Object?>) {
        try {
          list.add(CustomerSummary.fromJson(entry! as Map<String, Object?>));
        } on Object {
          // One unreadable line must not take the rest down with it.
          continue;
        }
      }
    } on Object {
      list.clear();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _indexText = text;
    return _index = list;
  }

  Future<void> _write(
    SharedPreferences prefs,
    List<CustomerSummary> index,
  ) async {
    final text = jsonEncode([for (final s in index) s.toJson()]);
    await prefs.setString(indexKey, text);
    _indexText = text;
    _index = index;
  }

  /// The customers a search for [query] finds — by name or phone —
  /// most recently changed first: [limit] of them from [offset], and how
  /// many it found in all.
  Future<CustomerPage> page({
    String query = '',
    int offset = 0,
    int limit = 40,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _read(prefs);
    final found = query.trim().isEmpty
        ? index
        : [
            for (final s in index)
              if (s.matches(query)) s,
          ];
    final start = offset.clamp(0, found.length);
    final end = (start + limit).clamp(start, found.length);
    return CustomerPage(found.sublist(start, end), found.length);
  }

  /// How many customers are kept.
  Future<int> count() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _read(prefs)).length;
  }

  /// The customer kept as [id], or null where there is none.
  Future<Customer?> load(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(_customerKey(id));
    if (text == null) return null;
    try {
      return Customer.fromJson(jsonDecode(text) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  /// Keeps [customer], new or changed, and returns it as kept.
  Future<Customer> save(Customer customer) async {
    final prefs = await SharedPreferences.getInstance();
    final index = [
      for (final s in await _read(prefs))
        if (s.id != customer.id) s,
    ];
    await prefs.setString(
      _customerKey(customer.id),
      jsonEncode(customer.toJson()),
    );
    final summary = CustomerSummary.of(customer);
    var at = 0;
    while (at < index.length &&
        !index[at].updatedAt.isBefore(summary.updatedAt)) {
      at++;
    }
    index.insert(at, summary);
    await _write(prefs, index);
    return customer;
  }

  /// A new customer called [name], kept, with whatever else is known.
  Future<Customer> create({
    required String name,
    String phone = '',
    String address = '',
    String notes = '',
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return save(
      Customer(
        id: _newId(at),
        name: name.trim(),
        phone: phone.trim(),
        address: address.trim(),
        notes: notes.trim(),
        createdAt: at,
        updatedAt: at,
      ),
    );
  }

  /// The customer called [name] — however it is spaced or capitalised — or
  /// null where there is none. Where more than one has that name, the one
  /// changed most recently.
  Future<Customer?> named(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final wanted = Customer.keyOf(name);
    if (wanted.isEmpty) return null;
    for (final s in await _read(prefs)) {
      if (Customer.keyOf(s.name) == wanted) return load(s.id);
    }
    return null;
  }

  /// The customer a design typed as being for [name] belongs to: the one
  /// already called that, or a new one made for it at [at].
  ///
  /// While the only thing the application has been told about a person is
  /// their name, the name is how they are recognised — which is what the
  /// list of designs already did, and what the designs kept before
  /// customers existed are brought over by.
  Future<Customer> obtain(String name, {DateTime? at}) async =>
      await named(name) ?? await create(name: name, now: at);
}
