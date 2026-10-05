import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_actions.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/inspector/profile_chooser.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/factory_colours.dart';
import 'package:proframe/app/screens/factory_prices_screen.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/colour_catalog.dart';
import 'package:proframe/domain/pricing/default_factory_pricing.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/profile_selection.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing_engine_test.dart' show engine;
import 'customers_screen_test.dart' as customers;
import 'material_and_colour_on_screen_test.dart' show kept, madeUp, pick;
import 'pricing_integrity_on_screen_test.dart' show loadTheAppsTypeface;
import 'the_designs_screen_test.dart' as screen;
import 'the_price_button_test.dart'
    show cardButton, closeSheet, seed, textOf, toAdam, toSummary;

// The factory's colour catalog on the screens: the Colours section of the
// factory prices, read by staff and changed by the owner — a colour added,
// edited, renamed and retired, each kept as a version — and the selector,
// the cards and the customer's summary showing the catalog as it is.

const anthracite = 0xFF383E42;

/// Opens the factory prices from the customers' header at [size].
Future<ProviderContainer> toFactory(
  WidgetTester tester, {
  Size size = const Size(1280, 900),
}) async {
  final c = await screen.openTheApp(tester, size: size);
  await customers.toCustomers(tester);
  await tester.tap(find.byKey(FactoryPricesButton.buttonKey).first);
  await tester.pumpAndSettle();
  return c;
}

/// Unlocks the factory prices as the owner, setting the PIN 2468.
Future<void> unlock(WidgetTester tester) async {
  await tester.tap(find.byKey(FactoryPricesScreen.unlockKey));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(FactoryPricesScreen.pinKey), '2468');
  await tester.enterText(find.byKey(FactoryPricesScreen.pinAgainKey), '2468');
  await tester.tap(find.byKey(FactoryPricesScreen.pinOkKey));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

/// Scrolls the factory prices until [finder] is in sight.
Future<void> reach(WidgetTester tester, Finder finder) async {
  final list = find
      .descendant(
        of: find.byType(FactoryPricesScreen),
        matching: find.byType(Scrollable),
      )
      .first;
  // From the top, so what is above is reached as surely as what is below.
  tester.state<ScrollableState>(list).position.jumpTo(0);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(finder.hitTestable(), 120, scrollable: list);
  await tester.pumpAndSettle();
}

/// Lets a save to the device finish and the screen settle.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

Future<PriceList> keptList(WidgetTester tester) async =>
    (await tester.runAsync(() => PriceListStore().load()))!;

/// The list kept as the owner's before the app opens.
Future<PriceList> keepAsOwner(WidgetTester tester, PriceList list) async =>
    (await tester.runAsync(
      () => PriceListStore().save(list, by: WorkshopRole.owner),
    ))!;

ColourDraft draftOf(String name, int swatch, Map<MaterialKind, double> rates) =>
    ColourDraft(
      name: name,
      swatch: swatch,
      rates: {
        for (final e in rates.entries)
          e.key: ColourSurcharge(perMetre: e.value),
      },
    );

String richText(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).textSpan!.toPlainText();

/// The names offered by the open colour dropdown.
/// The first is the field's own showing of the colour chosen; the rest
/// are the menu.
List<String> offeredNames(WidgetTester tester) => [
  for (final item in tester.widgetList<DropdownMenuItem<String>>(
    find.byType(DropdownMenuItem<String>),
  ))
    if (item.child case final Row row)
      if (row.children.last case Flexible(child: final Text t)) t.data!,
].skip(1).toList();

