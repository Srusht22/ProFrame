import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/model/customer.dart';
import '../domain/model/customer_discount.dart';
import '../domain/model/payment.dart';
import '../domain/model/receipt.dart';
import '../domain/pricing/extra_charge.dart';
import '../domain/pricing/price_result.dart';
import '../domain/pricing/pricing_access.dart';
import 'design_store.dart';
import 'quotation_store.dart';

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
  /// Who is reading, for a store the application hands out: asked before
  /// anything is read through it, so seeing what is kept needs its `.view`
  /// capability in the store itself and not only on the screen. Null for a
  /// store with nobody to ask — the device's own housekeeping, or a test —
  /// which reads as the device always could.
  final Future<Authority> Function()? readsAs;

  CustomerStore({this.readsAs});

  /// Nothing where whoever is reading may see customers; [AccessDenied]
  /// otherwise, before anything is read.
  Future<void> _mayRead() async {
    final who = readsAs;
    if (who != null) (await who()).require(Capability.customersView);
  }

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
  ///
  /// The same holds for the customer's discount log and their receipts:
  /// each only grows, so a copy read before a discount was given or a
  /// receipt issued keeps them when it is saved.
  ///
  /// **A customer's extras are changed only by [saveExtra] and
  /// [takeExtraOff]** ([extrasToo]). Anything else that keeps a customer —
  /// their phone edited, a payment recorded — keeps the extras the device
  /// has, so a copy read before an extra was added, changed or removed
  /// cannot put back what it saw.
  Future<void> _keepNow(
    SharedPreferences prefs,
    Customer customer, {
    bool extrasToo = false,
  }) {
    final kept = _loadNow(prefs, customer.id);
    if (kept != null && !extrasToo) {
      customer = customer.copyWith(
        extras: kept.extras,
        updatedAt: customer.updatedAt,
      );
    }
    if (kept != null) {
      var ledger = customer.ledger;
      for (final t in kept.payments) {
        ledger = ledger.plus(t);
      }
      final discounts = [
        ...kept.discounts,
        for (final d in customer.discounts)
          if (!kept.discounts.any((k) => k.id == d.id)) d,
      ];
      final receipts = [
        ...kept.receipts,
        for (final r in customer.receipts)
          if (!kept.receipts.any((k) => k.number == r.number)) r,
      ];
      if (ledger.transactions.length != customer.payments.length ||
          discounts.length != customer.discounts.length ||
          receipts.length != customer.receipts.length) {
        customer = customer.copyWith(
          payments: ledger.transactions,
          discounts: discounts,
          receipts: receipts,
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
    await _mayRead();
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
    await _mayRead();
    final prefs = await SharedPreferences.getInstance();
    return _indexNow(prefs).length;
  }

  /// The customer kept as [id], or null where there is none.
  Future<Customer?> load(String id) async {
    await _mayRead();
    return _loadNow(await SharedPreferences.getInstance(), id);
  }

  /// Keeps [customer], new or changed, as asked [by] — `customers.create`
  /// for one not kept yet, `customers.edit` for one that is — and returns
  /// it as kept. Without that, nothing is written ([AccessDenied]).
  Future<Customer> save(Customer customer, {required Authority by}) async {
    final prefs = await SharedPreferences.getInstance();
    by.require(
      _loadNow(prefs, customer.id) == null
          ? Capability.customersCreate
          : Capability.customersEdit,
    );
    await _keepNow(prefs, customer);
    return customer;
  }

  /// Puts [extra] on customer [customerId]'s job — added where it is new,
  /// changed where it is already there by id — as asked [by] whoever holds
  /// `extras.create` or `extras.edit`, and returns the customer as kept, or
  /// null where they are not kept.
  ///
  /// An extra that is not one (`ExtraCharge.problemWith`) is refused
  /// ([ArgumentError]); one that looks like a cost the designs' prices
  /// already work out — [calculated] — is refused unless [additional] says
  /// it is meant on top ([StateError] with the reason). Nothing but the
  /// customer's extras changes: no design, no price, no payment.
  Future<Customer?> saveExtra(
    String customerId,
    ExtraCharge extra, {
    required Authority by,
    Iterable<PriceLine> calculated = const [],
    bool additional = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, customerId);
    final exists = customer?.extras.any((e) => e.id == extra.id) ?? false;
    by.require(exists ? Capability.extrasEdit : Capability.extrasCreate);
    final problem = ExtraCharge.problemWith(
      name: extra.name,
      quantityMilli: extra.quantityMilli,
      unit: extra.unit,
      unitPriceCents: extra.unitPriceCents,
    );
    if (problem != null) throw ArgumentError(problem);
    if (!additional) {
      final same = ExtraCharge.alreadyCalculated(
        extra.name,
        extra.category,
        calculated,
      );
      if (same.isNotEmpty) {
        throw StateError(
          ExtraCharge.alreadyCalculatedMessage(
            same,
            (c) => (c / 100).toStringAsFixed(2),
          ),
        );
      }
    }
    if (customer == null) return null;
    final now = customer.copyWith(extras: customer.extras.withExtra(extra));
    await _keepNow(prefs, now, extrasToo: true);
    return now;
  }

  /// Takes the extra [extraId] off customer [customerId]'s job, as asked
  /// [by] whoever holds `extras.delete`, and returns the customer as kept.
  Future<Customer?> takeExtraOff(
    String customerId,
    String extraId, {
    required Authority by,
  }) async {
    by.require(Capability.extrasDelete);
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, customerId);
    if (customer == null) return null;
    if (customer.extras.every((e) => e.id != extraId)) return customer;
    final now = customer.copyWith(extras: customer.extras.without(extraId));
    await _keepNow(prefs, now, extrasToo: true);
    return now;
  }

  /// Records [transaction] in the ledger of the customer it belongs to,
  /// as asked [by], and returns the customer as kept — or null where that
  /// customer is not kept.
  ///
  /// A payment needs `payments.create` and a refund `payments.refund`;
  /// without it nothing is written and [AccessDenied] is thrown — whatever
  /// screen, or none, asked. Read and written with nothing waited on in
  /// between, so two recorded at once are both kept. A transaction whose id
  /// is already in the ledger is not recorded twice. Nothing but the ledger
  /// changes.
  Future<Customer?> record(
    PaymentTransaction transaction, {
    required Authority by,
  }) async {
    by.require(
      transaction.type == PaymentType.payment
          ? Capability.paymentsCreate
          : Capability.paymentsRefund,
    );
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

  /// The sequence receipts are numbered from: the last number given.
  static const receiptSequenceKey = 'proframe.receipt-sequence.v1';

  /// The receipt for the payment [transactionId] of customer [customerId],
  /// issued at [now] [by] whoever holds `receipts.create`, with the balance
  /// as the caller worked it out — or the one already issued for it.
  ///
  /// **Issuing a receipt adds no money.** It reads the payment from the
  /// ledger and writes a receipt beside it; the ledger is not touched, so
  /// no total can change, and asking again gives back the same receipt
  /// rather than a second.
  ///
  /// Its number is the sequence kept on the device, plus one — never how
  /// many receipts there are, so no number is ever given twice. Where the
  /// sequence has been lost, it starts after the highest number any
  /// customer's receipt carries. Null where the customer, or the payment, is
  /// not kept; a refund has no receipt ([ArgumentError]).
  Future<Receipt?> issueReceipt({
    required String customerId,
    required String transactionId,
    required Authority by,
    required String currency,
    required int? balanceAfterCents,
    DateTime? now,
  }) async {
    by.require(Capability.receiptsCreate);
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, customerId);
    if (customer == null) return null;
    final payment = customer.payments
        .where((t) => t.id == transactionId)
        .firstOrNull;
    if (payment == null) return null;
    if (payment.type != PaymentType.payment) {
      throw ArgumentError('A receipt is for a payment, not a refund.');
    }
    final existing = customer.receiptFor(transactionId);
    if (existing != null) return existing;
    final number = _lastReceiptNumber(prefs) + 1;
    final receipt = Receipt.forPayment(
      payment,
      number: number,
      now: now ?? DateTime.now(),
      currency: currency,
      balanceAfterCents: balanceAfterCents,
      by: by.label,
    );
    final sequence = prefs.setInt(receiptSequenceKey, number);
    final kept = _keepNow(
      prefs,
      customer.copyWith(
        receipts: [...customer.receipts, receipt],
        updatedAt: customer.updatedAt,
      ),
    );
    await Future.wait([sequence, kept]);
    return receipt;
  }

  int _lastReceiptNumber(SharedPreferences prefs) {
    final kept = prefs.getInt(receiptSequenceKey);
    if (kept != null) return kept;
    var highest = 0;
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(customerKeyPrefix)) continue;
      final c = _loadNow(prefs, key.substring(customerKeyPrefix.length));
      for (final r in c?.receipts ?? const <Receipt>[]) {
        if (r.number > highest) highest = r.number;
      }
    }
    return highest;
  }

  /// Gives customer [customerId] the discount [entry] — or, where it is a
  /// removal, takes away the one in force — as asked [by] whoever holds
  /// `discounts.apply`. It is added to the customer's discount log; nothing
  /// in it is removed, and nothing but the log changes. Whether the figure
  /// can be given against the subtotal is the caller's to check first
  /// (`CustomerDiscount.problemWith`); an entry that is not a discount at
  /// all is refused here ([ArgumentError]).
  Future<Customer?> applyDiscount(
    String customerId,
    CustomerDiscount entry, {
    required Authority by,
  }) async {
    by.require(Capability.discountsApply);
    if (!entry.isRemoval &&
        (entry.value <= 0 ||
            (entry.kind == DiscountKind.percent && entry.value > 10000) ||
            (entry.kind == DiscountKind.fixed && entry.currency == null))) {
      throw ArgumentError('Not a discount: ${entry.toJson()}');
    }
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, customerId);
    if (customer == null) return null;
    if (customer.discounts.any((d) => d.id == entry.id)) return customer;
    final now = customer.copyWith(discounts: [...customer.discounts, entry]);
    await _keepNow(prefs, now);
    return now;
  }

  /// A new customer called [name], kept, with whatever else is known, as
  /// asked [by] whoever holds `customers.create`.
  Future<Customer> create({
    required String name,
    required Authority by,
    String phone = '',
    String address = '',
    String notes = '',
    DateTime? now,
  }) async {
    by.require(Capability.customersCreate);
    return save(
      _newCustomer(
        name: name,
        phone: phone,
        address: address,
        notes: notes,
        now: now,
      ),
      by: by,
    );
  }

  /// The customer called [name] — however it is spaced or capitalised — or
  /// null where there is none. Where more than one has that name, the one
  /// changed most recently.
  Future<Customer?> named(String name) async {
    await _mayRead();
    return _namedNow(await SharedPreferences.getInstance(), name);
  }

  /// Deletes customer [id], as asked [by] whoever holds `customers.delete`
  /// — or says why not, deleting nothing.
  ///
  /// **Only a customer with nothing that would go with them is deleted**: a
  /// customer made by mistake. One with a design is refused — each design
  /// is deleted on its own, asked about by its name — and so is one with
  /// any financial record or charge: a payment or refund, a receipt, a
  /// discount, a quotation or an extra charge. Those are the workshop's
  /// history and are never deleted, so neither is the customer they are
  /// the history of. What is deleted is the customer's record and its line
  /// of the index, written in one step, and nothing else; it can be kept
  /// again, whole, by [save].
  Future<({bool deleted, String? problem})> deleteCustomer(
    String id, {
    required Authority by,
  }) async {
    by.require(Capability.customersDelete);
    final prefs = await SharedPreferences.getInstance();
    final customer = _loadNow(prefs, id);
    if (customer == null) {
      return (deleted: false, problem: 'This customer is no longer kept.');
    }
    final designs =
        (await DesignStore(customers: this).countsByCustomer())[id] ?? 0;
    final quotations = switch (prefs.getString(
      '${QuotationStore.indexPrefix}$id',
    )) {
      final String text when text != '[]' => 1,
      _ => 0,
    };
    String some(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final has = [
      if (designs > 0) some(designs, 'design', 'designs'),
      if (customer.payments.isNotEmpty)
        some(customer.payments.length, 'payment', 'payments'),
      if (customer.receipts.isNotEmpty)
        some(customer.receipts.length, 'receipt', 'receipts'),
      if (customer.discounts.isNotEmpty) 'a discount',
      if (quotations > 0) 'quotations',
      if (customer.extras.isNotEmpty)
        some(customer.extras.length, 'extra charge', 'extra charges'),
    ];
    if (has.isNotEmpty) {
      return (
        deleted: false,
        problem:
            '${customer.name} cannot be deleted: they have '
            '${has.join(', ')}. A customer is deleted only when nothing of '
            'theirs would go with them — delete each design on its own; '
            'payments, receipts, discounts and quotations are the '
            "workshop's records and are kept.",
      );
    }
    // The record and its line of the index, with nothing awaited between
    // reading the index and writing it back.
    final index = [
      for (final s in _indexNow(prefs))
        if (s.id != id) s,
    ];
    await Future.wait([prefs.remove(_customerKey(id)), _write(prefs, index)]);
    return (deleted: true, problem: null);
  }

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
  ///
  /// Making one is adding a customer, so it needs [by] to hold
  /// `customers.create`; finding one needs nothing more.
  Future<Customer> obtain(
    String name, {
    required Authority by,
    DateTime? at,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final found = _namedNow(prefs, name);
    if (found != null) return found;
    by.require(Capability.customersCreate);
    final made = _newCustomer(name: name, now: at);
    await _keepNow(prefs, made);
    return made;
  }
}
