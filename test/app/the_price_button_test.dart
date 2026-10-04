import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_actions.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/design_price_state.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_readiness.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_record_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_unknown_category_test.dart' show sloped;
import '../domain/price_readiness_test.dart' show without;
import '../domain/pricing_engine_test.dart'
    show door, framedIn, given, glassOverPanel;
import 'a_customer_s_page_test.dart' as page;
import 'an_unknown_category_on_screen_test.dart' as unknown;
import 'an_unknown_category_on_screen_test.dart' show device, openCard;
import 'angled_geometry_feedback_on_screen_test.dart' show openFor;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart' show notNowToSizes;
import 'the_designs_screen_test.dart' as screen;

// The price on the real app: **Calculate price** in the workspace and
// **Price** on every design card, enabled by one answer — whether the
// design can be priced — and a customer's total and money worked out from
// their designs' prices.

const engine = PricingEngine();
final list = PriceList.starter;

Finder get barButton => find.byKey(WorkspacePriceButton.buttonKey);

/// Whether the price button [at] can be pressed.
bool enabledAt(WidgetTester tester, Finder at) =>
    tester
        .widget<ButtonStyleButton>(
          find.descendant(
            of: at,
            matching: find.bySubtype<ButtonStyleButton>(),
          ),
        )
        .onPressed !=
    null;

/// What a press on a disabled price button said.
String said(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(PriceButton.messageKey)).data!;

Future<void> closeSheet(WidgetTester tester) async {
  Navigator.of(tester.element(find.byKey(DesignPriceSheet.sheetKey))).pop();
  await tester.pumpAndSettle();
}

String sheetTotal(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(DesignPriceSheet.totalKey)).data!;

String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key, skipOffstage: false)).data!;

Future<Map<String, Object?>> records(WidgetTester tester) async {
  final all = await device(tester);
  return {
    for (final e in all.entries)
      if (e.key.startsWith(PriceRecordStore.keyPrefix)) e.key: e.value,
  };
}

/// Adam's three designs: Front Entrance Door and Kitchen Window complete,
/// Basement Door with its height not given.
List<Design> adams() => [
  door(id: 'front').copyWith(name: 'Front Entrance Door'),
  framedIn(
    glassOverPanel(door(kind: DesignKind.window, id: 'kitchen')),
    const Finish(colour: 0xFF383E42, material: MaterialKind.aluminium),
  ).copyWith(name: 'Kitchen Window'),
  without(
    door(id: 'basement'),
    Measurements.heightKey,
  ).copyWith(name: 'Basement Door'),
];

Future<void> seed(WidgetTester tester, List<Design> designs) async {
  await tester.runAsync(() async {
    final people = CustomerStore();
    final adam = await people.create(name: 'Adam', now: DateTime(2026, 3, 1));
    final sara = await people.create(name: 'Sara', now: DateTime(2026, 3, 2));
    final store = DesignStore(customers: people);
    for (final d in designs) {
      await store.save(d.copyWith(customerId: adam.id));
    }
    await store.save(
      door(kind: DesignKind.window, id: 'saras').copyWith(customerId: sara.id),
    );
  });
}

Future<ProviderContainer> toAdam(WidgetTester tester) async {
  final c = await screen.openTheApp(tester, size: const Size(1280, 900));
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  return c;
}

/// The card's **Price** for [id], scrolled into sight.
Future<Finder> cardButton(WidgetTester tester, String id) async {
  final button = find.byKey(CustomerDesignCard.priceKey(id));
  await tester.scrollUntilVisible(
    button.hitTestable(),
    100,
    scrollable: find.byType(Scrollable).first,
  );
  return button;
}

