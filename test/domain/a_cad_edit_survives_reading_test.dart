import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/pricing/pricing_access.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/infrastructure/design_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'an_under_stair_design_test.dart' as under;
import 'angled_dimensions_test.dart' as angled;
import 'geometry_normalizer_test.dart' show pen;

// An edit made on the technical drawing is an edit to the design, and it
// survives everything that comes after it: a Read of the sheet, a trip
// through Draw, CAD and 3D, an undo and a redo, a save and a reload, more
// drawing, and more edits.
//
// It used not to survive a Read. Every edit on the technical drawing went
// into the one canonical design — so it was saved, undone and shown in all
// three views — but a Read builds the frame and every bar of the design
// again from the ink, and the edits never moved the ink. The head dragged
// from 200 to 190 cm came back at 200 the moment the sheet was read again.
// The edits now move the ink they were read from exactly as they move the
// geometry (`InkFollows`), the rule a typed size has always kept, so the
// sheet and the design say the same thing and a reading of the one builds
// the other.

const door = [Vec2(0, 0), Vec2(900, 0), Vec2(900, 2000), Vec2(0, 2000)];

/// A 90 × 200 cm design of [kind]: the outline, a transom 50 cm down and a
/// mark in the light below it.
Design drawn(DesignKind kind, {List<Vec2> outline = door}) =>
    Design.empty(id: 'd-${kind.name}', kind: kind).copyWith(
      sketch: Sketch(
        strokes: [
          pen('outline', [...outline, outline.first]),
          pen('transom', const [Vec2(0, 500), Vec2(900, 500)]),
          pen('mark', chevron(const Vec2(450, 1300))),
        ],
      ),
    );

const standard = [
  DesignKind.door,
  DesignKind.window,
  DesignKind.sliding,
  DesignKind.both,
];

/// The workspace, with [d] opened in it and its sheet read.
WorkspaceController opened(Design d, {bool read = true}) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final controller = c.read(workspaceProvider.notifier)..openDesign(d);
  if (read) controller.readDrawing();
  return controller;
}

int memberAt(Design d, String placement) =>
    d.frameMembers.singleWhere((m) => m.placement == placement).index;

Polygon outlineOf(WorkspaceController c) => c.state.design.frame!.outline;

DividerElement transomOf(Design d) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == 'transom');

Design reloaded(Design d) =>
    Design.fromJson(jsonDecode(jsonEncode(d.toJson())));

/// The overall height the technical drawing writes.
double drawnHeight(Design d) => [
  for (final c in DimensionChains.of(d))
    for (final r in c.runs)
      if (r.of == ChainRunOf.overall && c.axis == DimensionAxis.vertical)
        r.toMm - r.fromMm,
].single;

/// How high and low the solid's frame reaches.
(double, double) solidHeight(Design d) {
  final ys = [
    for (final f in MeshBuilder.build(d).facets)
      if (f.elementId == d.frame!.id)
        for (final c in f.corners) c.y,
  ];
  return (ys.reduce(math.min), ys.reduce(math.max));
}

/// Where the outline's ink reaches at the top.
double inkTop(Design d) =>
    [for (final s in d.sketch.byId('outline')!.samples) s.at.y]
        .reduce(math.min);

