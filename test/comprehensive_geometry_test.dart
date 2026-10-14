import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/frame_sides.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import 'app/pause_and_take_it_back_test.dart' show chevron;
import 'domain/an_under_stair_design_test.dart' as under;
import 'domain/angled_dimensions_test.dart' as angled;
import 'domain/geometry_normalizer_test.dart' show pen;
import 'domain/openings_inside_an_angled_design_test.dart' as gable;
import 'domain/the_solid_is_the_canonical_geometry_test.dart' as solid;

// The geometry, tested end to end, under the brief's own numbers.
//
// Standard (Door, Window, Sliding, Door & window):
//    1  a perfect rectangle            no unnecessary correction
//    2  a slightly tilted side         corrected
//    3  a slightly tilted top          corrected
//    4  a slightly inaccurate corner   corrected
//    5  left and right a little apart  corrected where clearly accidental
//    6  several openings               each independent
//    7  an opening and a divider       the divider stays local
//    8  glass and a panel              the materials unchanged
//    9  a handle and hinges            attached
//
// Angled / Asymmetrical:
//   10  a sloped top                   preserved
//   11  left 200 cm, right 150 cm      preserved
//   12  a trapezoid                    preserved
//   13  an under-stair shape           preserved
//   14  an angled opening              preserved
//   15  angled glass                   preserved
//   16  an angled panel                preserved
//   17  an angled divider              preserved
//   18  an angled handle               attached
//
// Each is held where the user sees it, not on one number: on the design,
// on the technical drawing's figures, on the solid, and through a reading
// of the same sheet again and a save and a reload.

const standard = [
  DesignKind.door,
  DesignKind.window,
  DesignKind.sliding,
  DesignKind.both,
];

Design blank(DesignKind kind, List<Stroke> strokes, {String id = 'd'}) =>
    Design.empty(id: id, kind: kind).copyWith(sketch: Sketch(strokes: strokes));

Interpretation interpret(DesignKind kind, List<Stroke> strokes) =>
    SketchInterpreter.interpret(blank(kind, strokes));

Design read(DesignKind kind, List<Stroke> strokes) =>
    solid.read(blank(kind, strokes));

/// A 120 × 150 cm outline through [corners], closed, and a transom 50 cm
/// down drawn jamb to jamb.
List<Stroke> outlined(List<Vec2> corners) => [
  pen('outline', [...corners, corners.first]),
  pen('transom', const [Vec2(0, 500), Vec2(1200, 500)]),
];

const exactly = [Vec2(0, 0), Vec2(1200, 0), Vec2(1200, 1500), Vec2(0, 1500)];

bool square(Polygon p) =>
    p.corners.length == 4 &&
    p.edges.every((e) => e.a.x == e.b.x || e.a.y == e.b.y);

