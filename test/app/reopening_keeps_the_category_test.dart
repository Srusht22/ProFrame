import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/screens/normalized_note.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/customer_store.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/an_under_stair_design_test.dart' as under;
import '../domain/the_solid_is_the_canonical_geometry_test.dart' as solid;
import 'a_customer_s_page_test.dart' as page;
import 'category_behaviour_is_clear_test.dart' show leaningWindow;
import 'customers_screen_test.dart' as customers;
import 'opening_an_existing_design_test.dart' show pressOpen;
import 'pause_and_take_it_back_test.dart' as sheet;
import 'the_designs_screen_test.dart' as screen;

// The category is kept in the design, and it goes on deciding how the
// geometry behaves after the design is opened again.
//
// Door, Window, Sliding and Door & window are standard; Angled /
// Asymmetrical is angled. Each is kept, read back and opened exactly as it
// was — nothing about opening a design reads it, squares it or rebuilds it,
// so an angled design is never made a rectangle by being opened. Read again
// afterwards, each is read as its own category: a standard one comes back
// the same square design, an angled one the same raked one. A line drawn on
// the sheet of a reopened design is read by the same category: squared in a
// standard design, kept at its slope in an angled one.
//
// Category conversion does not exist — a design's category is shown on its
// information form and is not changeable, because everything drawn in it was
// drawn in it — so there is nothing to warn about and nothing is added.

/// The hand-drawn window with a leaning side, read as [kind]: squared in
/// every standard category.
Design standardOf(DesignKind kind) => solid.said(
  solid.read(
    Design.empty(id: 'standard-${kind.name}', kind: kind).copyWith(
      sketch: Sketch(
        strokes: [
          ...leaningWindow().strokes,
          sheet.pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
          sheet.pen('mark', sheet.chevron(const Vec2(300, 1000))),
        ],
      ),
    ),
  ),
  kind.leafDefault ?? DesignKind.window,
);

/// Every design kept and opened again: the four standard categories, two
/// of them divided and furnished, and two angled ones.
final designs = <String, Design Function()>{
  'a door': solid.door,
  'a window': solid.window,
  'a sliding design': () => standardOf(DesignKind.sliding),
  'a door & window design': () => standardOf(DesignKind.both),
  'an angled window': solid.angledWindow,
  'a window under a stair': under.built,
};

String textOf(Design d) => jsonEncode(d.toJson());

bool isRectangle(Polygon p) =>
    p.corners.length == 4 &&
    p.edges.every((e) => e.a.x == e.b.x || e.a.y == e.b.y);