// Since Phase 32 the stores ask who is writing (`by:`) and refuse anybody
// without the capability; the writes here are the owner's, who may do
// everything, because what these tests hold is not about permissions.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the reproduction', () {
    test('the head dragged from 200 to 190 cm, then Read: 190 cm', () {
      final c = opened(drawn(DesignKind.door));
      expect(outlineOf(c).height, closeTo(2000, 1e-6));
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
    });

    test('the transom dragged 10 cm down, then Read: where it was put', () {
      final c = opened(drawn(DesignKind.door));
      c.moveDividerAcross(transomOf(c.state.design).id, const Vec2(450, 600));
      c.readDrawing();
      final t = transomOf(c.state.design);
      expect(t.a.y, closeTo(600, 1e-6));
      expect(t.b.y, closeTo(600, 1e-6));
    });
  });

  group('every standard category', () {
    for (final kind in standard) {
      test('${kind.name}: 200 → 190 cm in CAD, then every view, a Read, a '
          'save and a reload', () {
        final c = opened(drawn(kind));
        c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
        final edited = c.state.design;

        // CAD: the design and the figure it writes agree.
        expect(edited.frame!.outline.height, closeTo(1900, 1e-6));
        expect(drawnHeight(edited), closeTo(1900, 1e-6));
        // 3D: the solid's frame from 10 cm down to the sill.
        final (top, bottom) = solidHeight(edited);
        expect(top, closeTo(100, 1e-6));
        expect(bottom, closeTo(2000, 1e-6));
        // 2D: the sheet's own ink says the same.
        expect(inkTop(edited), closeTo(100, 1e-6));

        // Looking at it every way changes nothing.
        for (final view in WorkspaceView.values) {
          c.showView(view);
          expect(identical(c.state.design, edited), isTrue);
        }

        // Read: the edit stays.
        c.readDrawing();
        expect(outlineOf(c).height, closeTo(1900, 1e-6), reason: kind.name);
        expect(drawnHeight(c.state.design), closeTo(1900, 1e-6));
        expect(transomOf(c.state.design).a.y, closeTo(500, 1e-6));

        // Saved and reloaded, then read again: still 190 cm.
        final back = reloaded(c.state.design);
        expect(back.frame!.outline.height, closeTo(1900, 1e-6));
        final again = opened(back);
        expect(outlineOf(again).height, closeTo(1900, 1e-6));
      });
    }
  });

  group('each kind of edit on the technical drawing', () {
    test('a bar moved by its middle, and by one end', () {
      final c = opened(drawn(DesignKind.window));
      final id = transomOf(c.state.design).id;
      c.moveDividerTo(id, const Vec2(450, 700));
      c.readDrawing();
      expect(transomOf(c.state.design).a.y, closeTo(700, 1e-6));

      // A mullion from the transom to the sill, its foot dragged across.
      final m = opened(
        drawn(DesignKind.window).copyWith(
          sketch: Sketch(
            strokes: [
              ...drawn(DesignKind.window).sketch.strokes,
              pen('mullion', const [Vec2(300, 500), Vec2(300, 2000)]),
            ],
          ),
        ),
      );
      final mullion = m.state.design.dividers.singleWhere(
        (b) => b.fromStrokeId == 'mullion',
      );
      m.moveDividerTo(mullion.id, Vec2(360, mullion.segment.midpoint.y));
      m.readDrawing();
      final now = m.state.design.dividers.singleWhere(
        (b) => b.fromStrokeId == 'mullion',
      );
      expect(now.a.x, closeTo(360, 1e-6));
      expect(now.b.x, closeTo(360, 1e-6));
    });

    test('a length and an angle typed on the bar\'s panel', () {
      final c = opened(drawn(DesignKind.window));
      final id = transomOf(c.state.design).id;
      c.setDividerAngle(id, 20);
      final turned = c.state.design.dividerById(id)!;
      c.readDrawing();
      final read = transomOf(c.state.design);
      expect(read.a.distanceTo(turned.a), lessThan(1e-6));
      expect(read.b.distanceTo(turned.b), lessThan(1e-6));
    });

    test('a jamb dragged out, and the whole frame dragged', () {
      final c = opened(drawn(DesignKind.door));
      c.moveFrameMember(memberAt(c.state.design, 'Right jamb'), 60);
      c.readDrawing();
      expect(outlineOf(c).width, closeTo(960, 1e-6));
      // The transom drawn jamb to jamb reaches the new jamb.
      final t = transomOf(c.state.design);
      expect(math.max(t.a.x, t.b.x), closeTo(960, 1e-6));
    });
  });

  group('the opening and everything it holds', () {
    test('the frame and the mullion dragged in CAD: the opening, its '
        'divider, glass, panel, handle and hinges stay its own, and every '
        'material stays', () {
      final c = opened(
        Design.empty(id: 'w', kind: DesignKind.window).copyWith(
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 0),
                Vec2(1000, 0),
                Vec2(1000, 2000),
                Vec2(0, 2000),
                Vec2(0, 0),
              ]),
              pen('mullion', const [Vec2(500, 0), Vec2(500, 2000)]),
              pen('mark', chevron(const Vec2(250, 1000))),
            ],
          ),
        ),
      );
      final opening = c.state.design.openings.single;
      final region = c.state.design.sectionById(opening.sectionId)!.outline;
      c.addLineInside(
        opening.sectionId,
        Vec2(region.centroid.x, region.bottom - 600),
        horizontal: true,
      );
      var d = c.state.design;
      final panes = d.childSectionsOf(opening.sectionId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      d = Infill.fill(d, {
        panes.first.id: GlassLook.frosted.finish,
        panes.last.id: PanelColour.brown.finish,
      });
      const anthracite = Finish(
        colour: 0xFF383E42,
        material: MaterialKind.aluminium,
      );
      d = d.withElement(d.frame!.copyWith(finish: anthracite));
      c.state = c.state.copyWith(design: d);

      // Two edits on the technical drawing: the head down 10 cm, and the
      // mullion 6 cm to the right.
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      final mullion = c.state.design.dividers.singleWhere(
        (b) => b.fromStrokeId == 'mullion',
      );
      c.moveDividerAcross(mullion.id, Vec2(560, mullion.segment.midpoint.y));
      final edited = c.state.design;

      for (final (what, x) in [
        ('as edited', edited),
        ('read again', (c..readDrawing()).state.design),
        ('reloaded', reloaded(c.state.design)),
      ]) {
        expect(x.frame!.outline.height, closeTo(1900, 1e-6), reason: what);
        expect(
          x.dividers.singleWhere((b) => b.fromStrokeId == 'mullion').a.x,
          closeTo(560, 1e-6),
          reason: what,
        );
        expect(
          jsonEncode(x.frame!.finish.toJson()),
          jsonEncode(anthracite.toJson()),
        );
        final o = x.openings.single;
        expect(o.id, opening.id, reason: '$what: the same opening');
        final r = x.sectionById(o.sectionId)!.outline;
        expect(r.contains(o.markAt!), isTrue);
        final inside = x.dividers.singleWhere((b) => b.parentId != null);
        expect(x.openingHolding(inside.parentId)?.id, o.id, reason: what);
        for (final end in [inside.a, inside.b]) {
          expect(
            r.edges.map((e) => e.distanceTo(end)).reduce(math.min),
            lessThan(1),
            reason: '$what: the divider across its own opening',
          );
        }
        final now = x.childSectionsOf(o.sectionId)
          ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
        expect(now, hasLength(2), reason: what);
        expect(
          jsonEncode(now.first.finish.toJson()),
          jsonEncode(GlassLook.frosted.finish.toJson()),
        );
        expect(
          jsonEncode(now.last.finish.toJson()),
          jsonEncode(PanelColour.brown.finish.toJson()),
        );
        final pieces = [
          for (final h in x.hardware)
            if (x.openingHolding(h.parentId)?.id == o.id) h,
        ];
        expect(
          pieces.where((h) => h.kind == HardwareKind.hinge),
          isNotEmpty,
          reason: what,
        );
        expect(pieces.where((h) => h.kind.isHandle), isNotEmpty);
        for (final h in pieces) {
          expect(
            r.contains(h.at) || r.edges.any((e) => e.distanceTo(h.at) < 0.5),
            isTrue,
            reason: '$what: ${h.id} on its leaf',
          );
        }
      }
    });
  });

  group('angled designs stay angled', () {
    test('left 200, right 150: the mullion dragged and the right jamb '
        'pushed out, then Read — the slope, the unequal sides and the edits '
        'all kept', () {
      final c = opened(angled.drawn(), read: false);
      final before = c.state.design;
      final mullion = before.dividers.singleWhere(
        (b) => b.fromStrokeId == 'mullion',
      );
      c.moveDividerAcross(mullion.id, Vec2(560, mullion.segment.midpoint.y));
      c.moveFrameMember(memberAt(c.state.design, 'Right jamb'), 50);
      final edited = c.state.design;
      c.readDrawing();
      final read = c.state.design;
      expect(read.kind, DesignKind.angled);
      final o = read.frame!.outline;
      expect(
        o.corners.map((p) => '${p.x.round()},${p.y.round()}').toSet(),
        edited.frame!.outline.corners
            .map((p) => '${p.x.round()},${p.y.round()}')
            .toSet(),
      );
      expect(
        o.edges.any(
          (e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1,
        ),
        isTrue,
        reason: 'the slope kept',
      );
      final jambs = [
        for (final e in o.edges)
          if (e.a.x == e.b.x) e.length,
      ]..sort();
      expect(jambs.first, isNot(closeTo(jambs.last, 1)), reason: 'unequal');
      expect(o.width, closeTo(1050, 1e-6));
      expect(
        read.dividers.singleWhere((b) => b.fromStrokeId == 'mullion').b.x,
        closeTo(560, 1e-6),
      );
      expect(GeometryNormalizer.validateAngledGeometry(read), isEmpty);
      final back = reloaded(read);
      expect(back.kind, DesignKind.angled);
      expect(textOf(back), textOf(read));
    });

    test('under the stair: the mullion dragged, then Read — five corners '
        'and the slope kept', () {
      final c = opened(under.built(), read: false);
      final mullion = c.state.design.dividers.singleWhere(
        (b) => b.fromStrokeId == 'mullion',
      );
      final corners = c.state.design.frame!.outline.corners;
      c.moveDividerAcross(
        mullion.id,
        mullion.segment.midpoint + const Vec2(80, 0),
      );
      final moved = c.state.design.dividerById(mullion.id)!;
      c.readDrawing();
      final read = c.state.design;
      expect(read.frame!.outline.corners, hasLength(5));
      for (final p in corners) {
        expect(
          read.frame!.outline.corners
              .map((q) => q.distanceTo(p))
              .reduce(math.min),
          lessThan(1e-6),
        );
      }
      final now = read.dividers.singleWhere((b) => b.fromStrokeId == 'mullion');
      expect(now.a.x, closeTo(moved.a.x, 1e-6));
      expect(now.b.x, closeTo(moved.b.x, 1e-6));
    });
  });

  group('dimensions agree with the edit', () {
    test('a figure the user stated on the side that moved reads the new '
        'length, and holds it through a Read', () {
      final d = drawn(DesignKind.door).copyWith(
        dimensions: [
          const DimensionElement(
            id: 'left',
            a: Vec2(0, 0),
            b: Vec2(0, 2000),
            offsetMm: -150,
            statedMm: 2000,
          ),
        ],
      );
      final c = opened(d);
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      final figure = c.state.design.dimensions.single;
      expect(figure.statedMm, closeTo(1900, 1e-6));
      expect(figure.a.y, closeTo(100, 1e-6));
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
      expect(c.state.design.dimensions.single.statedMm, closeTo(1900, 1e-6));
    });

    test('a height given in the form, then dragged: the figure is the '
        'geometry, through a Read', () {
      final c = opened(drawn(DesignKind.window));
      c.measure({Measurements.heightKey: 2000});
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      expect(drawnHeight(c.state.design), closeTo(1900, 1e-6));
      c.readDrawing();
      expect(drawnHeight(c.state.design), closeTo(1900, 1e-6));
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
    });
  });

  group('undo, redo, and many edits', () {
    test('undo puts back the geometry and the ink; redo the edit — and a '
        'Read after either builds what is shown', () {
      final c = opened(drawn(DesignKind.door));
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      c.undo();
      expect(outlineOf(c).height, closeTo(2000, 1e-6));
      expect(inkTop(c.state.design), closeTo(0, 1e-6));
      c.redo();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
      expect(inkTop(c.state.design), closeTo(100, 1e-6));
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));

      // Undone, then read: the drawing as it was before the edit.
      c.undo(); // the Read
      c.undo(); // the edit
      expect(outlineOf(c).height, closeTo(2000, 1e-6));
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(2000, 1e-6));
    });

    test('three edits, then Read: all three kept', () {
      final c = opened(drawn(DesignKind.window));
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      c.moveDividerAcross(transomOf(c.state.design).id, const Vec2(450, 650));
      c.moveFrameMember(memberAt(c.state.design, 'Right jamb'), 40);
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
      expect(outlineOf(c).width, closeTo(940, 1e-6));
      expect(transomOf(c.state.design).a.y, closeTo(650, 1e-6));
    });

    test('edit, save, edit, Read, save, reload: everything kept', () async {
      final c = opened(drawn(DesignKind.door));
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      await DesignStore().save(
        c.state.design.copyWith(customer: 'Adam'),
        by: WorkshopRole.owner,
      );
      c.moveDividerAcross(transomOf(c.state.design).id, const Vec2(450, 650));
      c.readDrawing();
      final kept = await DesignStore().save(
        c.state.design,
        by: WorkshopRole.owner,
      );
      final back = (await DesignStore().load(kept.id))!;
      expect(textOf(back), textOf(kept));
      final again = opened(back);
      expect(outlineOf(again).height, closeTo(1900, 1e-6));
      expect(transomOf(again.state.design).a.y, closeTo(650, 1e-6));
    });

    test('an edit, then more drawing, then Read: the edit kept and the new '
        'line read', () {
      final c = opened(drawn(DesignKind.window));
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      final d = c.state.design;
      c.state = c.state.copyWith(
        design: d.copyWith(
          sketch: Sketch(
            strokes: [
              ...d.sketch.strokes,
              pen('mullion', const [Vec2(450, 500), Vec2(450, 2000)]),
            ],
          ),
        ),
      );
      c.readDrawing();
      expect(outlineOf(c).height, closeTo(1900, 1e-6));
      expect(
        c.state.design.dividers.where((b) => b.fromStrokeId == 'mullion'),
        hasLength(1),
      );
    });

    test('a drawing made by hand: the edit kept within a hand\'s nothing', () {
      final c = opened(
        drawn(
          DesignKind.door,
          outline: const [
            Vec2(0, 0),
            Vec2(900, 12),
            Vec2(918, 2000),
            Vec2(-8, 1994),
          ],
        ),
      );
      final was = outlineOf(c);
      c.moveFrameMember(memberAt(c.state.design, 'Head'), -100);
      final edited = outlineOf(c);
      expect(edited.height, closeTo(was.height - 100, 1e-6));
      c.readDrawing();
      for (final p in edited.corners) {
        expect(
          outlineOf(c).corners.map((q) => q.distanceTo(p)).reduce(math.min),
          lessThan(0.5),
        );
      }
    });
  });
}

String textOf(Design d) => jsonEncode(d.toJson());
