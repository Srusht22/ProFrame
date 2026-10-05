import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/customer_discount.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/model/receipt.dart';
import 'package:proframe/domain/model/staff.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/quotation_store.dart';
import 'package:proframe/infrastructure/staff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'payment_history_test.dart' show ledgerOf, transaction;
import 'price_readiness_test.dart' show fixed;
import 'pricing_engine_test.dart' show door;

// Phase 31: a customer's financial records — a discount off what their
// designs come to, quotations kept as they were offered, receipts for the
// payments received, the history a page at a time, money in more than one
// currency, and who may do which of it, asked by the stores themselves.

final _now = DateTime(2026, 10, 5, 10);

String usd(int cents) => '${(cents / 100).toStringAsFixed(2)} USD';

/// A price list at which a door costs [door] and a window [window], and
/// fitting a door that asks for it [fitting].
PriceList listAt({double door = 0, double window = 0, double fitting = 0}) =>
    fixed.copyWith(
      categories: {
        ...fixed.categories,
        'door': CategoryRate('Door', LabourRate(fixed: door)),
        'window': CategoryRate('Window', LabourRate(fixed: window)),
      },
      installation: InstallationRate(fixed: fitting),
    );

/// Designs and their kept prices, at [list].
CustomerPricing pricingOf(List<Design> designs, PriceList list) =>
    CustomerPricing.of([
      for (final d in designs) (d, PriceRecord.calculate(d, list)),
    ], list);

/// The brief's three designs: A 500, B 700, C 300.
({List<Design> designs, PriceList list}) threeDesigns() {
  final list = listAt(door: 300, window: 700, fitting: 200);
  final a = door(id: 'a')
      .copyWith(pricing: const PricingChoices(installation: true));
  final b = door(kind: DesignKind.window, id: 'b');
  final c = door(id: 'c');
  return (designs: [a, b, c], list: list);
}

CustomerDiscount percent(double p, {String id = 'DSC-1'}) => CustomerDiscount(
  id: id,
  kind: DiscountKind.percent,
  value: (p * 100).round(),
  at: _now,
  by: 'Owner',
);

CustomerDiscount fixedOff(double amount, {String id = 'DSC-1'}) =>
    CustomerDiscount(
      id: id,
      kind: DiscountKind.fixed,
      value: (amount * 100).round(),
      currency: 'USD',
      at: _now,
      by: 'Owner',
    );

StaffMember member(String name, Set<Capability> caps, {bool active = true}) =>
    StaffMember(
      id: 'staff-$name',
      name: name,
      capabilities: caps,
      pinSalt: 's',
      pinHash: 'h',
      createdAt: _now,
      active: active,
    );

Future<Customer> keptAdam() => CustomerStore().create(name: 'Adam', now: _now);

