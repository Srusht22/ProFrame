import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/inspector/unsupported_category_note.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_unknown_category_test.dart' show keptAs, sloped;
import '../domain/geometry_normalizer_test.dart' show pen;
import 'a_customer_s_page_test.dart' as page;
import 'a_design_in_every_view_test.dart' as every;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// A design of a category this version does not know, on the real app. Adam
// has three designs: a door, the sloped window kept by a later version as
// `future_custom_shape`, and another kept as `circular`. Neither of the two
// is ever called a window — on its card, in the filters, in a search, at
// the head of the drawing or in its own panel — and opening one shows it,
// as saved, in Draw, CAD and 3D, with a notice saying why nothing in it can
// be changed here. Nothing done to it changes it, and the device is left
// exactly as it was.

const phone = Size(390, 844);

/// Adam, a door of his, and [unknown] designs of his rewritten on the
/// device as a later version would have left them, each `(design,
/// category)`.
Future<void> seed(WidgetTester tester, List<(Design, Object?)> unknown) async {
  await tester.runAsync(() async {
    final people = CustomerStore();
    final adam = await people.create(name: 'Adam', now: DateTime(2026, 3, 1));
    final store = DesignStore(customers: people);
    final door = Design.empty(
      id: 'door',
      kind: DesignKind.door,
    ).copyWith(name: 'Basement Door', customerId: adam.id);
    await store.save(door);
    final prefs = await SharedPreferences.getInstance();
    for (final (design, category) in unknown) {
      final kept = await store.save(design.copyWith(customerId: adam.id));
      await prefs.setString(
        '${DesignStore.designKeyPrefix}${kept.id}',
        jsonEncode(keptAs(kept, category)),
      );
      final index =
          jsonDecode(prefs.getString(DesignStore.indexKey)!) as List<Object?>;
      await prefs.setString(
        DesignStore.indexKey,
        jsonEncode([
          for (final line in index.cast<Map<String, Object?>>())
            line['id'] == kept.id ? {...line, 'category': category} : line,
        ]),
      );
    }
  });
}

/// Every key the device holds, with its value.
Future<Map<String, Object?>> device(WidgetTester tester) async {
  late Map<String, Object?> all;
  await tester.runAsync(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    all = {for (final k in prefs.getKeys()) k: prefs.get(k)};
  });
  return all;
}

/// The two later-version designs: the sloped fixture and a second one.
List<(Design, Object?)> twoUnknown() => [
  (sloped(), 'future_custom_shape'),
  (sloped(id: 'round').copyWith(name: 'Round Window'), 'circular'),
];

Finder cardOf(String id) => find.byKey(CustomerScreen.designKey(id));

Future<ProviderContainer> toAdam(WidgetTester tester, {Size? size}) async {
  final c = await screen.openTheApp(
    tester,
    size: size ?? const Size(1280, 820),
  );
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
  return c;
}

