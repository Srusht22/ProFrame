import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/new_design_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'the_designs_screen_test.dart' as screen;

// Adam → Basement Door → Open. The design opens directly, by its id, exactly
// as it was kept — its drawing, geometry, sizes, opening, the line drawn
// inside it and the glass and panel either side — and nothing is asked on the
// way: what it is was said when it was begun and is kept in it. No choice of
// door or window, no new design, no copy.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 24; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 24)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

/// Adam's basement door, made the way a user makes it: drawn on the sheet
/// — an outline, a mullion and a `>` — read; a line drawn inside the
/// opening and read again; glass above that line and a panel below; every
/// size given; and what it is built of already said.
Design basementDoor(Customer adam) {
  final base = Design(
    id: 'basement-door',
    name: 'Basement Door',
    kind: DesignKind.door,
    customer: adam.name,
    customerId: adam.id,
    construction: Construction.both,
    partsAsked: true,
    measured: const {},
    createdAt: DateTime(2026, 3, 1, 9),
    updatedAt: DateTime(2026, 3, 1, 9),
    sketch: Sketch(
      strokes: [
        pen('outline', const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        pen('mullion', const [Vec2(1000, 0), Vec2(1000, 2100)]),
        pen('mark', const [Vec2(300, 800), Vec2(600, 1050), Vec2(300, 1300)]),
      ],
    ),
  );
  final marked = SketchInterpreter.interpret(base).design;
  final divided = SketchInterpreter.interpret(
    marked.copyWith(
      sketch: Sketch(
        strokes: [
          ...marked.sketch.strokes,
          pen('inside', const [Vec2(200, 1400), Vec2(700, 1400)]),
        ],
      ),
    ),
  ).design;
  final panes = divided.childSectionsOf(divided.openings.single.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  final filled = Infill.fill(divided, {
    panes.first.id: GlassLook.frosted.finish,
    panes.last.id: PanelColour.brown.finish,
  });
  final sized = Measurements.apply(filled, {
    for (final m in Measurements.of(filled))
      if (m.asked) m.key: m.currentMm(filled),
  }).design;
  return sized.copyWith(updatedAt: DateTime(2026, 3, 1, 9, 30));
}

/// Adam, his basement door and his kitchen window, kept; and Sara with a
/// design of her own.
Future<({Customer adam, Design door, Design window})> keepAdam() async {
  final people = CustomerStore();
  final store = DesignStore(customers: people);
  final adam = await people.create(
    name: 'Adam',
    phone: '+964 750 123 4567',
    now: DateTime(2026, 3, 1, 8),
  );
  final sara = await people.create(
    name: 'Sara',
    now: DateTime(2026, 3, 1, 8, 5),
  );
  final door = await store.save(basementDoor(adam));
  final window = await store.save(
    Design.empty(
      id: 'kitchen-window',
      kind: DesignKind.window,
      name: 'Kitchen Window',
      customerId: adam.id,
      now: DateTime(2026, 3, 1, 10),
    ),
  );
  await store.save(
    Design.empty(
      id: 'sara-door',
      kind: DesignKind.door,
      name: 'Garden Door',
      customerId: sara.id,
      now: DateTime(2026, 3, 1, 11),
    ),
  );
  return (adam: adam, door: door, window: window);
}

Future<String> storedJson(WidgetTester tester, String id) async =>
    jsonEncode((await tester.runAsync(() => DesignStore().load(id)))!.toJson());

/// Nothing that begins a design is anywhere on the navigator, on screen or
/// underneath it.
void noNewDesignFlow() {
  expect(find.byType(StartScreen, skipOffstage: false), findsNothing);
  expect(find.byType(NewDesignScreen, skipOffstage: false), findsNothing);
  expect(find.text('Choose your design', skipOffstage: false), findsNothing);
  expect(
    find.byKey(const ValueKey('construction-panel'), skipOffstage: false),
    findsNothing,
    reason: 'what it is built of was said when it was begun',
  );
}

Future<void> toAdam(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  await screen.openTheApp(tester, size: size);
  await customers.toCustomers(tester);
  await page.openCustomer(tester, 'Adam');
}

/// Brings the card's Open into reach, clear of anything standing over it,
/// and presses it.
Future<void> pressOpen(WidgetTester tester, String id) async {
  // From the top of the page: the customer's money stands under the cards,
  // so coming back from one can leave the page scrolled past the first.
  tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position
      .jumpTo(0);
  await tester.pumpAndSettle();
  final open = find.byKey(CustomerDesignCard.openKey(id)).hitTestable();
  await tester.scrollUntilVisible(
    open,
    100,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(open);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Adam → Basement Door → Open: the workspace, with exactly the '
      'design that was kept, and no category asked', (tester) async {
    final kept = await keepAdam();
    final c = await screen.openTheApp(tester, size: const Size(390, 844));
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final before = await page.keptDesigns(tester);
    final keptJson = await storedJson(tester, kept.door.id);

    await pressOpen(tester, kept.door.id);
    await tester.pumpAndSettle();

    // Straight into the design, and nothing that begins one.
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    noNewDesignFlow();

    // The exact design, by its id: the kept file, byte for byte.
    final open = c.read(workspaceProvider).design;
    expect(open.id, kept.door.id);
    expect(jsonEncode(open.toJson()), keptJson);
    // Its category is the one it was begun as.
    expect(open.kind, DesignKind.door);
    // Nothing is waiting to be read again.
    expect(c.read(workspaceProvider).needsReading, isFalse);

    // Nothing new was made, and nothing copied.
    expect(await page.keptDesigns(tester), before);
  });

  testWidgets('everything the design holds comes back with it', (tester) async {
    final kept = await keepAdam();
    final door = kept.door;
    // What is being checked is there to lose.
    expect(door.frame, isNotNull);
    expect(door.openings, hasLength(1));
    final inside = door.dividers.where((d) => d.parentId != null).toList();
    expect(inside, hasLength(1));
    expect(door.measured, isNotEmpty);

    await toAdam(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(CustomerScreen)),
    );
    await pressOpen(tester, door.id);
    await tester.pumpAndSettle();
    final open = c.read(workspaceProvider).design;

    // Geometry and sizes.
    expect(jsonEncode(open.frame!.toJson()), jsonEncode(door.frame!.toJson()));
    expect(open.measured, door.measured);
    expect(open.widthMm, door.widthMm);
    expect(open.heightMm, door.heightMm);
    // The drawing itself.
    expect(jsonEncode(open.sketch.toJson()), jsonEncode(door.sketch.toJson()));
    // The opening, and the line drawn inside it — still its own.
    expect(
      jsonEncode([for (final o in open.openings) o.toJson()]),
      jsonEncode([for (final o in door.openings) o.toJson()]),
    );
    final line = open.dividers.singleWhere((d) => d.id == inside.single.id);
    expect(line.parentId, door.openings.single.id);
    expect(jsonEncode(line.toJson()), jsonEncode(inside.single.toJson()));
    // Glass above it and panel below, as they were chosen.
    final panes = open.childSectionsOf(open.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
    expect(GlassLook.of(panes.first.finish), GlassLook.frosted);
    expect(PanelColour.of(panes.last.finish), PanelColour.brown);
    // Its ironmongery, and what it is built of.
    expect(
      jsonEncode([for (final h in open.hardware) h.toJson()]),
      jsonEncode([for (final h in door.hardware) h.toJson()]),
    );
    expect(open.construction, door.construction);
    expect(open.customerId, kept.adam.id);
    noNewDesignFlow();
  });

  testWidgets('tapping the card itself opens it the same way', (tester) async {
    final kept = await keepAdam();
    await toAdam(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(CustomerScreen)),
    );
    final name = find.text('Kitchen Window').hitTestable();
    await tester.scrollUntilVisible(
      name,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(name);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    noNewDesignFlow();
    final open = c.read(workspaceProvider).design;
    expect(open.id, kept.window.id);
    expect(open.kind, DesignKind.window);
    expect(jsonEncode(open.toJson()), await storedJson(tester, kept.window.id));
  });

  testWidgets('each card opens its own design, and coming back changes '
      'nothing and makes nothing', (tester) async {
    final kept = await keepAdam();
    await toAdam(tester);
    final c = ProviderScope.containerOf(
      tester.element(find.byType(CustomerScreen)),
    );
    final before = await page.keptDesigns(tester);
    final stored = {
      for (final id in [kept.door.id, kept.window.id])
        id: await storedJson(tester, id),
    };

    for (final id in [kept.window.id, kept.door.id, kept.window.id]) {
      await pressOpen(tester, id);
      await tester.pumpAndSettle();
      expect(c.read(workspaceProvider).design.id, id);
      noNewDesignFlow();

      // Back, without touching anything: to Adam's page, with the design
      // kept exactly as it was and no other made.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerScreen), findsOneWidget);
      expect(await page.keptDesigns(tester), before);
      expect(await storedJson(tester, id), stored[id]);
    }
    // Still Adam's two designs, no more.
    final ofAdam = await tester.runAsync(
      () => DesignStore().page(customerId: kept.adam.id),
    );
    expect(ofAdam!.items.map((s) => s.id).toSet(), {
      kept.door.id,
      kept.window.id,
    });
  });

  testWidgets('a quick second tap opens the design once', (tester) async {
    final kept = await keepAdam();
    await toAdam(tester);
    await pressOpen(tester, kept.door.id);
    final open = find.byKey(CustomerDesignCard.openKey(kept.door.id));
    await tester.tap(open, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen, skipOffstage: false), findsOneWidget);
    // One back is all it takes to be at Adam's again.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
  });

  testWidgets('a design no longer kept says so, and opens nothing', (
    tester,
  ) async {
    final kept = await keepAdam();
    await toAdam(tester);
    // Removed elsewhere while Adam's page still shows its card.
    final c = ProviderScope.containerOf(
      tester.element(find.byType(CustomerScreen)),
    );
    await tester.runAsync(
      () => c.read(designStoreProvider).remove(kept.window.id),
    );
    await pressOpen(tester, kept.window.id);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsNothing);
    expect(find.text('Kitchen Window could not be opened.'), findsOneWidget);
    noNewDesignFlow();
  });
}
