import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/designs_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'a_new_design_s_category_test.dart' as category;
import 'customers_screen_test.dart' as customers;
import 'new_design.dart';
import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;

// A fifth category beside the four: Angled / Asymmetrical, for a design
// whose shape is not square on purpose — a window under a stair, a sloped
// head, a trapezoid, sides of different heights. It is a category like the
// others: chosen on *Choose your design*, kept as the design's own, saved,
// and the same when the design is opened again tomorrow.

const card = 'ANGLED / ASYMMETRICAL';

Future<Map<String, Object?>> storedJson(WidgetTester tester, String id) async =>
    (await tester.runAsync(() async {
      final design = await DesignStore().load(id);
      return jsonDecode(jsonEncode(design!.toJson())) as Map<String, Object?>;
    }))!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the category itself', () {
    test('it is the fifth, after the four that were there, none renamed', () {
      expect(DesignKind.values.map((k) => k.name), [
        'door',
        'window',
        'both',
        'sliding',
        'angled',
        // Not a category anyone chooses: what a category this version does
        // not know is read as, rather than a window.
        'unsupported',
      ]);
      expect(DesignKind.categories, hasLength(5));
      expect(DesignKind.categories.last, DesignKind.angled);
      expect(DesignKind.angled.label, 'Angled / Asymmetrical');
      expect(StartScreen.choices.last, (
        DesignKind.angled,
        'Sloped, under-stair & custom shapes',
      ));
      expect(kindIcon(DesignKind.angled), Icons.change_history_outlined);
      // Its own mark, not one of the others'.
      for (final other in DesignKind.values) {
        if (other == DesignKind.angled) continue;
        expect(kindIcon(other), isNot(kindIcon(DesignKind.angled)));
      }
    });

    test('it says nothing about any one leaf, slides nothing and asks '
        'nothing as it starts', () {
      const angled = DesignKind.angled;
      expect(
        angled.leafDefault,
        isNull,
        reason: 'it can hold doors or windows, so it does not say which',
      );
      expect(angled.slides, isFalse);
      expect(angled.asksConstruction, isFalse);
      expect(DesignKind.leafKinds, isNot(contains(angled)));
      expect(angled.noun, 'angled design');
      expect(
        Design.empty(id: 'd', kind: angled).shownName,
        'Untitled angled design',
      );
    });

    test('it is saved as "angled" and read back as itself, in the design '
        'and in the list of designs', () {
      final design = Design.empty(
        id: 'stair',
        kind: DesignKind.angled,
        name: 'Under-stair Window',
        customerId: 'customer-1',
      );
      final json =
          jsonDecode(jsonEncode(design.toJson())) as Map<String, Object?>;
      expect(json['category'], 'angled');
      final back = Design.fromJson(json);
      expect(back.category, DesignKind.angled);
      expect(back.name, 'Under-stair Window');
      expect(back.customerId, 'customer-1');
      final summary = DesignSummary.fromJson(
        jsonDecode(jsonEncode(DesignSummary.of(design).toJson()))
            as Map<String, Object?>,
      );
      expect(summary.kind, DesignKind.angled);
    });
  });

  test('a leaf marked in it is asked door or window, because the category '
      'does not say — and nothing else is asked of it', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(workspaceProvider.notifier).startDesign(DesignKind.angled);
    await sheet.twoLeaves(c);
    final state = c.read(workspaceProvider);
    expect(state.design.openings, hasLength(2));
    expect(state.openingKindQuestions, hasLength(2));
    // Until it is said, a leaf hangs on its hinges and carries no handle.
    for (final opening in state.design.openings) {
      final pieces = [
        for (final h in state.design.hardware)
          if (h.parentId == opening.id) h.kind,
      ];
      expect(pieces, contains(HardwareKind.hinge));
      expect(pieces.where((k) => k.isHandle), isEmpty);
    }
    // Said, and the leaf has what that kind of leaf has.
    final first = state.design.openings.first;
    c
        .read(workspaceProvider.notifier)
        .setOpeningKind(first.id, DesignKind.window);
    final now = c.read(workspaceProvider);
    expect(now.openingKindQuestions, hasLength(1));
    expect([
      for (final h in now.design.hardware)
        if (h.parentId == first.id && h.kind.isHandle) h.kind,
    ], isNotEmpty);
  });

  testWidgets('made, saved, closed and opened again: still Angled / '
      'Asymmetrical', (tester) async {
    final kept = await customers.keepThreeCustomers();
    var c = await screen.openTheApp(tester, size: const Size(390, 844));
    await category.toAdamsCategories(tester, name: 'Under-stair Window');

    // On *Choose your design*, as the others are: its name, its line.
    await tester.ensureVisible(find.text(card));
    await tester.pumpAndSettle();
    expect(find.text(card), findsOneWidget);
    expect(find.text('Sloped, under-stair & custom shapes'), findsOneWidget);

    await chooseDesign(tester, card);
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    // Nothing is asked about what it is built of: it has the Material tool.
    expect(find.byKey(const ValueKey('construction-panel')), findsNothing);
    final made = c.read(workspaceProvider).design;
    expect(made.category, DesignKind.angled);
    expect(made.name, 'Under-stair Window');
    expect(made.customerId, kept['Adam']!.id);

    // Saved.
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    final json = await storedJson(tester, made.id);
    expect(json['category'], 'angled');

    // Closed: back to Adam's page, where its card says what it is.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);

    // The app closed altogether, and opened again from what the device kept.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    c = await screen.openTheApp(tester, size: const Size(390, 844));
    await page.openCustomer(tester, 'Adam');
    final open = find.byKey(CustomerDesignCard.openKey(made.id));
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final theCard = find.ancestor(
      of: open,
      matching: find.byType(CustomerDesignCard),
    );
    expect(
      find.descendant(
        of: theCard,
        matching: find.text('Angled / Asymmetrical'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: theCard,
        matching: find.byIcon(Icons.change_history_outlined),
      ),
      findsOneWidget,
    );

    // Reopened: the same design, its category as it was kept, and the
    // choice of category never put again.
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
    final reopened = c.read(workspaceProvider).design;
    expect(reopened.id, made.id);
    expect(reopened.category, DesignKind.angled);
    expect(reopened.customerId, kept['Adam']!.id);
    expect((await storedJson(tester, made.id))['category'], 'angled');
  });

  testWidgets('a customer\'s designs can be narrowed to Angled / '
      'Asymmetrical, and its card fits a phone, a tablet and a laptop', (
    tester,
  ) async {
    final kept = await customers.keepThreeCustomers();
    await tester.runAsync(
      () => DesignStore().save(
        Design.empty(
          id: 'stair',
          kind: DesignKind.angled,
          name: 'Under-stair Window',
          customerId: kept['Adam']!.id,
        ),
      ),
    );
    for (final size in const [
      Size(360, 740),
      Size(820, 1180),
      Size(1280, 860),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      await page.openCustomer(tester, 'Adam');
      final chip = find.descendant(
        of: find.byKey(CustomerScreen.filterKey(DesignKind.angled)),
        matching: find.text('Angled / Asymmetrical  1'),
      );
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byType(CustomerDesignCard), findsOneWidget);
      expect(find.text('Under-stair Window'), findsOneWidget);
      expect(page.overflowing(tester), isEmpty, reason: 'at $size');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the five cards fit a phone, a tablet and a laptop, every '
      'card the same size', (tester) async {
    await customers.keepThreeCustomers();
    for (final size in const [
      Size(360, 740),
      Size(390, 844),
      Size(820, 1180),
      Size(1280, 860),
      Size(1440, 900),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await screen.openTheApp(tester, size: size);
      await category.toAdamsCategories(tester);
      expect(page.overflowing(tester), isEmpty, reason: 'at $size');
      expect(tester.takeException(), isNull);
      // Every card as wide as every other, the angled one included.
      final widths = {
        for (final title in category.cards)
          tester
              .getSize(
                find
                    .ancestor(
                      of: find.text(title),
                      matching: find.byType(InkWell),
                    )
                    .first,
              )
              .width
              .round(),
      };
      expect(widths, hasLength(1), reason: 'at $size: $widths');
    }
  });
}
