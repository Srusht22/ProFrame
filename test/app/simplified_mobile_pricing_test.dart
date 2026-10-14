import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/app.dart';
import 'package:proframe/app/inspector/extra_charges.dart';
import 'package:proframe/app/inspector/price_actions.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/inspector/price_summary.dart';
import 'package:proframe/app/screens/factory_defaults_screen.dart';
import 'package:proframe/app/screens/factory_extras.dart';
import 'package:proframe/app/screens/factory_prices_screen.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/domain/pricing/extra_catalog.dart';
import 'package:proframe/domain/pricing/extra_charge.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/extra_catalog_store.dart';
import 'package:proframe/infrastructure/keep_failed.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/flexible_factory_pricing_test.dart' show factoryList;
import '../domain/pricing_engine_test.dart' show door, engine;
import 'financial_records_on_screen_test.dart' show overflowing, owner, settle;
import 'flexible_pricing_on_screen_test.dart'
    show frontEntranceDoor, kept, openPrice, seedWith, tapIn, toAdam, valueOf;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;

// Phase 35 on the real app: a design's price as a summary a person reads at
// a glance on a phone — the final total first, then the costs part by part,
// each line saying how it is worked out — and the factory's prices edited
// field by field, with its own *Charge for glass* and its own list of
// extras that a charge on a design is added from.

const phone = Size(390, 844);

/// The price the engine gives design [id] as kept, at [list].
Future<PriceResult> priceOf(
  WidgetTester tester,
  String id,
  PriceList list,
) async => engine.price(await kept(tester, id), list);

/// Factory prices, opened from the customers' header.
Future<void> toFactoryPrices(WidgetTester tester) async {
  // Factory prices are under Factory defaults on the header now, beside
  // the default measurements and kept apart from them.
  await tester.tap(find.byKey(FactoryButton.buttonKey).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(FactoryDefaultsScreen.pricesKey));
  await tester.pumpAndSettle();
  expect(find.byType(FactoryPricesScreen), findsOneWidget);
}

