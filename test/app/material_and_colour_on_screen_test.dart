import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_actions.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/inspector/profile_chooser.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/factory_prices_screen.dart';
import 'package:proframe/app/state/access.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_selection.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing_engine_test.dart' show door, engine;
import 'angled_geometry_feedback_on_screen_test.dart' show openFor;
import 'customers_screen_test.dart' as customers;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;
import 'the_price_button_test.dart'
    show
        adams,
        barButton,
        cardButton,
        closeSheet,
        enabledAt,
        seed,
        sheetTotal,
        textOf,
        toAdam,
        toSummary;

// What a design is made of, on the screens: every card says its category,
// its material and its colour in words; the price sheet chooses the
// material and colour and works the price out again; and the factory's
// rates are the owner's to change, behind the owner's PIN.

const black = 0xFF1C1C1C;
const white = 0xFFFFFFFF;

/// Adam's three designs, as [adams] has them, with the front door made in
/// black aluminium, the kitchen window in white uPVC, and the basement door
/// in the stock finish nobody chose.
List<Design> madeUp() {
  final [front, kitchen, basement] = adams();
  return [
    ProfileSelection.choose(
      front,
      material: MaterialKind.aluminium,
      colour: black,
    ),
    ProfileSelection.choose(
      kitchen,
      material: MaterialKind.upvc,
      colour: white,
    ),
    basement.copyWith(profileChosen: false),
  ];
}

