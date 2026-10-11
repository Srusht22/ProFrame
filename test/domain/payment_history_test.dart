import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'price_readiness_test.dart' show fixed;
import 'pricing_engine_test.dart' show door, given;

// Phase 30: a customer's payment ledger. Payments and refunds are
// transactions, each with an id, a customer, a date, a method and a note;
// what the customer has paid is summed from them, never kept beside them;
// and the balance against what their designs come to is due, paid in full
// or credit. Nothing here touches a design or a price.

final _day = DateTime(2026, 10, 5, 9, 30);
var _made = 0;

/// A transaction of [type] for [cents] — the test's own.
PaymentTransaction transaction(
  PaymentType type,
  int cents, {
  String customerId = 'adam',
  DateTime? at,
  DateTime? createdAt,
  PaymentMethod method = PaymentMethod.cash,
  String note = '',
  String? id,
  String currency = 'USD',
}) {
  final n = _made++;
  return PaymentTransaction(
    id: id ?? '${type == PaymentType.payment ? 'PAY' : 'REF'}-T-$n',
    customerId: customerId,
    type: type,
    amountCents: cents,
    at: at ?? _day.add(Duration(minutes: n)),
    method: method,
    note: note,
    createdAt: createdAt ?? _day.add(Duration(minutes: n)),
    currency: currency,
  );
}

/// A ledger of [payments] and [refunds], in whole currency units.
PaymentLedger ledgerOf({
  List<double> payments = const [],
  List<double> refunds = const [],
}) => PaymentLedger([
  for (final p in payments) transaction(PaymentType.payment, (p * 100).round()),
  for (final r in refunds) transaction(PaymentType.refund, (r * 100).round()),
]);

/// A ledger of one payment of [amount].
PaymentLedger paid(double amount) =>
    amount == 0 ? PaymentLedger.empty : ledgerOf(payments: [amount]);

/// A customer's designs coming to [total], as `CustomerPricing` sums them:
/// one door, priced at a list whose only figure is a door's making.
CustomerPricing pricedAt(double total) {
  final list = fixed.copyWith(
    categories: {
      ...fixed.categories,
      'door': CategoryRate('Door', LabourRate(fixed: total)),
    },
  );
  final d = door(id: 'priced');
  return CustomerPricing.of([(d, PriceRecord.calculate(d, list))], list);
}

String _money(int cents) => '${(cents / 100).toStringAsFixed(2)} USD';

Map<String, String> problems(
  PaymentLedger ledger,
  PaymentType type,
  int? cents, {
  DateTime? at,
}) => ledger.problemsWith(
  type: type,
  cents: cents,
  at: at ?? _day,
  now: _day.add(const Duration(hours: 1)),
  currency: 'USD',
  money: _money,
);

Customer adam({List<PaymentTransaction> payments = const []}) => Customer(
  id: 'adam',
  name: 'Adam',
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 1),
  payments: payments,
);

