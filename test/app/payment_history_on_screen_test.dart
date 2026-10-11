import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'an_unknown_category_on_screen_test.dart' show device;
import 'customers_screen_test.dart' as customers;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;
import 'the_price_button_test.dart'
    show
        adams,
        cardButton,
        closeSheet,
        engine,
        list,
        seed,
        textOf,
        toAdam,
        toSummary;

// A customer's payments, refunds and credit on the real app: **Add
// payment** and **Refund** record transactions in the customer's ledger,
// the summary works out what they come to, and the history lists them,
// newest first — kept through a reload, never edited or removed, and never
// touching a design or a price.

String money(double v) => PricePanel.money(v, 'USD');

Future<Customer> adamOnDevice(WidgetTester tester) async {
  late Customer adam;
  await tester.runAsync(() async {
    final store = CustomerStore();
    final found = await store.page(query: 'Adam');
    adam = (await store.load(found.items.single.id))!;
  });
  return adam;
}

/// Prices Adam's complete designs from their cards, so his total is final
/// — the incomplete one is not seeded — and gives the total.
Future<double> pricedTotal(WidgetTester tester) async {
  final two = adams().take(2).toList();
  for (final d in two) {
    await tester.tap(await cardButton(tester, d.id));
    await tester.pumpAndSettle();
    await closeSheet(tester);
  }
  return two.fold<double>(0, (s, d) => s + engine.price(d, list).total!);
}

Future<void> openDialog(WidgetTester tester, PaymentType type) async {
  final button = find.byKey(
    type == PaymentType.payment
        ? CustomerFinancialSummary.addPaymentKey
        : CustomerFinancialSummary.refundKey,
  );
  // Scrolled to either way: since Phase 31 the summary is long enough —
  // quotations under the history — to have been scrolled past.
  if (button.evaluate().isEmpty) await toSummary(tester);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> chooseMethod(WidgetTester tester, PaymentMethod method) async {
  await tester.tap(find.byKey(PaymentDialogKeys.method));
  await tester.pumpAndSettle();
  await tester.tap(find.text(method.label).last);
  await tester.pumpAndSettle();
}

/// Fills the dialog in and presses save — which records it, or says why
/// not and stays.
Future<void> fill(
  WidgetTester tester,
  String amount, {
  PaymentMethod? method,
  String? other,
  String? note,
}) async {
  await tester.enterText(find.byKey(PaymentDialogKeys.amount), amount);
  if (method != null) await chooseMethod(tester, method);
  if (other != null) {
    await tester.enterText(find.byKey(PaymentDialogKeys.other), other);
  }
  if (note != null) {
    await tester.enterText(find.byKey(PaymentDialogKeys.note), note);
  }
  await tester.tap(find.byKey(PaymentDialogKeys.save));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<void> record(
  WidgetTester tester,
  PaymentType type,
  String amount, {
  PaymentMethod? method,
  String? other,
  String? note,
}) async {
  await openDialog(tester, type);
  await fill(tester, amount, method: method, other: other, note: note);
  expect(find.byType(TransactionDialog), findsNothing, reason: amount);
}

String? errorUnder(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(PaymentDialogKeys.amount))
    .decoration
    ?.errorText;

String figure(WidgetTester tester, Key key) {
  final shown = textOf(tester, key);
  return shown;
}

/// The history as shown, top to bottom: each row's words.
List<String> historyRows(WidgetTester tester) {
  final rows = find.byType(TransactionRow, skipOffstage: false);
  final shown = <(double, String)>[];
  for (final element in rows.evaluate()) {
    final box = element.renderObject! as RenderBox;
    final words = find
        .descendant(
          of: find.byWidget(element.widget, skipOffstage: false),
          matching: find.byType(Text, skipOffstage: false),
        )
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .join(' | ');
    shown.add((box.localToGlobal(Offset.zero).dy, words));
  }
  shown.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final s in shown) s.$2];
}

Future<Map<String, Object?>> designsAndPrices(WidgetTester tester) async {
  final all = await device(tester);
  return {
    for (final e in all.entries)
      if (!e.key.startsWith(CustomerStore.customerKeyPrefix) &&
          e.key != CustomerStore.indexKey &&
          // Since Phase 31 a payment can be given its receipt, numbered
          // from a sequence kept beside the customers.
          e.key != CustomerStore.receiptSequenceKey)
        e.key: e.value,
  };
}

