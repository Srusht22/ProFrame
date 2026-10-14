import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/frame_sides.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// Openings inside an angled design:
//
//              ╱╲
//            ╱    ╲
//          ╱│      │╲
//        ╱  │      │  ╲
//       │ > │      │ <  │
//       │───│      │  │ │
//       └───┴──────┴──┴─┘
//     Opening 1  fixed  Opening 2
//
// A gable, two mullions, and an opening under each slope: Opening 1 a window
// hinged on the left, divided by a rail into glass above and a panel below;
// Opening 2 a door hinged on the right, divided by an upright from the sill
// to the slope into glass and a panel. Each opening is the shape the frame
// gives it — raked, not a rectangle — and everything in it is its own: the
// divider, the glass, the panel, the hinges and the handle. Then the design
// is edited every way that reshapes an opening, and each time all of it is
// still the opening's and still inside it.

/// `<`: the mirror of [chevron], its point to the left.
List<Vec2> leftward(Vec2 at) => [
  Vec2(at.x + 55, at.y - 110),
  Vec2(at.x - 55, at.y),
  Vec2(at.x + 55, at.y + 110),
];

Design read(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

/// The gable, drawn and read, its openings said and furnished.
Design built() {
  var d = read(
    Design.empty(id: 'gable', kind: DesignKind.angled).copyWith(
      name: 'Gable',
      sketch: Sketch(
        strokes: [
          pen('outline', const [
            Vec2(0, 2000),
            Vec2(0, 800),
            Vec2(1200, 0),
            Vec2(2400, 800),
            Vec2(2400, 2000),
            Vec2(0, 2000),
          ]),
          pen('m1', const [Vec2(800, 267), Vec2(800, 2000)]),
          pen('m2', const [Vec2(1600, 267), Vec2(1600, 2000)]),
          pen('one', chevron(const Vec2(400, 1400))),
          pen('two', leftward(const Vec2(2000, 1400))),
        ],
      ),
    ),
  ).copyWith(measured: {});
  final [one, two] = d.openingsInOrder;
  d = OpeningHardware.settle(
    d.copyWith(
      openings: [
        for (final o in d.openings)
          o.copyWith(
            kind: o.id == one.id ? DesignKind.window : DesignKind.door,
          ),
      ],
    ),
  );
  final r1 = d.sectionById(one.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    one.sectionId,
    id: 'rail',
    at: Vec2(r1.centroid.x, r1.bottom - 400),
    horizontal: true,
  );
  final r2 = d.sectionById(two.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    two.sectionId,
    id: 'stile',
    at: Vec2(r2.left + 300, r2.centroid.y),
    horizontal: false,
  );
  // Glass where the slope is, a white panel below the rail and beside the
  // stile.
  final panelOne = d
      .childSectionsOf(one.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  final panelTwo = d
      .childSectionsOf(two.sectionId)
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  return d
      .withElement(panelOne.copyWith(finish: PanelColour.white.finish))
      .withElement(panelTwo.copyWith(finish: PanelColour.white.finish));
}

OpeningElement opening(Design d, String strokeId) =>
    d.openings.singleWhere((o) => o.id == 'opening-$strokeId');

Polygon regionOf(Design d, OpeningElement o) =>
    d.sectionById(o.sectionId)!.outline;

bool raked(Polygon p) =>
    p.edges.any((e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1);

/// Whether [p] is inside [region], give or take [slack] millimetres.
bool within(Polygon region, Vec2 p, {double slack = 0.5}) =>
    region.contains(p) || region.edges.any((e) => e.distanceTo(p) <= slack);

double boundaryDistance(Polygon region, Vec2 p) =>
    region.edges.map((e) => e.distanceTo(p)).reduce((a, b) => a < b ? a : b);

SectionElement glassOf(Design d, OpeningElement o) => d
    .childSectionsOf(o.sectionId)
    .singleWhere((s) => s.finish.material.isGlazing);

SectionElement panelOf(Design d, OpeningElement o) => d
    .childSectionsOf(o.sectionId)
    .singleWhere((s) => !s.finish.material.isGlazing);

/// Every relationship the phase names, required of [d]: the two openings
/// raked and on their own regions, each holding exactly its divider, its
/// glass, its panel, its hinges and its handle, all inside it.
void expectEveryRelationship(Design d, {String? when}) {
  final reason = when ?? '';
  final one = opening(d, 'one'), two = opening(d, 'two');
  expect(d.openings, hasLength(2), reason: reason);
  // The design's own lines are the two mullions, and nothing else.
  expect(d.topLevelDividers, hasLength(2), reason: reason);
  for (final bar in d.topLevelDividers) {
    expect(bar.isVertical, isTrue, reason: reason);
  }

  final tree = DesignTree.of(d);
  for (final (o, divider) in [(one, 'rail'), (two, 'stile')]) {
    final region = regionOf(d, o);
    expect(raked(region), isTrue, reason: '${o.id} follows the slope $reason');
    expect(o.sectionId, isNot(d.frame!.id));

    // The tree: the opening's branch holds its divider and its two panes.
    final branch = tree.openings.singleWhere((b) => b.openingId == o.id);
    expect(branch.barIds, [divider], reason: reason);
    expect(branch.panes, hasLength(2), reason: '${o.id} $reason');

    // The divider is the opening's and inside it, end to end, and each end
    // meets the opening's edge — so it divides.
    final bar = d.dividerById(divider)!;
    expect(d.openingHolding(bar.parentId)?.id, o.id, reason: reason);
    expect(region.holds(bar.segment, reach: 0.5), isTrue, reason: reason);
    for (final end in [bar.a, bar.b]) {
      expect(
        boundaryDistance(region, end),
        lessThan(0.5),
        reason: '$divider meets the edge of ${o.id} $reason',
      );
    }

    // Glass and panel, each the opening's and inside it.
    final glass = glassOf(d, o), panel = panelOf(d, o);
    for (final pane in [glass, panel]) {
      expect(d.openingHolding(pane.parentId)?.id, o.id, reason: reason);
      for (final c in pane.outline.corners) {
        expect(within(region, c), isTrue, reason: '${pane.id} $c $reason');
      }
    }
    // The glass is the pane the slope bounds; the panel is square.
    expect(raked(glass.outline), isTrue, reason: '${o.id} glass $reason');
    expect(panel.finish, PanelColour.white.finish);

    // Its leaf follows the shape, and what fills each pane is inside it.
    final geometry = DesignGeometry.of(d);
    final section = d.sectionById(o.sectionId)!;
    final leaf = geometry.leafInner(section)!;
    expect(raked(leaf), isTrue, reason: '${o.id} leaf $reason');
    for (final pane in [glass, panel]) {
      for (final c in geometry.fillOf(pane).corners) {
        expect(within(leaf, c), isTrue, reason: '${pane.id} fill $reason');
      }
    }
    for (final c in geometry.barBody(bar).corners) {
      expect(within(geometry.leafOuter(section), c), isTrue, reason: reason);
    }

    // Hinges and a handle, each the opening's and on its leaf.
    final pieces = [
      for (final h in d.hardware)
        if (d.openingHolding(h.parentId)?.id == o.id) h,
    ];
    final hinges = pieces.where((h) => h.kind == HardwareKind.hinge).toList();
    final handles = pieces.where((h) => h.kind.isHandle).toList();
    expect(hinges.length, greaterThanOrEqualTo(2), reason: reason);
    expect(handles, hasLength(1), reason: reason);
    for (final h in pieces) {
      expect(h.parentId, isNotNull);
      expect(within(region, h.at, slack: 1), isTrue, reason: '$h $reason');
    }
    // The hinges on one stile, the handle on the other.
    final hingeX = hinges.first.at.x;
    for (final h in hinges) {
      expect(h.at.x, closeTo(hingeX, 1e-6), reason: reason);
    }
    expect((handles.single.at.x - hingeX).abs(), greaterThan(300));
    expect(
      [for (final h in pieces) h.kind],
      o.id == two.id
          ? contains(HardwareKind.lock)
          : isNot(contains(HardwareKind.lock)),
    );
  }

  // Nothing of one opening is the other's.
  final ofOne = {for (final e in d.contentsOf(one)) e.id};
  final ofTwo = {for (final e in d.contentsOf(two)) e.id};
  expect(ofOne.intersection(ofTwo), isEmpty, reason: reason);
  // The light between them is fixed, and nothing is in it.
  final fixed = d.topLevelSections.singleWhere(
    (s) => d.openingOf(s.id) == null,
  );
  expect(d.childSectionsOf(fixed.id), isEmpty, reason: reason);
  expect(GeometryNormalizer.validateAngledGeometry(d), isEmpty);
}

/// The height of [o]'s panel below its rail, or its width beside its
/// stile — the figure a reshape of the opening must leave alone.
double panelSize(Design d, OpeningElement o, {required bool down}) {
  final panel = panelOf(d, o).outline;
  return down ? panel.height : panel.width;
}

void main() {
  group('two openings, each the shape the frame gives it', () {
    test('every relationship holds as drawn', () {
      expectEveryRelationship(built(), when: 'as drawn');
    });

    test('Opening 1 is a window hinged on its left, under the left slope; '
        'Opening 2 a door hinged on its right, under the right slope', () {
      final d = built();
      final one = opening(d, 'one'), two = opening(d, 'two');
      expect(d.openingsInOrder.map((o) => o.id), [one.id, two.id]);
      expect(d.kindOf(one), DesignKind.window);
      expect(d.kindOf(two), DesignKind.door);
      final r1 = regionOf(d, one), r2 = regionOf(d, two);
      final hinge1 = d.hardware.firstWhere(
        (h) => h.parentId == one.id && h.kind == HardwareKind.hinge,
      );
      final hinge2 = d.hardware.firstWhere(
        (h) => h.parentId == two.id && h.kind == HardwareKind.hinge,
      );
      expect(hinge1.at.x, closeTo(r1.left, 1e-6));
      expect(hinge2.at.x, closeTo(r2.right, 1e-6));
    });

    test('the rail divides Opening 1 into raked glass above and a square '
        'panel below, 40 cm off the sill; the stile divides Opening 2 into '
        'raked glass and a square panel, and runs from the sill to the '
        'slope', () {
      final d = built();
      final one = opening(d, 'one'), two = opening(d, 'two');
      final rail = d.dividerById('rail')!;
      expect(rail.isHorizontal, isTrue);
      expect(regionOf(d, one).bottom - rail.a.y, closeTo(400, 1e-6));
      final stile = d.dividerById('stile')!;
      expect(stile.isVertical, isTrue);
      final slope = regionOf(d, two).edges.singleWhere(
        (e) => (e.a.x - e.b.x).abs() > 1 && (e.a.y - e.b.y).abs() > 1,
      );
      final top = stile.a.y < stile.b.y ? stile.a : stile.b;
      expect(slope.distanceTo(top), lessThan(1e-6));
      expect(glassOf(d, one).outline.bottom, lessThan(rail.a.y));
      expect(panelOf(d, two).outline.right, lessThan(stile.a.x));
    });
  });

  group('in the solid', () {
    test('shut, every bar and pane of each opening is inside its own region; '
        'swung, the openings move and nothing else does', () {
      final d = built();
      final shut = MeshBuilder.build(d);
      final open = MeshBuilder.build(d, openFraction: 1);
      final one = opening(d, 'one'), two = opening(d, 'two');
      final inside = <String, OpeningElement>{
        for (final o in [one, two])
          for (final e in d.contentsOf(o)) e.id: o,
        one.sectionId: one,
        two.sectionId: two,
      };

      for (final f in shut.facets) {
        final o = inside[f.elementId];
        if (o == null) continue;
        final e = d.elementById(f.elementId);
        if (e is HardwareElement) continue; // ironmongery stands proud
        for (final c in f.corners) {
          expect(
            within(regionOf(d, o), Vec2(c.x, c.y), slack: 1),
            isTrue,
            reason: '${f.elementId} at $c',
          );
        }
      }

      String print(Facet f) => [
        f.elementId,
        for (final c in f.corners)
          '${c.x.toStringAsFixed(4)},${c.y.toStringAsFixed(4)},'
              '${c.z.toStringAsFixed(4)}',
      ].join(';');
      final still = [
        for (final f in shut.facets)
          if (!inside.containsKey(f.elementId)) print(f),
      ];
      final stillOpen = [
        for (final f in open.facets)
          if (!inside.containsKey(f.elementId)) print(f),
      ];
      expect(stillOpen, still, reason: 'nothing outside the openings moves');
      for (final id in ['rail', 'stile']) {
        final a = [
          for (final f in shut.facets)
            if (f.elementId == id) print(f),
        ];
        final b = [
          for (final f in open.facets)
            if (f.elementId == id) print(f),
        ];
        expect(a, isNotEmpty);
        expect(b, isNot(a), reason: '$id swings with its opening');
      }
    });
  });

  group('every edit that reshapes an opening keeps all of it', () {
    test('the mullion beside Opening 2 moved either way: the stile still '
        'meets the slope, the glass and panel are still there, and the '
        'rail in Opening 1 has not moved', () {
      final d = built();
      final two = opening(d, 'two');
      final mullion = d.topLevelDividers.reduce(
        (a, b) => a.a.x > b.a.x ? a : b,
      );
      for (final by in [-150.0, 150.0]) {
        final moved = DesignEdits.moveDivider(d, mullion.id, Vec2(by, 0));
        expectEveryRelationship(moved, when: 'mullion $by');
        expect(
          moved.dividerById('rail')!.segment.a.y,
          d.dividerById('rail')!.segment.a.y,
        );
        expect(
          panelSize(moved, opening(moved, 'one'), down: true),
          closeTo(panelSize(d, opening(d, 'one'), down: true), 1e-6),
        );
        expect(regionOf(moved, opening(moved, 'two')), isNot(regionOf(d, two)));
      }
    });

    test('the mullion beside Opening 1 moved: its rail stays 40 cm off the '
        'sill, so its panel keeps its height, and runs from jamb to '
        'mullion', () {
      final d = built();
      final mullion = d.topLevelDividers.reduce(
        (a, b) => a.a.x < b.a.x ? a : b,
      );
      for (final by in [-150.0, 150.0]) {
        final moved = DesignEdits.moveDivider(d, mullion.id, Vec2(by, 0));
        expectEveryRelationship(moved, when: 'mullion $by');
        final one = opening(moved, 'one');
        expect(
          regionOf(moved, one).bottom - moved.dividerById('rail')!.a.y,
          closeTo(400, 1e-6),
        );
        expect(
          panelSize(moved, one, down: true),
          closeTo(panelSize(d, opening(d, 'one'), down: true), 1e-6),
        );
      }
    });

    test('each jamb made taller and shorter: the slope moves, the openings '
        'follow it, and every divider, pane and piece of ironmongery is '
        'still the opening\'s and inside it', () {
      final d = built();
      for (final side in FrameSides.of(d)) {
        for (final by in [-200.0, 300.0]) {
          final outcome = Measurements.apply(d, {
            side.key: side.lengthOn(d.frame!.outline) + by,
          });
          expect(outcome.ok, isTrue, reason: '${side.label} $by');
          expectEveryRelationship(outcome.design, when: '${side.label} $by');
          // The rail met no slope, so it is where it was.
          expect(
            outcome.design.dividerById('rail')!.segment.a.y,
            closeTo(d.dividerById('rail')!.segment.a.y, 1e-6),
          );
        }
      }
    });

    test('the overall height and width: the sill taken down takes the rail '
        'with it, so the panel keeps its height; made wider, the stile '
        'still meets the slope', () {
      final d = built();
      final taller = Measurements.apply(d, {
        Measurements.heightKey: 2300,
      }).design;
      expectEveryRelationship(taller, when: 'taller');
      expect(
        panelSize(taller, opening(taller, 'one'), down: true),
        closeTo(panelSize(d, opening(d, 'one'), down: true), 1e-6),
      );
      final wider = Measurements.apply(d, {Measurements.widthKey: 2800}).design;
      expectEveryRelationship(wider, when: 'wider');
    });

    test('Opening 1 moved into the light under the apex: its rail, glass, '
        'panel and ironmongery go with it, and the light it left is one '
        'fixed light again', () {
      final d = built();
      final one = opening(d, 'one');
      final apex = d.topLevelSections.singleWhere(
        (s) => d.openingOf(s.id) == null,
      );
      final left = one.sectionId;
      final moved = DesignEdits.moveOpeningToSection(d, one.id, apex.id);
      final now = opening(moved, 'one');
      expect(now.sectionId, apex.id);
      final region = regionOf(moved, now);
      expect(region.corners, hasLength(5), reason: 'two slopes and an apex');
      final rail = moved.dividerById('rail')!;
      expect(moved.openingHolding(rail.parentId)?.id, one.id);
      expect(region.holds(rail.segment, reach: 0.5), isTrue);
      expect(region.bottom - rail.a.y, closeTo(400, 1e-6));
      expect(moved.childSectionsOf(now.sectionId), hasLength(2));
      expect(panelOf(moved, now).finish, PanelColour.white.finish);
      expect(moved.childSectionsOf(left), isEmpty);
      for (final h in moved.hardware.where((h) => h.parentId == one.id)) {
        expect(within(region, h.at, slack: 1), isTrue);
      }
      expect(GeometryNormalizer.validateAngledGeometry(moved), isEmpty);
    });

    test('saved and loaded, and read from the sheet again: the same', () {
      final d = built();
      final text = jsonEncode(d.toJson());
      final loaded = Design.fromJson(jsonDecode(text));
      expect(jsonEncode(loaded.toJson()), text);
      expectEveryRelationship(loaded, when: 'loaded');
      final again = read(d);
      expectEveryRelationship(again, when: 'read again');
      for (final id in ['rail', 'stile']) {
        expect(again.dividerById(id)!.segment, d.dividerById(id)!.segment);
      }
    });
  });

  group('the carry is measured from the sides that bound a region square', () {
    test('on a rectangle it is the box\'s proportion, exactly as before', () {
      final a = Polygon.rect(100, 200, 800, 1200);
      final b = Polygon.rect(150, 100, 1000, 1500);
      for (final p in const [Vec2(100, 200), Vec2(500, 800), Vec2(900, 1400)]) {
        final expected = Vec2(
          b.left + (p.x - a.left) * b.width / a.width,
          b.top + (p.y - a.top) * b.height / a.height,
        );
        expect(a.sameIn(b, p).distanceTo(expected), lessThan(1e-9));
      }
      const line = Segment(Vec2(100, 700), Vec2(900, 700));
      final carried = a.lineIn(b, line, onEdge: 1);
      expect(carried.a, a.sameIn(b, line.a));
      expect(carried.b, a.sameIn(b, line.b));
    });

    test('on a raked light it follows the sill, not the box: a light whose '
        'slope now meets the bar beside it lower carries nothing down', () {
      const was = Polygon([
        Vec2(0, 400),
        Vec2(800, 0),
        Vec2(800, 2000),
        Vec2(0, 2000),
      ]);
      const now = Polygon([
        Vec2(0, 400),
        Vec2(1000, -100),
        Vec2(1000, 2000),
        Vec2(0, 2000),
      ]);
      expect(was.sameIn(now, const Vec2(400, 1600)).y, 1600);
      expect(was.sameIn(now, const Vec2(400, 1600)).x, 500);
      // An upright dropped from the slope still meets it.
      const upright = Segment(Vec2(400, 200), Vec2(400, 2000));
      final carried = was.lineIn(now, upright, onEdge: 1);
      expect(carried.a.x, 500);
      expect(now.edges[0].distanceTo(carried.a), lessThan(1e-9));
      expect(carried.b, const Vec2(500, 2000));
    });
  });
}