// Since Phase 31 the store asks who records money (`by:`); these record as
// the device with no staff accounts, which may (`WorkshopRole.staff`).
// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the helper prices designs at the figure asked', () {
    expect(pricedAt(1000).total, 1000);
    expect(pricedAt(1000).isFinal, isTrue);
  });

  group('46. the financial scenarios', () {
    void expectFinance(
      CustomerFinance f, {
      required double netPaid,
      required double due,
      required double credit,
      PaymentStatus? status,
    }) {
      expect(f.netPaid, netPaid);
      expect(f.due, due);
      expect(f.credit, credit);
      if (status != null) expect(f.status, status);
    }

    test('A — partial payment: 1,000 with 400 paid is 600 due', () {
      expectFinance(
        CustomerFinance.of(pricedAt(1000), ledgerOf(payments: [400])),
        netPaid: 400,
        due: 600,
        credit: 0,
        status: PaymentStatus.outstanding,
      );
    });

    test('B — full payment: paid in full', () {
      expectFinance(
        CustomerFinance.of(pricedAt(1000), ledgerOf(payments: [1000])),
        netPaid: 1000,
        due: 0,
        credit: 0,
        status: PaymentStatus.paidInFull,
      );
    });

    test('C — overpayment: 1,200 against 1,000 is 200 credit, never a '
        'negative amount due', () {
      final f = CustomerFinance.of(pricedAt(1000), ledgerOf(payments: [1200]));
      expectFinance(
        f,
        netPaid: 1200,
        due: 0,
        credit: 200,
        status: PaymentStatus.credit,
      );
      expect(f.balanceCents, -20000);
      expect(f.dueCents, 0);
    });

    test('D — refund after full payment: 200 due again', () {
      expectFinance(
        CustomerFinance.of(
          pricedAt(1000),
          ledgerOf(payments: [1000], refunds: [200]),
        ),
        netPaid: 800,
        due: 200,
        credit: 0,
        status: PaymentStatus.outstanding,
      );
    });

    test('E — several payments: 500 + 700 + 300 against 2,000', () {
      final f = CustomerFinance.of(
        pricedAt(2000),
        ledgerOf(payments: [500, 700, 300]),
      );
      expect(f.grossPayments, 1500);
      expectFinance(f, netPaid: 1500, due: 500, credit: 0);
    });

    test('F — payment, refund and credit: 1,300 less 100 against 1,000', () {
      final f = CustomerFinance.of(
        pricedAt(1000),
        ledgerOf(payments: [1300], refunds: [100]),
      );
      expect(f.grossPayments, 1300);
      expect(f.grossRefunds, 100);
      expectFinance(
        f,
        netPaid: 1200,
        due: 0,
        credit: 200,
        status: PaymentStatus.credit,
      );
    });

    test('25. refund after a partial payment: 600 less 100 leaves 500 due', () {
      expectFinance(
        CustomerFinance.of(
          pricedAt(1000),
          ledgerOf(payments: [600], refunds: [100]),
        ),
        netPaid: 500,
        due: 500,
        credit: 0,
      );
    });

    test('24. credit refunded: 1,200 paid against 1,000, 200 refunded, paid '
        'in full', () {
      final before = ledgerOf(payments: [1200]);
      expect(problems(before, PaymentType.refund, 20000), isEmpty);
      final f = CustomerFinance.of(
        pricedAt(1000),
        PaymentLedger([
          ...before.transactions,
          transaction(PaymentType.refund, 20000),
        ]),
      );
      expectFinance(
        f,
        netPaid: 1000,
        due: 0,
        credit: 0,
        status: PaymentStatus.paidInFull,
      );
    });

    test('several refunds are summed', () {
      final f = CustomerFinance.of(
        pricedAt(1000),
        ledgerOf(payments: [1000], refunds: [100, 50.25]),
      );
      expect(f.grossRefunds, 150.25);
      expectFinance(f, netPaid: 849.75, due: 150.25, credit: 0);
    });

    test('nothing to pay and nothing paid; a total not final says neither '
        'due nor credit', () {
      final none = CustomerFinance.of(
        CustomerPricing.of(const [], fixed),
        PaymentLedger.empty,
      );
      expect(none.status, PaymentStatus.nothingToPay);
      final notFinal = CustomerFinance.of(
        CustomerPricing.of([(door(), null)], fixed),
        ledgerOf(payments: [300]),
      );
      expect(notFinal.status, PaymentStatus.pricingIncomplete);
      expect(notFinal.status.label, 'Pricing incomplete');
      expect(notFinal.due, isNull);
      expect(notFinal.credit, isNull);
      expect(notFinal.netPaid, 300, reason: 'what was paid is still known');
    });

    test('47. three designs, 500 + 700 + 300, with 500 and 400 paid: the '
        'total is the designs\' own prices, summed', () {
      // A door's making 300, a window's 700, and fitting 200 for the door
      // that asks for it: 500, 700 and 300.
      final list = fixed.copyWith(
        categories: {
          ...fixed.categories,
          'door': const CategoryRate('Door', LabourRate(fixed: 300)),
          'window': const CategoryRate('Window', LabourRate(fixed: 700)),
        },
        installation: const InstallationRate(fixed: 200),
      );
      final a = door(id: 'a')
          .copyWith(pricing: const PricingChoices(installation: true));
      final b = door(kind: DesignKind.window, id: 'b');
      final c = door(id: 'c');
      final each = [
        for (final d in [a, b, c]) const PricingEngine().price(d, list).total,
      ];
      expect(each, [500, 700, 300]);
      final pricing = CustomerPricing.of([
        for (final d in [a, b, c]) (d, PriceRecord.calculate(d, list)),
      ], list);
      final f = CustomerFinance.of(pricing, ledgerOf(payments: [500, 400]));
      expect(f.total, 1500);
      expect(f.grossPayments, 900);
      expect(f.grossRefunds, 0);
      expect(f.netPaid, 900);
      expect(f.due, 600);
      expect(f.credit, 0);
      expect(f.status, PaymentStatus.outstanding);
    });
  });

  group('transactions', () {
    test('a payment and a refund: each its id, its customer, its type, its '
        'amount in cents, its date, method and note', () {
      final ledger = adam().ledger;
      final now = DateTime(2026, 10, 5, 14);
      final payId = ledger.nextId(PaymentType.payment, now);
      expect(payId, 'PAY-20261005-0001');
      final pay = transaction(
        PaymentType.payment,
        50000,
        id: payId,
        method: PaymentMethod.bankTransfer,
        note: 'First installment',
      );
      final after = ledger.plus(pay);
      expect(after.nextId(PaymentType.refund, now), 'REF-20261005-0002');
      expect(pay.signedCents, 50000);
      expect(transaction(PaymentType.refund, 10000).signedCents, -10000);
      expect(pay.methodLabel, 'Bank transfer');
      expect(after.plus(pay).transactions, hasLength(1), reason: 'once');
    });

    test('ids never repeat, however many and whatever was recorded first', () {
      var ledger = PaymentLedger.empty;
      final at = DateTime(2026, 10, 5);
      final seen = <String>{};
      for (var i = 0; i < 30; i++) {
        final type = i.isEven ? PaymentType.payment : PaymentType.refund;
        final id = ledger.nextId(type, at);
        expect(seen.add(id), isTrue);
        ledger = ledger.plus(transaction(type, 100, id: id));
      }
      // A ledger kept with an id that the next number would have made.
      final odd = PaymentLedger([
        transaction(PaymentType.payment, 100, id: 'PAY-20261005-0002'),
      ]);
      expect(odd.nextId(PaymentType.payment, at), 'PAY-20261005-0003');
    });

    test('other, with a description; without one it is Other', () {
      final cheque = PaymentTransaction(
        id: 'PAY-1',
        customerId: 'adam',
        type: PaymentType.payment,
        amountCents: 100,
        at: _day,
        method: PaymentMethod.other,
        methodDetail: 'Company cheque',
        createdAt: _day,
      );
      expect(cheque.methodLabel, 'Other — Company cheque');
      expect(
        PaymentTransaction.fromJson(cheque.toJson())!.methodLabel,
        'Other — Company cheque',
      );
      expect(
        transaction(
          PaymentType.payment,
          100,
          method: PaymentMethod.other,
        ).methodLabel,
        'Other',
      );
      expect(PaymentMethod.offered.map((m) => m.label), [
        'Cash',
        'Bank transfer',
        'Card',
        'Other',
      ]);
    });

    test('newest first, by date, then by when it was recorded, then by id '
        '— never only the order kept', () {
      final oct5 = transaction(
        PaymentType.payment,
        50000,
        at: DateTime(2026, 10, 5),
        id: 'PAY-A',
      );
      final sep28 = transaction(
        PaymentType.payment,
        30000,
        at: DateTime(2026, 9, 28),
        id: 'PAY-B',
      );
      final oct2 = transaction(
        PaymentType.refund,
        10000,
        at: DateTime(2026, 10, 2),
        id: 'REF-C',
      );
      final sep20 = transaction(
        PaymentType.payment,
        20000,
        at: DateTime(2026, 9, 20),
        id: 'PAY-D',
      );
      // Recorded out of order: the September payment last.
      final ledger = PaymentLedger([oct2, oct5, sep20, sep28]);
      expect(ledger.newestFirst.map((t) => t.id), [
        'PAY-A',
        'REF-C',
        'PAY-B',
        'PAY-D',
      ]);
      // Two on the same moment: the one recorded later first, and for the
      // same moment recorded, by id.
      final same = DateTime(2026, 10, 1);
      final x = transaction(
        PaymentType.payment,
        1,
        at: same,
        createdAt: DateTime(2026, 10, 1, 8),
        id: 'PAY-X',
      );
      final y = transaction(
        PaymentType.payment,
        1,
        at: same,
        createdAt: DateTime(2026, 10, 1, 9),
        id: 'PAY-Y',
      );
      final z = transaction(
        PaymentType.payment,
        1,
        at: same,
        createdAt: DateTime(2026, 10, 1, 9),
        id: 'PAY-Z',
      );
      expect(PaymentLedger([x, z, y]).newestFirst.map((t) => t.id), [
        'PAY-Z',
        'PAY-Y',
        'PAY-X',
      ]);
    });
  });

  group('validation', () {
    test('15. an amount is a figure of more than nothing, to the cent', () {
      expect(PaymentLedger.readAmount('500.00').cents, 50000);
      expect(PaymentLedger.readAmount(' 1,200.5 ').cents, 120050);
      expect(PaymentLedger.readAmount('.75').cents, 75);
      expect(PaymentLedger.readAmount('287.21').cents, 28721);
      for (final (text, problem) in [
        ('', 'Enter an amount.'),
        ('0', 'The amount must be more than nothing.'),
        ('0.00', 'The amount must be more than nothing.'),
        ('-100', 'The amount must be more than nothing.'),
        ('abc', 'Enter the amount as a number, such as 500.00.'),
        (r'$500', 'Enter the amount as a number, such as 500.00.'),
        ('5e3', 'Enter the amount as a number, such as 500.00.'),
        (
          '12.345',
          'Enter the amount to the cent — two decimal places at '
              'most.',
        ),
      ]) {
        final read = PaymentLedger.readAmount(text);
        expect(read.cents, isNull, reason: text);
        expect(read.problem, problem, reason: text);
      }
    });

    test('7 & 8. a payment and a refund are each more than nothing', () {
      final some = ledgerOf(payments: [500]);
      for (final type in PaymentType.values) {
        expect(problems(some, type, 0)['amount'], isNotNull);
        expect(problems(some, type, -100)['amount'], isNotNull);
        expect(problems(some, type, null)['amount'], isNotNull);
      }
      expect(problems(some, PaymentType.payment, 50000), isEmpty);
    });

    test('16. a payment of more than is due is taken — it is credit', () {
      expect(
        problems(ledgerOf(payments: [1000]), PaymentType.payment, 1),
        isEmpty,
      );
      expect(
        problems(PaymentLedger.empty, PaymentType.payment, 99999999),
        isEmpty,
      );
    });

    test('24. a refund is never more than the net paid', () {
      final thousand = ledgerOf(payments: [1000]);
      expect(
        problems(thousand, PaymentType.refund, 110000)['amount'],
        'A refund cannot be more than the net paid, 1000.00 USD.',
      );
      expect(problems(thousand, PaymentType.refund, 100000), isEmpty);
      expect(
        problems(PaymentLedger.empty, PaymentType.refund, 100)['amount'],
        'Nothing has been paid, so nothing can be refunded.',
      );
      final refunded = ledgerOf(payments: [1000], refunds: [400]);
      expect(
        problems(refunded, PaymentType.refund, 60001)['amount'],
        isNotNull,
      );
      expect(problems(refunded, PaymentType.refund, 60000), isEmpty);
    });

    test('12. nothing is dated after now', () {
      final now = _day.add(const Duration(hours: 1));
      expect(
        problems(
          PaymentLedger.empty,
          PaymentType.payment,
          100,
          at: now.add(const Duration(days: 1)),
        )['date'],
        'Payments cannot be dated in the future.',
      );
      expect(
        problems(
          ledgerOf(payments: [10]),
          PaymentType.refund,
          100,
          at: now.add(const Duration(minutes: 1)),
        )['date'],
        'Refunds cannot be dated in the future.',
      );
      expect(
        problems(
          PaymentLedger.empty,
          PaymentType.payment,
          100,
          at: DateTime(2026, 9, 20),
        ),
        isEmpty,
      );
    });
  });

  group('kept and read back', () {
    test('33. a payment and a refund round-trip: id, customer, type, amount, '
        'date, method, its description, note, recorded and currency', () {
      for (final t in [
        PaymentTransaction(
          id: 'PAY-20261005-0001',
          customerId: 'adam',
          type: PaymentType.payment,
          amountCents: 28721,
          at: DateTime(2026, 10, 5, 9, 14, 3),
          method: PaymentMethod.other,
          methodDetail: 'Company cheque',
          note: 'First installment for front entrance door',
          createdAt: DateTime(2026, 10, 5, 11),
          currency: 'USD',
        ),
        PaymentTransaction(
          id: 'REF-20261005-0002',
          customerId: 'adam',
          type: PaymentType.refund,
          amountCents: 10000,
          at: DateTime(2026, 10, 2),
          method: PaymentMethod.cash,
          note: 'Refund for cancelled hardware',
          createdAt: DateTime(2026, 10, 5, 12),
          currency: 'USD',
        ),
      ]) {
        final back = PaymentTransaction.fromJson(
          jsonDecode(jsonEncode(t.toJson())),
        )!;
        expect(jsonEncode(back.toJson()), jsonEncode(t.toJson()));
        expect(back.amountCents, t.amountCents);
        expect(back.at, t.at);
        expect(back.type, t.type);
        expect(back.customerId, 'adam');
      }
    });

    test('a transaction that is not one is passed over, and one kept with a '
        'customer is that customer\'s', () {
      final good = transaction(PaymentType.payment, 100).toJson();
      for (final bad in [
        {...good, 'amountCents': 0},
        {...good, 'amountCents': -5},
        {...good, 'amountCents': 1.5},
        {...good, 'type': 'discount'},
        {...good, 'at': 'yesterday'},
        {...good, 'id': ''},
        'not a transaction',
      ]) {
        expect(PaymentTransaction.fromJson(bad), isNull, reason: '$bad');
      }
      final customer = Customer.fromJson({
        ...adam().toJson(),
        'payments': [
          {...good, 'customerId': 'sara'},
          good,
          {...good, 'amountCents': 0},
        ],
      });
      expect(customer.payments, hasLength(1), reason: 'once, and only valid');
      expect(customer.payments.single.customerId, 'adam');
    });

    test('32. on the device: payments and refunds survive a reload, and the '
        'customer\'s other details do not move them', () async {
      final people = CustomerStore();
      final made = await people.create(
        name: 'Adam',
        phone: '0750',
        by: WorkshopRole.owner,
      );
      final pay = transaction(
        PaymentType.payment,
        50000,
        customerId: made.id,
        note: 'Deposit',
      );
      final refund = transaction(
        PaymentType.refund,
        10000,
        customerId: made.id,
        method: PaymentMethod.card,
      );
      await people.record(pay, by: WorkshopRole.staff);
      await people.record(refund, by: WorkshopRole.staff);
      await people.record(refund, by: WorkshopRole.staff);
      final back = (await CustomerStore().load(made.id))!;
      expect(back.payments.map((t) => t.id), [pay.id, refund.id]);
      expect(back.ledger.netPaidCents('USD'), 40000);
      expect(back.payments.first.note, 'Deposit');
      expect(back.payments.last.method, PaymentMethod.card);
      // Editing the customer from a copy made before the payments keeps
      // every one of them.
      await people.save(made.copyWith(phone: '0751'), by: WorkshopRole.owner);
      final edited = (await CustomerStore().load(made.id))!;
      expect(edited.phone, '0751');
      expect(edited.payments.map((t) => t.id), [pay.id, refund.id]);
      // Nothing is recorded against a customer who is not kept.
      expect(
        await people.record(
          transaction(PaymentType.payment, 1, customerId: 'x'),
          by: WorkshopRole.staff,
        ),
        isNull,
      );
    });

    test('two recorded at once are both kept', () async {
      final people = CustomerStore();
      final made = await people.create(name: 'Adam', by: WorkshopRole.owner);
      await Future.wait([
        for (var i = 0; i < 6; i++)
          CustomerStore().record(
            transaction(PaymentType.payment, 100, customerId: made.id),
            by: WorkshopRole.staff,
          ),
      ]);
      final back = (await CustomerStore().load(made.id))!;
      expect(back.payments, hasLength(6));
    });
  });

  group('34 & 35 & 57. a customer kept with one paid figure', () {
    Map<String, Object?> old(Object? paid) => {
      'id': 'adam',
      'name': 'Adam',
      'notes': 'Second floor',
      'paid': paid,
      'createdAt': '2026-03-01T00:00:00.000',
      'updatedAt': '2026-04-12T10:30:00.000',
    };

    test('500 paid becomes one legacy payment of 500, and only one however '
        'often it is read', () {
      final first = Customer.fromJson(old(500));
      expect(first.payments, hasLength(1));
      final legacy = first.payments.single;
      expect(legacy.id, PaymentTransaction.legacyId);
      expect(legacy.isLegacy, isTrue);
      expect(legacy.type, PaymentType.payment);
      expect(legacy.amountCents, 50000);
      expect(legacy.method, PaymentMethod.legacy);
      expect(legacy.methodLabel, 'Legacy / unknown');
      expect(legacy.note, PaymentTransaction.legacyNote);
      expect(legacy.at, DateTime(2026, 4, 12, 10, 30));
      expect(legacy.customerId, 'adam');
      expect(first.notes, 'Second floor', reason: 'not in the notes');
      // Read again, and again from what it is written as.
      expect(Customer.fromJson(old(500)).payments, hasLength(1));
      final written = first.toJson();
      expect(written.containsKey('paid'), isFalse);
      final again = Customer.fromJson(
        jsonDecode(jsonEncode(written)) as Map<String, Object?>,
      );
      expect(again.payments, hasLength(1));
      expect(again.ledger.netPaidCents('USD'), 50000);
    });

    test('750 paid is 750 in the summary, never nothing', () {
      final c = Customer.fromJson(old(750));
      final f = CustomerFinance.of(pricedAt(1000), c.ledger);
      expect(f.netPaid, 750);
      expect(f.due, 250);
      expect(Customer.fromJson(old(287.21)).payments.single.amountCents, 28721);
    });

    test('nothing paid, or a figure that is not one, is no payment', () {
      for (final bad in [null, 0, -5, 'lots', double.nan]) {
        expect(Customer.fromJson(old(bad)).payments, isEmpty, reason: '$bad');
      }
    });

    test('on the device: an old customer loads with the 500, stays at 500 '
        'through reads, a save, a payment and a reload', () async {
      SharedPreferences.setMockInitialValues({
        '${CustomerStore.customerKeyPrefix}adam': jsonEncode(old(500)),
        CustomerStore.indexKey: jsonEncode([
          {
            'id': 'adam',
            'name': 'Adam',
            'createdAt': '2026-03-01T00:00:00.000',
            'updatedAt': '2026-04-12T10:30:00.000',
          },
        ]),
      });
      final store = CustomerStore();
      for (var i = 0; i < 3; i++) {
        final read = (await CustomerStore().load('adam'))!;
        expect(read.payments.map((t) => t.amountCents), [50000]);
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('${CustomerStore.customerKeyPrefix}adam'),
        jsonEncode(old(500)),
        reason: 'reading writes nothing',
      );
      await store.record(
        transaction(PaymentType.payment, 25000, customerId: 'adam'),
        by: WorkshopRole.staff,
      );
      for (var i = 0; i < 3; i++) {
        final read = (await CustomerStore().load('adam'))!;
        expect(read.payments.map((t) => t.amountCents), [50000, 25000]);
        expect(
          read.payments.where((t) => t.isLegacy),
          hasLength(1),
          reason: 'the 500 brought over once',
        );
      }
      final kept = jsonDecode(
        prefs.getString('${CustomerStore.customerKeyPrefix}adam')!,
      ) as Map<String, Object?>;
      expect(kept.containsKey('paid'), isFalse, reason: 'one record of money');
    });
  });

  group('the ledger is its own domain', () {
    test('30 & 48. a design deleted takes no payment with it: 500 + 700, '
        '1,000 paid; the first deleted leaves 700 and 300 credit', () async {
      final people = CustomerStore();
      final designs = DesignStore(customers: people);
      final made = await people.create(name: 'Adam', by: WorkshopRole.owner);
      final list = await PriceListStore().load();
      final one = given(door(id: 'one')).copyWith(customerId: made.id);
      final two = given(door(id: 'two')).copyWith(customerId: made.id);
      await designs.save(one, by: WorkshopRole.owner);
      await designs.save(two, by: WorkshopRole.owner);
      await people.record(
        transaction(PaymentType.payment, 100000, customerId: made.id),
        by: WorkshopRole.staff,
      );
      PriceRecord rec(Design d) => PriceRecord.calculate(d, list)!;
      final both = CustomerPricing.of([(one, rec(one)), (two, rec(two))], list);
      final before = CustomerFinance.of(
        both,
        (await people.load(made.id))!.ledger,
      );
      expect(before.netPaid, 1000);

      await designs.remove('one', by: WorkshopRole.owner);
      final after = (await people.load(made.id))!;
      expect(after.payments, hasLength(1), reason: 'the payment is kept');
      final left = CustomerPricing.of([(two, rec(two))], list);
      final f = CustomerFinance.of(left, after.ledger);
      expect(f.netPaid, 1000);
      final t = left.totalCents!;
      expect(f.creditCents, 100000 > t ? 100000 - t : 0);
      expect(f.dueCents, 100000 > t ? 0 : t - 100000);
      // At the brief's own figures.
      final brief = CustomerFinance.of(
        pricedAt(700),
        ledgerOf(payments: [1000]),
      );
      expect(brief.credit, 300);
      expect(brief.status, PaymentStatus.credit);
    });

    test(
      '49 & 50. recording money moves no design, no price, no list',
      () async {
        final people = CustomerStore();
        final designs = DesignStore(customers: people);
        final made = await people.create(name: 'Adam', by: WorkshopRole.owner);
        final d = given(door(id: 'front')).copyWith(customerId: made.id);
        await designs.save(d, by: WorkshopRole.owner);
        final list = await PriceListStore().load();
        final record = PriceRecord.calculate(d, list)!;
        await PriceRecordStore().save(d.id, record);
        final prefs = await SharedPreferences.getInstance();
        final before = {
          for (final k in prefs.getKeys())
            if (!k.startsWith(CustomerStore.customerKeyPrefix) &&
                k != CustomerStore.indexKey)
              k: prefs.get(k),
        };
        await people.record(
          transaction(PaymentType.payment, 50000, customerId: made.id),
          by: WorkshopRole.staff,
        );
        await people.record(
          transaction(PaymentType.refund, 10000, customerId: made.id),
          by: WorkshopRole.staff,
        );
        final after = {
          for (final k in prefs.getKeys())
            if (!k.startsWith(CustomerStore.customerKeyPrefix) &&
                k != CustomerStore.indexKey)
              k: prefs.get(k),
        };
        expect(after, before, reason: 'designs, prices and the list untouched');
        final kept = (await designs.load('front'))!;
        expect(jsonEncode(kept.toJson()), jsonEncode(d.toJson()));
        expect(
          DesignPriceState.of(kept, list, record).status,
          DesignPriceStatus.current,
        );
        expect((await PriceListStore().load()).version, list.version);
      },
    );

    test('36. money in another currency is not added to the prices\' and is '
        'said', () {
      final f = CustomerFinance.of(
        pricedAt(1000),
        PaymentLedger([
          transaction(PaymentType.payment, 40000),
          transaction(PaymentType.payment, 99999, currency: 'IQD'),
        ]),
      );
      expect(f.netPaid, 400);
      expect(f.otherCurrency, 1);
    });

    test('51 & 52. no discount and no quotation is a transaction', () {
      expect(PaymentType.values.map((t) => t.name), ['payment', 'refund']);
    });
  });
}
