import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/customer_screen.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/customer.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/a_customer_s_page_test.dart' as page;
import 'app/cad_is_the_canonical_geometry_test.dart' as cad;
import 'app/customers_screen_test.dart' as customers;
import 'app/designs_are_kept_for_their_customer_test.dart' as kept;
import 'app/new_design.dart';
import 'app/opening_an_existing_design_test.dart' show pressOpen;
import 'app/pause_and_take_it_back_test.dart' show chevron;
import 'app/persistence_and_old_designs_test.dart'
    show fieldsOf, putQuestionsAway;
import 'app/the_designs_screen_test.dart' as screen;
import 'domain/an_under_stair_design_test.dart' as under;
import 'domain/geometry_normalizer_test.dart' show pen;

// The whole of ProFrame, end to end, the way the user uses it:
//
//   Drawing → raw geometry → normalisation / validation → canonical
//   geometry → 2D, CAD, 3D → save → reload
//
// Two designs for Adam, made through the screens and drawn on the sheet:
//
//   an imperfect door      every corner a little out, a fanlight transom
//                          stopped short of the far jamb, a `>` below it,
//                          then a line drawn short inside the leaf — the
//                          door corrected square, both lines completed
//   a window under a stair drawn by hand, every side a little out — the
//                          slope kept, the wobble taken out — a `>` under
//                          the slope and a line drawn short inside it
//
// each made frosted glass over a brown panel in an anthracite aluminium
// frame, with silver handles and black hinges. At every stage — read, then
// saved, then the app closed and opened again from the device and the
// design opened from its card — the geometry, dimensions, openings,
// dividers, glass, panel, frame, handles, hinges and materials are checked,
// the technical drawing is checked on its pixels against the geometry, and
// the solid on its facets. Then the features round them: the customer's
// page, several designs, their names, the most recent first, filtering by
// category, and another customer who sees none of Adam's.

const laptop = Size(1280, 860);

const anthracite = Finish(colour: 0xFF383E42, material: MaterialKind.aluminium);
const silver = Finish(colour: 0xFFC3C7C9, material: MaterialKind.steel);
const black = Finish(colour: 0xFF1C1C1C, material: MaterialKind.steel);

/// The door as a hand draws it: the head rising 12 mm, the hinge side
/// leaning 30 mm out, the sill dipping; a transom 45 cm down drawn from the
/// left jamb and lifted 15 cm short of the right; a `>` in the leaf.
final doorSheet = [
  pen('outline', const [
    Vec2(0, 0),
    Vec2(1000, 12),
    Vec2(1030, 2100),
    Vec2(-10, 2094),
    Vec2(0, 0),
  ]),
  pen('transom', const [Vec2(0, 450), Vec2(850, 450)]),
  pen('mark', chevron(const Vec2(500, 1300))),
];

/// The window under the stair, drawn by hand.
final stairSheet = under.drawn(outline: under.byHand).sketch.strokes;

/// The slope of the stair as drawn exactly, in degrees.
final stairSlope = _degrees(Segment(under.stair[1], under.stair[2]));

double _degrees(Segment s) =>
    math.atan2((s.b.y - s.a.y).abs(), (s.b.x - s.a.x).abs()) * 180 / math.pi;

