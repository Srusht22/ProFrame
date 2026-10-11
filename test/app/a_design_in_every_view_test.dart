import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/design_painter.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/screens/start_screen.dart';
import 'package:proframe/app/screens/workspace_bars.dart';
import 'package:proframe/app/screens/workspace_screen.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/app/viewer/model_painter.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'a_customer_s_page_test.dart' as page;
import 'customers_screen_test.dart' as customers;
import 'opening_an_existing_design_test.dart' as existing;
import 'the_designs_screen_test.dart' as screen;

// Adam → Basement Door, and the design as it was saved is the one design
// every view shows:
//
//   Customer → Design → the saved design → Draw / CAD / 3D
//
// Nothing is rebuilt, read again, re-measured or approximated on the way
// in, and no view keeps a geometry of its own: the drawing, the technical
// drawing and the solid are each painted from the very design the
// workspace holds — the same object — and looking at it in all three
// changes nothing that is kept.

const laptop = Size(1280, 860);

/// Adam's Basement Door as `opening_an_existing_design_test` keeps it —
/// drawn, marked, divided inside the opening, glass over panel, every size
/// given — with a measurement drawn on the sheet as well.
Future<void> keepAdam() async {
  final kept = await existing.keepAdam();
  await DesignStore().save(
    kept.door.copyWith(
      dimensions: const [
        DimensionElement(
          id: 'dim-width',
          a: Vec2(0, 2300),
          b: Vec2(1600, 2300),
          statedMm: 1600,
        ),
      ],
    ),
    by: WorkshopRole.owner,
  );
}

Future<String> savedText(WidgetTester tester, String id) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${DesignStore.designKeyPrefix}$id')!;
    }))!;

Future<Map<String, Object?>> everythingKept(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final prefs = await SharedPreferences.getInstance();
      return {for (final key in prefs.getKeys()) key: prefs.get(key)};
    }))!;

Future<void> showView(WidgetTester tester, WorkspaceView view) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ViewTabs),
      matching: find.byIcon(ViewTabs.iconOf(view)),
    ),
  );
  await tester.pumpAndSettle();
}