Future<void> openCard(WidgetTester tester, String id) async {
  final open = find.byKey(CustomerDesignCard.openKey(id)).hitTestable();
  await tester.scrollUntilVisible(
    open,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(open);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, size) in [
    ('a laptop', const Size(1280, 820)),
    ('a phone', phone),
  ]) {
    testWidgets('on $name, Adam\'s designs of a category this version does '
        'not know are listed as Unsupported, never Window — in the cards, '
        'the filters and a search', (tester) async {
      await seed(tester, twoUnknown());
      final before = await device(tester);
      await toAdam(tester, size: size);

      for (final id in ['angled', 'round']) {
        final card = cardOf(id);
        await tester.scrollUntilVisible(
          card,
          100,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.descendant(
            of: card,
            matching: find.text(DesignKind.unsupported.label),
          ),
          findsOneWidget,
          reason: '$id says what it is',
        );
        expect(
          find.descendant(of: card, matching: find.text('Window')),
          findsNothing,
          reason: '$id is not called a window',
        );
      }
      expect(tester.takeException(), isNull);

      // The filters: All, Door, and Unsupported — no Window chip, because
      // Adam has no window.
      expect(
        find.byKey(CustomerScreen.filterKey(DesignKind.window)),
        findsNothing,
      );
      final unsupported = find.byKey(
        CustomerScreen.filterKey(DesignKind.unsupported),
      );
      expect(unsupported, findsOneWidget);
      await tester.ensureVisible(unsupported);
      await tester.tap(unsupported);
      await tester.pumpAndSettle();
      expect(find.text('2 of 3', skipOffstage: false), findsOneWidget);
      expect(cardOf('door'), findsNothing);
      final door = find.byKey(CustomerScreen.filterKey(DesignKind.door));
      await tester.ensureVisible(door);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(find.text('1 of 3', skipOffstage: false), findsOneWidget);
      expect(cardOf('angled'), findsNothing);
      final all = find.byKey(CustomerScreen.filterKey(null));
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // A search by the design's name finds it, as itself.
      await tester.enterText(find.byKey(CustomerScreen.searchField), 'Sloped');
      await tester.pumpAndSettle();
      expect(find.text('1 of 3', skipOffstage: false), findsOneWidget);
      expect(cardOf('angled'), findsOneWidget);
      expect(
        find.descendant(
          of: cardOf('angled'),
          matching: find.text(DesignKind.unsupported.label),
        ),
        findsOneWidget,
      );

      // Looking wrote nothing.
      expect(await device(tester), before);
    });
  }

  testWidgets('opened, it is shown as it was saved in all three views with '
      'the notice, asks nothing, and nothing done to it changes it or the '
      'device', (tester) async {
    await seed(tester, twoUnknown());
    final before = await device(tester);
    final c = await toAdam(tester);
    await openCard(tester, 'angled');

    final shown = c.read(workspaceProvider).design;
    expect(shown.kind, DesignKind.unsupported);
    expect(shown.kind, isNot(DesignKind.window));
    expect(shown.savedCategory, 'future_custom_shape');
    expect(find.byType(Dialog), findsNothing, reason: 'no sizes asked');
    expect(find.text('Not now'), findsNothing, reason: 'nothing asked');
    expect(c.read(workspaceProvider).allQuestions, isEmpty);
    expect(c.read(workspaceProvider).sizesToAsk, isEmpty);

    // The notice, in words, in every view — and the drawing, the technical
    // drawing and the solid each of that very design.
    for (final view in [
      WorkspaceView.draw,
      WorkspaceView.plan,
      WorkspaceView.model,
    ]) {
      await every.showView(tester, view);
      expect(
        find.byKey(UnsupportedCategoryNote.noteKey),
        findsOneWidget,
        reason: '$view',
      );
      expect(find.text(UnsupportedCategoryNote.title), findsOneWidget);
    }
    expect(find.textContaining('enum'), findsNothing);
    expect(find.textContaining('future_custom_shape'), findsNothing);
    final solid = every.painterOf<ModelPainter>(tester);
    expect(every.facets(solid), every.projected(c, shown));
    expect(every.facets(solid), isNotEmpty);
    await every.showView(tester, WorkspaceView.plan);
    expect(identical(every.painterOf<CadPainter>(tester).design, shown), true);
    await every.showView(tester, WorkspaceView.draw);
    expect(
      identical(every.painterOf<DesignPainter>(tester).design, shown),
      true,
    );
    // Its own panel names it Unsupported, not Window.
    expect(find.text(DesignKind.unsupported.label), findsWidgets);

    // Everything that would change it — none does.
    final controller = c.read(workspaceProvider.notifier);
    final opening = shown.openings.single;
    controller.addStroke(
      pen('x', const [Vec2(100, 1300), Vec2(900, 1300)]).samples,
      tool: Tool.line,
    );
    controller.readDrawing();
    controller.setOpeningKind(opening.id, DesignKind.door);
    controller.setFinish(shown.frame!.id, PanelColour.brown.finish);
    controller.moveDividerTo(
      shown.topLevelDividers.first.id,
      const Vec2(300, 900),
    );
    controller.resizeFrame(widthMm: 1400);
    controller.setDepth(120);
    controller.rename('Changed');
    controller.select(shown.topLevelDividers.first.id);
    controller.deleteSelected();
    await tester.pumpAndSettle();
    expect(identical(c.read(workspaceProvider).design, shown), isTrue);
    expect(controller.canUndo, isFalse);
    expect(c.read(workspaceProvider).needsReading, isFalse);

    // Save, then away and back: the device exactly as it was.
    await tester.runAsync(controller.save);
    await tester.runAsync(controller.keep);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(await device(tester), before);

    // Read back from the device, it is still what it was saved as.
    late Design again;
    await tester.runAsync(() async {
      again = (await DesignStore(customers: CustomerStore()).load('angled'))!;
    });
    expect(again.savedCategory, 'future_custom_shape');
    expect(jsonEncode(again.toJson()), jsonEncode(shown.toJson()));
  });

  testWidgets('a known design opened after it is edited as ever — the '
      'refusal is the unknown design\'s alone', (tester) async {
    await seed(tester, twoUnknown());
    final c = await toAdam(tester);
    await openCard(tester, 'angled');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openCard(tester, 'door');
    final door = c.read(workspaceProvider).design;
    expect(door.kind, DesignKind.door);
    expect(find.byKey(UnsupportedCategoryNote.noteKey), findsNothing);
    c.read(workspaceProvider.notifier).rename('Front Door');
    await tester.pumpAndSettle();
    expect(c.read(workspaceProvider).design.name, 'Front Door');
  });

  testWidgets('a card of an unknown design offers no Edit information and '
      'no Duplicate — they would write it in this version\'s words', (
    tester,
  ) async {
    await seed(tester, twoUnknown());
    await toAdam(tester);
    expect(find.byKey(CustomerDesignCard.editKey('angled')), findsNothing);
    expect(find.byKey(CustomerDesignCard.editKey('door')), findsOneWidget);
    final more = find.byKey(CustomerDesignCard.moreKey('angled'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('design-action-duplicate')), findsNothing);
    expect(
      find.byKey(const ValueKey('design-action-information')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('design-action-open')), findsOneWidget);
    expect(find.byKey(const ValueKey('design-action-delete')), findsOneWidget);
  });
}
