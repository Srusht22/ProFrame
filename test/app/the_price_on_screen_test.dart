import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/inspector/price_panel.dart';
import 'package:proframe/app/state/pricing.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/price_list.dart';
import 'package:proframe/domain/pricing/price_result.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/pricing/pricing_engine.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:proframe/infrastructure/price_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/pricing_engine_test.dart' show door;
import 'a_customer_s_page_test.dart' as page;
import 'an_unknown_category_on_screen_test.dart' as unknown;
import 'angled_geometry_feedback_on_screen_test.dart' show openFor;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// The price on the real app: the design's own panel shows what the design
// comes to by the price list, worked out afresh with every change to the
// design and to the list — and never by changing the design to do it.

/// The total as the panel writes it.
String shownTotal(WidgetTester tester) => tester
    .widget<Text>(find.byKey(PricePanel.totalKey, skipOffstage: false))
    .data!;

PriceResult priceOf(ProviderContainer c) => c.read(designPriceProvider)!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the design\'s panel shows its price, worked out afresh as '
      'its width, height, material, colour, glass and hinges change', (
    tester,
  ) async {
    final c = await openFor(tester, door());
    final controller = c.read(workspaceProvider.notifier);
    expect(find.byKey(PricePanel.panelKey, skipOffstage: false), findsOne);

    final first = priceOf(c);
    expect(first.isPriced, isTrue, reason: '${first.issues}');
    expect(shownTotal(tester), PricePanel.money(first.total!, first.currency));
    expect(
      find.textContaining('Example prices', skipOffstage: false),
      findsOne,
    );

    // Each edit, and the price the panel shows after it.
    final seen = <String>{shownTotal(tester)};
    Future<void> after(String what, void Function() edit) async {
      final before = shownTotal(tester);
      edit();
      await tester.pumpAndSettle();
      final now = shownTotal(tester);
      expect(now, isNot(before), reason: what);
      expect(
        now,
        PricePanel.money(priceOf(c).total!, priceOf(c).currency),
        reason: what,
      );
      seen.add(now);
    }

    await after('width', () => controller.resizeFrame(widthMm: 1200));
    await after('height', () => controller.resizeFrame(heightMm: 2300));
    final frame = c.read(workspaceProvider).design.frame!;
    await after(
      'aluminium',
      () => controller.setFinish(
        frame.id,
        frame.finish.copyWith(material: MaterialKind.aluminium),
      ),
    );
    await after(
      'a special colour',
      () => controller.setFinish(
        frame.id,
        const Finish(colour: 0xFF8C1E20, material: MaterialKind.aluminium),
      ),
    );
    final pane = Infill.partsOf(c.read(workspaceProvider).design).single;
    await after(
      'glass to panel',
      () => controller.setFinish(pane.id, PanelColour.brown.finish),
    );
    final opening = c.read(workspaceProvider).design.openings.single;
    final hinges = c
        .read(workspaceProvider)
        .design
        .hardware
        .where((h) => h.kind == HardwareKind.hinge)
        .length;
    await after(
      'a hinge more',
      () => controller.setOpeningHardware(opening.id, hingeCount: hinges + 1),
    );
    await after(
      'the hinge taken off again',
      () => controller.setOpeningHardware(opening.id, hingeCount: hinges),
    );
    expect(seen.length, greaterThanOrEqualTo(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('installation is off until it is switched on, is kept with '
      'the design, and comes back with it', (tester) async {
    final c = await openFor(tester, door());
    final controller = c.read(workspaceProvider.notifier);
    expect(priceOf(c).sumOf(PriceGroup.installation), 0);
    final switchTile = find.byKey(
      PricePanel.installationKey,
      skipOffstage: false,
    );
    await tester.scrollUntilVisible(
      switchTile.hitTestable(),
      100,
      scrollable: find
          .ancestor(
            of: find.byType(PricePanel, skipOffstage: false),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).design.pricing.installation, isTrue);
    expect(priceOf(c).sumOf(PriceGroup.installation), greaterThan(0));
    final total = priceOf(c).total;

    // Kept, and read back as the same price.
    await tester.runAsync(controller.save);
    late Design kept;
    await tester.runAsync(() async {
      kept = (await DesignStore(customers: CustomerStore()).load('door'))!;
    });
    expect(kept.pricing.installation, isTrue);
    final list = c.read(priceListProvider).value!;
    expect(const PricingEngine().price(kept, list).total, total);

    // Undone, it is off again.
    controller.undo();
    await tester.pumpAndSettle();
    expect(priceOf(c).sumOf(PriceGroup.installation), 0);
  });

  testWidgets('a price list the owner keeps prices the design open at '
      'once; staff are refused and nothing changes', (tester) async {
    final c = await openFor(tester, door());
    final before = priceOf(c).total;

    final dearer = PriceList.starter.copyWith(
      profiles: {
        ...PriceList.starter.profiles,
        MaterialKind.upvc: const ProfileRate(
          framePerMetre: 100000,
          sashPerMetre: 18000,
          barPerMetre: 14000,
          colours: [
            ColourRate('Off white', 0xFFF3F4F2, ColourGrade.standard, 0),
          ],
        ),
      },
    );
    final element = tester.element(
      find.byType(PricePanel, skipOffstage: false),
    );
    final ref = ProviderScope.containerOf(element);
    expect(ref.read(workshopRoleProvider), WorkshopRole.staff);

    Object? refused;
    await tester.runAsync(() async {
      try {
        await ref
            .read(priceListStoreProvider)
            .save(dearer, by: ref.read(workshopRoleProvider));
      } on PricingAccessDenied catch (e) {
        refused = e;
      }
    });
    expect(refused, isA<PricingAccessDenied>());
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PriceListStore.key), isNull);
    });
    expect(priceOf(c).total, before);

    ref.read(workshopRoleProvider.notifier).become(WorkshopRole.owner);
    await tester.runAsync(() async {
      await ref
          .read(priceListStoreProvider)
          .save(dearer, by: ref.read(workshopRoleProvider));
    });
    ref.invalidate(priceListProvider);
    await tester.runAsync(() => ref.read(priceListProvider.future));
    await tester.pumpAndSettle();
    expect(priceOf(c).total, greaterThan(before!));
    expect(
      find.textContaining('Example prices', skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('a design of a category this version does not know says '
      'Price unavailable — no figure, never a window\'s', (tester) async {
    await unknown.seed(tester, unknown.twoUnknown());
    final c = await unknown.toAdam(tester);
    await unknown.openCard(tester, 'angled');
    final result = priceOf(c);
    expect(result.status, PriceStatus.unsupportedCategory);
    expect(result.total, isNull);
    expect(find.text('Price unavailable', skipOffstage: false), findsOneWidget);
    expect(find.byKey(PricePanel.totalKey, skipOffstage: false), findsNothing);
    final installation = tester.widget<Switch>(
      find.byKey(PricePanel.installationKey, skipOffstage: false),
    );
    expect(installation.onChanged, isNull);
  });

  testWidgets('pricing a design writes nothing to it or to the device', (
    tester,
  ) async {
    final design = OpeningHardware.settle(door());
    await tester.runAsync(() async {
      final people = CustomerStore();
      final adam = await people.create(name: 'Adam');
      await DesignStore(customers: people)
          .save(design.copyWith(customerId: adam.id));
    });
    late Map<String, Object?> before;
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
    });
    final c = await screen.openTheApp(tester);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    await unknown.openCard(tester, 'door');
    final shown = c.read(workspaceProvider).design;
    final text = jsonEncode(shown.toJson());
    for (var i = 0; i < 3; i++) {
      expect(priceOf(c).isPriced, isTrue, reason: '${priceOf(c).issues}');
      await tester.pumpAndSettle();
    }
    expect(identical(c.read(workspaceProvider).design, shown), isTrue);
    expect(jsonEncode(shown.toJson()), text);
    expect(c.read(workspaceProvider.notifier).canUndo, isFalse);
    await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
    });
  });
}