void main() {
  setUpAll(loadTheAppsTypeface);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('staff see every colour with its rates and its state, and '
      'cannot add, edit or retire one; a wrong PIN changes nothing', (
    tester,
  ) async {
    final c = await toFactory(tester);
    final black = FactoryColoursSection.rowKey('colour-black');
    await reach(tester, find.byKey(black));
    expect(
      textOf(tester, FactoryColoursSection.statusKey('colour-black')),
      'Active',
    );
    expect(
      textOf(tester, FactoryColoursSection.ratesKey('colour-black')),
      'uPVC 1.00 USD/m · Aluminium 1.00 USD/m',
    );
    expect(
      textOf(tester, FactoryColoursSection.ratesKey('colour-silver')),
      'Aluminium 0.00 USD/m',
    );
    expect(find.byKey(FactoryColoursSection.addKey), findsNothing);
    expect(
      find.byKey(FactoryColoursSection.editKey('colour-black')),
      findsNothing,
    );
    expect(
      find.byKey(FactoryColoursSection.retireKey('colour-black')),
      findsNothing,
    );

    await tester.runAsync(
      () => c.read(ownerAccessStoreProvider).setPin('2468'),
    );
    await reach(tester, find.byKey(FactoryPricesScreen.unlockKey));
    await tester.tap(find.byKey(FactoryPricesScreen.unlockKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(FactoryPricesScreen.pinKey), '1111');
    await tester.tap(find.byKey(FactoryPricesScreen.pinOkKey));
    await settle(tester);
    expect(find.text('That is not the owner PIN.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.read(workshopRoleProvider), WorkshopRole.staff);
    expect(find.byKey(FactoryColoursSection.addKey), findsNothing);
  });

  testWidgets('A. the owner adds Anthracite Grey — PVC 2.00, aluminium 1.50 '
      '— each problem said as it is typed; kept as a new version, it lasts a '
      'reload; a figure typed over and not yet kept is not lost', (
    tester,
  ) async {
    final c = await toFactory(tester);
    await unlock(tester);
    final upvcNormal = find.byKey(
      FactoryPricesScreen.fieldKey('profile.upvc.normal'),
    );
    await tester.enterText(upvcNormal, '8');

    await reach(tester, find.byKey(FactoryColoursSection.addKey));
    await tester.tap(find.byKey(FactoryColoursSection.addKey));
    await tester.pumpAndSettle();
    final save = find.byKey(ColourDialog.saveKey);

    // Nothing typed.
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Colour name is required.'), findsOneWidget);
    expect(find.text('Choose at least one material.'), findsOneWidget);

    await tester.enterText(find.byKey(ColourDialog.nameKey), 'Anthracite Grey');
    await tester.enterText(find.byKey(ColourDialog.hexKey), '383E42');
    for (final m in [MaterialKind.upvc, MaterialKind.aluminium]) {
      await tester.ensureVisible(find.byKey(ColourDialog.materialKey(m)));
      await tester.tap(find.byKey(ColourDialog.materialKey(m)));
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(ColourDialog.metreKey(MaterialKind.upvc)),
      '2.00',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Aluminium colour rate is required for a colour that applies to '
        'Aluminium.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(ColourDialog.metreKey(MaterialKind.aluminium)),
      'abc',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter a figure.'), findsOneWidget);
    await tester.enterText(
      find.byKey(ColourDialog.metreKey(MaterialKind.aluminium)),
      '-1',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('A rate cannot be below nothing.'), findsOneWidget);
    // A name an active colour already has on that material.
    await tester.enterText(find.byKey(ColourDialog.nameKey), 'anthracite');
    await tester.enterText(
      find.byKey(ColourDialog.metreKey(MaterialKind.aluminium)),
      '1.50',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'An active colour is already called Anthracite for '
        'Aluminium.',
      ),
      findsOneWidget,
    );
    expect(await keptList(tester), isA<PriceList>());
    expect((await keptList(tester)).isStarter, isTrue, reason: 'none kept');

    await tester.enterText(find.byKey(ColourDialog.nameKey), 'Anthracite Grey');
    await tester.tap(save);
    await settle(tester);
    expect(find.byType(ColourDialog), findsNothing);

    final list = await keptList(tester);
    final added = list.colourById('colour-anthracite-grey')!;
    expect(added.name, 'Anthracite Grey');
    expect(added.swatch, anthracite);
    expect(added.rateFor(MaterialKind.upvc)!.perMetre, 2);
    expect(added.rateFor(MaterialKind.aluminium)!.perMetre, 1.5);
    expect(added.active, isTrue);
    expect(list.version, 1);
    expect(
      textOf(tester, FactoryColoursSection.ratesKey(added.id)),
      'uPVC 2.00 USD/m · Aluminium 1.50 USD/m',
    );
    // The figure typed over before is still there, not yet kept.
    expect(list.profiles[MaterialKind.upvc]!.normalPerMetre, 7);
    await reach(tester, upvcNormal);
    expect(tester.widget<TextField>(upvcNormal).controller!.text, '8');
    expect(c.read(workshopRoleProvider), WorkshopRole.owner);

    // From nothing but the device.
    await tester.pumpWidget(const SizedBox());
    final again = await screen.openTheApp(tester, size: const Size(1280, 900));
    final read = await again.read(priceListProvider.future);
    expect(read.colourById(added.id)!.name, 'Anthracite Grey');
    expect(
      read.offeredFor(MaterialKind.upvc).map((c) => c.id),
      contains(added.id),
    );
  });

  testWidgets('D & E. the owner edits a rate and renames, then retires: '
      'each a version, a price calculated before left as it was', (
    tester,
  ) async {
    final [front, _, _] = madeUp();
    final v1 = await keepAsOwner(
      tester,
      ColourCatalog.add(
        DefaultFactoryPricing.list,
        draftOf('Anthracite Grey', anthracite, {
          MaterialKind.upvc: 2,
          MaterialKind.aluminium: 1.5,
        }),
      ).list!,
    );
    const id = 'colour-anthracite-grey';
    await seed(tester, [
      ProfileSelection.choose(
        front,
        material: MaterialKind.aluminium,
        colour: anthracite,
        colourId: id,
      ),
    ]);
    // Calculated at version 1 from its card.
    await toAdam(tester);
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    await closeSheet(tester);
    final before = textOf(tester, CustomerDesignCard.priceValueKey('front'));
    expect(before, startsWith('Price: '));

    await tester.pumpWidget(const SizedBox());
    final c = await toFactory(tester);
    await unlock(tester);
    await reach(tester, find.byKey(FactoryColoursSection.editKey(id)));
    await tester.tap(find.byKey(FactoryColoursSection.editKey(id)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.byKey(ColourDialog.metreKey(MaterialKind.aluminium)),
          )
          .controller!
          .text,
      '1.50',
    );
    await tester.enterText(
      find.byKey(ColourDialog.metreKey(MaterialKind.aluminium)),
      '2.00',
    );
    await tester.enterText(find.byKey(ColourDialog.nameKey), 'Anthracite');
    await tester.tap(find.byKey(ColourDialog.saveKey));
    await tester.pumpAndSettle();
    // The starter's own Anthracite is active on aluminium.
    expect(find.textContaining('already called Anthracite'), findsOneWidget);
    await tester.enterText(find.byKey(ColourDialog.nameKey), 'Slate');
    await tester.tap(find.byKey(ColourDialog.saveKey));
    await settle(tester);
    var list = await keptList(tester);
    expect(list.version, v1.version + 1);
    expect(list.colourById(id)!.name, 'Slate', reason: 'the same id');
    expect(list.colourById(id)!.rateFor(MaterialKind.aluminium)!.perMetre, 2);

    await tester.tap(find.byKey(FactoryColoursSection.retireKey(id)));
    await tester.pumpAndSettle();
    expect(find.text('Retire Slate?'), findsOneWidget);
    await tester.tap(find.byKey(FactoryColoursSection.confirmRetireKey));
    await settle(tester);
    list = await keptList(tester);
    expect(list.version, v1.version + 2);
    expect(list.colourById(id)!.active, isFalse);
    expect(list.colours.length, v1.colours.length, reason: 'never deleted');
    expect(textOf(tester, FactoryColoursSection.statusKey(id)), 'Retired');
    expect(find.byKey(FactoryColoursSection.restoreKey(id)), findsOneWidget);
    expect(c.read(workshopRoleProvider), WorkshopRole.owner);

    // The design: still in it, still named, its old price a previous one.
    await tester.pumpWidget(const SizedBox());
    await toAdam(tester);
    await cardButton(tester, 'front');
    expect(
      richText(tester, CustomerDesignCard.colourKey('front')),
      'Colour: Slate',
    );
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: recalculate',
    );
    // On its sheet: still its colour, said to be retired, priced afresh.
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    expect(
      find.text('Retired: no longer offered for new designs.'),
      findsOneWidget,
    );
    expect(find.byKey(DesignPriceSheet.totalKey), findsOneWidget);
    await closeSheet(tester);
    final design = (await kept(tester, 'front'))!;
    expect(design.profileColourId, id);
    expect(design.frame!.finish.colour, anthracite);
    // Recalculated: still priced, at the retired colour's own rate.
    final r = engine.price(design, list);
    expect(r.isPriced, isTrue);
    expect(r.lines.singleWhere((l) => l.label.startsWith('Slate')).rate, 2);
  });

  testWidgets('the selector offers the active colours of the material '
      'chosen; made uPVC, a colour sold only in aluminium is asked again — '
      'nothing chosen for the user — and the card says so', (tester) async {
    final [front, _, _] = madeUp();
    await seed(tester, [
      ProfileSelection.choose(
        front,
        material: MaterialKind.aluminium,
        colour: 0xFF9C9C9C,
        colourId: 'colour-silver',
      ),
    ]);
    await toAdam(tester);
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();

    final colourField = find.descendant(
      of: find.byKey(ProfileChooser.colourKey),
      matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField),
    );
    await tester.tap(colourField);
    await tester.pumpAndSettle();
    final onAlu = offeredNames(tester);
    expect(
      onAlu,
      DefaultFactoryPricing.list
          .offeredFor(MaterialKind.aluminium)
          .map((c) => c.name)
          .toList(),
    );
    expect(onAlu, contains('Silver'));
    expect(onAlu, isNot(contains('Cream')));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await pick(tester, ProfileChooser.materialKey, 'uPVC');
    final design = (await kept(tester, 'front'))!;
    expect(design.profileColourId, 'colour-silver');
    expect(design.frame!.finish.colour, 0xFF9C9C9C, reason: 'not repainted');
    expect(
      find.text('Please select a colour available for uPVC.'),
      findsWidgets,
    );
    expect(find.byKey(DesignPriceSheet.totalKey), findsNothing);
    await pick(tester, ProfileChooser.colourKey, 'Cream');
    final cream = (await kept(tester, 'front'))!;
    expect(cream.profileColourId, 'colour-cream');
    expect(find.byKey(DesignPriceSheet.totalKey), findsOneWidget);
    await closeSheet(tester);
    expect(
      richText(tester, CustomerDesignCard.colourKey('front')),
      'Colour: Cream',
    );

    // Back to aluminium: Cream is not sold in it — the card says so.
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    await pick(tester, ProfileChooser.materialKey, 'Aluminium');
    await closeSheet(tester);
    expect(
      textOf(tester, CustomerDesignCard.priceValueKey('front')),
      'Price: choose colour',
    );
  });

  testWidgets('B & C. a colour the owner added is on the selector, the '
      'card, the summary and the frame the views are drawn in, and its '
      'surcharge is on the price', (tester) async {
    final [front, kitchen, _] = madeUp();
    await keepAsOwner(
      tester,
      ColourCatalog.add(
        DefaultFactoryPricing.list,
        draftOf('Anthracite Grey', anthracite, {
          MaterialKind.upvc: 2,
          MaterialKind.aluminium: 1.5,
        }),
      ).list!,
    );
    await seed(tester, [front, kitchen]);
    await toAdam(tester);
    await tester.tap(await cardButton(tester, 'front'));
    await tester.pumpAndSettle();
    await pick(tester, ProfileChooser.colourKey, 'Anthracite Grey');
    final d = (await kept(tester, 'front'))!;
    expect(d.profileColourId, 'colour-anthracite-grey');
    expect(
      d.frame!.finish,
      const Finish(colour: anthracite, material: MaterialKind.aluminium),
      reason: 'the finish every view draws',
    );
    expect(
      find.textContaining('Anthracite Grey Aluminium (non-standard colour)'),
      findsOneWidget,
    );
    final list = await keptList(tester);
    final r = engine.price(d, list);
    expect(find.byKey(DesignPriceSheet.totalKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(DesignPriceSheet.totalKey)).data,
      PricePanel.money(r.total!, 'USD'),
    );
    await closeSheet(tester);
    expect(
      richText(tester, CustomerDesignCard.colourKey('front')),
      'Colour: Anthracite Grey',
    );
    await toSummary(tester);
    await tester.tap(find.text('Show each design and the materials'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, CustomerFinancialSummary.profileKey('front')),
      'Category: Door · Material: Aluminium · Colour: Anthracite Grey',
    );
  });

  for (final size in const [
    Size(320, 640),
    Size(390, 844),
    Size(768, 1024),
    Size(1280, 800),
    Size(1920, 1080),
  ]) {
    testWidgets('the colours fit at ${size.width.toInt()} × '
        '${size.height.toInt()}: Lock in sight, the list kept from the '
        'screen, the colour dialog saved from within it', (tester) async {
      await toFactory(tester, size: size);
      await unlock(tester);
      expect(
        find.byKey(FactoryPricesScreen.lockKey).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(FactoryPricesScreen.saveKey).hitTestable(),
        findsOneWidget,
      );
      await reach(tester, find.byKey(FactoryColoursSection.addKey));
      await reach(
        tester,
        find.byKey(FactoryColoursSection.retireKey('colour-walnut-effect')),
      );
      await reach(tester, find.byKey(FactoryColoursSection.addKey));
      await tester.tap(find.byKey(FactoryColoursSection.addKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(ColourDialog.nameKey), 'Golden Oak');
      await tester.ensureVisible(
        find.byKey(ColourDialog.materialKey(MaterialKind.upvc)),
      );
      await tester.tap(find.byKey(ColourDialog.materialKey(MaterialKind.upvc)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ColourDialog.metreKey(MaterialKind.upvc)),
      );
      await tester.enterText(
        find.byKey(ColourDialog.metreKey(MaterialKind.upvc)),
        '2',
      );
      await tester.ensureVisible(find.byKey(ColourDialog.saveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(ColourDialog.saveKey).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(ColourDialog.saveKey));
      await settle(tester);
      expect(find.byType(ColourDialog), findsNothing);
      expect(
        (await keptList(tester)).colourById('colour-golden-oak'),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
