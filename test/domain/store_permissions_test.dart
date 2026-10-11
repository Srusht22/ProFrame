import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/extra_charge.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/quotation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'financial_records_test.dart' show member;

// Phase 33's permissions, held on the stores themselves: reading through
// the application's stores needs the `.view` capability in the store, not
// only on the screen; and `customers.delete` deletes a customer only where
// nothing of theirs would go with them.

final _now = DateTime(2026, 10, 10, 9);

/// The stores as the application hands them out: reading as [who].
({CustomerStore customers, DesignStore designs, QuotationStore quotations})
storesFor(Authority who) {
  Future<Authority> reader() async => who;
  final customers = CustomerStore(readsAs: reader);
  return (
    customers: customers,
    designs: DesignStore(customers: customers, readsAs: reader),
    quotations: QuotationStore(readsAs: reader),
  );
}

Future<Map<String, Object?>> device() async {
  final prefs = await SharedPreferences.getInstance();
  return {for (final k in prefs.getKeys()) k: prefs.get(k)};
}

/// Adam, kept, with nothing of his yet.
Future<Customer> adam() =>
    CustomerStore().create(name: 'Adam', now: _now, by: WorkshopRole.owner);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('reading is checked by the stores themselves', () {
    test('somebody without customers.view or designs.view reads nothing — '
        'the store refuses, whatever a screen shows', () async {
      final a = await adam();
      await DesignStore().save(
        Design.empty(
          id: 'd1',
          kind: DesignKind.door,
        ).copyWith(name: 'Basement Door', customerId: a.id),
        by: WorkshopRole.owner,
      );
      final blind = storesFor(member('Blind', {Capability.financialView}));
      for (final read in <Future<Object?> Function()>[
        () => blind.customers.page(),
        () => blind.customers.load(a.id),
        () => blind.customers.named('Adam'),
        () => blind.customers.count(),
        () => blind.designs.page(),
        () => blind.designs.load('d1'),
        () => blind.designs.countsByCustomer(),
        () => blind.designs.kindsOf(a.id),
        () => blind.designs.count(),
        () => blind.designs.all(),
        () => blind.quotations.page(a.id),
        () => blind.quotations.load('Q-000001'),
      ]) {
        await expectLater(read(), throwsA(isA<AccessDenied>()));
      }
    });

    test('somebody who may look reads as before; nobody signed in may '
        'look', () async {
      final a = await adam();
      final looking = storesFor(const NobodySignedIn());
      expect((await looking.customers.load(a.id))!.name, 'Adam');
      expect((await looking.customers.page()).total, 1);
      expect((await looking.designs.page()).total, 0);
      final owner = storesFor(WorkshopRole.owner);
      expect((await owner.customers.named('adam'))!.id, a.id);
    });

    test('a store with nobody to ask — the device\'s own housekeeping — '
        'reads as it always could', () async {
      final a = await adam();
      expect((await CustomerStore().load(a.id))!.name, 'Adam');
    });

    test('nobody may add, edit, create or edit what they are not allowed '
        'to: refused by the stores, nothing written', () async {
      final a = await adam();
      final before = jsonEncode(await device());
      final looking = member('Looking', Capability.viewOnly);
      await expectLater(
        CustomerStore().create(name: 'Sara', by: looking),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        CustomerStore().save(a.copyWith(phone: '0750'), by: looking),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        DesignStore().save(
          Design.empty(
            id: 'd2',
            kind: DesignKind.window,
          ).copyWith(name: 'Kitchen Window', customerId: a.id),
          by: looking,
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect(jsonEncode(await device()), before);
    });
  });

  group('customers.delete', () {
    test('the owner holds it; nobody signed in, the standard set and a new '
        'member of staff do not; a member given it does', () {
      expect(WorkshopRole.owner.can(Capability.customersDelete), isTrue);
      expect(Capability.standard.contains(Capability.customersDelete), isFalse);
      expect(Capability.viewOnly.contains(Capability.customersDelete), isFalse);
      expect(const NobodySignedIn().can(Capability.customersDelete), isFalse);
      expect(
        member('Admin', {
          Capability.customersDelete,
        }).can(Capability.customersDelete),
        isTrue,
      );
      expect(Capability.byKey('customers.delete'), Capability.customersDelete);
    });

    test('without it, nothing is deleted: refused by the store', () async {
      final a = await adam();
      final before = jsonEncode(await device());
      await expectLater(
        CustomerStore().deleteCustomer(a.id, by: WorkshopRole.staff),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        CustomerStore().deleteCustomer(
          a.id,
          by: member('Clerk', Capability.standard),
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect(jsonEncode(await device()), before);
    });

    test('a customer with nothing kept — made by mistake — is deleted, and '
        'kept again whole by Undo', () async {
      final a = await adam();
      final sara = await CustomerStore().create(
        name: 'Sara',
        now: _now,
        by: WorkshopRole.owner,
      );
      final out = await CustomerStore().deleteCustomer(
        a.id,
        by: WorkshopRole.owner,
      );
      expect(out.deleted, isTrue);
      expect(out.problem, isNull);
      expect(await CustomerStore().load(a.id), isNull);
      final page = await CustomerStore().page();
      expect(page.items.map((s) => s.name), ['Sara']);
      expect((await CustomerStore().load(sara.id))!.name, 'Sara');
      // Undo: kept again, the same customer.
      await CustomerStore().save(a, by: WorkshopRole.owner);
      expect(
        jsonEncode((await CustomerStore().load(a.id))!.toJson()),
        jsonEncode(a.toJson()),
      );
    });

    test('a customer with a design, a payment, a quotation or an extra '
        'charge is not deleted, and the reason names what they have', () async {
      Future<void> refused(
        String has,
        Future<void> Function(Customer) give,
      ) async {
        SharedPreferences.setMockInitialValues({});
        final a = await adam();
        await give(a);
        final before = jsonEncode(await device());
        final out = await CustomerStore().deleteCustomer(
          a.id,
          by: WorkshopRole.owner,
        );
        expect(out.deleted, isFalse, reason: has);
        expect(out.problem, contains('Adam cannot be deleted'));
        expect(out.problem, contains(has));
        expect(jsonEncode(await device()), before, reason: 'nothing written');
      }

      await refused('1 design', (a) async {
        await DesignStore().save(
          Design.empty(
            id: 'd',
            kind: DesignKind.door,
          ).copyWith(name: 'Basement Door', customerId: a.id),
          by: WorkshopRole.owner,
        );
      });
      await refused('1 payment', (a) async {
        await CustomerStore().record(
          PaymentTransaction(
            id: 'PAY-1',
            customerId: a.id,
            type: PaymentType.payment,
            amountCents: 10000,
            at: _now,
            method: PaymentMethod.cash,
            createdAt: _now,
          ),
          by: WorkshopRole.owner,
        );
      });
      await refused('1 extra charge', (a) async {
        await CustomerStore().saveExtra(
          a.id,
          ExtraCharge(
            id: 'EXT-1',
            name: 'Delivery trip',
            category: ExtraCategory.transport,
            quantityMilli: 1000,
            unit: 'trip',
            unitPriceCents: 3000,
            currency: 'USD',
            scope: ExtraScope.customer,
            createdAt: _now,
            updatedAt: _now,
          ),
          by: WorkshopRole.owner,
        );
      });
      await refused('quotations', (a) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '${QuotationStore.indexPrefix}${a.id}',
          jsonEncode(['Q-000001']),
        );
      });
    });
  });
}