bool raked(Polygon p) =>
    p.edges.any((e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1);

void expectSameShape(Polygon a, Polygon b, String what) {
  expect(a.corners, hasLength(b.corners.length), reason: what);
  for (var i = 0; i < a.corners.length; i++) {
    expect(
      a.corners[i].distanceTo(b.corners[i]),
      lessThan(1e-6),
      reason: '$what: ${a.corners[i]} against ${b.corners[i]}',
    );
  }
}

/// The geometry of [after] is the geometry of [before]: the frame, every
/// bar, every section, every opening, every piece of ironmongery and every
/// figure, and the category.
void expectSameGeometry(Design before, Design after, String name) {
  expect(after.kind, before.kind, reason: name);
  expectSameShape(after.frame!.outline, before.frame!.outline, '$name frame');
  expectSameShape(
    after.frame!.innerOutline,
    before.frame!.innerOutline,
    '$name daylight',
  );
  expect(after.dividers, hasLength(before.dividers.length), reason: name);
  for (final bar in before.dividers) {
    final same = after.dividers.firstWhere(
      (b) => b.id == bar.id,
      orElse: () => after.dividers.firstWhere(
        (b) =>
            b.segment.a.distanceTo(bar.segment.a) < 1e-6 &&
            b.segment.b.distanceTo(bar.segment.b) < 1e-6,
      ),
    );
    expect(same.segment.a.distanceTo(bar.segment.a), lessThan(1e-6));
    expect(same.segment.b.distanceTo(bar.segment.b), lessThan(1e-6));
    expect(same.parentId == null, bar.parentId == null, reason: bar.id);
  }
  List<Polygon> outlines(Design d) =>
      [for (final s in d.sections) s.outline]..sort((a, b) {
        final c = a.centroid.y.compareTo(b.centroid.y);
        return c != 0 ? c : a.centroid.x.compareTo(b.centroid.x);
      });
  final was = outlines(before), now = outlines(after);
  expect(now, hasLength(was.length), reason: '$name sections');
  for (var i = 0; i < was.length; i++) {
    expectSameShape(now[i], was[i], '$name section $i');
  }
  expect(after.openings, hasLength(before.openings.length), reason: name);
  for (final o in before.openings) {
    final same = after.openings.singleWhere((x) => x.id == o.id);
    expect(same.mechanism, o.mechanism);
    expectSameShape(
      after.sectionById(same.sectionId)!.outline,
      before.sectionById(o.sectionId)!.outline,
      '$name ${o.id}',
    );
  }
  expect(
    {for (final h in after.hardware) '${h.id} ${h.at}'},
    {for (final h in before.hardware) '${h.id} ${h.at}'},
    reason: '$name ironmongery',
  );
  expect(
    [
      for (final c in DimensionChains.of(after))
        for (final r in c.runs) '${r.of.name} ${r.fromMm} ${r.toMm}',
    ],
    [
      for (final c in DimensionChains.of(before))
        for (final r in c.runs) '${r.of.name} ${r.fromMm} ${r.toMm}',
    ],
    reason: '$name figures',
  );
}

/// The solid, face by face.
List<String> facetsOf(Mesh mesh) => [
  for (final f in mesh.facets)
    '${f.elementId} ${f.role.name} '
        '${[for (final c in f.corners) '${c.x.toStringAsFixed(6)},${c.y.toStringAsFixed(6)},${c.z.toStringAsFixed(6)}'].join(' ')}',
];

/// [d] kept for Adam, under its own id as its name.
Future<Design> keep(Design d) async {
  final people = CustomerStore();
  final adam = await people.obtain('Adam');
  return DesignStore(customers: people).save(
    d.copyWith(customer: adam.name, customerId: adam.id, name: d.id),
  );
}

Future<Design> reopen(String id) async => (await DesignStore().load(id))!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('kept and opened again', () {
    for (final MapEntry(key: name, value: make) in designs.entries) {
      test('$name: read back exactly as kept, and opened without being '
          'read, squared or rebuilt', () async {
        final kept = await keep(make());
        final angled = kept.kind == DesignKind.angled;
        expect(
          raked(kept.frame!.outline),
          angled,
          reason: '$name is ${angled ? 'raked' : 'square'} as kept',
        );
        if (!angled) expect(isRectangle(kept.frame!.outline), isTrue);

        final loaded = await reopen(kept.id);
        expect(textOf(loaded), textOf(kept), reason: name);
        expectSameGeometry(kept, loaded, name);
        expect(
          facetsOf(MeshBuilder.build(loaded)),
          facetsOf(MeshBuilder.build(kept)),
          reason: '$name: the same solid',
        );

        // Opened in the workspace: that design, and nothing done to it.
        final c = ProviderContainer();
        addTearDown(c.dispose);
        c.read(workspaceProvider.notifier).openDesign(loaded);
        final state = c.read(workspaceProvider);
        expect(identical(state.design, loaded), isTrue);
        expect(state.needsReading, isFalse);
        expect(textOf(state.design), textOf(kept));
        expect(state.normalizedNotice, 0);
        expect(raked(state.design.frame!.outline), angled);
      });

      test('$name: read again after it is opened, it is read as its own '
          'category — the same design, square or raked as kept', () async {
        final kept = await keep(make());
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final controller = c.read(workspaceProvider.notifier);
        controller.openDesign(await reopen(kept.id));
        controller.readDrawing();
        final read = c.read(workspaceProvider).design;
        expectSameGeometry(kept, read, name);
        expect(raked(read.frame!.outline), kept.kind == DesignKind.angled);
        // Nothing was straightened that had not been already, so nothing
        // is said about it.
        expect(c.read(workspaceProvider).normalizedNotice, 0);
      });

      test('$name: a line drawn on the sheet of the reopened design is read '
          'by the same category', () async {
        final kept = await keep(make());
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final controller = c.read(workspaceProvider.notifier);
        final opened = await reopen(kept.id);
        controller.openDesign(opened);

        // An upright drawn from the head to the sill most of the way
        // across, two degrees out of plumb: a wobble in a standard design,
        // a slope the user drew in an angled one.
        final outline = opened.frame!.outline;
        final x = outline.left + outline.width * 0.85;
        final (top, bottom) = OpeningHardware.coverAt(outline, x: x)!;
        final lean = (bottom - top) * math.tan(2 * math.pi / 180);
        controller.state = controller.state.copyWith(
          design: opened.copyWith(
            sketch: Sketch(
              strokes: [
                ...opened.sketch.strokes,
                sheet.pen('upright', [
                  Vec2(x - lean / 2, top),
                  Vec2(x + lean / 2, bottom),
                ]),
              ],
            ),
          ),
        );
        controller.readDrawing();
        final read = c.read(workspaceProvider).design;
        final bar = read.dividers.singleWhere(
          (d) => d.fromStrokeId == 'upright',
        );
        if (kept.kind == DesignKind.angled) {
          expect(
            (bar.segment.a.x - bar.segment.b.x).abs(),
            greaterThan(lean / 2),
            reason: '$name: kept at the slope it was drawn',
          );
        } else {
          expect(
            bar.segment.a.x,
            closeTo(bar.segment.b.x, 1e-9),
            reason: '$name: straightened',
          );
        }

        // The frame is the frame it was, in either category.
        expectSameShape(read.frame!.outline, outline, '$name frame');
        expect(read.kind, kept.kind);
      });
    }

    test('an angled design is never made a rectangle by being kept, opened '
        'and read again, however many times', () async {
      var d = await keep(under.built());
      final corners = d.frame!.outline;
      for (var i = 0; i < 3; i++) {
        final c = ProviderContainer();
        addTearDown(c.dispose);
        final controller = c.read(workspaceProvider.notifier);
        controller.openDesign(await reopen(d.id));
        controller.readDrawing();
        d = await keep(c.read(workspaceProvider).design);
        expectSameShape(d.frame!.outline, corners, 'round $i');
        expect(d.frame!.outline.corners, hasLength(5));
        expect(d.kind, DesignKind.angled);
      }
    });
  });

  group('on the real app', () {
    for (final (name, make) in [
      ('a standard window', solid.window),
      ('an angled window under a stair', under.built),
    ]) {
      testWidgets('$name, kept and opened from its card, is exactly what was '
          'kept in every view, and on the device after', (tester) async {
        final kept = (await tester.runAsync(() => keep(make())))!;

        final c = await screen.openTheApp(tester, size: const Size(390, 844));
        await customers.toCustomers(tester);
        await page.openCustomer(tester, 'Adam');
        await pressOpen(tester, kept.id);
        await tester.pumpAndSettle();
        // A design whose sizes are not given has them asked for over it,
        // as any design does; that is a question, not a change.
        final notNow = find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Not now'),
        );
        if (notNow.evaluate().isNotEmpty) {
          await tester.tap(notNow.first);
          await tester.pumpAndSettle();
        }

        final opened = c.read(workspaceProvider).design;
        expect(textOf(opened), textOf(kept), reason: name);
        expect(find.text(NormalizedNote.message), findsNothing);

        // Looked at every way: still exactly what was kept.
        for (final tab in ['CAD', '3D', 'Draw']) {
          await tester.tap(find.text(tab).first);
          await tester.pumpAndSettle();
          expect(textOf(c.read(workspaceProvider).design), textOf(kept));
        }
        expect(
          raked(c.read(workspaceProvider).design.frame!.outline),
          kept.kind == DesignKind.angled,
        );
        expect(
          c.read(workspaceProvider).design.kind,
          kept.kind,
          reason: 'the category as kept',
        );

        // And on the device, as it was kept.
        final again = await tester.runAsync(() => reopen(kept.id));
        expect(textOf(again!), textOf(kept));
      });
    }
  });
}
