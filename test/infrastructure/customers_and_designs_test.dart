import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A customer is not a design. One customer has many designs, and every
// design belongs to exactly one customer, by its customerId:
//
// Adam
//  ├── Basement Door
//  ├── Front Entrance Door
//  ├── Kitchen Window
//  └── Third Floor Sliding
//
// The customer holds the person — name, phone, address, notes — and the
// design holds the drawing, its name and its category. Neither holds a copy
// of the other.

final at = DateTime(2026, 3, 1, 9);

Design design(
  String id,
  String name,
  DesignKind kind, {
  String? customer,
  String? customerId,
  Duration after = Duration.zero,
}) => Design(
  id: id,
  name: name,
  kind: kind,
  customer: customer,
  customerId: customerId,
  createdAt: at.add(after),
  updatedAt: at.add(after),
);

void main() {
  late CustomerStore customers;
  late DesignStore designs;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    customers = CustomerStore();
    designs = DesignStore(customers: customers);
  });

  test('1 — a customer exists on its own, with no design at all', () async {
    final adam = await customers.create(name: 'Adam', now: at);
    expect(await customers.count(), 1);
    expect((await customers.load(adam.id))!.name, 'Adam');
    expect((await designs.page(customerId: adam.id)).total, 0);
    expect(await designs.count(), 0);
  });

  test('2 — a customer has many designs, found by customerId', () async {
    final adam = await customers.create(name: 'Adam', now: at);
    final sara = await customers.create(name: 'Sara', now: at);
    final adams = [
      design('d1', 'Basement Door', DesignKind.door, customerId: adam.id),
      design(
        'd2',
        'Front Entrance Door',
        DesignKind.door,
        customerId: adam.id,
        after: const Duration(minutes: 1),
      ),
      design(
        'd3',
        'Kitchen Window',
        DesignKind.window,
        customerId: adam.id,
        after: const Duration(minutes: 2),
      ),
      design(
        'd4',
        'Third Floor Sliding',
        DesignKind.sliding,
        customerId: adam.id,
        after: const Duration(minutes: 3),
      ),
    ];
    for (final d in adams) {
      await designs.save(d);
    }
    await designs.save(
      design('d5', 'Garden Gate', DesignKind.door, customerId: sara.id),
    );

    final ofAdam = await designs.page(customerId: adam.id);
    expect(ofAdam.total, 4);
    expect(ofAdam.items.map((s) => s.name), [
      'Third Floor Sliding',
      'Kitchen Window',
      'Front Entrance Door',
      'Basement Door',
    ]);
    final ofSara = await designs.page(customerId: sara.id);
    expect(ofSara.items.map((s) => s.name), ['Garden Gate']);

    // The customer holds no copy of any design: what is kept for a customer
    // is the same size with four designs as with none.
    final prefs = await SharedPreferences.getInstance();
    final kept = prefs.getString(
      '${CustomerStore.customerKeyPrefix}${adam.id}',
    )!;
    expect(kept, jsonEncode(adam.toJson()));
    expect(kept, isNot(contains('Basement')));
  });

  test('3 — every design kept has a customerId', () async {
    // Given one.
    final adam = await customers.create(name: 'Adam', now: at);
    final given = await designs.save(
      design('d1', 'Basement Door', DesignKind.door, customerId: adam.id),
    );
    expect(given.customerId, adam.id);
    // Typed as being for somebody, as the app does today: that customer.
    final typed = await designs.save(
      design('d2', 'Front Door', DesignKind.door, customer: 'adam '),
    );
    expect(typed.customerId, adam.id, reason: 'the customer called that');
    // For somebody new: a customer is made for them.
    final newcomer = await designs.save(
      design('d3', 'Kitchen Window', DesignKind.window, customer: 'Karwan'),
    );
    expect((await customers.load(newcomer.customerId!))!.name, 'Karwan');
    // Every line of the index and every kept file says so.
    for (final s in (await designs.page()).items) {
      expect(s.customerId, isNotNull);
      expect((await designs.load(s.id))!.customerId, s.customerId);
    }
  });

  test(
    '4, 5 — the design\'s name and category are the design\'s own',
    () async {
      final adam = await customers.create(name: 'Adam', now: at);
      for (final (i, kind) in DesignKind.values.indexed) {
        await designs.save(
          design(
            'd$i',
            'Design ${kind.name}',
            kind,
            customerId: adam.id,
            after: Duration(minutes: i),
          ),
        );
      }
      // Every category the application has: door, window, sliding, and door
      // & window.
      expect(DesignKind.values.toSet(), {
        DesignKind.door,
        DesignKind.window,
        DesignKind.sliding,
        DesignKind.both,
      });
      for (final (i, kind) in DesignKind.values.indexed) {
        final kept = (await designs.load('d$i'))!;
        expect(kept.name, 'Design ${kind.name}');
        expect(kept.kind, kind);
        expect(kept.customerId, adam.id);
      }
      // Changing the customer changes no design's name or category.
      await customers.save(adam.copyWith(name: 'Adam Karim'));
      for (final (i, kind) in DesignKind.values.indexed) {
        final kept = (await designs.load('d$i'))!;
        expect(kept.name, 'Design ${kind.name}');
        expect(kept.kind, kind);
      }
    },
  );

  test('6 — phone, address and notes are the customer\'s, and never in a '
      'design', () async {
    final adam = await customers.create(
      name: 'Adam',
      phone: '0750 123 4567',
      address: 'Sulaymaniyah, Salim Street 12',
      notes: 'Prefers dark frames. Call after 5.',
      now: at,
    );
    final kept = (await customers.load(adam.id))!;
    expect(kept.phone, '0750 123 4567');
    expect(kept.address, 'Sulaymaniyah, Salim Street 12');
    expect(kept.notes, 'Prefers dark frames. Call after 5.');

    final d = await designs.save(
      design('d1', 'Basement Door', DesignKind.door, customerId: adam.id),
    );
    final text = jsonEncode(d.toJson());
    for (final said in [kept.phone, kept.address, kept.notes]) {
      expect(text, isNot(contains(said)));
    }
    expect(d.toJson().keys, isNot(contains('phone')));
    expect(d.toJson().keys, isNot(contains('address')));
    expect(d.toJson().keys, isNot(contains('notes')));

    // Editing the customer's details touches no design.
    final before = jsonEncode((await designs.load('d1'))!.toJson());
    await customers.save(kept.copyWith(phone: '0770 999 0000'));
    expect(jsonEncode((await designs.load('d1'))!.toJson()), before);
    expect((await customers.load(adam.id))!.phone, '0770 999 0000');
  });

  test('customers are found by name or phone, a page at a time', () async {
    for (var i = 0; i < 60; i++) {
      await customers.create(
        name: 'Customer $i',
        phone: '0750 000 ${i.toString().padLeft(4, '0')}',
        now: at.add(Duration(minutes: i)),
      );
    }
    final first = await customers.page(limit: 25);
    expect(first.total, 60);
    expect(first.items, hasLength(25));
    expect(first.items.first.name, 'Customer 59', reason: 'latest first');
    expect((await customers.page(query: 'customer 4')).total, 11);
    expect(
      (await customers.page(query: '07500000042')).items.single.name,
      'Customer 42',
    );
  });

  group('7 — designs kept before customers existed are brought over', () {
    test('each is given the customer it was typed as being for, and '
        'nothing else about it changes', () async {
      // Kept by the app as it was: designs with a customer's name on them
      // and no customer anywhere.
      final older = [
        design('d1', 'Karwan', DesignKind.door, customer: 'Karwan'),
        design(
          'd2',
          'Karwan',
          DesignKind.window,
          customer: 'karwan',
          after: const Duration(hours: 1),
        ),
        design(
          'd3',
          'Sara',
          DesignKind.sliding,
          customer: 'Sara',
          after: const Duration(hours: 2),
        ),
        // Kept before anybody was asked who a design was for: known by its
        // own name, as the list showed it.
        design(
          'd4',
          'Old front door',
          DesignKind.door,
          after: const Duration(hours: 3),
        ),
      ];
      SharedPreferences.setMockInitialValues({
        DesignStore.indexKey: jsonEncode([
          for (final d in older) DesignSummary.of(d).toJson(),
        ]),
        for (final d in older)
          '${DesignStore.designKeyPrefix}${d.id}': jsonEncode(d.toJson()),
      });
      final store = DesignStore(customers: CustomerStore());

      final page = await store.page();
      expect(page.total, 4, reason: 'none lost');
      for (final d in older) {
        final now = (await store.load(d.id))!;
        expect(now.customerId, isNotNull);
        expect(
          jsonEncode(now.toJson()..remove('customerId')),
          jsonEncode(d.toJson()),
          reason: 'nothing but the customer added',
        );
      }
      // Karwan's two designs are one customer's; Sara's another's; the
      // unnamed one its own.
      Future<String?> owner(String id) async =>
          (await store.load(id))!.customerId;
      expect(await owner('d1'), await owner('d2'));
      expect(await owner('d3'), isNot(await owner('d1')));
      expect(await store.customers.count(), 3);
      expect(
        (await store.customers.load((await owner('d4'))!))!.name,
        'Old front door',
      );
      expect((await store.page(customerId: await owner('d1'))).total, 2);

      // Read again, nothing more is made.
      await DesignStore(customers: store.customers).page();
      expect(await store.customers.count(), 3);
    });

    test('from the oldest store of all, the single list, too', () async {
      final older = [
        design('d1', 'Karwan', DesignKind.door, customer: 'Karwan'),
        design('d2', 'Ahmed', DesignKind.window, customer: 'Ahmed'),
      ];
      SharedPreferences.setMockInitialValues({
        DesignStore.legacyKey: [for (final d in older) jsonEncode(d.toJson())],
      });
      final store = DesignStore();
      expect((await store.page()).total, 2);
      for (final d in older) {
        final now = (await store.load(d.id))!;
        expect((await store.customers.load(now.customerId!))!.name, d.customer);
      }
    });
  });

  test('8 — what Phase 2 builds on: a customer opened, their designs listed, '
      'a design made for them, one removed', () async {
    final adam = await customers.create(name: 'Adam', now: at);
    // Made for this customer.
    final made = await designs.save(
      Design.empty(
        id: 'd1',
        kind: DesignKind.door,
        name: 'Basement Door',
        customerId: adam.id,
        now: at,
      ),
    );
    expect(made.customerId, adam.id);
    await designs.save(
      Design.empty(
        id: 'd2',
        kind: DesignKind.window,
        name: 'Kitchen Window',
        customerId: adam.id,
        now: at.add(const Duration(minutes: 1)),
      ),
    );
    expect((await designs.page(customerId: adam.id)).total, 2);
    // One removed: the customer and their other design stay.
    await designs.remove('d1');
    expect((await designs.page(customerId: adam.id)).items.map((s) => s.id), [
      'd2',
    ]);
    expect(await customers.load(adam.id), isNotNull);
    // A design saved again keeps its customer.
    final again = await designs.save(
      (await designs.load('d2'))!.copyWith(name: 'Kitchen Window, wide'),
    );
    expect(again.customerId, adam.id);
    expect(await customers.count(), 1, reason: 'nobody new was made');
  });

  test('a customer and a design say the same thing after a save and a '
      'reload', () {
    final adam = Customer(
      id: 'customer-1',
      name: 'Adam',
      phone: '0750',
      address: 'Erbil',
      notes: 'n',
      createdAt: at,
      updatedAt: at,
    );
    expect(
      jsonEncode(Customer.fromJson(adam.toJson()).toJson()),
      jsonEncode(adam.toJson()),
    );
    final d = design(
      'd1',
      'Basement Door',
      DesignKind.door,
      customerId: adam.id,
    );
    expect(
      Design.fromJson(jsonDecode(jsonEncode(d.toJson()))).customerId,
      adam.id,
    );
  });
}
