import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/extra_charges.dart';
import 'package:proframe/app/inspector/price_actions.dart';
import 'package:proframe/app/inspector/view_only_note.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/finance_documents.dart';
import 'package:proframe/app/state/access.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:proframe/infrastructure/staff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/financial_records_test.dart' show listAt;
import '../domain/flexible_factory_pricing_test.dart' show factoryList;
import '../domain/pricing_engine_test.dart' show acceptance, door;
import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'financial_records_on_screen_test.dart'
    show closeSheets, owner, overflowing, settle, tapKey;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;
import 'the_price_button_test.dart' show cardButton, textOf, toSummary;

// Phase 32 on the real app: a design's price set out as the factory reads
// it — the automatic costs, glass said to be not used where there is none,
// the extras added by hand, the design's own discount — the customer's own
// extras before their discount, and the screens following who may do what.

/// The brief's Front Entrance Door, all panel, with nothing said about its
/// price yet — as a new design starts. Since Phase 33 the shared `given`
/// says glass is included, which these tests are not about: here the door
/// is as the factory first sees it, its glass not included.
Design frontEntranceDoor() => acceptance().copyWith(
  name: 'Front Entrance Door',
  pricing: PricingChoices.none,
);

/// Adam with [designs], and the price list [list] kept as the factory's.
Future<void> seedWith(
  WidgetTester tester,
  List<Design> designs,
  PriceList list,
) async {
  await tester.runAsync(() async {
    final people = CustomerStore();
    final adam = await people.create(
      name: 'Adam',
      now: DateTime(2026, 3, 1),
      by: WorkshopRole.owner,
    );
    final store = DesignStore(customers: people);
    for (final d in designs) {
      await store.save(d.copyWith(customerId: adam.id), by: WorkshopRole.owner);
    }
    await PriceListStore().save(list, by: WorkshopRole.owner);
  });
}

Future<ProviderContainer> toAdam(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
}) async {
  final c = await screen.openTheApp(tester, size: size);
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  return c;
}

/// The price sheet of design [id], from its card.
Future<void> openPrice(WidgetTester tester, String id) async {
  await tester.tap(await cardButton(tester, id));
  await settle(tester);
  expect(find.byKey(DesignPriceSheet.sheetKey), findsOneWidget);
}

