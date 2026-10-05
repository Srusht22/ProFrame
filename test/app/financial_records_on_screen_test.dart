import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/finance_documents.dart';
import 'package:proframe/app/screens/staff_screen.dart';
import 'package:proframe/app/state/access.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/domain/model/payment.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/quotation.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/quotation_store.dart';
import 'package:proframe/infrastructure/staff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'payment_history_on_screen_test.dart'
    show adamOnDevice, fill, historyRows, money, openDialog, pricedTotal;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;
import 'the_price_button_test.dart'
    show adams, cardButton, seed, textOf, toAdam, toSummary;

// Phase 31 on the real app: a discount on the customer's page, receipts for
// payments, money in another currency, quotations kept as they were made,
// and who may do which — the screens offering by who is signed in, and the
// stores refusing whatever they may not do.

void owner(ProviderContainer c) =>
    c.read(workshopRoleProvider.notifier).become(WorkshopRole.owner);

Future<void> scrollTo(WidgetTester tester, Key key) async {
  final at = find.byKey(key);
  if (at.evaluate().isEmpty) await toSummary(tester);
  await tester.ensureVisible(at);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, Key key) async {
  await scrollTo(tester, key);
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// The discount dialog filled in and applied.
Future<void> giveDiscount(
  WidgetTester tester, {
  required String value,
  bool fixed = false,
}) async {
  await tapKey(tester, CustomerFinancialSummary.discountButtonKey);
  if (fixed) {
    await tester.tap(find.byKey(DiscountKeys.fixed));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byKey(DiscountKeys.value), value);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(DiscountKeys.apply));
  await settle(tester);
}

String? discountError(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(DiscountKeys.value))
    .decoration
    ?.errorText;

Future<void> chooseCurrency(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(PaymentDialogKeys.currency));
  await tester.pumpAndSettle();
  await tester.tap(find.text(code).last);
  await tester.pumpAndSettle();
}