// Since Phase 31 the store asks who records money (`by:`); these record as
// the device with no staff accounts, which may (`WorkshopRole.staff`).
void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('A–D, as the workshop does it: 100 Cash, 50 by bank '
      'transfer, more than is due becoming credit, and a refund of some of '
      'it — the summary, the status and the history following each, and all '
      'of it the same after the app is closed and opened again', (
    tester,
  ) async {
    await seed(tester, adams().take(2).toList());
    await toAdam(tester);
    final total = await pricedTotal(tester);
    expect(total, greaterThan(150));
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.totalKey), money(total));
    // Phase 31's wording for an empty history.
    expect(find.text('No payment history yet.'), findsOneWidget);
    expect(find.text('OUTSTANDING'), findsOneWidget);
    // Nothing paid: nothing to refund.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(CustomerFinancialSummary.refundKey),
          )
          .onPressed,
      isNull,
    );
    final untouched = await designsAndPrices(tester);

    // 1. $100 cash (Adam's two designs come to under 500).
    await record(tester, PaymentType.payment, '100', note: 'First payment');
    await toSummary(tester);
    expect(
      textOf(tester, CustomerFinancialSummary.grossPaymentsKey),
      money(100),
    );
    expect(textOf(tester, CustomerFinancialSummary.refundsKey), money(0));
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(100));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - 100));
    expect(textOf(tester, CustomerFinancialSummary.creditKey), money(0));
    expect(find.text('OUTSTANDING'), findsOneWidget);

    // 2. $50 by bank transfer.
    await record(
      tester,
      PaymentType.payment,
      '50',
      method: PaymentMethod.bankTransfer,
    );
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(150));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - 150));

    // 3. More than is due: taken, and credit — never refused, never a
    // negative amount due.
    final over = total - 150 + 300;
    await record(tester, PaymentType.payment, over.toStringAsFixed(2));
    await toSummary(tester);
    expect(
      textOf(tester, CustomerFinancialSummary.paidKey),
      money(total + 300),
    );
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(0));
    expect(textOf(tester, CustomerFinancialSummary.creditKey), money(300));
    expect(find.text('CREDIT'), findsOneWidget);
    // A minus before a figure: since Phase 31 a receipt's number has a
    // hyphen in it (RCP-000001), which is not a negative amount.
    expect(
      find.textContaining(RegExp(r'(^|\s)-\d')),
      findsNothing,
      reason: 'no negative',
    );

    // 4. A refund of $100 of the credit.
    await record(
      tester,
      PaymentType.refund,
      '100',
      note: 'Returned part of the credit',
    );
    await toSummary(tester);
    expect(
      textOf(tester, CustomerFinancialSummary.grossPaymentsKey),
      money(total + 300),
    );
    expect(textOf(tester, CustomerFinancialSummary.refundsKey), money(100));
    expect(
      textOf(tester, CustomerFinancialSummary.paidKey),
      money(total + 200),
    );
    expect(textOf(tester, CustomerFinancialSummary.creditKey), money(200));
    expect(find.text('CREDIT'), findsOneWidget);

    // The history, newest first, each in words, its sign and its method.
    final rows = historyRows(tester);
    expect(rows, hasLength(4));
    expect(rows[0], contains('REFUND'));
    expect(rows[0], contains('−${money(100)}'));
    expect(rows[0], contains('Returned part of the credit'));
    expect(rows[1], contains('+${money(over)}'));
    expect(rows[2], contains('Bank transfer'));
    expect(rows[2], contains('+${money(50)}'));
    expect(rows[3], contains('PAYMENT'));
    expect(rows[3], contains('+${money(100)}'));
    expect(rows[3], contains('Cash'));
    expect(rows[3], contains('First payment'));
    expect(rows[3], contains(dayOf(DateTime.now())));
    // The type is said in words and by its mark, never by colour alone.
    final marks = tester
        .widgetList<Icon>(
          find.descendant(
            of: find.byType(TransactionRow),
            matching: find.byType(Icon),
          ),
        )
        .map((i) => i.semanticLabel)
        // Since Phase 31 a payment's row also carries its receipt's icon,
        // which is not the type's mark.
        .nonNulls
        .toList();
    expect(marks, ['Refund', 'Payment', 'Payment', 'Payment']);

    // The glance on the bar says it too.
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(CustomerMoneyGlance.glanceKey),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Credit ${money(200)}',
    );

    // No design and no price was touched.
    expect(await designsAndPrices(tester), untouched);

    // 5. Closed and opened again: the history is kept, as it was.
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    await toSummary(tester);
    expect(historyRows(tester), rows);
    expect(
      textOf(tester, CustomerFinancialSummary.paidKey),
      money(total + 200),
    );
    expect(textOf(tester, CustomerFinancialSummary.creditKey), money(200));
    final adam = await adamOnDevice(tester);
    expect(adam.payments, hasLength(4));
    expect(adam.payments.map((t) => t.type).toList(), [
      PaymentType.payment,
      PaymentType.payment,
      PaymentType.payment,
      PaymentType.refund,
    ]);
    expect(adam.payments.every((t) => t.amountCents > 0), isTrue);
  });

  testWidgets('E–F: paid in full exactly, and a refund taking it back to '
      'outstanding; a refund of more than the net paid refused', (
    tester,
  ) async {
    await seed(tester, adams().take(2).toList());
    await toAdam(tester);
    final total = await pricedTotal(tester);
    await record(tester, PaymentType.payment, total.toStringAsFixed(2));
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(0));
    expect(textOf(tester, CustomerFinancialSummary.creditKey), money(0));
    expect(find.text('PAID IN FULL'), findsOneWidget);

    await openDialog(tester, PaymentType.refund);
    expect(find.text('Refund to Adam'), findsOneWidget);
    expect(find.text('Reason / note'), findsOneWidget);
    await fill(tester, (total + 0.01).toStringAsFixed(2));
    expect(
      errorUnder(tester),
      'A refund cannot be more than the net paid, ${money(total)}.',
    );
    await fill(tester, '50');
    expect(find.byType(TransactionDialog), findsNothing);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(50));
    expect(find.text('OUTSTANDING'), findsOneWidget);
  });

  testWidgets('the dialog checks the amount and says why, records nothing '
      'until it is right, offers the four methods, an Other described, and '
      'no day after today', (tester) async {
    await seed(tester, adams().take(2).toList());
    await toAdam(tester);
    await pricedTotal(tester);
    final before = await device(tester);
    await openDialog(tester, PaymentType.payment);
    expect(find.text('Payment from Adam'), findsOneWidget);
    for (final (typed, said) in [
      ('', 'Enter an amount.'),
      ('0', 'The amount must be more than nothing.'),
      ('-5', 'The amount must be more than nothing.'),
      ('abc', 'Enter the amount as a number, such as 500.00.'),
      ('1.234', 'Enter the amount to the cent — two decimal places at most.'),
    ]) {
      await fill(tester, typed);
      expect(errorUnder(tester), said, reason: typed);
      expect(find.byType(TransactionDialog), findsOneWidget);
    }
    expect(await device(tester), before, reason: 'nothing recorded');

    // The methods offered, and never the legacy one.
    await tester.tap(find.byKey(PaymentDialogKeys.method));
    await tester.pumpAndSettle();
    for (final m in PaymentMethod.offered) {
      expect(find.text(m.label), findsWidgets, reason: m.label);
    }
    expect(find.text(PaymentMethod.legacy.label), findsNothing);
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    // Today, and the calendar ends today.
    final now = DateTime.now();
    expect(find.text(dayOf(now)), findsOneWidget);
    await tester.tap(find.byKey(PaymentDialogKeys.date));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.lastDate, DateTime(now.year, now.month, now.day));
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();

    await fill(tester, '1,250.5', other: 'Company cheque', note: 'Deposit');
    expect(find.byType(TransactionDialog), findsNothing);
    final adam = await adamOnDevice(tester);
    final t = adam.payments.single;
    expect(t.amountCents, 125050);
    expect(t.method, PaymentMethod.other);
    expect(t.methodLabel, 'Other — Company cheque');
    expect(t.note, 'Deposit');
    expect(t.currency, 'USD');
    expect(t.id, startsWith('PAY-'));
    await toSummary(tester);
    expect(historyRows(tester).single, contains('Other — Company cheque'));
    expect(historyRows(tester).single, contains('+${money(1250.50)}'));
  });

  testWidgets('pricing incomplete: a deposit is taken and counted, and no '
      'amount due is said until the total is final', (tester) async {
    await seed(tester, adams());
    await toAdam(tester);
    await toSummary(tester);
    expect(find.text('PRICING INCOMPLETE'), findsOneWidget);
    await record(tester, PaymentType.payment, '200');
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(200));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), '—');
    expect(textOf(tester, CustomerFinancialSummary.creditKey), '—');
    expect(find.text('PRICING INCOMPLETE'), findsOneWidget);
  });

  testWidgets('a customer kept with the old paid figure: one legacy payment '
      'of exactly that, shown as such, and looking writes nothing', (
    tester,
  ) async {
    await seed(tester, adams().take(2).toList());
    // Adam's record as an older version kept it: one figure, paid.
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      final key = prefs.getKeys().firstWhere(
        (k) =>
            k.startsWith(CustomerStore.customerKeyPrefix) &&
            (jsonDecode(prefs.getString(k)!) as Map)['name'] == 'Adam',
      );
      final map = jsonDecode(prefs.getString(key)!) as Map<String, Object?>
        ..remove('payments')
        ..['paid'] = 750;
      await prefs.setString(key, jsonEncode(map));
    });
    final kept = await device(tester);
    await toAdam(tester);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(750));
    final row = historyRows(tester).single;
    expect(row, contains('+${money(750)}'));
    expect(row, contains(PaymentMethod.legacy.label));
    expect(row, contains(PaymentTransaction.legacyNote));
    // Looking — and a reload — leave the device as it was.
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    await toSummary(tester);
    expect(historyRows(tester), [row]);
    final now = await device(tester);
    expect(
      {
        for (final e in now.entries)
          if (!e.key.startsWith('proframe.price.')) e.key: e.value,
      },
      {
        for (final e in kept.entries)
          if (!e.key.startsWith('proframe.price.')) e.key: e.value,
      },
    );

    // A new payment keeps the legacy one, once, and the old figure goes.
    await record(tester, PaymentType.payment, '100');
    final adam = await adamOnDevice(tester);
    expect(adam.payments.map((t) => t.id), [
      PaymentTransaction.legacyId,
      startsWith('PAY-'),
    ]);
    expect(adam.ledger.netPaidCents('USD'), 85000);
    final raw = (await device(tester)).entries.firstWhere(
      (e) =>
          e.key.startsWith(CustomerStore.customerKeyPrefix) &&
          (jsonDecode(e.value! as String) as Map)['name'] == 'Adam',
    );
    expect(
      (jsonDecode(raw.value! as String) as Map).containsKey('paid'),
      false,
    );
  });

  testWidgets('a long history shows ten at a time, Load more the rest, in order, '
      'with no transaction twice and the totals the whole ledger\'s', (tester) async {
    await seed(tester, adams().take(2).toList());
    final adam = await adamOnDevice(tester);
    await tester.runAsync(() async {
      final store = CustomerStore();
      for (var i = 1; i <= 12; i++) {
        await store.record(
          PaymentTransaction(
            id: 'PAY-202609${i.toString().padLeft(2, '0')}-00${i.toString().padLeft(2, '0')}',
            customerId: adam.id,
            type: PaymentType.payment,
            amountCents: i * 1000,
            at: DateTime(2026, 9, i, 12),
            method: PaymentMethod.cash,
            createdAt: DateTime(2026, 9, i, 12),
            currency: 'USD',
          ),
          by: WorkshopRole.staff,
        );
      }
    });
    await toAdam(tester);
    await toSummary(tester);
    // Since Phase 31 the history is read a page of ten at a time with Load
    // more, where it was the latest five and Show all.
    final first = historyRows(tester);
    expect(first, hasLength(CustomerFinancialSummary.pageSize));
    expect(first.first, contains('12 Sep 2026'));
    // The totals are the whole ledger's, whatever page is shown.
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(780));
    expect(find.text('Load more (2 more)'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(CustomerFinancialSummary.loadMoreKey),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CustomerFinancialSummary.loadMoreKey));
    await tester.pumpAndSettle();
    final all = historyRows(tester);
    expect(all, hasLength(12));
    expect(all.sublist(0, 10), first, reason: 'the first page unmoved');
    expect(all.last, contains('01 Sep 2026'));
    expect(all.toSet(), hasLength(12), reason: 'none twice');
    expect(find.byKey(CustomerFinancialSummary.loadMoreKey), findsNothing);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(780));
  });

  for (final size in const [
    Size(320, 640),
    Size(390, 844),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}: the '
        'summary, the history and both dialogs fit, every button in reach '
        'and nothing overflowing', (tester) async {
      await seed(tester, adams().take(2).toList());
      final adam = await adamOnDevice(tester);
      await tester.runAsync(() async {
        await CustomerStore().record(
          PaymentTransaction(
            id: 'PAY-20260901-0001',
            customerId: adam.id,
            type: PaymentType.payment,
            amountCents: 123456789,
            at: DateTime(2026, 9, 1, 12),
            method: PaymentMethod.other,
            methodDetail: 'A long description of how it was paid',
            note: 'A long note written about this payment by the workshop',
            createdAt: DateTime(2026, 9, 1, 12),
            currency: 'USD',
          ),
          by: WorkshopRole.staff,
        );
      });
      await screen.openTheApp(tester, size: size);
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      await toSummary(tester);
      expect(tester.takeException(), isNull);
      final width = size.width;
      for (final key in [
        CustomerFinancialSummary.addPaymentKey,
        CustomerFinancialSummary.refundKey,
      ]) {
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        expect(find.byKey(key).hitTestable(), findsOneWidget);
        expect(tester.getRect(find.byKey(key)).right, lessThanOrEqualTo(width));
      }
      final row = find.byType(TransactionRow);
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(tester.getRect(row).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);

      for (final type in PaymentType.values) {
        await openDialog(tester, type);
        await chooseMethod(tester, PaymentMethod.other);
        expect(tester.takeException(), isNull, reason: type.label);
        await tester.ensureVisible(find.byKey(PaymentDialogKeys.save));
        await tester.pumpAndSettle();
        final save = tester.getRect(find.byKey(PaymentDialogKeys.save));
        expect(save.right, lessThanOrEqualTo(width));
        expect(save.bottom, lessThanOrEqualTo(size.height));
        expect(
          find.byKey(PaymentDialogKeys.save).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }
}
