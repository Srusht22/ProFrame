import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/measure_form.dart';
import 'package:proframe/app/l10n/app_localizations.dart';
import 'package:proframe/app/screens/appearance_button.dart';
import 'package:proframe/app/screens/customer_finance.dart';
import 'package:proframe/app/screens/customers_screen.dart';
import 'package:proframe/app/screens/design_name_screen.dart';
import 'package:proframe/app/screens/factory_defaults_screen.dart';
import 'package:proframe/app/screens/factory_prices_screen.dart';
import 'package:proframe/app/screens/language_button.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/staff_screen.dart';
import 'package:proframe/app/state/appearance.dart';
import 'package:proframe/app/state/language.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurement_defaults.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/measurement_defaults_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;
import 'the_sizes_are_asked_test.dart' as sizes;

// What the user asked for over four screenshots, after Phase 35:
//
// 1. *The icons are not in the same line — two of them are much higher
//    than the others. Remove the Settings icon, change how the mode icon is
//    shown, and change "کڕیاران" in Kurdish to something else.*
// 2. *When we click New Design and type a customer, it must show the ones
//    that match, character by character, in real time, until we click.*
// 3. *The overall width does not take the number* — held in
//    `test/domain/a_size_keeps_the_opening_s_mark_test.dart` — *and a
//    button on the first page to set the frame border, the bar thickness
//    and the rest for each type, PVC or aluminium, and the default prices
//    for each type and colour, separate from the default measurements.*
// 4. *The way the price is shown on the customer's page is very crowded;
//    make it simple.*

final kurdish = lookupAppLocalizations(const Locale('ckb'));

/// The header's icons, each as the box it stands in.
List<Rect> headerIcons(WidgetTester tester) => [
  for (final key in const [
    AccountButton.buttonKey,
    FactoryButton.buttonKey,
    LanguageButton.buttonKey,
    AppearanceButton.buttonKey,
  ])
    tester.getRect(find.byKey(key).first),
];

