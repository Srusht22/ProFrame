import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/customer.dart';
import '../domain/model/payment.dart';

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

  /// Shared by every instance, so two stores making a customer in the same
  /// moment — the web's clock stops at the millisecond — still give them
  /// two ids rather than one that the second overwrites.
  static int _made = 0;

  /// A new customer's id: the moment it was made, and a count, so two made
  /// in the same moment are still two.
  String _newId(DateTime at) =>
      'customer-${at.microsecondsSinceEpoch}-${_made++}';

  /// The index as the device holds it at this moment, read without
  /// waiting for anything.
  ///
  /// **Changing the index is a read and a write with nothing waited on in
  /// between**, and that is what keeps two changes made at once from losing
  /// one another. Storage takes a value the moment it is set, so an index
  /// read here and written back before anything is awaited cannot have been
  /// changed in between by anybody — every other change either finished
  /// before this read or starts after this write. Reading, then waiting,
  /// then writing is how four customers saved at once came back as one.
  List<CustomerSummary> _indexNow(SharedPreferences prefs) {
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

  /// Sets the index to [index] now, and answers when the device has it.
  Future<bool> _write(SharedPreferences prefs, List<CustomerSummary> index) {
    final text = jsonEncode([for (final s in index) s.toJson()]);
    final done = prefs.setString(indexKey, text);
    _indexText = text;
    _index = index;
    return done;
  }

  /// Keeps [customer] — its record and its line in the index — without
  /// waiting on anything between reading the index and writing it back.
  ///
  /// **A transaction kept is never dropped.** A customer saved from an
  /// older copy — a form opened before a payment was recorded — keeps every
  /// payment and refund already on the device: the ledger only grows.
  Future<void> _keepNow(SharedPreferences prefs, Customer customer) {
    final kept = _loadNow(prefs, customer.id);
    if (kept != null) {
      var ledger = customer.ledger;
      for (final t in kept.payments) {
        ledger = ledger.plus(t);
      }
      if (ledger.transactions.length != customer.payments.length) {
        customer = customer.copyWith(
          payments: ledger.transactions,
          updatedAt: customer.updatedAt,
        );
      }
    }
    final index = [
      for (final s in _indexNow(prefs))
        if (s.id != customer.id) s,
    ];
    final record = prefs.setString(
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
    return Future.wait([record, _write(prefs, index)]);
  }

  /// Every customer's name as it is kept now, by id — one pass over the
  /// index, never the records themselves.
  Map<String, String> namesNow(SharedPreferences prefs) => {
    for (final s in _indexNow(prefs)) s.id: s.name,
  };

  /// The customer kept as [id], read now, or null where there is none.
  Customer? _loadNow(SharedPreferences prefs, String id) {
    final text = prefs.getString(_customerKey(id));
    if (text == null) return null;
    try {
      return Customer.fromJson(jsonDecode(text) as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  /// The customer called [name], found now — see [named].
  Customer? _namedNow(SharedPreferences prefs, String name) {
    final wanted = Customer.keyOf(name);
    if (wanted.isEmpty) return null;
    for (final s in _indexNow(prefs)) {
      if (Customer.keyOf(s.name) == wanted) return _loadNow(prefs, s.id);
    }
    return null;
  }

  Customer _newCustomer({
    required String name,
    String phone = '',
    String address = '',
    String notes = '',
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    return Customer(
      id: _newId(at),
      name: name.trim(),
      phone: phone.trim(),
      address: address.trim(),
      notes: notes.trim(),
      createdAt: at,
      updatedAt: at,
    );
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
    final index = _indexNow(prefs);
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
    return _indexNow(prefs).length;
  }

  /// The customer kept as [id], or null where there is none.
  Future<Customer?> load(String id) async =>
      _loadNow(await SharedPreferences.getInstance(), id);

  /// Keeps [customer], new or changed, and returns it as kept.
  Future<Customer> save(Customer customer) async {
    await _keepNow(await SharedPreferences.getInstance(), customer);
    return customer;
  }

  /// Records [transaction] in the ledger of the customer it belongs to,
  /// and returns the customer as kept — or null where that customer is not
  /// kept. Read and written with nothing waited on in between, so two
  /// recorded at once are both kept. A transaction whose id is already in
  /// the ledger is not recorded twice. Nothing but the ledger changes.
  Future<Customer?> record(PaymentTransaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, transaction.customerId);
    if (customer == null) return null;
    if (customer.ledger.contains(transaction.id)) return customer;
    final now = customer.copyWith(
      payments: customer.ledger.plus(transaction).transactions,
    );
    await _keepNow(prefs, now);
    return now;
  }

  /// A new customer called [name], kept, with whatever else is known.
  Future<Customer> create({
    required String name,
    String phone = '',
    String address = '',
    String notes = '',
    DateTime? now,
  }) => save(
    _newCustomer(
      name: name,
      phone: phone,
      address: address,
      notes: notes,
      now: now,
    ),
  );

  /// The customer called [name] — however it is spaced or capitalised — or
  /// null where there is none. Where more than one has that name, the one
  /// changed most recently.
  Future<Customer?> named(String name) async =>
      _namedNow(await SharedPreferences.getInstance(), name);

  /// The customer a design typed as being for [name] belongs to: the one
  /// already called that, or a new one made for it at [at].
  ///
  /// While the only thing the application has been told about a person is
  /// their name, the name is how they are recognised — which is what the
  /// list of designs already did, and what the designs kept before
  /// customers existed are brought over by.
  ///
  /// Looking and making are one step with nothing waited on between them,
  /// so two designs kept at once for somebody nobody has made yet make one
  /// customer between them, not two.
  Future<Customer> obtain(String name, {DateTime? at}) async {
    final prefs = await SharedPreferences.getInstance();
    final found = _namedNow(prefs, name);
    if (found != null) return found;
    final made = _newCustomer(name: name, now: at);
    await _keepNow(prefs, made);
    return made;
  }
}