Future<void> closeSheets(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
  nav.pop();
  await tester.pumpAndSettle();
}

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a discount, by the owner: 10% shows the subtotal, the discount '
      'and the final total; what cannot be given is said; it lasts a reload; '
      'and it can be taken away', (tester) async {
    await seed(tester, adams().take(2).toList());
    final c = await toAdam(tester);
    final total = await pricedTotal(tester);
    await toSummary(tester);
    // The device as it always was: no discount offered.
    expect(
      find.byKey(CustomerFinancialSummary.discountButtonKey),
      findsNothing,
    );
    owner(c);
    await tester.pumpAndSettle();

    // What cannot be given.
    await tapKey(tester, CustomerFinancialSummary.discountButtonKey);
    for (final (typed, said) in [
      ('150', 'A percentage cannot be more than 100%.'),
      ('0', 'A discount must be more than nothing.'),
      ('abc', 'Enter the percentage as a number, such as 10 or 12.5.'),
    ]) {
      await tester.enterText(find.byKey(DiscountKeys.value), typed);
      await tester.tap(find.byKey(DiscountKeys.apply));
      await tester.pumpAndSettle();
      expect(discountError(tester), said, reason: typed);
    }
    await tester.tap(find.byKey(DiscountKeys.fixed));
    await tester.enterText(
      find.byKey(DiscountKeys.value),
      (total + 1).toStringAsFixed(2),
    );
    await tester.tap(find.byKey(DiscountKeys.apply));
    await tester.pumpAndSettle();
    expect(
      discountError(tester),
      'The discount cannot be more than the subtotal, ${money(total)}.',
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect((await adamOnDevice(tester)).discounts, isEmpty);

    // 10%.
    await giveDiscount(tester, value: '10');
    final off = (total * 10).round() / 100;
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.subtotalKey), money(total));
    expect(
      textOf(tester, CustomerFinancialSummary.discountKey),
      '−${money(off)}',
    );
    expect(find.text('Discount (10%)'), findsOneWidget);
    expect(find.text('Final total'), findsOneWidget);
    expect(
      textOf(tester, CustomerFinancialSummary.totalKey),
      money(total - off),
    );
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - off));

    // Kept, and read back after the app is closed and opened again.
    await tester.pumpWidget(const SizedBox());
    final again = await toAdam(tester);
    await toSummary(tester);
    expect(
      textOf(tester, CustomerFinancialSummary.totalKey),
      money(total - off),
    );
    final kept = await adamOnDevice(tester);
    expect(kept.discount!.value, 1000);
    expect(kept.discount!.by, 'Owner');

    // Taken away.
    owner(again);
    await tester.pumpAndSettle();
    await tapKey(tester, CustomerFinancialSummary.discountButtonKey);
    await tester.tap(find.byKey(DiscountKeys.remove));
    await settle(tester);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.totalKey), money(total));
    expect(find.byKey(CustomerFinancialSummary.discountKey), findsNothing);
    expect((await adamOnDevice(tester)).discounts, hasLength(2));
  });

  testWidgets('43. a payment of 250 with its receipt: RCP-000001 on its row, '
      'opened to show the payment and the balance after it; opening it '
      'changes nothing; a receipt issued later is RCP-000002', (tester) async {
    await seed(tester, adams().take(2).toList());
    await toAdam(tester);
    final total = await pricedTotal(tester);
    await openDialog(tester, PaymentType.payment);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(PaymentDialogKeys.issueReceipt))
          .value,
      isTrue,
    );
    await fill(tester, '250');
    await toSummary(tester);
    final adam = await adamOnDevice(tester);
    final first = adam.payments.single;
    expect(adam.receipts.single.label, 'RCP-000001');
    expect(adam.receipts.single.transactionId, first.id);
    expect(
      adam.receipts.single.balanceAfterCents,
      ((total - 250) * 100).round(),
    );

    await tapKey(tester, CustomerFinancialSummary.receiptKey(first.id));
    expect(find.byKey(ReceiptKeys.sheet), findsOneWidget);
    expect(textOf(tester, ReceiptKeys.number), 'RCP-000001');
    expect(textOf(tester, ReceiptKeys.amount), money(250));
    expect(textOf(tester, ReceiptKeys.balance), '${money(total - 250)} due');
    await closeSheets(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(250));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - 250));
    expect((await adamOnDevice(tester)).payments, hasLength(1));

    // Recorded without one; issued from its row afterwards.
    await openDialog(tester, PaymentType.payment);
    await tester.tap(find.byKey(PaymentDialogKeys.issueReceipt));
    await tester.pumpAndSettle();
    await fill(tester, '50', method: PaymentMethod.bankTransfer);
    final second = (await adamOnDevice(tester)).payments.last;
    expect((await adamOnDevice(tester)).receiptFor(second.id), isNull);
    await tapKey(tester, CustomerFinancialSummary.issueReceiptKey(second.id));
    await settle(tester);
    expect(textOf(tester, ReceiptKeys.number), 'RCP-000002');
    await closeSheets(tester);
    final now = await adamOnDevice(tester);
    expect(now.receipts.map((r) => r.label), ['RCP-000001', 'RCP-000002']);
    expect(now.payments, hasLength(2));
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(300));
    expect(historyRows(tester).first, contains('RCP-000002'));
  });

  testWidgets('41. 500 in USD and 200 in EUR with no rate: paid 500 USD, the '
      'euros shown in their own currency and said to be left out; 100 EUR at '
      '1.10 counts as 110 USD', (tester) async {
    await seed(tester, adams().take(2).toList());
    await toAdam(tester);
    await pricedTotal(tester);
    await openDialog(tester, PaymentType.payment);
    await fill(tester, '500');
    await openDialog(tester, PaymentType.payment);
    await chooseCurrency(tester, 'EUR');
    expect(find.byKey(PaymentDialogKeys.rate), findsOneWidget);
    await fill(tester, '200');
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(500));
    expect(
      find.byKey(CustomerFinancialSummary.otherCurrenciesKey),
      findsOneWidget,
    );
    expect(find.text('200.00 EUR'), findsOneWidget);
    expect(
      find.textContaining('not included in the USD total'),
      findsOneWidget,
    );
    expect(historyRows(tester).first, contains('+200.00 EUR'));

    await openDialog(tester, PaymentType.payment);
    await chooseCurrency(tester, 'EUR');
    await tester.enterText(find.byKey(PaymentDialogKeys.rate), 'abc');
    await fill(tester, '100');
    expect(find.byType(TransactionDialog), findsOneWidget, reason: 'bad rate');
    await tester.enterText(find.byKey(PaymentDialogKeys.rate), '1.10');
    await tester.tap(find.byKey(PaymentDialogKeys.save));
    await settle(tester);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(610));
    expect(historyRows(tester).first, contains('At 1 EUR = 1.1 USD'));
    final kept = (await adamOnDevice(tester)).payments.last;
    expect(kept.currency, 'EUR');
    expect(kept.conversion!.cents, 11000);
  });

  testWidgets('a quotation: made from the customer\'s designs, kept as made, '
      'issued; an incomplete design stops it', (tester) async {
    await seed(tester, adams());
    await toAdam(tester);
    final adam = await adamOnDevice(tester);

    await tapKey(tester, CustomerFinancialSummary.newQuotationKey);
    expect(find.byKey(QuotationKeys.dialog), findsOneWidget);
    await tester.tap(find.byKey(QuotationKeys.create));
    await settle(tester);
    expect(
      textOf(tester, QuotationKeys.problem),
      startsWith(Quotation.incompleteMessage),
    );
    expect(textOf(tester, QuotationKeys.problem), contains('Basement Door'));
    expect(
      (await tester.runAsync(() => QuotationStore().page(adam.id)))!.total,
      0,
    );
    // Without the incomplete design: the two complete ones, each priced as
    // it is quoted.
    await tester.tap(find.byKey(QuotationKeys.design('basement')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(QuotationKeys.create));
    await settle(tester);
    expect(find.byKey(QuotationKeys.sheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(QuotationKeys.sheet),
        matching: find.text('Q-000001'),
      ),
      findsOneWidget,
    );
    final q = (await tester.runAsync(() => QuotationStore().page(adam.id)))!
        .items
        .single;
    expect(q.lines.map((l) => l.designId).toSet(), {'front', 'kitchen'});
    expect(textOf(tester, QuotationKeys.total), money(q.totalCents / 100));
    expect(q.status, QuotationStatus.draft);

    await tester.tap(find.byKey(QuotationKeys.become(QuotationStatus.issued)));
    await settle(tester);
    expect(
      (await tester.runAsync(() => QuotationStore().load(q.id)))!.status,
      QuotationStatus.issued,
    );
    expect(
      find.byKey(QuotationKeys.become(QuotationStatus.accepted)),
      findsOneWidget,
    );
    await closeSheets(tester);
    await scrollTo(tester, CustomerFinancialSummary.quotationKey(q.id));
    expect(find.text('ISSUED'), findsOneWidget);
    // A quotation adds nothing to what is owed.
    expect(textOf(tester, CustomerFinancialSummary.totalKey), 'Not final');
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(0));
  });

  testWidgets('42. with staff accounts and nobody signed in, the device may '
      'only look: no payment, refund, discount or quotation offered; a '
      'cashier signed in may record a payment and nothing more; prices hidden '
      'from somebody not allowed them', (tester) async {
    await seed(tester, adams().take(2).toList());
    late String cashierId;
    await tester.runAsync(() async {
      final staff = StaffStore();
      final cashier = await staff.add(
        name: 'Cashier',
        pin: '1111',
        capabilities: Capability.viewOnly,
        by: WorkshopRole.owner,
      );
      await staff.setCapabilities(cashier.id, {
        ...Capability.viewOnly,
        Capability.paymentsCreate,
      }, by: WorkshopRole.owner);
      cashierId = cashier.id;
      await staff.add(
        name: 'Blind',
        pin: '2222',
        capabilities: {Capability.financialView},
        by: WorkshopRole.owner,
      );
    });
    await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);

    // Signed in as the cashier from the header.
    await tester.tap(find.byKey(AccountButton.buttonKey));
    await tester.pumpAndSettle();
    expect(find.text('Nobody signed in'), findsOneWidget);
    await tester.tap(find.byKey(AccountButton.staffKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(StaffSignInDialog.memberKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cashier').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(StaffSignInDialog.pinKey), '9999');
    await tester.tap(find.byKey(StaffSignInDialog.okKey));
    await settle(tester);
    expect(find.text('That is not their PIN.'), findsOneWidget);
    await tester.enterText(find.byKey(StaffSignInDialog.pinKey), '1111');
    await tester.tap(find.byKey(StaffSignInDialog.okKey));
    await settle(tester);
    expect(find.byType(StaffSignInDialog), findsNothing);

    await page.openCustomer(tester, 'Adam');
    await toSummary(tester);
    ButtonStyleButton button(Key key) =>
        tester.widget<ButtonStyleButton>(find.byKey(key));
    expect(button(CustomerFinancialSummary.addPaymentKey).onPressed, isNotNull);
    expect(button(CustomerFinancialSummary.refundKey).onPressed, isNull);
    expect(
      find.byKey(CustomerFinancialSummary.discountButtonKey),
      findsNothing,
    );
    expect(find.byKey(CustomerFinancialSummary.newQuotationKey), findsNothing);
    await openDialog(tester, PaymentType.payment);
    expect(
      find.byKey(PaymentDialogKeys.issueReceipt),
      findsNothing,
      reason: 'no receipts.create',
    );
    await fill(tester, '20');
    final adam = await adamOnDevice(tester);
    expect(adam.payments.single.recordedBy, 'Cashier');
    expect(adam.receipts, isEmpty);
    expect(
      find.byKey(
        CustomerFinancialSummary.issueReceiptKey(adam.payments.single.id),
      ),
      findsNothing,
    );

    // Signed out: with staff accounts, the device may only look.
    final scope = tester.element(find.byType(CustomerFinancialSummary));
    final container = ProviderScope.containerOf(scope);
    container.read(signedInStaffProvider.notifier).become(null);
    await tester.pumpAndSettle();
    await toSummary(tester);
    expect(button(CustomerFinancialSummary.addPaymentKey).onPressed, isNull);
    expect(container.read(actorProvider), isA<NobodySignedIn>());
    // And the store refuses, whatever a screen offers.
    Object? refused;
    await tester.runAsync(() async {
      try {
        await CustomerStore().record(
          PaymentTransaction(
            id: 'PAY-X',
            customerId: adam.id,
            type: PaymentType.payment,
            amountCents: 100,
            at: DateTime(2026),
            method: PaymentMethod.cash,
            createdAt: DateTime(2026),
          ),
          by: container.read(actorProvider),
        );
      } on AccessDenied catch (e) {
        refused = e;
      }
    });
    expect(refused, isA<AccessDenied>());
    expect((await adamOnDevice(tester)).payments, hasLength(1));

    // Somebody who may see finances but not prices: the card's price hidden.
    final blind = (await tester.runAsync(StaffStore().all))!.last;
    container.read(signedInStaffProvider.notifier).become(blind);
    await tester.pumpAndSettle();
    await cardButton(tester, 'front');
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: hidden',
    );
    expect(cashierId, isNotEmpty);
  });

  testWidgets('the owner adds a member of staff and gives them a permission '
      'on Staff & permissions; it is kept', (tester) async {
    final c = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await tester.tap(find.byKey(AccountButton.buttonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(AccountButton.manageKey), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    owner(c);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AccountButton.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AccountButton.manageKey));
    await tester.pumpAndSettle();
    expect(find.byType(StaffScreen), findsOneWidget);
    await tester.tap(find.byKey(StaffScreen.addKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(AddStaffDialog.nameKey), 'Ahmed');
    await tester.enterText(find.byKey(AddStaffDialog.pinKey), '1234');
    await tester.enterText(find.byKey(AddStaffDialog.againKey), '1234');
    await tester.tap(find.byKey(AddStaffDialog.okKey));
    await settle(tester);
    final ahmed = (await tester.runAsync(StaffStore().all))!.single;
    expect(ahmed.capabilities, Capability.viewOnly);
    await tester.tap(
      find.byKey(
        StaffScreen.capabilityKey(ahmed.id, Capability.paymentsCreate),
      ),
    );
    await settle(tester);
    expect(
      (await tester.runAsync(StaffStore().all))!.single.capabilities,
      contains(Capability.paymentsCreate),
    );
    expect(find.text('Ahmed'), findsOneWidget);
  });

  for (final size in const [Size(320, 640), Size(768, 1024), Size(1440, 900)]) {
    testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}: a '
        'discount, a receipt and a quotation — the summary, the discount '
        'dialog, the receipt and the quotation fit, nothing overflowing', (
      tester,
    ) async {
      await seed(tester, adams().take(2).toList());
      final c = await screen.openTheApp(tester, size: size);
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      owner(c);
      await tester.pumpAndSettle();
      await giveDiscount(tester, value: '12.5');
      expect(overflowing(tester), isEmpty, reason: 'summary');
      await tapKey(tester, CustomerFinancialSummary.discountButtonKey);
      expect(overflowing(tester), isEmpty, reason: 'discount dialog');
      final apply = tester.getRect(find.byKey(DiscountKeys.apply));
      expect(apply.right, lessThanOrEqualTo(size.width));
      expect(apply.bottom, lessThanOrEqualTo(size.height));
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      await openDialog(tester, PaymentType.payment);
      await fill(tester, '100');
      final adam = await adamOnDevice(tester);
      await tapKey(
        tester,
        CustomerFinancialSummary.receiptKey(adam.payments.single.id),
      );
      expect(overflowing(tester), isEmpty, reason: 'receipt');
      expect(
        tester.getRect(find.byKey(ReceiptKeys.balance)).right,
        lessThanOrEqualTo(size.width),
      );
      await closeSheets(tester);

      await tapKey(tester, CustomerFinancialSummary.newQuotationKey);
      expect(overflowing(tester), isEmpty, reason: 'new quotation');
      await tester.tap(find.byKey(QuotationKeys.create));
      await settle(tester);
      expect(find.byKey(QuotationKeys.sheet), findsOneWidget);
      expect(overflowing(tester), isEmpty, reason: 'quotation');
      expect(
        tester.getRect(find.byKey(QuotationKeys.total)).right,
        lessThanOrEqualTo(size.width),
      );
      await closeSheets(tester);
      expect(overflowing(tester), isEmpty, reason: 'after');
      expect(tester.takeException(), isNull);
      expect(find.text(PricePanel.money(0, 'USD')), findsWidgets);
    });
  }
}