Quotation quote(
  CustomerPricing pricing, {
  CustomerDiscount? discount,
  int number = 1,
  Set<String>? only,
}) {
  final made = Quotation.build(
    customerId: 'adam',
    customerName: 'Adam',
    chosen: [
      for (final d in pricing.designs)
        if (only == null || only.contains(d.designId)) d,
    ],
    currency: 'USD',
    number: number,
    now: _now,
    by: 'Owner',
    money: usd,
    discount: discount,
  );
  expect(made.problem, isNull);
  return made.quotation!;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('discounts', () {
    test('40. A 500 + B 700 + C 300 = 1,500; 10% off is 150; the final total '
        '1,350; 500 and 400 paid is 900, and 450 remains', () {
      final t = threeDesigns();
      final pricing = pricingOf(t.designs, t.list);
      expect([for (final d in pricing.designs) d.state.total], [500, 700, 300]);
      final f = CustomerFinance.of(
        pricing,
        ledgerOf(payments: [500, 400]),
        discount: percent(10),
      );
      expect(f.subtotalCents, 150000);
      expect(f.discountCents, 15000);
      expect(f.totalCents, 135000);
      expect(f.netPaidCents, 90000);
      expect(f.dueCents, 45000);
      expect(f.creditCents, 0);
      expect(f.status, PaymentStatus.outstanding);
      // A payment is not a discount, and a discount not a payment.
      expect(f.grossPaymentsCents, 90000);
    });

    test('a fixed amount: 75 off 1,000 is 925', () {
      final t = listAt(door: 1000);
      final f = CustomerFinance.of(
        pricingOf([door(id: 'd')], t),
        PaymentLedger.empty,
        discount: fixedOff(75),
      );
      expect(f.discountCents, 7500);
      expect(f.totalCents, 92500);
    });

    test('percentages are read to two places, never below nothing or above '
        '100', () {
      expect(CustomerDiscount.readPercent('10').value, 1000);
      expect(CustomerDiscount.readPercent('12.5').value, 1250);
      expect(CustomerDiscount.readPercent('12.75%').value, 1275);
      expect(CustomerDiscount.readPercent('100').value, 10000);
      for (final (typed, said) in [
        ('', 'Enter the discount.'),
        ('-5', 'A discount must be more than nothing.'),
        ('101', 'A percentage cannot be more than 100%.'),
        ('abc', 'Enter the percentage as a number, such as 10 or 12.5.'),
        ('1.234', 'Enter the percentage as a number, such as 10 or 12.5.'),
      ]) {
        expect(
          CustomerDiscount.readPercent(typed).problem,
          said,
          reason: typed,
        );
      }
    });

    test('what cannot be given is said: zero, more than 100%, more than the '
        'subtotal, a fixed amount before the total is final', () {
      String? problem(DiscountKind kind, int? value, int? subtotal) =>
          CustomerDiscount.problemWith(
            kind: kind,
            value: value,
            subtotalCents: subtotal,
            money: usd,
          );
      expect(
        problem(DiscountKind.percent, 0, 50000),
        'A discount must be more than nothing.',
      );
      expect(
        problem(DiscountKind.fixed, 0, 50000),
        'A discount must be more than nothing.',
      );
      expect(
        problem(DiscountKind.percent, 10001, 50000),
        'A percentage cannot be more than 100%.',
      );
      expect(
        problem(DiscountKind.fixed, 60000, 50000),
        'The discount cannot be more than the subtotal, 500.00 USD.',
      );
      expect(problem(DiscountKind.fixed, 5000, null), contains('not final'));
      expect(
        problem(DiscountKind.percent, 1000, null),
        isNull,
        reason: 'a percentage waits for the total',
      );
      expect(
        problem(DiscountKind.fixed, 50000, 50000),
        isNull,
        reason: 'the whole subtotal can be given',
      );
      expect(problem(DiscountKind.percent, null, 50000), 'Enter the discount.');
    });

    test('never a figure below nothing: a fixed discount more than a subtotal '
        'that fell takes the whole subtotal, and says so', () {
      final f = CustomerFinance.of(
        pricingOf([door(id: 'd')], listAt(door: 500)),
        PaymentLedger.empty,
        discount: fixedOff(600),
      );
      expect(f.discountCents, 50000);
      expect(f.totalCents, 0);
      expect(f.discountExceedsSubtotal, isTrue);
      expect(f.dueCents, 0);
    });

    test('one discount in force: a new one replaces the last, a removal takes '
        'it away, and the log keeps every entry', () {
      final log = <CustomerDiscount>[
        percent(10, id: 'DSC-1'),
        fixedOff(50, id: 'DSC-2'),
      ];
      expect(log.inForce!.id, 'DSC-2');
      expect(
        log.inForce!.offCents(100000, 'USD'),
        5000,
        reason: 'never 10% and 50 both',
      );
      log.add(CustomerDiscount.removal(id: 'DSC-3', at: _now, by: 'Owner'));
      expect(log.inForce, isNull);
      expect(log, hasLength(3));
      expect(log.nextDiscountId(_now), 'DSC-20261005-0004');
    });

    test('a fixed discount in another currency takes nothing — it is never '
        'read as the customer\'s', () {
      final euro = CustomerDiscount(
        id: 'D',
        kind: DiscountKind.fixed,
        value: 5000,
        currency: 'EUR',
        at: _now,
        by: 'Owner',
      );
      expect(euro.offCents(100000, 'USD'), 0);
    });

    test('kept: given, read back after a reload, and taken away — by whoever '
        'holds discounts.apply and nobody else', () async {
      final adam = await keptAdam();
      final store = CustomerStore();
      await expectLater(
        store.applyDiscount(adam.id, percent(10), by: WorkshopRole.staff),
        throwsA(isA<AccessDenied>()),
      );
      expect((await store.load(adam.id))!.discounts, isEmpty);
      await store.applyDiscount(adam.id, percent(10), by: WorkshopRole.owner);
      final back = (await CustomerStore().load(adam.id))!;
      expect(back.discount!.kind, DiscountKind.percent);
      expect(back.discount!.value, 1000);
      expect(back.discount!.by, 'Owner');
      expect(back.discount!.at, _now);
      // The same entry twice is one entry.
      await store.applyDiscount(adam.id, percent(10), by: WorkshopRole.owner);
      expect((await store.load(adam.id))!.discounts, hasLength(1));
      // A member of staff given it may.
      final ahmed = member('Ahmed', {Capability.discountsApply});
      await store.applyDiscount(
        adam.id,
        CustomerDiscount.removal(id: 'DSC-2', at: _now, by: 'Ahmed'),
        by: ahmed,
      );
      expect((await store.load(adam.id))!.discount, isNull);
      expect((await store.load(adam.id))!.discounts, hasLength(2));
      // Something that is not a discount is refused.
      await expectLater(
        store.applyDiscount(
          adam.id,
          CustomerDiscount(
            id: 'X',
            kind: DiscountKind.percent,
            value: 20000,
            at: _now,
            by: 'Owner',
          ),
          by: WorkshopRole.owner,
        ),
        throwsArgumentError,
      );
    });

    test(
      'a customer saved from a copy read before the discount keeps it',
      () async {
        final adam = await keptAdam();
        final stale = (await CustomerStore().load(adam.id))!;
        await CustomerStore().applyDiscount(
          adam.id,
          percent(10),
          by: WorkshopRole.owner,
        );
        await CustomerStore().save(stale.copyWith(phone: '0750 123 4567'));
        final back = (await CustomerStore().load(adam.id))!;
        expect(back.phone, '0750 123 4567');
        expect(back.discount?.value, 1000);
      },
    );
  });

  group('quotations', () {
    test('made from the designs\' current prices: each design, the subtotal, '
        'the discount and the final total, as a draft', () {
      final t = threeDesigns();
      final q = quote(pricingOf(t.designs, t.list), discount: percent(10));
      expect(q.label, 'Q-000001');
      expect(q.status, QuotationStatus.draft);
      expect([for (final l in q.lines) l.totalCents], [50000, 70000, 30000]);
      expect(q.subtotalCents, 150000);
      expect(q.discountCents, 15000);
      expect(q.totalCents, 135000);
      expect(q.discount!.value, 1000);
      expect(q.history.single.status, QuotationStatus.draft);
      // The whole price of each design is kept with it.
      expect(q.lines.first.result.totalCents, 50000);
      expect(q.lines.first.result.lines, isNotEmpty);
    });

    test(
      '44. the snapshot: 500 less 50 is quoted at 450; the factory\'s price '
      'rises to 700; the old quotation still says 450 and a new one 650',
      () async {
        final d = door(id: 'd');
        final before = pricingOf([d], listAt(door: 500));
        final old = quote(before, discount: fixedOff(50));
        expect(old.totalCents, 45000);
        final kept = jsonEncode(old.toJson());

        final after = pricingOf([d], listAt(door: 700));
        final again = quote(after, discount: fixedOff(50), number: 2);
        expect(again.totalCents, 65000);
        // Read back, never worked out again: still 450.
        final back = Quotation.fromJson(jsonDecode(kept))!;
        expect(back.totalCents, 45000);
        expect(back.lines.single.totalCents, 50000);
        expect(back.subtotalCents, 50000);
        expect(back.discountCents, 5000);
      },
    );

    test('a design changed after the quotation is said; the quotation is not '
        'rewritten', () {
      final d = door(id: 'd');
      final q = quote(pricingOf([d], listAt(door: 500)));
      final same = pricingOf([d], listAt(door: 900));
      expect(
        q.changedDesigns({
          for (final x in same.designs) x.designId: x.designKey,
        }),
        isEmpty,
        reason: 'the prices moving is not the design changing',
      );
      final wider = d.copyWith(depthMm: d.depthMm + 10);
      final edited = pricingOf([wider], listAt(door: 500));
      expect(
        q
            .changedDesigns({
              for (final x in edited.designs) x.designId: x.designKey,
            })
            .single
            .designId,
        'd',
      );
      expect(
        q.changedDesigns({}).single.designId,
        'd',
        reason: 'a design gone is changed',
      );
      expect(q.totalCents, 50000);
    });

    test('13. an incomplete design cannot be quoted, and is named', () {
      final list = listAt(door: 500);
      final good = door(id: 'good');
      final bad = door(id: 'bad').copyWith(measured: const {});
      final pricing = CustomerPricing.of([
        (good, PriceRecord.calculate(good, list)),
        (bad, null),
      ], list);
      expect(pricing.designs.last.state.isCurrent, isFalse);
      final made = Quotation.build(
        customerId: 'adam',
        customerName: 'Adam',
        chosen: pricing.designs,
        currency: 'USD',
        number: 1,
        now: _now,
        by: 'Owner',
        money: usd,
      );
      expect(made.quotation, isNull);
      expect(made.problem, startsWith(Quotation.incompleteMessage));
      expect(made.problem, contains(pricing.designs.last.name));
      // The complete one alone can be.
      expect(quote(pricing, only: {'good'}).totalCents, 50000);
      // Nothing chosen is nothing to quote.
      expect(
        Quotation.build(
          customerId: 'adam',
          customerName: 'Adam',
          chosen: const [],
          currency: 'USD',
          number: 1,
          now: _now,
          by: 'Owner',
          money: usd,
        ).problem,
        'Choose at least one design.',
      );
    });

    test('a fixed discount more than the quotation\'s subtotal stops it', () {
      final made = Quotation.build(
        customerId: 'adam',
        customerName: 'Adam',
        chosen: pricingOf([door(id: 'd')], listAt(door: 500)).designs,
        currency: 'USD',
        number: 1,
        now: _now,
        by: 'Owner',
        money: usd,
        discount: fixedOff(600),
      );
      expect(made.quotation, isNull);
      expect(made.problem, contains("more than this quotation's subtotal"));
    });

    test('statuses: draft, issued, then accepted, rejected or expired — '
        'never back, and every change kept with who made it', () {
      final q = quote(pricingOf([door(id: 'd')], listAt(door: 500)));
      expect(QuotationStatus.draft.next, [QuotationStatus.issued]);
      expect(
        q.become(QuotationStatus.accepted, at: _now, by: 'x').problem,
        isNotNull,
      );
      final issued = q
          .become(QuotationStatus.issued, at: _now, by: 'Owner')
          .quotation!;
      final accepted = issued
          .become(QuotationStatus.accepted, at: _now, by: 'Ahmed')
          .quotation!;
      expect(accepted.status, QuotationStatus.accepted);
      expect(accepted.history.map((h) => h.status), [
        QuotationStatus.draft,
        QuotationStatus.issued,
        QuotationStatus.accepted,
      ]);
      expect(accepted.history.last.by, 'Ahmed');
      expect(accepted.totalCents, q.totalCents, reason: 'figures unmoved');
      expect(
        accepted.become(QuotationStatus.issued, at: _now, by: 'x').problem,
        isNotNull,
      );
      for (final end in [QuotationStatus.rejected, QuotationStatus.expired]) {
        expect(issued.become(end, at: _now, by: 'x').quotation!.status, end);
      }
    });

    test('kept: numbered from a sequence that never repeats, a page at a time, '
        'read back as made, and only by whoever may', () async {
      final store = QuotationStore();
      final pricing = pricingOf([door(id: 'd')], listAt(door: 500));
      ({Quotation? quotation, String? problem}) build(int n) => Quotation.build(
        customerId: 'adam',
        customerName: 'Adam',
        chosen: pricing.designs,
        currency: 'USD',
        number: n,
        now: _now,
        by: 'Owner',
        money: usd,
      );
      final nobody = member('Nobody', Capability.viewOnly);
      await expectLater(
        store.create(build, by: nobody),
        throwsA(isA<AccessDenied>()),
      );
      final made = await Future.wait([
        for (var i = 0; i < 6; i++) store.create(build, by: WorkshopRole.owner),
      ]);
      expect({for (final m in made) m.quotation!.number}, {1, 2, 3, 4, 5, 6});
      // A refused build uses no number.
      final refused = await store.create(
        (n) => (quotation: null, problem: 'no'),
        by: WorkshopRole.owner,
      );
      expect(refused.problem, 'no');
      final page = await QuotationStore().page('adam', limit: 4);
      expect(page.total, 6);
      expect([for (final q in page.items) q.number], [6, 5, 4, 3]);
      final rest = await QuotationStore().page('adam', offset: 4, limit: 4);
      expect([for (final q in rest.items) q.number], [2, 1]);
      // The sequence lost: it starts after the highest kept.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(QuotationStore.sequenceKey);
      expect(
        (await store.create(build, by: WorkshopRole.owner)).quotation!.number,
        7,
      );
      // Its status, by whoever holds quotations.edit.
      final id = made.first.quotation!.id;
      await expectLater(
        store.setStatus(id, QuotationStatus.issued, by: nobody),
        throwsA(isA<AccessDenied>()),
      );
      final issued = await store.setStatus(
        id,
        QuotationStatus.issued,
        by: member('Sara', {Capability.quotationsEdit}),
      );
      expect(issued.quotation!.status, QuotationStatus.issued);
      final back = (await QuotationStore().load(id))!;
      expect(back.status, QuotationStatus.issued);
      expect(back.history.last.by, 'Sara');
      expect(back.totalCents, 50000);
    });

    test('a quotation read back without its optional parts loads', () {
      final q = quote(pricingOf([door(id: 'd')], listAt(door: 500)));
      final json = q.toJson()
        ..remove('history')
        ..remove('notes')
        ..remove('createdBy')
        ..remove('priceListVersion');
      final back = Quotation.fromJson(json)!;
      expect(back.totalCents, 50000);
      expect(back.history, isEmpty);
      expect(Quotation.fromJson({'number': 1}), isNull);
    });
  });

  group('receipts', () {
    test('43. 1,000 owed and 250 paid: the receipt is for 250, the balance '
        '750; issuing it again changes nothing and makes no second', () async {
      final adam = await keptAdam();
      final store = CustomerStore();
      final pay = transaction(PaymentType.payment, 25000, customerId: adam.id);
      await store.record(pay, by: WorkshopRole.staff);
      final pricing = pricingOf([door(id: 'd')], listAt(door: 1000));
      CustomerFinance finance(Customer c) =>
          CustomerFinance.of(pricing, c.ledger, discount: c.discount);
      final before = finance((await store.load(adam.id))!);
      expect(before.netPaidCents, 25000);
      expect(before.dueCents, 75000);

      final receipt = (await store.issueReceipt(
        customerId: adam.id,
        transactionId: pay.id,
        by: WorkshopRole.staff,
        currency: 'USD',
        balanceAfterCents: before.balanceCents,
        now: _now,
      ))!;
      expect(receipt.label, 'RCP-000001');
      expect(receipt.amountCents, 25000);
      expect(receipt.transactionId, pay.id);
      expect(receipt.balanceAfterCents, 75000);
      expect(receipt.method, PaymentMethod.cash);

      final again = await store.issueReceipt(
        customerId: adam.id,
        transactionId: pay.id,
        by: WorkshopRole.staff,
        currency: 'USD',
        balanceAfterCents: 0,
      );
      expect(again!.number, 1, reason: 'the same receipt');
      final after = (await CustomerStore().load(adam.id))!;
      expect(after.payments, hasLength(1), reason: 'no second payment');
      expect(after.receipts, hasLength(1));
      expect(finance(after).netPaidCents, 25000);
      expect(finance(after).dueCents, 75000);
    });

    test('17. 300 + 250 + 450 against 1,000: three payments, three '
        'receipts, numbered in turn, paid in full', () async {
      final adam = await keptAdam();
      final store = CustomerStore();
      final pays = [
        for (final c in [30000, 25000, 45000])
          transaction(PaymentType.payment, c, customerId: adam.id),
      ];
      for (final p in pays) {
        await store.record(p, by: WorkshopRole.staff);
        await store.issueReceipt(
          customerId: adam.id,
          transactionId: p.id,
          by: WorkshopRole.staff,
          currency: 'USD',
          balanceAfterCents: null,
        );
      }
      final c = (await store.load(adam.id))!;
      expect(
        [for (final r in c.receipts) r.label],
        ['RCP-000001', 'RCP-000002', 'RCP-000003'],
      );
      final f = CustomerFinance.of(
        pricingOf([door(id: 'd')], listAt(door: 1000)),
        c.ledger,
      );
      expect(f.netPaidCents, 100000);
      expect(f.dueCents, 0);
      expect(f.status, PaymentStatus.paidInFull);
      for (final p in pays) {
        expect(c.receiptFor(p.id)!.amountCents, p.amountCents);
      }
    });

    test('numbers are the workshop\'s, across customers, never reused — even '
        'with the sequence lost', () async {
      final store = CustomerStore();
      final adam = await keptAdam();
      final sara = await store.create(name: 'Sara', now: _now);
      Future<Receipt> pay(Customer who, int cents) async {
        final t = transaction(PaymentType.payment, cents, customerId: who.id);
        await store.record(t, by: WorkshopRole.staff);
        return (await store.issueReceipt(
          customerId: who.id,
          transactionId: t.id,
          by: WorkshopRole.staff,
          currency: 'USD',
          balanceAfterCents: null,
        ))!;
      }

      expect((await pay(adam, 100)).number, 1);
      expect((await pay(sara, 100)).number, 2);
      expect((await pay(adam, 100)).number, 3);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(CustomerStore.receiptSequenceKey);
      expect((await pay(sara, 100)).number, 4);
    });

    test('a refund has no receipt; an unknown payment none; and only whoever '
        'holds receipts.create issues one', () async {
      final adam = await keptAdam();
      final store = CustomerStore();
      final pay = transaction(PaymentType.payment, 5000, customerId: adam.id);
      final back = transaction(PaymentType.refund, 1000, customerId: adam.id);
      await store.record(pay, by: WorkshopRole.staff);
      await store.record(back, by: WorkshopRole.staff);
      await expectLater(
        store.issueReceipt(
          customerId: adam.id,
          transactionId: back.id,
          by: WorkshopRole.staff,
          currency: 'USD',
          balanceAfterCents: null,
        ),
        throwsArgumentError,
      );
      expect(
        await store.issueReceipt(
          customerId: adam.id,
          transactionId: 'nothing',
          by: WorkshopRole.staff,
          currency: 'USD',
          balanceAfterCents: null,
        ),
        isNull,
      );
      await expectLater(
        store.issueReceipt(
          customerId: adam.id,
          transactionId: pay.id,
          by: member('Ali', {Capability.paymentsCreate}),
          currency: 'USD',
          balanceAfterCents: null,
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect((await store.load(adam.id))!.receipts, isEmpty);
    });

    test('a receipt round-trips, and one that cannot be read, or repeats a '
        'number or a payment, is passed over', () {
      final r = Receipt.forPayment(
        transaction(PaymentType.payment, 5000),
        number: 7,
        now: _now,
        currency: 'USD',
        balanceAfterCents: -2000,
        by: 'Owner',
      );
      final back = Receipt.fromJson(r.toJson())!;
      expect(back.toJson(), r.toJson());
      final c = Customer.fromJson({
        'id': 'adam',
        'name': 'Adam',
        'createdAt': _now.toIso8601String(),
        'updatedAt': _now.toIso8601String(),
        'receipts': [
          r.toJson(),
          r.toJson(),
          {'number': 'x'},
        ],
      });
      expect(c.receipts, hasLength(1));
    });
  });

  group('history', () {
    test('45. paged: 25 transactions, ten at a time, newest first, none twice, '
        'none missing, the totals the whole ledger\'s', () {
      final ledger = PaymentLedger([
        for (var i = 0; i < 25; i++)
          transaction(
            PaymentType.payment,
            100 * (i + 1),
            at: _now.add(Duration(days: i)),
          ),
      ]);
      final seen = <String>[];
      var offset = 0;
      while (true) {
        final page = ledger.page(offset: offset, limit: 10);
        seen.addAll(page.items.map((t) => t.id));
        offset += page.items.length;
        if (!page.hasMore) break;
      }
      expect(seen, hasLength(25));
      expect(seen.toSet(), hasLength(25));
      expect(seen, [for (final t in ledger.newestFirst) t.id]);
      expect(ledger.page(limit: 10).total, 25);
      expect(ledger.netPaidCents('USD'), 100 * 25 * 26 ~/ 2);
      expect(ledger.page(offset: 30).items, isEmpty);
    });
  });

  group('currencies', () {
    PaymentTransaction inEuro(int cents, {double? rate, PaymentType? type}) =>
        PaymentTransaction(
          id: 'EUR-$cents-${type?.name ?? 'p'}-$rate',
          customerId: 'adam',
          type: type ?? PaymentType.payment,
          amountCents: cents,
          at: _now,
          method: PaymentMethod.bankTransfer,
          createdAt: _now,
          currency: 'EUR',
          conversion: rate == null ? null : Conversion.of(cents, rate, 'USD'),
        );

    test('41. 500 USD and 200 EUR with no rate: paid is 500 USD, the 200 EUR '
        'kept in euros and never added', () {
      final ledger = PaymentLedger([
        transaction(PaymentType.payment, 50000),
        inEuro(20000),
      ]);
      final f = CustomerFinance.of(
        pricingOf([door(id: 'd')], listAt(door: 1000)),
        ledger,
      );
      expect(f.netPaidCents, 50000);
      expect(f.dueCents, 50000);
      expect(f.otherCurrency, 1);
      final euros = f.otherCurrencies.single;
      expect(euros.currency, 'EUR');
      expect(euros.paymentsCents, 20000);
      expect(euros.netCents, 20000);
    });

    test('with a rate given when it was recorded: 100 EUR at 1.10 counts as '
        '110 USD, at that rate for good', () {
      final t = inEuro(10000, rate: 1.10);
      expect(t.conversion!.cents, 11000);
      expect(t.countedIn('USD'), 11000);
      expect(t.countedIn('GBP'), isNull);
      final back = PaymentTransaction.fromJson(
        jsonDecode(jsonEncode(t.toJson())),
      )!;
      expect(back.conversion!.rate, 1.10);
      expect(back.conversion!.cents, 11000);
      final ledger = PaymentLedger([
        transaction(PaymentType.payment, 50000),
        back,
      ]);
      expect(ledger.netPaidCents('USD'), 61000);
      expect(ledger.otherCurrencyCount('USD'), 0);
      // Rounding: half a cent up.
      expect(Conversion.of(333, 1.5, 'USD').cents, 500);
    });

    test('a refund in euros is limited by what was paid in euros', () {
      final ledger = PaymentLedger([inEuro(20000)]);
      Map<String, String> asked(int cents) => ledger.problemsWith(
        type: PaymentType.refund,
        cents: cents,
        at: _now,
        now: _now,
        currency: 'USD',
        money: usd,
        inCurrency: 'EUR',
        moneyIn: (c, cur) => '${(c / 100).toStringAsFixed(2)} $cur',
      );
      expect(asked(20000), isEmpty);
      expect(
        asked(20001)['amount'],
        'A refund cannot be more than the net paid, 200.00 EUR.',
      );
      expect(
        PaymentLedger.empty.problemsWith(
          type: PaymentType.refund,
          cents: 100,
          at: _now,
          now: _now,
          currency: 'USD',
          money: usd,
          inCurrency: 'EUR',
        )['amount'],
        'Nothing has been paid in EUR, so nothing can be refunded.',
      );
    });

    test('a rate is a figure of more than nothing, or nothing at all', () {
      expect(PaymentLedger.readRate('1.10').rate, 1.10);
      expect(PaymentLedger.readRate('').rate, isNull);
      expect(PaymentLedger.readRate('').problem, isNull);
      expect(PaymentLedger.readRate('abc').problem, isNotNull);
      expect(PaymentLedger.readRate('0').problem, isNotNull);
      expect(PaymentLedger.readRate('-1').problem, isNotNull);
      expect(PaymentLedger.readRate('1.1234567').problem, isNotNull);
    });

    test('a conversion that is not one is no conversion', () {
      for (final bad in [
        {'to': 'USD', 'rate': 0, 'cents': 10},
        {'to': '', 'rate': 1, 'cents': 10},
        {'to': 'USD', 'rate': 1, 'cents': -1},
        'x',
      ]) {
        expect(Conversion.fromJson(bad), isNull, reason: '$bad');
      }
    });
  });

  group('permissions', () {
    test('42. the owner may do everything', () {
      for (final c in Capability.values) {
        expect(WorkshopRole.owner.can(c), isTrue, reason: c.key);
      }
    });

    test('the device with no staff accounts may do what it always could, and '
        'never change prices, discount or manage staff', () {
      for (final c in [
        Capability.paymentsCreate,
        Capability.paymentsRefund,
        Capability.receiptsCreate,
        Capability.quotationsCreate,
        Capability.financialView,
        Capability.pricingView,
      ]) {
        expect(WorkshopRole.staff.can(c), isTrue, reason: c.key);
      }
      for (final c in [
        Capability.pricingEdit,
        Capability.discountsApply,
        Capability.usersManage,
        Capability.permissionsManage,
      ]) {
        expect(WorkshopRole.staff.can(c), isFalse, reason: c.key);
      }
      expect(WorkshopRole.staff.canConfigurePrices, isFalse);
    });

    test('nobody signed in, once there are staff accounts, may only look', () {
      const nobody = NobodySignedIn();
      for (final c in Capability.values) {
        expect(nobody.can(c), Capability.viewOnly.contains(c), reason: c.key);
      }
    });

    test('42. staff without financial permissions are refused, by the stores, '
        'whatever screen asked', () async {
      final adam = await keptAdam();
      final looker = member('Looker', Capability.viewOnly);
      final store = CustomerStore();
      final pay = transaction(PaymentType.payment, 100, customerId: adam.id);
      await expectLater(
        store.record(pay, by: looker),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        store.applyDiscount(adam.id, percent(5), by: looker),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        PriceListStore().save(fixed, by: looker),
        throwsA(isA<AccessDenied>()),
      );
      final kept = (await store.load(adam.id))!;
      expect(kept.payments, isEmpty);
      expect(kept.discounts, isEmpty);
      final denied = AccessDenied(looker, Capability.paymentsCreate);
      expect(denied.toString(), contains('payments.create'));
    });

    test('42. staff with payment permission may record payments and see the '
        'finances — and not edit prices unless given it', () async {
      final adam = await keptAdam();
      final cashier = member('Cashier', {
        ...Capability.viewOnly,
        Capability.paymentsCreate,
      });
      expect(cashier.can(Capability.financialView), isTrue);
      final pay = transaction(PaymentType.payment, 100, customerId: adam.id);
      await CustomerStore().record(pay, by: cashier);
      expect((await CustomerStore().load(adam.id))!.payments, hasLength(1));
      await expectLater(
        CustomerStore().record(
          transaction(PaymentType.refund, 50, customerId: adam.id),
          by: cashier,
        ),
        throwsA(isA<AccessDenied>()),
        reason: 'a refund is its own permission',
      );
      await expectLater(
        PriceListStore().save(fixed, by: cashier),
        throwsA(isA<AccessDenied>()),
      );
      final pricer = cashier.copyWith(
        capabilities: {...cashier.capabilities, Capability.pricingEdit},
      );
      final kept = await PriceListStore().save(fixed, by: pricer);
      expect(kept.version, 1);
      // Made inactive, they may do nothing.
      expect(pricer.copyWith(active: false).can(Capability.pricingView), false);
    });

    test('staff are added and given permissions only by whoever may, never '
        'beyond what they hold, and sign in by their own PIN', () async {
      final store = StaffStore();
      await expectLater(
        store.add(
          name: 'Ahmed',
          pin: '1234',
          capabilities: Capability.viewOnly,
          by: WorkshopRole.staff,
        ),
        throwsA(isA<AccessDenied>()),
      );
      expect(await store.hasAccounts(), isFalse);
      final ahmed = await store.add(
        name: 'Ahmed',
        pin: '1234',
        capabilities: Capability.viewOnly,
        by: WorkshopRole.owner,
        now: _now,
      );
      expect(ahmed.capabilities, Capability.viewOnly);
      expect(await store.hasAccounts(), isTrue);
      expect(await store.signIn(ahmed.id, '1234'), isNotNull);
      expect(await store.signIn(ahmed.id, '9999'), isNull);
      expect(
        jsonEncode(
          (await SharedPreferences.getInstance()).getString(StaffStore.key),
        ),
        isNot(contains('1234')),
        reason: 'the PIN is never kept',
      );
      // The same name twice is refused; a short PIN too.
      await expectLater(
        store.add(
          name: ' ahmed ',
          pin: '1234',
          capabilities: const {},
          by: WorkshopRole.owner,
        ),
        throwsArgumentError,
      );
      await expectLater(
        store.add(
          name: 'Sara',
          pin: '12',
          capabilities: const {},
          by: WorkshopRole.owner,
        ),
        throwsArgumentError,
      );
      // The owner gives Ahmed payments and permissions.manage.
      final given = await store.setCapabilities(ahmed.id, {
        ...Capability.viewOnly,
        Capability.paymentsCreate,
        Capability.permissionsManage,
        Capability.usersManage,
      }, by: WorkshopRole.owner);
      expect(given.can(Capability.paymentsCreate), isTrue);
      // Ahmed adds Sara, and may give her what he holds and nothing more.
      final sara = await store.add(
        name: 'Sara',
        pin: '5678',
        capabilities: const {},
        by: given,
      );
      await store.setCapabilities(sara.id, {
        Capability.paymentsCreate,
      }, by: given);
      await expectLater(
        store.setCapabilities(sara.id, {Capability.pricingEdit}, by: given),
        throwsA(isA<AccessDenied>()),
      );
      await expectLater(
        store.setCapabilities(ahmed.id, {
          ...given.capabilities,
          Capability.discountsApply,
        }, by: given),
        throwsA(isA<AccessDenied>()),
        reason: 'nobody gives themselves more',
      );
      // Made inactive: cannot sign in, may do nothing; never removed.
      await store.setActive(sara.id, active: false, by: WorkshopRole.owner);
      expect(await store.signIn(sara.id, '5678'), isNull);
      final all = await StaffStore().all();
      expect(all.map((m) => m.name), ['Ahmed', 'Sara']);
      expect(all.last.can(Capability.paymentsCreate), isFalse);
      await store.setPin(sara.id, '4321', by: WorkshopRole.owner);
      await store.setActive(sara.id, active: true, by: WorkshopRole.owner);
      expect(await store.signIn(sara.id, '4321'), isNotNull);
    });

    test('a capability this version does not know is passed over', () {
      final m = StaffMember.fromJson({
        'id': 's',
        'name': 'S',
        'capabilities': ['payments.create', 'rockets.launch'],
        'pinSalt': 'a',
        'pinHash': 'b',
        'createdAt': _now.toIso8601String(),
      })!;
      expect(m.capabilities, {Capability.paymentsCreate});
      expect(StaffMember.fromJson({'id': 's'}), isNull);
    });
  });

  group('older records', () {
    test(
      'a customer kept before Phase 31 — payments with no currency, '
      'conversion or recorder, no discount, no receipts — loads as it was',
      () async {
        final old = {
          'id': 'customer-old',
          'name': 'Old Adam',
          'payments': [
            {
              'id': 'PAY-20261001-0001',
              'customerId': 'customer-old',
              'type': 'payment',
              'amountCents': 30000,
              'at': '2026-10-01T12:00:00.000',
              'method': 'cash',
              'createdAt': '2026-10-01T12:00:00.000',
            },
          ],
          'createdAt': '2026-03-01T00:00:00.000',
          'updatedAt': '2026-10-01T12:00:00.000',
        };
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          '${CustomerStore.customerKeyPrefix}customer-old',
          jsonEncode(old),
        );
        final c = (await CustomerStore().load('customer-old'))!;
        expect(c.discounts, isEmpty);
        expect(c.discount, isNull);
        expect(c.receipts, isEmpty);
        final t = c.payments.single;
        expect(t.currency, isNull);
        expect(t.conversion, isNull);
        expect(t.recordedBy, '');
        expect(t.countedIn('USD'), 30000, reason: 'the price list\'s currency');
        // Its receipt can be issued now.
        final r = await CustomerStore().issueReceipt(
          customerId: 'customer-old',
          transactionId: t.id,
          by: WorkshopRole.staff,
          currency: 'USD',
          balanceAfterCents: null,
        );
        expect(r!.currency, 'USD');
        expect(r.label, 'RCP-000001');
        // And the old payment is written back as it was.
        final again = (await CustomerStore().load('customer-old'))!;
        expect(again.payments.single.toJson(), t.toJson());
      },
    );

    test('a customer with only the oldest paid figure still has it, once', () {
      final c = Customer.fromJson({
        'id': 'x',
        'name': 'X',
        'paid': 750,
        'createdAt': _now.toIso8601String(),
        'updatedAt': _now.toIso8601String(),
      });
      expect(c.ledger.netPaidCents('USD'), 75000);
      expect(c.discounts, isEmpty);
    });
  });

  group('one price engine', () {
    test('a discount, a quotation and a payment move no design price', () {
      final t = threeDesigns();
      final before = [
        for (final d in t.designs) const PricingEngine().price(d, t.list).total,
      ];
      final pricing = pricingOf(t.designs, t.list);
      quote(pricing, discount: percent(10));
      CustomerFinance.of(
        pricing,
        ledgerOf(payments: [500]),
        discount: percent(10),
      );
      expect([
        for (final d in t.designs) const PricingEngine().price(d, t.list).total,
      ], before);
      expect(pricing.totalCents, 150000);
    });
  });
}