bool raked(Polygon p) =>
    p.edges.any((e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1);

bool within(Polygon shape, Vec2 p, {double slack = 0.5}) =>
    shape.contains(p) || shape.edges.any((e) => e.distanceTo(p) <= slack);

Vec2 flat(Vec3 p) => Vec2(p.x, p.y);

String textOf(Design d) => jsonEncode(d.toJson());

Design saveAndReload(Design d) =>
    Design.fromJson(jsonDecode(jsonEncode(d.toJson())));

Design readAgain(Design d) => solid.read(d);

void expectCorners(Polygon actual, List<Vec2> expected, String what) {
  expect(actual.corners, hasLength(expected.length), reason: what);
  for (final c in expected) {
    expect(
      actual.corners.any((a) => a.distanceTo(c) < 1e-6),
      isTrue,
      reason: '$what: no corner at $c in ${actual.corners}',
    );
  }
}

/// What every design must be, whatever was drawn: the same after a save
/// and a reload, its technical drawing measuring only what is there, and
/// its solid inside its outline.
void expectSound(Design d, String what) {
  final again = saveAndReload(d);
  expect(textOf(again), textOf(d), reason: '$what: saved and reloaded');
  final outline = d.frame!.outline;
  for (final facet in MeshBuilder.build(d).facets) {
    for (final c in facet.corners) {
      expect(
        within(outline, flat(c)),
        isTrue,
        reason: '$what: ${facet.elementId} built outside the outline at $c',
      );
    }
  }
  for (final chain in DimensionChains.of(d)) {
    for (final run in chain.runs) {
      expect(run.toMm, greaterThan(run.fromMm), reason: '$what: a figure');
    }
  }
  if (d.kind == DesignKind.angled) {
    expect(
      GeometryNormalizer.validateAngledGeometry(d),
      isEmpty,
      reason: '$what: valid',
    );
  }
}

/// [d]'s only opening.
OpeningElement theOpening(Design d) => d.openings.single;

Polygon regionOf(Design d, OpeningElement o) =>
    d.sectionById(o.sectionId)!.outline;

/// Everything of [o]'s, as text: its region, its lines, its panes and their
/// finishes, its ironmongery.
String fingerprintOf(Design d, OpeningElement o) => jsonEncode({
  'opening': o.toJson(),
  'region': d.sectionById(o.sectionId)!.toJson(),
  'contents': [for (final e in d.contentsOf(o)) e.toJson()],
});

void main() {
  group('standard', () {
    test('1 · a perfect rectangle: no unnecessary correction', () {
      for (final kind in standard) {
        final reading = interpret(kind, outlined(exactly));
        expect(
          reading.corrections,
          isEmpty,
          reason:
              '${kind.name}: '
              '${reading.corrections}',
        );
        expect(reading.noticeablyCorrected, isEmpty);
        final d = read(kind, outlined(exactly));
        expectCorners(d.frame!.outline, exactly, kind.name);
        expect(d.dividers.single.segment.a, const Vec2(0, 500));
        expect(d.dividers.single.segment.b, const Vec2(1200, 500));
        expectSound(d, kind.name);
      }
    });

    test('2 · a slightly tilted side: corrected, and only that side', () {
      for (final kind in standard) {
        for (final lean in [30.0, 80.0, 160.0]) {
          final reading = interpret(
            kind,
            outlined([
              const Vec2(0, 0),
              const Vec2(1200, 0),
              Vec2(1200 + lean, 1500),
              const Vec2(0, 1500),
            ]),
          );
          final outline = reading.design.frame!.outline;
          final what = '${kind.name}, the side $lean mm out';
          expect(square(outline), isTrue, reason: what);
          expect(outline.left, closeTo(0, 1e-9), reason: '$what: left kept');
          expect(outline.top, closeTo(0, 1e-9));
          expect(outline.bottom, closeTo(1500, 1e-9));
          expect(outline.right, inInclusiveRange(1200, 1200 + lean));
          if (lean > 30) expect(reading.noticeablyCorrected, {'outline'});
          expectSound(
            solid.read(
              blank(
                kind,
                outlined([
                  const Vec2(0, 0),
                  const Vec2(1200, 0),
                  Vec2(1200 + lean, 1500),
                  const Vec2(0, 1500),
                ]),
              ),
            ),
            what,
          );
        }
      }
    });

    test('3 · a slightly tilted top: corrected, level', () {
      for (final kind in standard) {
        for (final rise in [20.0, 60.0, 120.0]) {
          final d = read(
            kind,
            outlined([
              const Vec2(0, 0),
              Vec2(1200, -rise),
              const Vec2(1200, 1500),
              const Vec2(0, 1500),
            ]),
          );
          final outline = d.frame!.outline;
          final what = '${kind.name}, the head rising $rise mm';
          expect(square(outline), isTrue, reason: what);
          expect(outline.bottom, closeTo(1500, 1e-9), reason: what);
          expect(outline.top, inInclusiveRange(-rise, 0));
          // The head is one level line, and the transom stays level too.
          for (final bar in d.dividers) {
            expect(bar.segment.a.y, closeTo(bar.segment.b.y, 1e-9));
          }
          expectSound(d, what);
        }
      }
    });

    test('4 · a slightly inaccurate corner: joined, trimmed or squared — '
        'and no line made of what was drawn past it', () {
      for (final kind in standard) {
        // Ends drawn 15 mm apart at the top right.
        final apart = read(kind, [
          pen('a', const [Vec2(0, 1500), Vec2(0, 0), Vec2(1200, 0)]),
          pen('b', const [Vec2(1210, 12), Vec2(1200, 1500), Vec2(0, 1500)]),
        ]);
        expect(square(apart.frame!.outline), isTrue, reason: kind.name);
        expect(apart.dividers, isEmpty, reason: '${kind.name}: no stub');
        expectSound(apart, '${kind.name}, ends apart');

        // The head drawn past the jamb, and the jamb past the head.
        final past = read(kind, [
          pen('head', const [Vec2(-40, 0), Vec2(1250, 0)]),
          pen('jambs', const [
            Vec2(1200, -40),
            Vec2(1200, 1500),
            Vec2(0, 1500),
            Vec2(0, -40),
          ]),
        ]);
        expectCorners(past.frame!.outline, exactly, '${kind.name}, past');
        expect(past.dividers, isEmpty, reason: '${kind.name}: trimmed, no bar');
        expectSound(past, '${kind.name}, drawn past');

        // A corner two degrees off square.
        final off = read(
          kind,
          outlined([
            const Vec2(0, 0),
            const Vec2(1200, 0),
            Vec2(1200 + 1500 * math.tan(2 * math.pi / 180), 1500),
            const Vec2(0, 1500),
          ]),
        );
        expect(square(off.frame!.outline), isTrue);
        expectSound(off, '${kind.name}, off square');
      }
    });

    test('5 · left and right a little apart: made one height where it is '
        'clearly the hand — and a real difference kept', () {
      for (final kind in standard) {
        // Left 150 cm, right 148: the hand.
        final accident = read(
          kind,
          outlined(const [
            Vec2(0, 0),
            Vec2(1200, 20),
            Vec2(1200, 1500),
            Vec2(0, 1500),
          ]),
        );
        final o = accident.frame!.outline;
        expect(square(o), isTrue, reason: kind.name);
        final jambs = o.edges.where((e) => e.a.x == e.b.x).toList();
        expect(jambs, hasLength(2));
        expect(jambs[0].length, closeTo(jambs[1].length, 1e-9));
        expectSound(accident, '${kind.name}, 2 cm apart');

        // Left 150 cm, right 110: not the hand, a slope — kept as drawn.
        final meant = read(
          kind,
          outlined(const [
            Vec2(0, 0),
            Vec2(1200, 400),
            Vec2(1200, 1500),
            Vec2(0, 1500),
          ]),
        );
        expect(square(meant.frame!.outline), isFalse, reason: kind.name);
        expectCorners(meant.frame!.outline, const [
          Vec2(0, 0),
          Vec2(1200, 400),
          Vec2(1200, 1500),
          Vec2(0, 1500),
        ], '${kind.name}, 40 cm apart');
      }
    });

    test('6 · several openings: each its own, and an edit to one leaves the '
        'others exactly as they were', () {
      for (final kind in standard) {
        var d = read(kind, [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(2400, 0),
            Vec2(2400, 1500),
            Vec2(0, 1500),
            Vec2(0, 0),
          ]),
          pen('m1', const [Vec2(800, 0), Vec2(800, 1500)]),
          pen('m2', const [Vec2(1600, 0), Vec2(1600, 1500)]),
          pen('one', chevron(const Vec2(400, 750))),
          pen('three', chevron(const Vec2(2000, 750))),
        ]);
        d = solid.said(d, kind.leafDefault ?? DesignKind.window);
        expect(d.openings, hasLength(2), reason: kind.name);
        final [one, three] = d.openingsInOrder;
        expect(one.sectionId, isNot(three.sectionId));
        final ids1 = {for (final e in d.contentsOf(one)) e.id};
        final ids3 = {for (final e in d.contentsOf(three)) e.id};
        expect(ids1.intersection(ids3), isEmpty);
        expect(d.hardware.where((h) => h.parentId == one.id), isNotEmpty);

        // A line drawn inside the first; the third untouched.
        final third = fingerprintOf(d, three);
        final r1 = regionOf(d, one);
        d = DesignEdits.addLineInside(
          d,
          one.sectionId,
          id: 'in-one',
          at: Vec2(r1.centroid.x, r1.centroid.y),
          horizontal: true,
        );
        expect(
          fingerprintOf(d, d.openings.singleWhere((o) => o.id == three.id)),
          third,
          reason: '${kind.name}: the other opening untouched',
        );
        expect(d.contentsOf(three).map((e) => e.id), isNot(contains('in-one')));

        // Swung, both move, each as its own leaf, and nothing else does.
        final shut = MeshBuilder.build(d);
        final open = MeshBuilder.build(d, openFraction: 0.5);
        final movers = {
          for (final o in d.openings) ...{
            o.sectionId,
            for (final e in d.contentsOf(o)) e.id,
          },
        };
        for (var i = 0; i < shut.facets.length; i++) {
          final same =
              shut.facets[i].corners.toString() ==
              open.facets[i].corners.toString();
          if (!movers.contains(shut.facets[i].elementId)) {
            expect(same, isTrue, reason: '${shut.facets[i].elementId} moved');
          }
        }
        expectSound(d, '${kind.name}, two openings');
      }
    });

    test('7 · an opening and a divider: the divider stays the opening\'s, '
        'inside it, and the design\'s own divisions do not change', () {
      for (final kind in standard) {
        var d = solid.said(
          read(kind, [
            ...outlined(exactly),
            pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
            pen('mark', chevron(const Vec2(300, 1000))),
          ]),
          kind.leafDefault ?? DesignKind.window,
        );
        final topBars = jsonEncode([
          for (final b in d.topLevelDividers) b.toJson(),
        ]);
        final topSections = jsonEncode([
          for (final s in d.topLevelSections) s.outline.toJson(),
        ]);
        d = solid.divided(d);
        final o = theOpening(d);
        final region = regionOf(d, o);
        final inside = d.dividers.singleWhere((b) => b.parentId != null);
        expect(d.openingHolding(inside.parentId)?.id, o.id);
        expect(within(region, inside.segment.a), isTrue);
        expect(within(region, inside.segment.b), isTrue);
        expect(d.childSectionsOf(o.sectionId), hasLength(2));
        expect(
          jsonEncode([for (final b in d.topLevelDividers) b.toJson()]),
          topBars,
          reason: '${kind.name}: the design\'s bars as they were',
        );
        expect(
          jsonEncode([for (final s in d.topLevelSections) s.outline.toJson()]),
          topSections,
        );
        // Through a reading of the sheet again, still the opening's.
        final again = readAgain(d);
        expect(
          again.dividers.singleWhere((b) => b.id == inside.id).parentId,
          inside.parentId,
        );
        // And in the solid, inside the leaf.
        final leaf = DesignGeometry.of(d)
            .leafOuter(d.sectionById(o.sectionId)!);
        for (final f in MeshBuilder.build(d).facets) {
          if (f.elementId != inside.id) continue;
          for (final c in f.corners) {
            expect(within(leaf, flat(c)), isTrue, reason: '$c');
          }
        }
        expectSound(d, '${kind.name}, a divider in the opening');
      }
    });

    test('8 · glass and a panel: what each pane is made of survives a '
        'reading, a resize, a moved bar and a reload', () {
      for (final kind in standard) {
        var d = solid.divided(
          solid.said(
            read(kind, [
              ...outlined(exactly),
              pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
              pen('mark', chevron(const Vec2(300, 1000))),
            ]),
            kind.leafDefault ?? DesignKind.window,
          ),
        );
        final panes = d.childSectionsOf(theOpening(d).sectionId)
          ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
        d = Infill.fill(d, {
          panes.first.id: GlassLook.frosted.finish,
          panes.last.id: PanelColour.brown.finish,
        });

        void expectMaterials(Design x, String what) {
          final now = x.childSectionsOf(theOpening(x).sectionId)
            ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
          expect(now, hasLength(2), reason: what);
          expect(
            jsonEncode(now.first.finish.toJson()),
            jsonEncode(GlassLook.frosted.finish.toJson()),
            reason: '$what: the glass',
          );
          expect(
            jsonEncode(now.last.finish.toJson()),
            jsonEncode(PanelColour.brown.finish.toJson()),
            reason: '$what: the panel',
          );
          final mesh = MeshBuilder.build(x);
          expect(
            mesh.facets.where(
              (f) => f.elementId == now.first.id && f.role == FacetRole.glazing,
            ),
            isNotEmpty,
          );
          final panel = mesh.facets
              .where((f) => f.elementId == now.last.id)
              .toList();
          expect(panel.every((f) => f.role == FacetRole.panel), isTrue);
          expect(
            panel.every((f) => f.colour == PanelColour.brown.finish.colour),
            isTrue,
          );
        }

        final what = kind.name;
        expectMaterials(d, '$what as made');
        expectMaterials(readAgain(d), '$what read again');
        final sized = Measurements.apply(d, {
          for (final m in Measurements.of(d))
            if (m.asked) m.key: m.currentMm(d),
        }).design;
        expectMaterials(
          Measurements.apply(sized, {Measurements.widthKey: 1400}).design,
          '$what made wider',
        );
        final mullion = d.dividers.singleWhere(
          (b) => b.fromStrokeId == 'mullion',
        );
        expectMaterials(
          DesignEdits.moveDivider(d, mullion.id, const Vec2(60, 0)),
          '$what with the mullion moved',
        );
        expectMaterials(saveAndReload(d), '$what saved and reloaded');
      }
    });

    test('9 · a handle and hinges: the opening\'s, on its leaf, and going '
        'where the leaf goes', () {
      for (final kind in [
        DesignKind.door,
        DesignKind.window,
        DesignKind.both,
      ]) {
        final made = solid.divided(
          solid.said(
            read(kind, [
              ...outlined(exactly),
              pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
              pen('mark', chevron(const Vec2(300, 1000))),
            ]),
            kind.leafDefault ?? DesignKind.door,
          ),
        );
        final sized = Measurements.apply(made, {
          for (final m in Measurements.of(made))
            if (m.asked) m.key: m.currentMm(made),
        }).design;
        final mullion = made.dividers.singleWhere(
          (b) => b.fromStrokeId == 'mullion',
        );
        for (final (what, d) in [
          ('as made', made),
          ('read again', readAgain(made)),
          (
            'made wider',
            Measurements.apply(sized, {Measurements.widthKey: 1500}).design,
          ),
          (
            'mullion moved',
            DesignEdits.moveDivider(made, mullion.id, const Vec2(80, 0)),
          ),
          ('reloaded', saveAndReload(made)),
        ]) {
          _expectAttached(d, '${kind.name} $what');
        }
        _expectSwingsWithItsLeaf(made, kind.name);
      }
    });
  });

  group('angled', () {
    test('10 · a sloped top: preserved — where the same sheet begun as a '
        'window is squared', () {
      final head = [
        const Vec2(0, 0),
        Vec2(1200, 1200 * math.tan(7 * math.pi / 180)),
        const Vec2(1200, 1500),
        const Vec2(0, 1500),
      ];
      final kept = read(DesignKind.angled, outlined(head));
      expectCorners(kept.frame!.outline, head, 'angled');
      expect(raked(kept.frame!.outline), isTrue);
      expect(
        interpret(DesignKind.angled, outlined(head)).noticeablyCorrected,
        isEmpty,
      );
      expect(
        square(read(DesignKind.window, outlined(head)).frame!.outline),
        isTrue,
        reason: 'the same sheet as a window',
      );
      expectCorners(readAgain(kept).frame!.outline, head, 'read again');
      expectSound(kept, 'a sloped top');
    });

    test('11 · left 200 cm, right 150 cm: preserved, and each side its own '
        'figure', () {
      final d = angled.drawn();
      final sides = {
        for (final s in FrameSides.of(d)) s.label: s.lengthOn(d.frame!.outline),
      };
      expect(sides.values, contains(closeTo(1500, 1e-6)));
      final o = d.frame!.outline;
      expect(o.height, closeTo(2000, 1e-6));
      expect(o.width, closeTo(1000, 1e-6));
      final runs = [
        for (final c in DimensionChains.of(d))
          for (final r in c.runs)
            if (r.of == ChainRunOf.side) r.toMm - r.fromMm,
      ];
      expect(runs, contains(closeTo(1500, 1e-6)));
      for (final x in [d, readAgain(d), saveAndReload(d)]) {
        expectCorners(x.frame!.outline, o.corners, 'left 200 right 150');
      }
      expectSound(d, 'left 200, right 150');
    });

    test('12 · a trapezoid: preserved — both sides leaning in', () {
      const trapezoid = [
        Vec2(200, 0),
        Vec2(1000, 0),
        Vec2(1200, 1500),
        Vec2(0, 1500),
      ];
      final d = read(DesignKind.angled, [
        pen('outline', [...trapezoid, trapezoid.first]),
      ]);
      expectCorners(d.frame!.outline, trapezoid, 'trapezoid');
      for (final x in [readAgain(d), saveAndReload(d)]) {
        expectCorners(x.frame!.outline, trapezoid, 'trapezoid again');
      }
      // The solid's frame stands on the four corners drawn.
      final frame = MeshBuilder.build(d).facets
          .where((f) => f.elementId == d.frame!.id);
      for (final c in trapezoid) {
        expect(
          frame.any((f) => f.corners.any((p) => flat(p).distanceTo(c) < 0.5)),
          isTrue,
          reason: 'the solid has no corner at $c',
        );
      }
      expectSound(d, 'a trapezoid');
    });

    test('13 · an under-stair shape: preserved, five corners as drawn', () {
      final d = under.built();
      final corners = under.stair.take(5).toList();
      for (final (what, x) in [
        ('built', d),
        ('read again', readAgain(d)),
        ('reloaded', saveAndReload(d)),
      ]) {
        expectCorners(x.frame!.outline, corners, 'under the stair, $what');
      }
      expectSound(d, 'under the stair');
    });

    test('14 · an angled opening: preserved — raked, on its own region, '
        'holding its mark', () {
      final d = gable.built();
      expect(d.openings, hasLength(2));
      for (final o in d.openings) {
        final region = regionOf(d, o);
        expect(raked(region), isTrue, reason: o.id);
        expect(region.contains(o.markAt!), isTrue);
        for (final x in [readAgain(d), saveAndReload(d)]) {
          final same = x.openings.singleWhere((y) => y.id == o.id);
          expectCorners(regionOf(x, same), region.corners, '${o.id} again');
        }
      }
      expectSound(d, 'the gable');
    });

    test('15 · angled glass: preserved — the pane under the slope is '
        'raked, and the solid\'s glass follows it', () {
      final d = gable.built();
      final one = gable.opening(d, 'one');
      final glass = d
          .childSectionsOf(one.sectionId)
          .singleWhere((s) => s.finish.material.isGlazing);
      final fill = DesignGeometry.of(d).fillOf(glass);
      expect(raked(fill), isTrue);
      final lites = MeshBuilder.build(d).facets
          .where((f) => f.elementId == glass.id && f.role == FacetRole.glazing);
      for (final c in fill.corners) {
        expect(
          lites.any((f) => f.corners.any((p) => flat(p).distanceTo(c) < 0.5)),
          isTrue,
          reason: 'no glass at $c',
        );
      }
      for (final x in [readAgain(d), saveAndReload(d)]) {
        expectCorners(
          DesignGeometry.of(x).fillOf(x.sectionById(glass.id)!),
          fill.corners,
          'the glass again',
        );
      }
    });

    test('16 · an angled panel: preserved — raked, a panel in the solid, '
        'never glass', () {
      final d = gable.built();
      final two = gable.opening(d, 'two');
      final panel = d
          .childSectionsOf(two.sectionId)
          .singleWhere((s) => !s.finish.material.isGlazing);
      final fill = DesignGeometry.of(d).fillOf(panel);
      expect(raked(fill), isTrue);
      final faces = MeshBuilder.build(d).facets
          .where((f) => f.elementId == panel.id)
          .toList();
      expect(faces.every((f) => f.role == FacetRole.panel), isTrue);
      for (final c in fill.corners) {
        expect(
          faces.any((f) => f.corners.any((p) => flat(p).distanceTo(c) < 0.5)),
          isTrue,
          reason: 'no panel at $c',
        );
      }
      for (final x in [readAgain(d), saveAndReload(d)]) {
        final same = x.sectionById(panel.id)!;
        expect(same.finish.material.isGlazing, isFalse);
        expectCorners(DesignGeometry.of(x).fillOf(same), fill.corners, 'again');
      }
    });

    test('17 · an angled divider: preserved — drawn at a slope inside a '
        'raked opening, it keeps its angle and divides it', () {
      var d = gable.built();
      final one = gable.opening(d, 'one');
      // The rail taken out, and a line at 15° drawn across instead.
      d = DesignEdits.delete(d, 'rail');
      final region = regionOf(d, one);
      final y = region.bottom - 500;
      final rise = region.width * math.tan(15 * math.pi / 180);
      d = DesignEdits.addDividerInside(
        d,
        one.sectionId,
        id: 'sloped',
        a: Vec2(region.left - 20, y),
        b: Vec2(
          region.right + 20,
          y - rise - 40 * math.tan(15 * math.pi / 180),
        ),
      );
      final bar = d.dividers.singleWhere((b) => b.id == 'sloped');
      final angle =
          math.atan2(
            bar.segment.a.y - bar.segment.b.y,
            bar.segment.b.x - bar.segment.a.x,
          ) *
          180 /
          math.pi;
      expect(angle, closeTo(15, 1e-6));
      expect(d.openingHolding(bar.parentId)?.id, one.id);
      expect(d.childSectionsOf(one.sectionId), hasLength(2));
      for (final x in [readAgain(d), saveAndReload(d)]) {
        final same = x.dividers.singleWhere((b) => b.id == 'sloped');
        expect(same.segment.a.distanceTo(bar.segment.a), lessThan(1e-6));
        expect(same.segment.b.distanceTo(bar.segment.b), lessThan(1e-6));
        expect(x.childSectionsOf(one.sectionId), hasLength(2));
      }
      final body = DesignGeometry.of(d).barBody(bar);
      for (final f in MeshBuilder.build(d).facets) {
        if (f.elementId != 'sloped') continue;
        for (final c in f.corners) {
          expect(within(body, flat(c)), isTrue);
        }
      }
      expectSound(d, 'a sloped divider');
    });

    test('18 · an angled handle: on the leaf, on the stile opposite the '
        'hinges, and turning with it — under a slope and on a leaning '
        'stile', () {
      final gabled = gable.built();
      for (final o in gabled.openings) {
        _expectAttached(gabled, 'the gable, ${o.id}', opening: o);
      }
      _expectSwingsWithItsLeaf(gabled, 'the gable');

      // A leaf hung on a stile drawn leaning.
      final leaning = solid.said(
        read(DesignKind.angled, [
          pen('outline', const [
            Vec2(0, 0),
            Vec2(1200, 500),
            Vec2(1300, 2000),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
          pen('mullion', const [Vec2(600, 250), Vec2(600, 2000)]),
          pen('mark', [
            for (final p in chevron(const Vec2(900, 1300)))
              Vec2(1800 - p.x, p.y),
          ]),
        ]),
        DesignKind.door,
      );
      _expectAttached(leaning, 'a leaning stile');
      _expectSwingsWithItsLeaf(leaning, 'a leaning stile');
      _expectAttached(under.built(), 'under the stair');
    });
  });
}

/// Every piece of [d]'s opening's ironmongery is the opening's and on its
/// leaf: the hinges down the stile it hangs on, the handle on the other.
void _expectAttached(Design d, String what, {OpeningElement? opening}) {
  final o = opening ?? d.openings.single;
  final leaf = d.sectionById(o.sectionId)!.outline;
  final pieces = [
    for (final h in d.hardware)
      if (d.openingHolding(h.parentId)?.id == o.id) h,
  ];
  final hinges = [
    for (final h in pieces)
      if (h.kind == HardwareKind.hinge) h,
  ];
  final handles = [
    for (final h in pieces)
      if (h.kind.isHandle) h,
  ];
  expect(hinges.length, greaterThanOrEqualTo(2), reason: '$what: hinges');
  expect(handles, hasLength(1), reason: '$what: a handle');
  for (final h in pieces) {
    expect(within(leaf, h.at), isTrue, reason: '$what: ${h.id} off the leaf');
  }
  final edge = o.mechanism.hingeEdge!;
  if (edge == OpeningEdge.left || edge == OpeningEdge.right) {
    final hingeStile = OpeningHardware.stileOf(leaf, edge)!;
    final handleStile = OpeningHardware.stileOf(
      leaf,
      edge == OpeningEdge.left ? OpeningEdge.right : OpeningEdge.left,
    )!;
    for (final h in hinges) {
      expect(hingeStile.distanceTo(h.at), lessThan(1e-6), reason: what);
    }
    expect(
      handleStile.distanceTo(handles.single.at),
      lessThan(hingeStile.distanceTo(handles.single.at)),
      reason: '$what: the handle on the far stile',
    );
  }
  // Built, each piece is there and none is the design's.
  final built = {for (final f in MeshBuilder.build(d).facets) f.elementId};
  for (final h in pieces) {
    expect(built, contains(h.id), reason: what);
    expect(h.parentId, isNotNull);
  }
}

/// Swung, every opening's ironmongery keeps its distance from that
/// opening's sash — it turns with the leaf, as one body.
void _expectSwingsWithItsLeaf(Design d, String what) {
  final shut = MeshBuilder.build(d);
  final open = MeshBuilder.build(d, openFraction: 0.7);
  expect(open.facets, hasLength(shut.facets.length));
  for (final o in d.openings) {
    final sash = <int>[];
    final pieces = <int>[];
    final ids = {
      for (final h in d.hardware)
        if (d.openingHolding(h.parentId)?.id == o.id) h.id,
    };
    for (var i = 0; i < shut.facets.length; i++) {
      final f = shut.facets[i];
      if (f.elementId == o.sectionId && f.role == FacetRole.sash) sash.add(i);
      if (ids.contains(f.elementId)) pieces.add(i);
    }
    expect(sash, isNotEmpty, reason: '$what ${o.id}');
    expect(pieces, isNotEmpty, reason: '$what ${o.id}');
    final anchor = shut.facets[sash.first].corners.first;
    final anchorOpen = open.facets[sash.first].corners.first;
    var moved = false;
    for (final i in pieces) {
      for (var k = 0; k < shut.facets[i].corners.length; k++) {
        final a = shut.facets[i].corners[k], b = open.facets[i].corners[k];
        expect(
          _distance(b, anchorOpen),
          closeTo(_distance(a, anchor), 1e-6),
          reason: '$what ${o.id}: ${shut.facets[i].elementId} left its leaf',
        );
        if (_distance(a, b) > 1) moved = true;
      }
    }
    expect(moved, isTrue, reason: '$what ${o.id}: the ironmongery turned');
  }
  // Leaves of a leaning stile turn about it: the hinge line stays put.
  for (final o in d.openings) {
    final (a, b, _) = OpeningHardware.swingOf(
      d.sectionById(o.sectionId)!.outline,
      o.mechanism.hingeEdge!,
    );
    final line = Segment(a, b);
    for (var i = 0; i < shut.facets.length; i++) {
      final f = shut.facets[i];
      if (f.elementId != o.sectionId || f.role != FacetRole.sash) continue;
      for (var k = 0; k < f.corners.length; k++) {
        final p = f.corners[k];
        if (line.distanceTo(flat(p)) > 1e-6) continue;
        final pivot = MeshBuilder.swingsTowardViewer(d, o)
            ? MeshBuilder.leafFront(d.depthMm)
            : MeshBuilder.leafBack(d.depthMm);
        if ((p.z - pivot).abs() > 1e-6) continue;
        expect(
          _distance(p, open.facets[i].corners[k]),
          lessThan(1e-6),
          reason: '$what ${o.id}: a point on the hinge line moved',
        );
      }
    }
  }
}

double _distance(Vec3 a, Vec3 b) => math.sqrt(
  (a.x - b.x) * (a.x - b.x) +
      (a.y - b.y) * (a.y - b.y) +
      (a.z - b.z) * (a.z - b.z),
);
