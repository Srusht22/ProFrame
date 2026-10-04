import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/screens/customer_price_card.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_unknown_category_test.dart' show sloped;
import '../domain/pricing_engine_test.dart'
    show door, framedIn, given, glassOverPanel;
import 'a_customer_s_page_test.dart' as page;
import 'an_unknown_category_on_screen_test.dart' show device, openCard;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// The customer's page says what all their designs come to: each design
// priced on its own from what is kept, and the total of them — worked out
// afresh, never kept on the customer.

/// Adam's three designs, each of its own geometry, material and colour.
List<Design> adams() => [
  door(id: 'front'),
  framedIn(
    glassOverPanel(door(kind: DesignKind.window, id: 'kitchen')),
    const Finish(colour: 0xFF383E42, material: MaterialKind.aluminium),
  ),
  framedIn(
    given(sloped(id: 'stair')),
    const Finish(colour: 0xFF7B4A2B, material: MaterialKind.upvc),
  ),
];

Future<void> seed(WidgetTester tester) async {
  await tester.runAsync(() async {
    final people = CustomerStore();
    final adam = await people.create(name: 'Adam', now: DateTime(2026, 3, 1));
    final sara = await people.create(name: 'Sara', now: DateTime(2026, 3, 2));
    final store = DesignStore(customers: people);
    for (final d in adams()) {
      await store.save(d.copyWith(customerId: adam.id));
    }
    await store.save(
      door(kind: DesignKind.window, id: 'saras').copyWith(customerId: sara.id),
    );
  });
}

String shown(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key, skipOffstage: false)).data!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Adam\'s page totals his three designs — each its own price, '
      'the total their sum, the profile in metres and the infill in square '
      'metres — and looking writes nothing', (tester) async {
    await seed(tester);
    final before = await device(tester);
    await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');

    final adam = CustomerPricing.of(adams(), PriceList.starter);
    expect(adam.complete, isTrue);
    expect(
      shown(tester, CustomerPriceCard.totalKey),
      PricePanel.money(adam.total, 'USD'),
    );
    final each = [
      for (final d in adams())
        const PricingEngine().price(d, PriceList.starter),
    ];
    expect(
      adam.total,
      closeTo(each.fold<double>(0, (s, r) => s + r.total!), 1e-9),
    );

    // The total stands under the cards, so it is scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(CustomerPriceCard.toggleKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(CustomerPriceCard.toggleKey));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(MeasurementRows.totalProfileKey),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    for (final (i, d) in adams().indexed) {
      final line = find.byKey(
        CustomerPriceCard.designKey(d.id),
        skipOffstage: false,
      );
      expect(line, findsOneWidget);
      expect(
        find.descendant(
          of: line,
          matching: find.text(
            PricePanel.money(each[i].total!, 'USD'),
            skipOffstage: false,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(
      shown(tester, MeasurementRows.totalProfileKey),
      adam.measurements.totalProfile.label,
    );
    expect(adam.measurements.totalProfile.label, endsWith(' m'));
    expect(
      find.text(adam.measurements.panelArea.label, skipOffstage: false),
      findsOneWidget,
    );
    expect(adam.measurements.panelArea.label, endsWith(' m²'));
    expect(find.text('Sara'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(await device(tester), before);
  });

  testWidgets('a change to one design reaches the total', (tester) async {
    await seed(tester);
    final c = await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final first = shown(tester, CustomerPriceCard.totalKey);

    await openCard(tester, 'front');
    c.read(workspaceProvider.notifier).resizeFrame(widthMm: 1300);
    await tester.pumpAndSettle();
    await tester.runAsync(c.read(workspaceProvider.notifier).save);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await c.read(
        customerPricingProvider(c.read(workspaceProvider).design.customerId!)
            .future,
      );
    });
    await tester.pumpAndSettle();

    final wider = c.read(workspaceProvider).design;
    final now = CustomerPricing.of([
      wider,
      ...adams().skip(1),
    ], PriceList.starter);
    final after = shown(tester, CustomerPriceCard.totalKey);
    expect(after, isNot(first));
    expect(after, PricePanel.money(now.total, 'USD'));
  });

  testWidgets('Sara\'s total is hers alone', (tester) async {
    await seed(tester);
    await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Sara');
    final saras = CustomerPricing.of([
      door(kind: DesignKind.window, id: 'saras'),
    ], PriceList.starter);
    expect(
      shown(tester, CustomerPriceCard.totalKey),
      PricePanel.money(saras.total, 'USD'),
    );
  });
}