List<String> overflowing(WidgetTester tester) => [
  for (final r in tester.allRenderObjects)
    if (r is RenderFlex && r.toStringShort().contains('OVERFLOWING'))
      r.debugCreator.toString().split('\n').first,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. the header', () {
    for (final size in const [
      Size(1366, 768),
      Size(1024, 768),
      Size(820, 1180),
      Size(390, 844),
    ]) {
      testWidgets('at ${size.width.round()} wide, in Kurdish and dark: four '
          'icons on one line, no Settings, a moon, and the new title', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          Language.key: 'ckb',
          Appearance.key: 'dark',
        });
        await screen.openTheApp(tester, size: size);

        final icons = headerIcons(tester);
        final middle = icons.first.center.dy;
        for (final r in icons) {
          // The same middle, to the pixel, whatever kind of button it is.
          expect(r.center.dy, closeTo(middle, 0.5));
          expect(r.height, icons.first.height);
        }
        // And, on a wide screen, level with the two buttons beside them.
        if (size.width >= 1000) {
          final button = tester.getRect(
            find.byKey(CustomersScreen.newDesignButton),
          );
          expect(button.center.dy, closeTo(middle, 0.5));
        }

        // Settings is gone: nothing on the header is a gear.
        expect(find.byIcon(Icons.settings_outlined), findsNothing);
        expect(find.byIcon(Icons.settings), findsNothing);

        // The appearance shows what is on the screen: a moon in the dark.
        expect(
          find.descendant(
            of: find.byKey(AppearanceButton.buttonKey),
            matching: find.byIcon(Icons.dark_mode_outlined),
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.brightness_auto_outlined), findsNothing);

        // The Kurdish title is no longer کڕیاران.
        expect(kurdish.customersTitle, isNot('کڕیاران'));
        expect(find.text(kurdish.customersTitle), findsOneWidget);
        expect(find.text('کڕیاران'), findsNothing);

        expect(overflowing(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the appearance icon turns to a sun in the light, and the '
        'device\'s mark is only in its list', (tester) async {
      SharedPreferences.setMockInitialValues({Appearance.key: 'light'});
      await screen.openTheApp(tester);
      final button = find.byKey(AppearanceButton.buttonKey);
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.light_mode_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byIcon(Appearance.icons[ThemeMode.system]!), findsOneWidget);
      await tester.tap(find.byKey(AppearanceButton.optionKey(ThemeMode.dark)));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: button,
          matching: find.byIcon(Icons.dark_mode_outlined),
        ),
        findsOneWidget,
      );
    });
  });

  group('2. New Design finds the customer as the name is typed', () {
    testWidgets('a letter at a time, the matches narrowing; a tap goes on '
        'with that customer, and no second one is made', (tester) async {
      final kept = await screen.keepThree(); // Karwan, Ahmed, Sara
      await screen.openTheApp(tester);
      await tester.tap(find.byKey(CustomersScreen.newDesignButton));
      await tester.pumpAndSettle();
      final field = find.byKey(NewDesignScreen.customerField);

      // Each customer kept, by name and id.
      final ids = {for (final d in kept) d.customer!: d.customerId!};
      Future<List<String>> offered(String typed) async {
        await tester.enterText(field, typed);
        await tester.pumpAndSettle();
        return [
          for (final e in ids.entries)
            if (find
                .byKey(NewDesignScreen.suggestionKey(e.value))
                .evaluate()
                .isNotEmpty)
              e.key,
        ];
      }

      expect(await offered('a'), unorderedEquals(['Karwan', 'Ahmed', 'Sara']));
      expect(await offered('ar'), unorderedEquals(['Karwan', 'Sara']));
      expect(await offered('kar'), ['Karwan']);
      // Nobody called exactly that, so a new customer is offered too.
      expect(find.byKey(NewDesignScreen.newCustomerKey), findsOneWidget);
      expect(await offered('zz'), isEmpty);
      expect(find.byKey(NewDesignScreen.newCustomerKey), findsOneWidget);

      // Karwan, picked.
      final before = (await tester.runAsync(CustomerStore().count))!;
      await offered('kar');
      final karwan = kept.firstWhere((d) => d.customer == 'Karwan');
      await tester.tap(
        find.byKey(NewDesignScreen.suggestionKey(karwan.customerId!)),
      );
      await tester.pumpAndSettle();
      final step = tester.widget<DesignNameScreen>(
        find.byType(DesignNameScreen),
      );
      expect(step.setup.customerId, karwan.customerId);
      expect(step.setup.customer, 'Karwan');
      expect((await tester.runAsync(CustomerStore().count))!, before);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a name typed exactly as a customer kept goes on as that '
        'customer, by Continue too', (tester) async {
      final kept = await screen.keepThree();
      await screen.openTheApp(tester);
      await tester.tap(find.byKey(CustomersScreen.newDesignButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(NewDesignScreen.customerField), 'sara');
      await tester.pumpAndSettle();
      expect(find.byKey(NewDesignScreen.newCustomerKey), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      final step = tester.widget<DesignNameScreen>(
        find.byType(DesignNameScreen),
      );
      expect(
        step.setup.customerId,
        kept.firstWhere((d) => d.customer == 'Sara').customerId,
      );
    });

    testWidgets('it fits a phone, in Kurdish', (tester) async {
      SharedPreferences.setMockInitialValues({Language.key: 'ckb'});
      await screen.keepThree();
      await screen.openTheApp(tester, size: const Size(360, 740));
      await tester.tap(find.byKey(CustomersScreen.newDesignButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(NewDesignScreen.customerField), 'a');
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsWidgets);
      expect(overflowing(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  group('3. Factory defaults: measurements apart from prices', () {
    testWidgets('one button opens both, each its own page; staff read the '
        'measurements and the owner keeps them', (tester) async {
      final c = await screen.openTheApp(tester);
      await tester.tap(find.byKey(FactoryButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(FactoryDefaultsScreen.measurementsKey), findsOneWidget);
      expect(find.byKey(FactoryDefaultsScreen.pricesKey), findsOneWidget);

      // The prices are the price list, as before.
      await tester.tap(find.byKey(FactoryDefaultsScreen.pricesKey));
      await tester.pumpAndSettle();
      expect(find.byType(FactoryPricesScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(FactoryDefaultsScreen.measurementsKey));
      await tester.pumpAndSettle();
      expect(find.byType(MeasurementDefaultsScreen), findsOneWidget);
      // Staff: one set a kind of profile, read only.
      for (final m in [MaterialKind.upvc, MaterialKind.aluminium]) {
        for (final which in ['border', 'bars', 'depth']) {
          final f = find.byKey(MeasurementDefaultsScreen.fieldKey(m, which));
          expect(f, findsOneWidget);
          expect(tester.widget<TextField>(f).enabled, isFalse);
        }
      }
      expect(find.byKey(MeasurementDefaultsScreen.unlockKey), findsOneWidget);
      expect(find.byKey(MeasurementDefaultsScreen.saveKey), findsNothing);

      // The owner.
      c.read(workshopRoleProvider.notifier).become(WorkshopRole.owner);
      await tester.pumpAndSettle();
      Future<void> type(MaterialKind m, String which, String cm) async {
        await tester.enterText(
          find.byKey(MeasurementDefaultsScreen.fieldKey(m, which)),
          cm,
        );
      }

      await type(MaterialKind.upvc, 'border', '6');
      await type(MaterialKind.upvc, 'bars', '5');
      await type(MaterialKind.upvc, 'depth', '7');
      await type(MaterialKind.aluminium, 'border', '4.5');
      await type(MaterialKind.aluminium, 'bars', '0');
      await tester.pump();
      await tester.tap(find.byKey(MeasurementDefaultsScreen.saveKey));
      await tester.pumpAndSettle();
      // A figure that is not a size is said, and nothing is kept.
      expect(
        find.text('Enter a size in centimetres, more than nothing.'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(MeasurementDefaultsStore.key), isNull);

      await type(MaterialKind.aluminium, 'bars', '4');
      await tester.tap(find.byKey(MeasurementDefaultsScreen.saveKey));
      await tester.pumpAndSettle();
      final kept = MeasurementDefaults.fromJson(
        jsonDecode(prefs.getString(MeasurementDefaultsStore.key)!),
      );
      expect(
        kept.of(MaterialKind.upvc),
        const ProfileDefaults(borderMm: 60, barMm: 50, depthMm: 70),
      );
      expect(
        kept.of(MaterialKind.aluminium),
        const ProfileDefaults(borderMm: 45, barMm: 40),
      );
      // Apart from the prices: no price list was written.
      expect(prefs.getKeys().where((k) => k.contains('pricelist')), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the sizes form fills from them, and the design can still '
        'be given its own', (tester) async {
      SharedPreferences.setMockInitialValues({
        MeasurementDefaultsStore.key: jsonEncode(
          MeasurementDefaults.none
              .withMaterial(
                MaterialKind.upvc,
                const ProfileDefaults(borderMm: 60, barMm: 50, depthMm: 70),
              )
              .withMaterial(
                MaterialKind.aluminium,
                const ProfileDefaults(borderMm: 45, barMm: 40, depthMm: 55),
              )
              .toJson(),
        ),
      });
      final c = await sizes.openTheApp(tester, 'WINDOW');
      await sheet.twoLeaves(c);
      await tester.pumpAndSettle();
      expect(find.byType(MeasureForm), findsOneWidget);
      // Nothing is put in by itself: the profile is not chosen yet.
      expect(
        tester
            .widget<TextField>(sizes.field(Measurements.profileKey))
            .controller!
            .text,
        isEmpty,
      );
      String depth() => tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(MeasureForm.depthKey),
              matching: find.byType(TextField),
            ),
          )
          .controller!
          .text;

      await tester.tap(
        find.byKey(MeasureForm.defaultsKey(MaterialKind.aluminium)),
      );
      await tester.pumpAndSettle();
      String text(String key) =>
          tester.widget<TextField>(sizes.field(key)).controller!.text;
      expect(text(Measurements.profileKey), '4.5');
      expect(text(Measurements.barsKey), '4');
      expect(depth(), '5.5');

      // Changed for this design alone, then applied.
      await tester.enterText(sizes.field(Measurements.barsKey), '3.5');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final design = c.read(workspaceProvider).design;
      expect(design.frame!.profileMm, closeTo(45, 0.01));
      expect(
        design.dividers.every((b) => (b.widthMm - 35).abs() < 0.01),
        isTrue,
      );
      expect(design.depthMm, closeTo(55, 0.01));
      expect(
        design.measured,
        containsAll([Measurements.profileKey, Measurements.barsKey]),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a design whose profile is chosen is given its own kind\'s '
        'defaults as the form opens', (tester) async {
      SharedPreferences.setMockInitialValues({
        MeasurementDefaultsStore.key: jsonEncode(
          MeasurementDefaults.none
              .withMaterial(
                MaterialKind.upvc,
                const ProfileDefaults(borderMm: 60, barMm: 50, depthMm: 70),
              )
              .toJson(),
        ),
      });
      final c = await sizes.openTheApp(tester, 'WINDOW');
      await sheet.twoLeaves(c);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      c
          .read(workspaceProvider.notifier)
          .chooseProfile(material: MaterialKind.upvc, colour: 0xFFFFFFFF);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.straighten).first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(sizes.field(Measurements.profileKey))
            .controller!
            .text,
        '6',
      );
      expect(
        tester
            .widget<TextField>(sizes.field(Measurements.barsKey))
            .controller!
            .text,
        '5',
      );
      // Shown, not applied: the design has no border until Apply.
      expect(
        c.read(workspaceProvider).design.measured,
        isNot(contains(Measurements.profileKey)),
      );
    });

    testWidgets('with nothing set, the form says where to set it', (
      tester,
    ) async {
      final c = await sizes.openTheApp(tester, 'WINDOW');
      await sheet.twoLeaves(c);
      await tester.pumpAndSettle();
      expect(find.textContaining('No factory defaults yet'), findsOneWidget);
    });
  });

  group('4. the customer\'s money, simply', () {
    for (final size in const [Size(1280, 900), Size(360, 740)]) {
      testWidgets('at ${size.width.round()} wide: three figures, how they '
          'stand and what can be done; the rest folded away; nothing '
          'overflowing', (tester) async {
        await screen.keepThree();
        await screen.openTheApp(tester, size: size);
        await screen.openCustomer(tester, 'Sara');
        await tester.scrollUntilVisible(
          find.byKey(CustomerFinancialSummary.addPaymentKey).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        for (final key in const [
          CustomerFinancialSummary.totalKey,
          CustomerFinancialSummary.paidKey,
          CustomerFinancialSummary.dueKey,
          CustomerFinancialSummary.statusKey,
          CustomerFinancialSummary.refundKey,
        ]) {
          expect(find.byKey(key), findsOneWidget, reason: '$key');
        }
        // The breakdown is folded until asked for.
        expect(
          find.byKey(CustomerFinancialSummary.grossPaymentsKey),
          findsNothing,
        );
        expect(find.byKey(CustomerFinancialSummary.refundsKey), findsNothing);
        // An empty history is a heading, not a sentence.
        expect(find.text('No payment history yet.'), findsNothing);
        expect(find.byType(TransactionRow), findsNothing);

        await tester.scrollUntilVisible(
          find.byKey(CustomerFinancialSummary.toggleKey).hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(CustomerFinancialSummary.toggleKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(CustomerFinancialSummary.grossPaymentsKey),
          findsOneWidget,
        );
        expect(find.byKey(CustomerFinancialSummary.creditKey), findsOneWidget);
        expect(overflowing(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