Segment slopeOf(Polygon outline) => outline.edges.singleWhere(
  (e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1,
);

bool square(Polygon p) =>
    p.corners.length == 4 &&
    p.edges.every((e) => e.a.x == e.b.x || e.a.y == e.b.y);

bool within(Polygon shape, Vec2 p, {double slack = 0.5}) =>
    shape.contains(p) || shape.edges.any((e) => e.distanceTo(p) <= slack);

double toEdge(Polygon shape, Vec2 p) =>
    shape.edges.map((e) => e.distanceTo(p)).reduce(math.min);

Vec2 flat(Vec3 p) => Vec2(p.x, p.y);

String textOf(Design d) => jsonEncode(d.toJson());

WorkspaceController controllerOf(ProviderContainer c) =>
    c.read(workspaceProvider.notifier);

/// Adds [strokes] to the sheet and reads it, as **Read** does — saying
/// what each new leaf is, where the design leaves that to the user, and
/// putting away anything else the screens ask.
Future<void> drawAndRead(
  WidgetTester tester,
  ProviderContainer c,
  List<Stroke> strokes, {
  DesignKind leaf = DesignKind.window,
}) async {
  final controller = controllerOf(c);
  final design = controller.state.design;
  controller.state = controller.state.copyWith(
    design: design.copyWith(
      sketch: Sketch(strokes: [...design.sketch.strokes, ...strokes]),
    ),
  );
  controller.readDrawing();
  for (final o in controller.state.design.openings) {
    if (o.kind == null && design.kind.leafDefault == null) {
      controller.setOpeningKind(o.id, leaf);
    }
  }
  await tester.pumpAndSettle();
  await putQuestionsAway(tester);
}

/// The one opening, its region, and a line drawn on the sheet inside it,
/// 40 cm up from its sill and stopped 12 cm short of each side.
Stroke aLineInside(Design d) {
  final region = d.sectionById(d.openings.single.sectionId)!.outline;
  final y = region.bottom - 400;
  final (left, right) = (
    OpeningHardware.stileOf(region, OpeningEdge.left)!,
    OpeningHardware.stileOf(region, OpeningEdge.right)!,
  );
  double xAt(Segment s) =>
      s.a.x + (s.b.x - s.a.x) * ((y - s.a.y) / (s.b.y - s.a.y));
  return pen('inside', [Vec2(xAt(left) + 120, y), Vec2(xAt(right) - 120, y)]);
}

/// Frosted glass over a brown panel in the opening, an anthracite
/// aluminium frame, silver handles and black hinges.
void finish(ProviderContainer c) {
  final controller = controllerOf(c);
  var d = controller.state.design;
  final panes = d.childSectionsOf(d.openings.single.sectionId)
    ..sort((a, b) => a.outline.centroid.y.compareTo(b.outline.centroid.y));
  d = Infill.fill(d, {
    panes.first.id: GlassLook.frosted.finish,
    panes.last.id: PanelColour.brown.finish,
  });
  d = d.withElement(d.frame!.copyWith(finish: anthracite));
  d = d.copyWith(
    hardware: [
      for (final h in d.hardware)
        h.copyWith(finish: h.kind == HardwareKind.hinge ? black : silver),
    ],
  );
  controller.state = controller.state.copyWith(design: d);
}

/// Every part of the pipeline, held on [d].
Future<void> expectThePipeline(
  WidgetTester tester,
  Design d, {
  required bool angled,
  required String stage,
}) async {
  final what = '${d.name}, $stage';
  final frame = d.frame!;
  final outline = frame.outline;
  final geometry = DesignGeometry.of(d);

  // Geometry: corrected square, or the slope kept.
  if (angled) {
    expect(d.kind, DesignKind.angled, reason: what);
    expect(outline.corners, hasLength(5), reason: what);
    expect(_degrees(slopeOf(outline)), closeTo(stairSlope, 0.6), reason: what);
    for (final c in under.stair.take(5)) {
      expect(
        outline.corners.map((p) => p.distanceTo(c)).reduce(math.min),
        lessThan(12),
        reason: '$what: a corner where it was drawn, near $c',
      );
    }
  } else {
    expect(square(outline), isTrue, reason: '$what: corrected square');
  }

  // The frame, its material.
  expect(jsonEncode(frame.finish.toJson()), jsonEncode(anthracite.toJson()));

  // Openings: one, on a region holding its mark — never the frame.
  final opening = d.openings.single;
  final region = d.sectionById(opening.sectionId)!.outline;
  expect(region.contains(opening.markAt!), isTrue, reason: what);
  expect(d.topLevelSections.length, greaterThanOrEqualTo(2));

  // Dividers: the design's own reach the frame, and the line drawn
  // inside the leaf is the leaf's, spanning it.
  for (final bar in d.topLevelDividers) {
    for (final end in [bar.segment.a, bar.segment.b]) {
      expect(
        toEdge(outline, end),
        lessThan(frame.profileMm + 1),
        reason: '$what: ${bar.id} reaches the frame at $end',
      );
    }
  }
  final inside = d.dividers.singleWhere((b) => b.parentId != null);
  expect(d.openingHolding(inside.parentId)?.id, opening.id, reason: what);
  for (final end in [inside.segment.a, inside.segment.b]) {
    expect(toEdge(region, end), lessThan(1), reason: '$what: completed');
  }

  // Glass above, panel below, as said.
  final panes = d.childSectionsOf(opening.sectionId)
    ..sort((a, b) => a.outline.centroid.y.compareTo(b.outline.centroid.y));
  expect(panes, hasLength(2), reason: what);
  expect(
    jsonEncode(panes.first.finish.toJson()),
    jsonEncode(GlassLook.frosted.finish.toJson()),
  );
  expect(
    jsonEncode(panes.last.finish.toJson()),
    jsonEncode(PanelColour.brown.finish.toJson()),
  );
  if (angled) {
    expect(
      geometry
          .fillOf(panes.first)
          .edges
          .any((e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1),
      isTrue,
      reason: '$what: the glass under the slope is raked',
    );
  }

  // Handles and hinges: the opening's, on its leaf, hinges down the hinge
  // stile and the handle on the other, each in its finish.
  final edge = opening.mechanism.hingeEdge!;
  final hingeStile = OpeningHardware.stileOf(region, edge)!;
  final pieces = [
    for (final h in d.hardware)
      if (d.openingHolding(h.parentId)?.id == opening.id) h,
  ];
  final hinges = [
    for (final h in pieces)
      if (h.kind == HardwareKind.hinge) h,
  ];
  final handles = [
    for (final h in pieces)
      if (h.kind.isHandle) h,
  ];
  expect(hinges.length, greaterThanOrEqualTo(2), reason: what);
  expect(handles, hasLength(1), reason: what);
  for (final h in hinges) {
    expect(hingeStile.distanceTo(h.at), lessThan(1e-6), reason: what);
    expect(jsonEncode(h.finish.toJson()), jsonEncode(black.toJson()));
  }
  expect(within(region, handles.single.at), isTrue, reason: what);
  expect(
    jsonEncode(handles.single.finish.toJson()),
    jsonEncode(silver.toJson()),
  );
  if (!angled) {
    expect(
      pieces.any((h) => h.kind == HardwareKind.lock),
      isTrue,
      reason: '$what: a door has its lock',
    );
  }

  // Dimensions: every figure is the frame, a side or a section there is.
  for (final chain in DimensionChains.of(d)) {
    for (final run in chain.runs) {
      if (run.sectionId != null) {
        expect(d.sectionById(run.sectionId!), isNotNull, reason: what);
      }
    }
  }
  final overall = [
    for (final chain in DimensionChains.of(d))
      for (final run in chain.runs)
        if (run.of == ChainRunOf.overall) run.toMm - run.fromMm,
  ];
  expect(overall, contains(closeTo(outline.width, 1e-6)), reason: what);
  expect(overall, contains(closeTo(outline.height, 1e-6)), reason: what);

  // CAD: every line of the outline, the daylight and every bar is inked
  // where the geometry puts it, and nothing outside the outline.
  final view = cad.viewOf(d);
  final rgba = (await tester.runAsync(() => cad.paint(d, cad.geometryOnly)))!;
  final paper = cad.paperOf(rgba);
  final covered = [
    for (final piece in d.hardware)
      if (!d.isConcealed(piece))
        for (final shape in geometry.hardwareOf(piece))
          if (!shape.isEmpty) view.pathOf(shape).getBounds().inflate(3),
  ];
  for (final e in [
    ...frame.lines.outside,
    ...frame.lines.daylight,
    for (final bar in d.dividers) ...geometry.barBody(bar).edges,
  ]) {
    for (final p in cad.along(view, e)) {
      if (covered.any((r) => r.contains(p))) continue;
      expect(cad.inkNear(rgba, paper, p), isTrue, reason: '$what: CAD at $p');
    }
  }
  var stray = 0;
  for (var y = 0; y < 900; y += 3) {
    for (var x = 0; x < 900; x += 3) {
      if (!cad.inked(rgba, paper, x, y)) continue;
      if (cad.outside(view, outline, Offset(x.toDouble(), y.toDouble())) > 3) {
        stray++;
      }
    }
  }
  expect(stray, 0, reason: '$what: CAD ink outside the outline');

  // 3D: nothing outside the outline; the frame on every corner of it; the
  // glass glazing and the panel brown and opaque; every part the drawing
  // has, and nothing it has not.
  final mesh = MeshBuilder.build(d);
  for (final f in mesh.facets) {
    for (final c in f.corners) {
      expect(within(outline, flat(c)), isTrue, reason: '$what: 3D at $c');
    }
  }
  final frameFaces = mesh.facets.where((f) => f.elementId == frame.id);
  for (final c in outline.corners) {
    expect(
      frameFaces.any((f) => f.corners.any((p) => flat(p).distanceTo(c) < 0.5)),
      isTrue,
      reason: '$what: the solid frame has no corner at $c',
    );
  }
  expect(
    mesh.facets.where(
      (f) => f.elementId == panes.first.id && f.role == FacetRole.glazing,
    ),
    isNotEmpty,
  );
  final panel = mesh.facets.where((f) => f.elementId == panes.last.id);
  expect(panel.every((f) => f.role == FacetRole.panel), isTrue);
  expect(
    panel.every((f) => f.colour == PanelColour.brown.finish.colour),
    isTrue,
  );
  for (final h in pieces) {
    expect(mesh.facets.any((f) => f.elementId == h.id), isTrue, reason: h.id);
  }
}

/// From the customer's page now open: New Design, called [name], of
/// [card].
Future<void> beginDesign(WidgetTester tester, String name, String card) async {
  await tester.tap(
    find.byKey(CustomerScreen.newDesignButton).hitTestable().first,
  );
  await tester.pumpAndSettle();
  await nameTheDesign(tester, name);
  await chooseDesign(tester, card);
}

Future<void> saveAndGoBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Save'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Back'));
  await tester.pumpAndSettle();
  expect(find.byType(CustomerScreen), findsOneWidget);
}