Future<void> toSummary(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(CustomerFinancialSummary.recordPaymentKey).hitTestable(),
    150,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('38. in the workspace: an incomplete design\'s Calculate price '
      'is there, disabled, and says what to complete; nothing is priced; '
      'completed, it is enabled and calculates', (tester) async {
    final incomplete = without(door(), Measurements.heightKey);
    final c = await openFor(tester, incomplete);
    expect(barButton, findsOneWidget);
    expect(enabledAt(tester, barButton), isFalse);
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsNothing);
    expect(
      textOf(tester, PricePanel.stateKey),
      'Price unavailable until design is completed',
    );

    await tester.tap(barButton);
    await tester.pumpAndSettle();
    expect(
      said(tester),
      'Please give the overall height to calculate the '
      'price.',
    );
    expect(find.byKey(DesignPriceSheet.sheetKey), findsNothing);
    expect(await records(tester), isEmpty);

    // The height given: enabled at once, with nothing reopened.
    c.read(workspaceProvider.notifier).measure({Measurements.heightKey: 2000});
    await tester.pumpAndSettle();
    expect(enabledAt(tester, barButton), isTrue);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    final design = c.read(workspaceProvider).design;
    final expected = engine.price(design, list);
    expect(expected.isPriced, isTrue);
    expect(sheetTotal(tester), PricePanel.money(expected.total!, 'USD'));
    expect(find.text('MATERIAL MEASUREMENTS'), findsOneWidget);
    expect(find.text('COST BREAKDOWN'), findsOneWidget);
    await closeSheet(tester);
    expect(
      textOf(tester, PricePanel.totalKey),
      PricePanel.money(expected.total!, 'USD'),
    );
    expect(await records(tester), hasLength(1));
  });

  testWidgets('24 & 43. in the workspace: a calculated price, the geometry '
      'changed — needs recalculation, never the old figure; made incomplete '
      '— unavailable and disabled; completed and calculated — the new price', (
    tester,
  ) async {
    final c = await openFor(tester, door());
    final controller = c.read(workspaceProvider.notifier);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    final first = sheetTotal(tester);
    await closeSheet(tester);

    controller.resizeFrame(widthMm: 1200);
    await tester.pumpAndSettle();
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsNothing);
    expect(textOf(tester, PricePanel.stateKey), 'Price needs recalculation');
    expect(textOf(tester, PricePanel.previousKey), contains(first));
    expect(enabledAt(tester, barButton), isTrue);

    // A line drawn inside the opening: its pane's height is not given.
    final opening = c.read(workspaceProvider).design.openings.single;
    final box = c
        .read(workspaceProvider)
        .design
        .sectionById(opening.sectionId)!
        .outline;
    controller.addLineInside(opening.sectionId, box.centroid, horizontal: true);
    await tester.pumpAndSettle();
    await notNowToSizes(tester);
    expect(enabledAt(tester, barButton), isFalse);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    // The first thing to give is named, and that there is more.
    expect(
      said(tester),
      'Please give the bar thickness to calculate the price. 1 more thing '
      'needs completing too.',
    );

    // Every size given: enabled, and calculated afresh.
    final d = c.read(workspaceProvider).design;
    controller.measure({
      for (final m in Measurements.of(d))
        if (m.asked && !(d.measured ?? {}).contains(m.key))
          m.key: m.currentMm(d),
    });
    await tester.pumpAndSettle();
    expect(enabledAt(tester, barButton), isTrue);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    final now = sheetTotal(tester);
    expect(now, isNot(first));
    expect(
      now,
      PricePanel.money(
        engine.price(c.read(workspaceProvider).design, list).total!,
        'USD',
      ),
    );
  });

  testWidgets('39 & 9. the cards: complete designs\' Price enabled, the '
      'incomplete one\'s disabled and saying why — by the same answer as '
      'the workspace — and Price shows that design\'s own price', (
    tester,
  ) async {
    await seed(tester, adams());
    await toAdam(tester);
    for (final d in adams()) {
      final ready = PriceReadiness.of(d).isPriceCalculable;
      final button = await cardButton(tester, d.id);
      expect(enabledAt(tester, button), ready, reason: d.name);
      expect(
        textOf(tester, CustomerDesignCard.statusKey(d.id)),
        ready ? 'Complete' : 'Incomplete',
      );
    }
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('basement')),
      'Price: unavailable',
    );
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: not calculated',
    );

    await tester.tap(await cardButton(tester, 'basement'));
    await tester.pumpAndSettle();
    expect(
      said(tester),
      'Please give the overall height to calculate the '
      'price.',
    );
    expect(find.byKey(DesignPriceSheet.sheetKey), findsNothing);

    final front = adams().first;
    final before = await device(tester);
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    final expected = PricePanel.money(engine.price(front, list).total!, 'USD');
    expect(sheetTotal(tester), expected);
    await closeSheet(tester);
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: $expected',
    );
    // Calculating wrote the price and nothing else: no design changed.
    final after = await device(tester)
      ..removeWhere((k, _) => k.startsWith(PriceRecordStore.keyPrefix));
    expect(after, before);
  });

  testWidgets('42 & 14 & 22. the customer: a total that is not final while '
      'a design is incomplete, never the sum of the others as the price; '
      'the measurements in metres and square metres; and once every design '
      'is calculated, the total is their sum', (tester) async {
    final designs = adams().take(2).toList();
    await seed(tester, adams());
    await toAdam(tester);
    for (final d in designs) {
      await tester.tap(await cardButton(tester, d.id));
      await tester.pumpAndSettle();
      await closeSheet(tester);
    }
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.totalKey), 'Not final');
    expect(
      textOf(tester, CustomerFinancialSummary.notFinalKey),
      'Customer price is not final. 1 design is incomplete.',
    );
    final sum = designs.fold<double>(
      0,
      (s, d) => s + engine.price(d, list).total!,
    );
    expect(
      textOf(tester, CustomerFinancialSummary.pricedSoFarKey),
      PricePanel.money(sum, 'USD'),
    );
    expect(textOf(tester, CustomerFinancialSummary.dueKey), '—');
    expect(
      find.descendant(
        of: find.byKey(CustomerMoneyGlance.glanceKey),
        matching: find.text('Total not final'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(CustomerFinancialSummary.toggleKey));
    await tester.pumpAndSettle();
    expect(find.text('CUSTOMER MATERIAL SUMMARY'), findsOneWidget);
    expect(textOf(tester, MeasurementRows.totalProfileKey), endsWith(' m'));
    expect(find.textContaining('m²', skipOffstage: false), findsWidgets);
    // Adam's designs, each with its own line, and nobody else's.
    for (final d in adams()) {
      expect(
        find.byKey(
          CustomerFinancialSummary.designKey(d.id),
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(
        CustomerFinancialSummary.designKey('saras'),
        skipOffstage: false,
      ),
      findsNothing,
    );
  });

  testWidgets('40. three designs, each calculated: the total is their sum; '
      'one changed and calculated again: the total moves by it alone', (
    tester,
  ) async {
    final three = [
      ...adams().take(2),
      given(sloped(id: 'stair')).copyWith(name: 'Stair Window'),
    ];
    await seed(tester, three);
    final c = await toAdam(tester);
    for (final d in three) {
      await tester.tap(await cardButton(tester, d.id));
      await tester.pumpAndSettle();
      await closeSheet(tester);
    }
    await toSummary(tester);
    final each = [for (final d in three) engine.price(d, list).total!];
    final total = each.fold<double>(0, (s, t) => s + t);
    expect(
      textOf(tester, CustomerFinancialSummary.totalKey),
      PricePanel.money(total, 'USD'),
    );

    // The front door made wider, in the workspace, and calculated there.
    await openCard(tester, 'front');
    await notNowToSizes(tester);
    c.read(workspaceProvider.notifier).resizeFrame(widthMm: 1300);
    await tester.pumpAndSettle();
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    await closeSheet(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await toSummary(tester);
    final wider = engine.price(c.read(workspaceProvider).design, list).total!;
    expect(
      textOf(tester, CustomerFinancialSummary.totalKey),
      PricePanel.money(total - each[0] + wider, 'USD'),
    );
  });

  testWidgets('41 & 17 & 44. payment: recorded, the due and the status '
      'worked out, more than the total refused — and all of it, the prices '
      'and the disabled buttons the same after the app is closed and '
      'opened again', (tester) async {
    final two = adams().take(2).toList();
    await seed(tester, [...two, adams()[2]]);
    await toAdam(tester);
    for (final d in two) {
      await tester.tap(await cardButton(tester, d.id));
      await tester.pumpAndSettle();
      await closeSheet(tester);
    }
    // The incomplete design is in the way of a final total: it is
    // deleted, so the total of the two is final.
    late Design basement;
    await tester.runAsync(() async {
      final store = DesignStore(customers: CustomerStore());
      basement = (await store.load('basement'))!;
      await store.remove('basement');
    });
    // Closed and opened again.
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    await toSummary(tester);
    final total = two.fold<double>(
      0,
      (s, d) => s + engine.price(d, list).total!,
    );
    String money(double v) => PricePanel.money(v, 'USD');
    expect(textOf(tester, CustomerFinancialSummary.totalKey), money(total));
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(0));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total));
    expect(find.text('NOT PAID'), findsOneWidget);

    Future<void> pay(String amount) async {
      await toSummary(tester);
      await tester.tap(find.byKey(CustomerFinancialSummary.recordPaymentKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(PaymentDialogKeys.field), amount);
      await tester.tap(find.byKey(PaymentDialogKeys.save));
      await tester.pumpAndSettle();
    }

    await pay('${total + 10}');
    expect(
      find.text('Paid amount cannot exceed the total price.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(0));

    await pay('100');
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(100));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - 100));
    expect(find.text('AMOUNT DUE'), findsOneWidget);

    // Closed and opened again: the payment, the due and the prices kept.
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(100));
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(total - 100));
    expect(find.text('AMOUNT DUE'), findsOneWidget);
    for (final d in two) {
      expect(
        textOf(tester, CustomerDesignCard.priceValueKey(d.id)),
        'Price: ${money(engine.price(d, list).total!)}',
      );
    }

    await pay(total.toStringAsFixed(2));
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.dueKey), money(0));
    expect(find.text('PAID IN FULL'), findsOneWidget);

    // The incomplete design kept again: still incomplete, its Price still
    // disabled, after another reload; and the total no longer final.
    await tester.runAsync(() async {
      await DesignStore(customers: CustomerStore()).save(basement);
    });
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    final button = await cardButton(tester, 'basement');
    expect(enabledAt(tester, button), isFalse);
    await toSummary(tester);
    expect(textOf(tester, CustomerFinancialSummary.totalKey), 'Not final');
    expect(textOf(tester, CustomerFinancialSummary.paidKey), money(total));
    expect(find.text('TOTAL NOT FINAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('45. a design of a category this version does not know: '
      'Unsupported category, its Price disabled and saying so, nothing '
      'priced and nothing written', (tester) async {
    // Kept as a later version keeps it: this version's store will not
    // write one.
    await unknown.seed(tester, [(given(sloped()), 'future_shape')]);
    final before = await device(tester);
    await toAdam(tester);
    final button = await cardButton(tester, 'angled');
    expect(enabledAt(tester, button), isFalse);
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('angled')),
      'Price: unavailable',
    );
    expect(find.text('Window', skipOffstage: false), findsNothing);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(said(tester), 'Unsupported category. Price unavailable.');
    expect(find.byKey(DesignPriceSheet.sheetKey), findsNothing);
    expect(await device(tester), before);

    // And in the workspace.
    await openCard(tester, 'angled');
    expect(enabledAt(tester, barButton), isFalse);
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    expect(said(tester), 'Unsupported category. Price unavailable.');
    expect(await device(tester), before);
  });

  testWidgets('the workspace and the card read the same answer: a state '
      'worked out from the kept design is the card\'s', (tester) async {
    await seed(tester, adams());
    await toAdam(tester);
    for (final d in adams()) {
      final state = DesignPriceState.of(d, list, null);
      final button = await cardButton(tester, d.id);
      expect(enabledAt(tester, button), state.canCalculate, reason: d.name);
    }
  });

  testWidgets('it fits a phone: the bar\'s price button, a card\'s Price, '
      'and the summary, with nothing overflowing', (tester) async {
    await seed(tester, adams());
    await screen.openTheApp(tester, size: const Size(360, 740));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    expect(tester.takeException(), isNull, reason: 'the page');
    await toSummary(tester);
    expect(tester.takeException(), isNull, reason: 'the summary');
    await tester.tap(find.byKey(CustomerFinancialSummary.toggleKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'the summary open');
    await openCard(tester, 'front');
    await notNowToSizes(tester);
    expect(barButton, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