/// Picks [label] from the dropdown under the chooser's [key].
Future<void> pick(WidgetTester tester, Key key, String label) async {
  final field = find.descendant(
    of: find.byKey(key),
    matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
  );
  await tester.ensureVisible(field.first);
  await tester.pumpAndSettle();
  await tester.tap(field.first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<Design?> kept(WidgetTester tester, String id) =>
    tester.runAsync<Design?>(() => DesignStore().load(id));

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('40. every card says its category, its material and its '
      'colour in words, and where it stands', (tester) async {
    await seed(tester, madeUp());
    await toAdam(tester);
    final expected = {
      'front': ('Door', 'Aluminium', 'Black'),
      'kitchen': ('Window', 'uPVC', 'White'),
      'basement': ('Door', 'Not selected', 'Not selected'),
    };
    for (final MapEntry(key: id, value: (kind, material, colour))
        in expected.entries) {
      await cardButton(tester, id);
      final card = find.ancestor(
        of: find.byKey(CustomerDesignCard.materialKey(id)),
        matching: find.byType(CustomerDesignCard),
      );
      expect(
        find.descendant(of: card, matching: find.text(kind)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(CustomerDesignCard.materialKey(id)))
            .textSpan!
            .toPlainText(),
        'Material: $material',
      );
      expect(
        tester
            .widget<Text>(find.byKey(CustomerDesignCard.colourKey(id)))
            .textSpan!
            .toPlainText(),
        'Colour: $colour',
      );
      expect(find.byKey(CustomerDesignCard.statusKey(id)), findsOneWidget);
      expect(find.byKey(CustomerDesignCard.priceValueKey(id)), findsOneWidget);
    }
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('basement')),
      'Price: unavailable',
      reason: 'its height is not given either',
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(1024, 768),
    Size(1280, 900),
    Size(1440, 900),
    Size(390, 844),
  ]) {
    testWidgets('40. a long name, a long colour and a long category fit a '
        'card at ${size.width.toInt()} × ${size.height.toInt()}', (
      tester,
    ) async {
      final [front, kitchen, _] = madeUp();
      await seed(tester, [
        ProfileSelection.choose(
          front.copyWith(
            name: 'Front Entrance Door to the Courtyard Garden, North Side',
            kind: DesignKind.angled,
          ),
          material: MaterialKind.aluminium,
          colour: 0xFF4A2F1E,
        ),
        kitchen,
      ]);
      await toAdam(tester);
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      for (final id in ['front', 'kitchen']) {
        await cardButton(tester, id);
        for (final key in [
          CustomerDesignCard.materialKey(id),
          CustomerDesignCard.colourKey(id),
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(key),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '$key cut short at $size',
          );
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('31 & 32. from a card\'s price sheet: aluminium made uPVC, '
      'the price worked out again from uPVC\'s rates; made white, again; '
      'the card and the customer\'s summary follow', (tester) async {
    await seed(tester, madeUp());
    await toAdam(tester);
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    final list = PriceList.starter;
    final alu = (await kept(tester, 'front'))!;
    expect(
      sheetTotal(tester),
      PricePanel.money(engine.price(alu, list).total!, 'USD'),
    );
    expect(
      tester.widget<Text>(find.byKey(DesignPriceSheet.categoryKey)).data,
      'Category: Door',
    );

    await pick(tester, ProfileChooser.materialKey, 'uPVC');
    final pvc = (await kept(tester, 'front'))!;
    expect(ProfileSelection.of(pvc).material, MaterialKind.upvc);
    expect(ProfileSelection.of(pvc).colour, black);
    final pvcTotal = engine.price(pvc, list).total!;
    expect(sheetTotal(tester), PricePanel.money(pvcTotal, 'USD'));
    expect(pvcTotal, isNot(engine.price(alu, list).total));

    await pick(tester, ProfileChooser.colourKey, 'White');
    final whitePvc = (await kept(tester, 'front'))!;
    expect(ProfileSelection.of(whitePvc).colour, white);
    final whiteTotal = engine.price(whitePvc, list).total!;
    expect(sheetTotal(tester), PricePanel.money(whiteTotal, 'USD'));
    expect(whiteTotal, lessThan(pvcTotal), reason: 'black adds by the metre');
    await closeSheet(tester);

    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: ${PricePanel.money(whiteTotal, 'USD')}',
    );
    expect(
      tester
          .widget<Text>(find.byKey(CustomerDesignCard.materialKey('front')))
          .textSpan!
          .toPlainText(),
      'Material: uPVC',
    );
    await toSummary(tester);
    await tester.tap(find.text('Show each design and the materials'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, CustomerFinancialSummary.profileKey('front')),
      'Category: Door · Material: uPVC · Colour: White',
    );
    expect(
      textOf(tester, CustomerFinancialSummary.profileKey('kitchen')),
      'Category: Window · Material: uPVC · Colour: White',
    );
  });

  testWidgets('37. a design whose only gap is its material: Price opens the '
      'sheet to choose it, and it is priced the moment it is chosen', (
    tester,
  ) async {
    final [front, _, _] = adams();
    await seed(tester, [front.copyWith(profileChosen: false)]);
    await toAdam(tester);
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: choose material',
    );
    final button = await cardButton(tester, 'front');
    expect(enabledAt(tester, button), isTrue);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(DesignPriceSheet.unavailableKey)).data,
      'Please choose the material and colour of the profile to calculate '
      'the price.',
    );
    expect(find.byKey(DesignPriceSheet.totalKey), findsNothing);
    await pick(tester, ProfileChooser.materialKey, 'Aluminium');
    final chosen = (await kept(tester, 'front'))!;
    expect(ProfileSelection.of(chosen).material, MaterialKind.aluminium);
    expect(
      sheetTotal(tester),
      PricePanel.money(engine.price(chosen, PriceList.starter).total!, 'USD'),
    );
  });

  testWidgets('44. in the workspace: the material changed, the kept price '
      'is stale and never shown as the price; calculated, aluminium\'s', (
    tester,
  ) async {
    final c = await openFor(
      tester,
      ProfileSelection.choose(
        door(),
        material: MaterialKind.upvc,
        colour: white,
      ),
    );
    await tester.tap(barButton);
    await tester.pumpAndSettle();
    final first = sheetTotal(tester);
    await closeSheet(tester);

    await pick(tester, ProfileChooser.materialKey, 'Aluminium');
    final design = c.read(workspaceProvider).design;
    expect(ProfileSelection.of(design).material, MaterialKind.aluminium);
    expect(textOf(tester, PricePanel.stateKey), 'Price needs recalculation');
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsNothing);
    expect(textOf(tester, PricePanel.previousKey), contains(first));

    await tester.tap(barButton);
    await tester.pumpAndSettle();
    expect(
      sheetTotal(tester),
      PricePanel.money(engine.price(design, PriceList.starter).total!, 'USD'),
    );
    expect(sheetTotal(tester), isNot(first));
    // The choice is an edit like any other: undone, it is uPVC again.
    await closeSheet(tester);
    c.read(workspaceProvider.notifier).undo();
    await tester.pumpAndSettle();
    expect(
      ProfileSelection.of(c.read(workspaceProvider).design).material,
      MaterialKind.upvc,
    );
  });

  testWidgets('43 & 9. factory prices: staff read them and cannot change '
      'them; the owner sets a PIN, changes uPVC\'s rate and keeps it; it '
      'lasts a reload and prices the next uPVC design', (tester) async {
    final [_, kitchen, _] = madeUp();
    await seed(tester, [kitchen]);
    final c = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await tester.tap(find.byKey(FactoryPricesButton.buttonKey).first);
    await tester.pumpAndSettle();

    // Staff: every figure shown, none editable, no way to keep.
    expect(find.byKey(FactoryPricesScreen.readOnlyKey), findsOneWidget);
    expect(find.byKey(FactoryPricesScreen.saveKey), findsNothing);
    final field = find.byKey(
      FactoryPricesScreen.fieldKey('profile.upvc.normal'),
    );
    expect(tester.widget<TextField>(field).enabled, isFalse);
    expect(tester.widget<TextField>(field).controller!.text, '7');

    // The owner's PIN set, and the screen unlocked.
    await tester.tap(find.byKey(FactoryPricesScreen.unlockKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FactoryPricesScreen.pinKey), '2468');
    await tester.enterText(find.byKey(FactoryPricesScreen.pinAgainKey), '2468');
    await tester.tap(find.byKey(FactoryPricesScreen.pinOkKey));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(c.read(workshopRoleProvider), WorkshopRole.owner);
    expect(tester.widget<TextField>(field).enabled, isTrue);

    await tester.enterText(field, '9.5');
    await tester.tap(find.byKey(FactoryPricesScreen.saveKey));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    final keptList = await tester.runAsync(() => PriceListStore().load());
    expect(keptList!.profiles[MaterialKind.upvc]!.normalPerMetre, 9.5);
    expect(keptList.isStarter, isFalse);

    // Locked again: staff.
    await tester.tap(find.byKey(FactoryPricesScreen.lockKey));
    await tester.pumpAndSettle();
    expect(c.read(workshopRoleProvider), WorkshopRole.staff);

    // Reopened from nothing but the device: the rate is the owner's, and
    // the uPVC window is priced by it.
    await tester.pumpWidget(const SizedBox());
    final again = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    final list = await again.read(priceListProvider.future);
    expect(list.profiles[MaterialKind.upvc]!.normalPerMetre, 9.5);
    await tester.tap(find.byKey(FactoryPricesButton.buttonKey).first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(FactoryPricesScreen.fieldKey('profile.upvc.normal')),
          )
          .controller!
          .text,
      '9.50',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(FactoryPricesScreen.fieldKey('profile.upvc.normal')),
          )
          .enabled,
      isFalse,
      reason: 'a new run is staff until the PIN is given',
    );
    final line = engine
        .price(kitchen, list)
        .lines
        // Since Phase 33 the border is its own line, at the rate it shares
        // with the lines.
        .firstWhere((l) => l.label == 'uPVC — Border');
    expect(line.rate, 9.5);
  });

  testWidgets('a wrong PIN leaves it locked', (tester) async {
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });
    final c = await screen.openTheApp(tester, size: const Size(1280, 900));
    await customers.toCustomers(tester);
    await tester.runAsync(
      () => c.read(ownerAccessStoreProvider).setPin('2468'),
    );
    await tester.tap(find.byKey(FactoryPricesButton.buttonKey).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FactoryPricesScreen.unlockKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FactoryPricesScreen.pinAgainKey), findsNothing);
    await tester.enterText(find.byKey(FactoryPricesScreen.pinKey), '1111');
    await tester.tap(find.byKey(FactoryPricesScreen.pinOkKey));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.text('That is not the owner PIN.'), findsOneWidget);
    expect(c.read(workshopRoleProvider), WorkshopRole.staff);
  });
}