Future<Customer> customerNamed(WidgetTester tester, String name) async =>
    (await tester.runAsync(() => CustomerStore().named(name)))!;

Future<List<String>> designsOf(WidgetTester tester, Customer who) async =>
    (await tester.runAsync(() async {
      final found = await DesignStore().page(customerId: who.id, limit: 50);
      return [for (final s in found.items) s.id];
    }))!;

/// The ids of the cards on the customer's page now open, as shown.
List<String> cardsShown(WidgetTester tester) => screen.cardsShown(tester);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the whole pipeline, for an imperfect door and a window under '
      'a stair, and everything round them', (tester) async {
    // ------------------------------------------------------ the standard
    var c = await screen.openTheApp(tester, size: laptop);
    await kept.newCustomer(tester, 'Adam');
    await beginDesign(tester, 'Front Door', 'DOOR');
    await drawAndRead(tester, c, doorSheet);

    // The drawing corrected: square, and the transom stopped short
    // completed to the far jamb.
    var d = controllerOf(c).state.design;
    expect(square(d.frame!.outline), isTrue, reason: 'corrected');
    final transom = d.dividers.singleWhere((b) => b.fromStrokeId == 'transom');
    expect(transom.segment.a.y, closeTo(transom.segment.b.y, 1e-9));
    expect(
      math.max(transom.segment.a.x, transom.segment.b.x),
      greaterThan(d.frame!.outline.right - d.frame!.profileMm - 1),
      reason: 'the line stopped short completed to the jamb',
    );
    expect(d.openings, hasLength(1), reason: 'the opening the mark made');

    // A line drawn short inside the leaf: the leaf's, completed across it.
    await drawAndRead(tester, c, [aLineInside(d)]);
    finish(c);
    await tester.pumpAndSettle();
    final door = controllerOf(c).state.design;
    await expectThePipeline(tester, door, angled: false, stage: 'drawn');
    await saveAndGoBack(tester);

    // -------------------------------------------------------- the angled
    await beginDesign(tester, 'Under-stair Window', 'ANGLED / ASYMMETRICAL');
    await drawAndRead(tester, c, stairSheet);
    d = controllerOf(c).state.design;
    expect(d.frame!.outline.corners, hasLength(5), reason: 'kept angled');
    await drawAndRead(tester, c, [aLineInside(d)]);
    finish(c);
    await tester.pumpAndSettle();
    final window = controllerOf(c).state.design;
    await expectThePipeline(tester, window, angled: true, stage: 'drawn');
    await saveAndGoBack(tester);

    // A second customer, with a design of her own.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await kept.newCustomer(tester, 'Sara');
    await beginDesign(tester, 'Kitchen Window', 'WINDOW');
    await saveAndGoBack(tester);

    // ------------------------------------------------- close and reopen
    c = await kept.reopenTheApp(tester);
    final adam = await customerNamed(tester, 'Adam');
    final sara = await customerNamed(tester, 'Sara');

    // The customer/design relationship, on the device.
    expect((await designsOf(tester, adam)).toSet(), {door.id, window.id});
    expect(await designsOf(tester, sara), hasLength(1));
    for (final kept in [door, window]) {
      expect(kept.customerId, adam.id);
    }

    // Each opened from its card: exactly as saved, and the pipeline holds.
    for (final (saved, angled) in [(door, false), (window, true)]) {
      await customers.toCustomers(tester);
      await page.openCustomer(tester, 'Adam');
      await pressOpen(tester, saved.id);
      await tester.pumpAndSettle();
      await putQuestionsAway(tester);
      final opened = controllerOf(c).state.design;
      expect(textOf(opened), textOf(saved), reason: '${saved.name} reopened');
      final before = fieldsOf(saved), after = fieldsOf(opened);
      for (final field in before.keys) {
        expect(after[field], before[field], reason: '${saved.name}: $field');
      }
      await expectThePipeline(
        tester,
        opened,
        angled: angled,
        stage: 'reopened',
      );
      if (angled) {
        expect(
          _degrees(slopeOf(opened.frame!.outline)),
          closeTo(_degrees(slopeOf(saved.frame!.outline)), 1e-9),
          reason: 'the same slope',
        );
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    // ------------------------------------------- the features round them
    await customers.toCustomers(tester);
    await page.openCustomer(tester, 'Adam');

    // Adam's page: both his designs, by name, the most recent first — and
    // nothing of Sara's.
    expect(cardsShown(tester), [window.id, door.id]);
    expect(find.text('Front Door'), findsWidgets);
    expect(find.text('Under-stair Window'), findsWidgets);
    expect(find.text('Kitchen Window'), findsNothing);

    // Filtered by category: each chip shows its own.
    for (final (kind, ids) in [
      (DesignKind.door, [door.id]),
      (DesignKind.angled, [window.id]),
      (null, [window.id, door.id]),
    ]) {
      await tester.tap(find.byKey(CustomerScreen.filterKey(kind)));
      await tester.pumpAndSettle();
      expect(cardsShown(tester), ids, reason: kind?.name ?? 'all');
    }
    expect(
      find.byKey(CustomerScreen.filterKey(DesignKind.window)),
      findsNothing,
    );

    // An edit brings a design to the top.
    await pressOpen(tester, door.id);
    await tester.pumpAndSettle();
    await putQuestionsAway(tester);
    final controller = controllerOf(c);
    final now = controller.state.design;
    controller.state = controller.state.copyWith(
      design: now.withElement(
        now.frame!.copyWith(
          finish: const Finish(
            colour: 0xFF101010,
            material: MaterialKind.aluminium,
          ),
        ),
      ),
    );
    await saveAndGoBack(tester);
    expect(cardsShown(tester), [door.id, window.id], reason: 'most recent');

    // Sara's page: hers alone.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await page.openCustomer(tester, 'Sara');
    expect(cardsShown(tester), hasLength(1));
    expect(find.text('Kitchen Window'), findsWidgets);
    expect(find.text('Front Door'), findsNothing);
  });
}