T painterOf<T extends CustomPainter>(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<T>()
    .single;

String facets(ModelPainter painter) => [
  for (final face in painter.faces)
    [
      face.source.elementId,
      face.source.role.name,
      for (final c in face.corners)
        '${c.x.toStringAsFixed(4)},${c.y.toStringAsFixed(4)}',
    ].join('|'),
].join('\n');

String projected(ProviderContainer c, Design design) {
  final state = c.read(workspaceProvider);
  final mesh = MeshBuilder.build(design, openFraction: state.openFraction);
  return [
    for (final face in state.camera.project(mesh))
      [
        face.source.elementId,
        face.source.role.name,
        for (final corner in face.corners)
          '${corner.x.toStringAsFixed(4)},${corner.y.toStringAsFixed(4)}',
      ].join('|'),
  ].join('\n');
}

// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Adam → Basement Door: the saved design is the one design '
      'Draw, CAD and 3D all show — nothing rebuilt, nothing kept changed', (
    tester,
  ) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: laptop);
    final saved = await savedText(tester, 'basement-door');
    final before = await everythingKept(tester);
    final door = Design.fromJson(jsonDecode(saved) as Map<String, Object?>);
    // There is everything to get wrong.
    expect(door.frame, isNotNull);
    expect(door.openings, hasLength(1));
    expect(door.dividers.where((d) => d.parentId != null), isNotEmpty);
    expect(door.dimensions, hasLength(1));
    expect(door.measured, isNotEmpty);
    expect(door.hardware, isNotEmpty);

    // Customer → Design.
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final open = find
        .byKey(CustomerDesignCard.openKey('basement-door'))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceScreen), findsOneWidget);
    expect(find.byType(StartScreen, skipOffstage: false), findsNothing);

    // The saved design, exactly — not read again from its strokes, not
    // re-measured, not rebuilt.
    final inHand = c.read(workspaceProvider).design;
    expect(jsonEncode(inHand.toJson()), saved);
    expect(c.read(workspaceProvider.notifier).canUndo, isFalse);

    // Draw: painted from that very design.
    expect(c.read(workspaceProvider).view, WorkspaceView.draw);
    expect(identical(painterOf<DesignPainter>(tester).design, inHand), isTrue);

    // CAD: the same object, not a copy made for the drawing.
    await showView(tester, WorkspaceView.plan);
    expect(identical(c.read(workspaceProvider).design, inHand), isTrue);
    expect(identical(painterOf<CadPainter>(tester).design, inHand), isTrue);

    // 3D: the solid built from that design and nothing else, facet for
    // facet the one the saved design builds.
    await showView(tester, WorkspaceView.model);
    expect(identical(c.read(workspaceProvider).design, inHand), isTrue);
    final solid = painterOf<ModelPainter>(tester);
    expect(solid.faces, isNotEmpty);
    expect(facets(solid), projected(c, door));
    final parts = {for (final f in solid.faces) f.source.elementId};
    for (final id in [
      door.frame!.id,
      ...door.dividers.map((d) => d.id),
      door.openings.single.sectionId,
    ]) {
      expect(parts, contains(id), reason: 'the solid builds $id');
    }

    // Back to the drawing, and out: looking changed nothing.
    await showView(tester, WorkspaceView.draw);
    expect(jsonEncode(c.read(workspaceProvider).design.toJson()), saved);
    expect(c.read(workspaceProvider.notifier).canUndo, isFalse);
    await tester.pump(WorkspaceScreen.keepAfter * 2);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerScreen), findsOneWidget);
    expect(await everythingKept(tester), before);
  });

  testWidgets('an edit made in one view is the edit every view shows, and '
      'is what is kept', (tester) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: laptop);
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final open = find
        .byKey(CustomerDesignCard.openKey('basement-door'))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();

    // A glass pane made panel, in CAD.
    await showView(tester, WorkspaceView.plan);
    final opening = c.read(workspaceProvider).design.openings.single;
    final glass = c
        .read(workspaceProvider)
        .design
        .childSectionsOf(opening.sectionId)
        .firstWhere((s) => s.finish.material.isGlazing);
    c
        .read(workspaceProvider.notifier)
        .setFinish(glass.id, PanelColour.white.finish);
    await tester.pumpAndSettle();
    final edited = c.read(workspaceProvider).design;
    expect(identical(painterOf<CadPainter>(tester).design, edited), isTrue);

    await showView(tester, WorkspaceView.model);
    expect(
      facets(painterOf<ModelPainter>(tester)),
      projected(c, edited),
      reason: 'the solid is built from the edited design',
    );
    await showView(tester, WorkspaceView.draw);
    expect(identical(painterOf<DesignPainter>(tester).design, edited), isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(
      await savedText(tester, 'basement-door'),
      jsonEncode(c.read(workspaceProvider).design.toJson()),
    );
  });

  testWidgets('a design with nothing drawn opens as itself in every view, '
      'and no view makes geometry for it', (tester) async {
    await keepAdam();
    final c = await screen.openTheApp(tester, size: laptop);
    final saved = await savedText(tester, 'kitchen-window');
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');
    final open = find
        .byKey(CustomerDesignCard.openKey('kitchen-window'))
        .hitTestable();
    await tester.scrollUntilVisible(
      open,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(jsonEncode(c.read(workspaceProvider).design.toJson()), saved);
    for (final view in WorkspaceView.values) {
      c.read(workspaceProvider.notifier).showView(view);
      await tester.pumpAndSettle();
      final design = c.read(workspaceProvider).design;
      expect(design.frame, isNull, reason: '$view');
      expect(design.sections, isEmpty, reason: '$view');
      expect(jsonEncode(design.toJson()), saved, reason: '$view');
    }
  });
}