/// [target] in Factory prices, scrolled to: the list is long, and built as
/// it is scrolled.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find
        .descendant(
          of: find.byType(FactoryPricesScreen),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

/// A price list store whose every keep the device refuses.
class RefusingPriceListStore extends PriceListStore {
  @override
  Future<PriceList> save(PriceList list, {required Authority by}) async {
    by.require(Capability.pricingEdit);
    throw const KeepFailed(PriceListStore.key);
  }
}

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the price summary', () {
    testWidgets('on a phone: what it is for, the final total first, then '
        'each part with what it comes to', (tester) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      await toAdam(tester, size: phone);
      final id = frontEntranceDoor().id;
      await openPrice(tester, id);

      // What it is for, and the way out.
      expect(find.text('Price summary'), findsOneWidget);
      expect(find.byKey(DesignPriceSheet.nameKey), findsOneWidget);
      expect(find.text('Front Entrance Door'), findsWidgets);
      expect(find.byKey(DesignPriceSheet.closeKey), findsOneWidget);

      // The final total is the engine's, and in sight without scrolling.
      final price = await priceOf(tester, id, factoryList());
      expect(
        valueOf(tester, DesignPriceSheet.totalKey),
        PricePanel.money(price.total!, 'USD'),
      );
      // The price is worked out before the sheet rises: let it finish
      // rising.
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await settle(tester);
      // Just under what it is for, and whole on the screen. (Measured
      // from the sheet: a test's surface is resized under a window whose
      // own size the sheet's height is worked out from.)
      final sheet = tester.getRect(find.byType(DesignPriceSheet));
      final total = tester.getRect(find.byKey(DesignPriceSheet.totalKey));
      expect(total.top - sheet.top, lessThan(160));
      expect(total.bottom, lessThan(phone.height));

      // Each part, in order, each with what it comes to.
      double top(String text) =>
          tester.getTopLeft(find.text(text, skipOffstage: false).first).dy;
      final order = [
        'Profiles and frame',
        'Panels',
        'Glass',
        'Hardware',
        'Extra charges',
        'Final calculation',
      ];
      for (var i = 1; i < order.length; i++) {
        expect(top(order[i]), greaterThan(top(order[i - 1])), reason: order[i]);
      }

      // The border and the lines apart, each how it is worked out — the
      // measurement, the rate with its unit and currency — and its amount.
      final border = price.lines.firstWhere((l) => l.part?.name == 'border');
      final lines = price.lines.firstWhere((l) => l.part?.name == 'lines');
      expect(
        valueOf(tester, ExtraKeys.profileLine('all.border')),
        PricePanel.money(border.amount, 'USD'),
      );
      expect(
        valueOf(tester, ExtraKeys.profileLine('all.lines')),
        PricePanel.money(lines.amount, 'USD'),
      );
      expect(
        find.textContaining('× 20.00 USD/m', skipOffstage: false),
        findsNWidgets(2),
        reason: 'one rate, said on each of the two',
      );
      expect(
        find.textContaining('USD/m²', skipOffstage: false),
        findsWidgets,
        reason: 'a panel by its area, its rate per square metre',
      );

      // Glass the design does not have is said to be not used — no
      // unexplained 0.00.
      expect(valueOf(tester, ExtraKeys.glass), 'Not used');
      expect(
        find.text('This design has no glass.', skipOffstage: false),
        findsOneWidget,
      );
      expect(valueOf(tester, ExtraKeys.discountAmount), 'None');
      expect(overflowing(tester), isEmpty);
    });

    testWidgets('glass the design has and is not charged says why, and how '
        'much of it there is', (tester) async {
      final notIncluded = door(id: 'glazed');
      await seedWith(tester, [
        notIncluded.copyWith(
          pricing: notIncluded.pricing.copyWith(glassPriced: false),
        ),
      ], factoryList());
      await toAdam(tester, size: phone);
      await openPrice(tester, 'glazed');
      expect(valueOf(tester, ExtraKeys.glass), 'Not included');
      final note = valueOf(tester, PriceBreakdown.glassNoteKey);
      expect(note, contains('m²'));
      expect(note, contains('Include glass in price'));
    });

    testWidgets('where the factory does not charge for glass, the summary '
        'says so, and the design\'s own switch cannot turn it on', (
      tester,
    ) async {
      await seedWith(tester, [
        door(id: 'glazed'),
      ], factoryList().copyWith(chargesGlass: false));
      await toAdam(tester, size: phone);
      await openPrice(tester, 'glazed');
      expect(valueOf(tester, ExtraKeys.glass), 'Glass charging is turned off');
      expect(
        valueOf(tester, PriceBreakdown.glassNoteKey),
        contains('Charge for glass'),
      );
      final price = await priceOf(
        tester,
        'glazed',
        factoryList().copyWith(chargesGlass: false),
      );
      expect(price.lines.where((l) => l.group == PriceGroup.glass), isEmpty);
      expect(price.measurements.glassArea.value, greaterThan(0));
    });

    testWidgets('Edit factory prices is there only for whoever may change '
        'them, and opens Factory prices', (tester) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      final c = await toAdam(tester, size: phone);
      await openPrice(tester, frontEntranceDoor().id);
      expect(find.byKey(DesignPriceSheet.editPricingKey), findsNothing);
      Navigator.of(tester.element(find.byKey(DesignPriceSheet.sheetKey))).pop();
      await tester.pumpAndSettle();

      owner(c);
      await tester.pumpAndSettle();
      await openPrice(tester, frontEntranceDoor().id);
      await tapIn(tester, DesignPriceSheet.editPricingKey);
      expect(find.byType(FactoryPricesScreen), findsOneWidget);
    });

    testWidgets('in Kurdish on a phone, nothing overflows and the total is '
        'the same figure', (tester) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      await tester.runAsync(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(Language.key, 'ckb');
      });
      final c = await screen.openTheApp(tester, size: phone);
      expect(c.read(languageProvider), AppLanguage.centralKurdish);
      final design = await kept(tester, frontEntranceDoor().id);
      final price = engine.price(design, factoryList());
      await tester.tap(find.text('Adam').first);
      await settle(tester);
      await openPrice(tester, design.id);
      expect(
        valueOf(tester, DesignPriceSheet.totalKey),
        PricePanel.money(price.total!, 'USD'),
      );
      expect(overflowing(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('Factory prices, field by field', () {
    testWidgets('the owner changes a rate and keeps it; a Kurdish keyboard\'s '
        'digits are read; an empty figure is refused; nothing kept is lost '
        'to a restart', (tester) async {
      final c = await screen.openTheApp(tester, size: phone);
      owner(c);
      await tester.pumpAndSettle();
      await toFactoryPrices(tester);

      final rate = find.byKey(
        FactoryPricesScreen.fieldKey('profile.upvc.normal'),
      );
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '٢١٫٥');
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(rate).controller!.text, '21.5');
      expect(find.text('USD / m'), findsWidgets, reason: 'unit and currency');

      // Not kept yet: discarded, and back to what is kept.
      expect(find.byKey(FactoryPricesScreen.discardKey), findsOneWidget);
      await tester.tap(find.byKey(FactoryPricesScreen.discardKey));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(rate).controller!.text, isNot('21.5'));

      // A figure that is needed, left empty: refused, and said where.
      await tester.enterText(rate, '');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FactoryPricesScreen.saveKey));
      await settle(tester);
      expect(find.text('A price is needed here.'), findsOneWidget);
      final store = PriceListStore();
      expect(
        (await tester.runAsync(store.load))!.isStarter,
        isTrue,
        reason: 'nothing kept',
      );

      await tester.enterText(rate, '21.5');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FactoryPricesScreen.saveKey));
      await settle(tester);
      final now = (await tester.runAsync(store.load))!;
      expect(now.profiles.values.first, isNotNull);
      expect(
        now.profiles.entries
            .firstWhere((e) => e.key.name == 'upvc')
            .value
            .normalPerMetre,
        21.5,
      );
    });

    testWidgets('a keep the device refuses is said, and the figure typed '
        'stays in its field', (tester) async {
      await tester.binding.setSurfaceSize(phone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final container = ProviderContainer(
        overrides: [
          priceListStoreProvider.overrideWithValue(RefusingPriceListStore()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProFrameApp(),
        ),
      );
      await tester.pumpAndSettle();
      owner(container);
      await tester.pumpAndSettle();
      await toFactoryPrices(tester);
      final rate = find.byKey(
        FactoryPricesScreen.fieldKey('profile.upvc.normal'),
      );
      await tester.ensureVisible(rate);
      await tester.enterText(rate, '33');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FactoryPricesScreen.saveKey));
      await settle(tester);
      expect(
        find.text(
          'This could not be saved on this device. Nothing was changed — '
          'try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Prices kept. Every design priced before is now to be '
          'recalculated.',
        ),
        findsNothing,
      );
      expect(tester.widget<TextField>(rate).controller!.text, '33');
    });

    testWidgets('Charge for glass is off for a new configuration, its rates '
        'not asked for; turned on, asked about and kept, it lasts a restart', (
      tester,
    ) async {
      final c = await screen.openTheApp(tester, size: phone);
      owner(c);
      await tester.pumpAndSettle();
      await toFactoryPrices(tester);
      final toggle = find.byKey(FactoryPricesScreen.chargesGlassKey);
      await scrollTo(tester, toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      final glassRate = find.byKey(
        FactoryPricesScreen.fieldKey('glass.single.clear'),
        skipOffstage: false,
      );
      expect(glassRate, findsNothing);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(glassRate, findsOneWidget);
      await tester.tap(find.byKey(FactoryPricesScreen.saveKey));
      await tester.pumpAndSettle();
      // A change that reaches every design is asked about first.
      expect(find.byKey(FactoryPricesScreen.confirmKey), findsOneWidget);
      await tester.tap(find.byKey(FactoryPricesScreen.confirmKey));
      await settle(tester);
      expect(
        (await tester.runAsync(PriceListStore().load))!.chargesGlass,
        isTrue,
      );

      // Opened again from nothing but the device.
      await tester.pumpWidget(const SizedBox());
      final again = await screen.openTheApp(tester, size: phone);
      owner(again);
      await tester.pumpAndSettle();
      await toFactoryPrices(tester);
      await scrollTo(tester, toggle);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    });

    testWidgets('staff read the prices and the extras and change neither, '
        'and the store refuses them', (tester) async {
      await screen.openTheApp(tester, size: phone);
      await toFactoryPrices(tester);
      expect(find.byKey(FactoryPricesScreen.readOnlyKey), findsOneWidget);
      expect(find.byKey(FactoryPricesScreen.saveKey), findsNothing);
      await scrollTo(tester, find.byKey(FactoryExtrasSection.sectionKey));
      expect(find.byKey(FactoryExtrasSection.addKey), findsNothing);
      final refused = await tester.runAsync(() async {
        try {
          await ExtraCatalogStore().save(const [], by: WorkshopRole.staff);
          return false;
        } on AccessDenied {
          return true;
        }
      });
      expect(refused, isTrue);
    });
  });

  group("the factory's list of extras", () {
    testWidgets('the owner adds silicone at 3.00 a bottle; on a design it '
        'is chosen, 5 of it, 15.00 worked out as it is typed and charged; '
        'the item made dearer afterwards changes nothing already added', (
      tester,
    ) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      final c = await toAdam(tester, size: phone);
      owner(c);
      await tester.pumpAndSettle();

      // Added in Factory prices.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await toFactoryPrices(tester);
      await scrollTo(tester, find.byKey(FactoryExtrasSection.addKey));
      await tester.tap(find.byKey(FactoryExtrasSection.addKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ExtraItemDialog.nameKey), 'Silicone');
      await tester.tap(find.byKey(ExtraItemDialog.unitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bottle').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ExtraItemDialog.priceKey), '3');
      await tester.tap(find.byKey(ExtraItemDialog.saveKey));
      await settle(tester);
      expect(find.text('Silicone'), findsWidgets);
      expect(find.textContaining('3.00 USD per bottle'), findsOneWidget);
      final items = (await tester.runAsync(ExtraCatalogStore().load))!;
      expect(items.single.unitPriceCents, 300);

      // Chosen on the design. Back past Factory defaults, which the prices
      // are opened from, to the customers.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adam').first);
      await settle(tester);
      final id = frontEntranceDoor().id;
      await openPrice(tester, id);
      await tapIn(tester, ExtraKeys.add);
      await tester.tap(find.byKey(ExtraDialog.itemKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Silicone').last);
      await tester.pumpAndSettle();
      final price = tester.widget<TextField>(find.byKey(ExtraKeys.price));
      expect(price.enabled, isFalse, reason: "the factory's price");
      expect(price.controller!.text, '3.00');
      expect(find.byKey(ExtraDialog.factoryPriceKey), findsOneWidget);
      await tester.enterText(find.byKey(ExtraKeys.quantity), '5');
      await tester.pumpAndSettle();
      expect(valueOf(tester, ExtraKeys.total), '15.00 USD');
      expect(find.text('5 bottles × 3.00 USD'), findsOneWidget);
      await tester.tap(find.byKey(ExtraKeys.save));
      await settle(tester);
      expect(valueOf(tester, ExtraKeys.extrasCost), '15.00 USD');
      final added = (await kept(tester, id)).pricing.extras.single;
      expect(added.itemId, items.single.id);
      expect(added.totalCents, 1500);

      // The item made dearer: the charge added is what it was.
      await tester.runAsync(
        () => ExtraCatalogStore().save([
          items.single.copyWith(unitPriceCents: 400),
        ], by: WorkshopRole.owner),
      );
      expect((await kept(tester, id)).pricing.extras.single.totalCents, 1500);
    });

    testWidgets('with no list, an extra is typed in full as it always was', (
      tester,
    ) async {
      await seedWith(tester, [frontEntranceDoor()], factoryList());
      final c = await toAdam(tester, size: phone);
      owner(c);
      await tester.pumpAndSettle();
      await openPrice(tester, frontEntranceDoor().id);
      await tapIn(tester, ExtraKeys.add);
      expect(find.byKey(ExtraDialog.itemKey), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(ExtraKeys.price)).enabled,
        isTrue,
      );
    });
  });

  test('the catalog store is the only route to the list, and kept apart from '
      'the price list', () async {
    SharedPreferences.setMockInitialValues({});
    await ExtraCatalogStore().save([
      ExtraItem(
        id: 'item-silicone',
        name: 'Silicone',
        category: ExtraCategory.material,
        unit: 'bottle',
        unitPriceCents: 300,
        currency: 'USD',
        updatedAt: DateTime(2026, 10, 12),
      ),
    ], by: WorkshopRole.owner);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PriceListStore.key), isNull);
    expect(prefs.getString(ExtraCatalogStore.key), isNotNull);
  });
}