Future<void> tapIn(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Key dropdown, String item) async {
  await tester.tap(find.byKey(dropdown));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

/// The extra form filled in; [save] presses Add or Save.
Future<void> fillExtra(
  WidgetTester tester, {
  String? name,
  String? category,
  String? quantity,
  String? unit,
  String? price,
  bool save = true,
}) async {
  if (name != null) {
    await tester.enterText(find.byKey(ExtraKeys.name), name);
  }
  if (category != null) await choose(tester, ExtraKeys.category, category);
  if (quantity != null) {
    await tester.enterText(find.byKey(ExtraKeys.quantity), quantity);
  }
  if (unit != null) await choose(tester, ExtraKeys.unit, unit);
  if (price != null) {
    await tester.enterText(find.byKey(ExtraKeys.price), price);
  }
  await tester.pumpAndSettle();
  if (save) {
    await tester.tap(find.byKey(ExtraKeys.save));
    await settle(tester);
  }
}

String valueOf(WidgetTester tester, Key key) => textOf(tester, key);

Future<Design> kept(WidgetTester tester, String id) async =>
    (await tester.runAsync(() => DesignStore().load(id)))!;

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('48. Front Entrance Door: glass not used, silicone 5 × 3 and '
      'labour 5 × 10 added by hand, 45 off — 350.00, and kept', (tester) async {
    await seedWith(tester, [frontEntranceDoor()], factoryList());
    final c = await toAdam(tester);
    owner(c);
    await tester.pumpAndSettle();
    final first = await kept(tester, 'acceptance');
    await openPrice(tester, 'acceptance');

    expect(valueOf(tester, ExtraKeys.glass), 'Not used');
    expect(valueOf(tester, ExtraKeys.panel), '100.00 USD');
    expect(valueOf(tester, ExtraKeys.designCost), '330.00 USD');
    expect(valueOf(tester, ExtraKeys.extrasCost), '0.00 USD');
    expect(find.text('No extra charges.'), findsOneWidget);

    // Silicone: 5 bottles at 3.00, worked out as it is typed.
    await tapIn(tester, ExtraKeys.add);
    await fillExtra(
      tester,
      name: 'Silicone',
      quantity: '5',
      unit: 'bottle',
      price: '3',
      save: false,
    );
    expect(valueOf(tester, ExtraKeys.total), '15.00 USD');
    expect(find.text('5 bottles × 3.00 USD'), findsOneWidget);
    await tester.tap(find.byKey(ExtraKeys.save));
    await settle(tester);

    // Labour: 5 hours at 10.00.
    await tapIn(tester, ExtraKeys.add);
    await fillExtra(
      tester,
      name: 'Labour',
      category: 'Labour',
      quantity: '5',
      unit: 'hour',
      price: '10',
    );
    expect(find.textContaining('5 bottles × 3.00 USD'), findsOneWidget);
    expect(find.textContaining('5 hours × 10.00 USD'), findsOneWidget);
    expect(valueOf(tester, ExtraKeys.extrasCost), '65.00 USD');
    expect(valueOf(tester, ExtraKeys.subtotal), '395.00 USD');
    expect(valueOf(tester, ExtraKeys.glass), 'Not used', reason: 'still');

    // The design's own discount: 45.00 off.
    await tapIn(tester, ExtraKeys.discount);
    expect(find.byKey(DiscountKeys.dialog), findsOneWidget);
    await tester.tap(find.byKey(DiscountKeys.fixed));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(DiscountKeys.value), '45');
    await tester.pumpAndSettle();
    expect(valueOf(tester, DiscountKeys.previewTotal), '350.00 USD');
    await tester.tap(find.byKey(DiscountKeys.apply));
    await settle(tester);
    expect(valueOf(tester, ExtraKeys.discountAmount), '−45.00 USD');
    expect(valueOf(tester, DesignPriceSheet.totalKey), '350.00 USD');

    // Kept: the design on the device has both extras and the discount, its
    // geometry as it was, and its card says 350.00.
    final d = await kept(tester, 'acceptance');
    expect([for (final e in d.pricing.extras) e.totalCents], [1500, 5000]);
    expect(d.pricing.discount!.amount, 45);
    Map<String, Object?> geometry(Design x) => x.toJson()
      ..remove('pricing')
      ..remove('updatedAt');
    expect(jsonEncode(geometry(d)), jsonEncode(geometry(first)));
    await closeSheets(tester);
    expect(find.text('Price: 350.00 USD'), findsOneWidget);

    // After the app is closed and opened again.
    await tester.pumpWidget(const SizedBox.shrink());
    await toAdam(tester);
    expect(find.text('Price: 350.00 USD'), findsOneWidget);
    final again = await kept(tester, 'acceptance');
    expect(again.pricing.extras.first.sum((c) => '$c'), '5 bottles × 300');
  });

  testWidgets('an extra edited — 5 bottles become 6, 15.00 becomes 18.00 — '
      'and removed only once asked', (tester) async {
    await seedWith(tester, [frontEntranceDoor()], factoryList());
    await toAdam(tester);
    await openPrice(tester, 'acceptance');
    await tapIn(tester, ExtraKeys.add);
    await fillExtra(
      tester,
      name: 'Silicone',
      quantity: '5',
      unit: 'bottle',
      price: '3',
    );
    final id = (await kept(tester, 'acceptance')).pricing.extras.single.id;

    await tapIn(tester, ExtraKeys.edit(id));
    expect(find.text('Edit extra'), findsOneWidget);
    await fillExtra(tester, quantity: '6');
    expect(valueOf(tester, ExtraKeys.extrasCost), '18.00 USD');
    expect(find.textContaining('6 bottles × 3.00 USD'), findsOneWidget);
    expect((await kept(tester, 'acceptance')).pricing.extras, hasLength(1));

    // Removing asks, and Cancel keeps it.
    await tapIn(tester, ExtraKeys.remove(id));
    expect(
      find.text('Remove "Silicone" (18.00 USD) from this design?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(valueOf(tester, ExtraKeys.extrasCost), '18.00 USD');
    await tapIn(tester, ExtraKeys.remove(id));
    await tester.tap(find.byKey(ExtraKeys.confirmRemove));
    await settle(tester);
    expect(valueOf(tester, ExtraKeys.extrasCost), '0.00 USD');
    expect((await kept(tester, 'acceptance')).pricing.extras, isEmpty);
  });

  testWidgets('what is not an extra is said and nothing is kept; glass the '
      'design has is not added again without saying so', (tester) async {
    await seedWith(tester, [
      door(id: 'glazed').copyWith(name: 'Glazed Door'),
    ], factoryList());
    await toAdam(tester);
    await openPrice(tester, 'glazed');
    expect(valueOf(tester, ExtraKeys.panel), 'Not used');
    await tapIn(tester, ExtraKeys.add);
    // Half-filled: refused, said, nothing kept.
    await fillExtra(tester, name: 'Tape', quantity: '-2', price: '1');
    expect(
      valueOf(tester, ExtraKeys.problem),
      'The quantity must be more than nothing.',
    );
    await fillExtra(tester, quantity: '2', price: '-1');
    expect(
      valueOf(tester, ExtraKeys.problem),
      'A unit price cannot be below nothing.',
    );
    // Glass: the design already has it.
    await fillExtra(tester, name: 'Glass', price: '50', save: false);
    expect(find.byKey(ExtraKeys.overlap), findsOneWidget);
    await tester.tap(find.byKey(ExtraKeys.save));
    await settle(tester);
    expect(valueOf(tester, ExtraKeys.problem), contains('additional charge'));
    expect((await kept(tester, 'glazed')).pricing.extras, isEmpty);
    await tester.tap(find.byKey(ExtraKeys.additional));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ExtraKeys.save));
    await settle(tester);
    expect((await kept(tester, 'glazed')).pricing.extras.single.name, 'Glass');
  });

  testWidgets('49. Adam: A 500 + B 400 + a trip for the whole job 30 = 930; '
      '30 off — 900.00, the trip on no design', (tester) async {
    await seedWith(tester, [
      door(id: 'a').copyWith(name: 'Design A'),
      door(kind: DesignKind.window, id: 'b').copyWith(name: 'Design B'),
    ], listAt(door: 500, window: 400));
    final c = await toAdam(tester);
    for (final id in ['a', 'b']) {
      await openPrice(tester, id);
      await closeSheets(tester);
    }
    owner(c);
    await tester.pumpAndSettle();
    await tapKey(tester, CustomerFinancialSummary.addExtraKey);
    expect(find.textContaining('whole job'), findsWidgets);
    await fillExtra(
      tester,
      name: 'Transportation',
      category: 'Transport',
      quantity: '1',
      unit: 'trip',
      price: '30',
    );
    await toSummary(tester);
    expect(
      valueOf(tester, CustomerFinancialSummary.designsTotalKey),
      '900.00 USD',
    );
    expect(
      valueOf(tester, CustomerFinancialSummary.extrasTotalKey),
      '30.00 USD',
    );
    expect(valueOf(tester, CustomerFinancialSummary.subtotalKey), '930.00 USD');
    await tapKey(tester, CustomerFinancialSummary.discountButtonKey);
    await tester.tap(find.byKey(DiscountKeys.fixed));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(DiscountKeys.value), '30');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiscountKeys.apply));
    await settle(tester);
    await toSummary(tester);
    expect(valueOf(tester, CustomerFinancialSummary.totalKey), '900.00 USD');
    expect(find.text('Due 900.00 USD'), findsOneWidget);
    // Neither design carries the trip.
    for (final id in ['a', 'b']) {
      expect((await kept(tester, id)).pricing.extras, isEmpty);
    }
    final adam = (await tester.runAsync(
      () async => (await CustomerStore().named('Adam'))!,
    ))!;
    expect(adam.extras.single.totalCents, 3000);
  });

  testWidgets('who may: nobody signed in once there are staff sees but adds '
      'nothing; a member without designs.edit opens a design view only', (
    tester,
  ) async {
    await seedWith(tester, [frontEntranceDoor()], factoryList());
    await tester.runAsync(
      () => StaffStore().add(
        name: 'Viewer',
        pin: '1111',
        capabilities: {...Capability.viewOnly, Capability.pricingView},
        by: WorkshopRole.owner,
      ),
    );
    final c = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await settle(tester);
    expect(
      tester
          .widget<ButtonStyleButton>(
            find.byKey(CustomersScreen.newCustomerButton),
          )
          .onPressed,
      isNull,
    );
    await page.openCustomer(tester, 'Adam');
    expect(find.byKey(CustomerScreen.newDesignButton), findsNothing);
    expect(find.byKey(CustomerDesignCard.editKey('acceptance')), findsNothing);
    expect(find.byKey(CustomerFinancialSummary.addExtraKey), findsNothing);
    await openPrice(tester, 'acceptance');
    expect(find.byKey(ExtraKeys.add), findsNothing);
    expect(find.byKey(ExtraKeys.discount), findsNothing);
    await closeSheets(tester);

    // Opened: shown, said to be view only, and a change refused.
    await tester.tap(find.byKey(CustomerDesignCard.openKey('acceptance')));
    await settle(tester);
    expect(find.byKey(ViewOnlyNote.noteKey), findsOneWidget);
    final controller = c.read(workspaceProvider.notifier);
    final was = c.read(workspaceProvider).design;
    controller.rename('Changed by nobody');
    expect(identical(c.read(workspaceProvider).design, was), isTrue);
    expect(c.read(workspaceProvider).design.name, 'Front Entrance Door');
    // And the store refuses it too.
    final refused = await tester.runAsync(() async {
      try {
        await DesignStore().save(
          was.copyWith(name: 'Sneaked'),
          by: c.read(actorProvider),
        );
        return null;
      } on AccessDenied catch (e) {
        return e;
      }
    });
    expect(refused, isA<AccessDenied>());
    expect((await kept(tester, 'acceptance')).name, 'Front Entrance Door');
  });

  for (final size in const [Size(390, 844), Size(820, 1180), Size(1440, 900)]) {
    testWidgets('at ${size.width.toInt()} × ${size.height.toInt()}: the '
        'breakdown, the extra form and the customer\'s extras fit', (
      tester,
    ) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      await toAdam(tester, size: size);
      await openPrice(tester, 'acceptance');
      await tapIn(tester, ExtraKeys.add);
      await fillExtra(
        tester,
        name: 'Special aluminium accessory with a long name',
        category: 'Installation',
        quantity: '2.5',
        unit: 'square metre',
        price: '1250.75',
        save: false,
      );
      expect(overflowing(tester), isEmpty);
      await tester.tap(find.byKey(ExtraKeys.save));
      await settle(tester);
      expect(overflowing(tester), isEmpty);
      expect(find.textContaining('3,126.88 USD'), findsWidgets);
      await closeSheets(tester);
      await tapKey(tester, CustomerFinancialSummary.addExtraKey);
      await fillExtra(
        tester,
        name: 'Delivery',
        category: 'Transport',
        quantity: '1',
        unit: 'trip',
        price: '30',
      );
      await toSummary(tester);
      expect(overflowing(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
