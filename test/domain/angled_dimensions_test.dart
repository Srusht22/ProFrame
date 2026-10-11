import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/frame_sides.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'an_under_stair_design_test.dart' as under;
import 'geometry_normalizer_test.dart' show pen;

// Dimensions on a design that is not a rectangle. The brief's own:
//
//   ┌╲
//   │  ╲            left 200 cm, right 150 cm, 100 cm wide: three figures,
//   │    │          each measured on the side that is there, none made
//   │    │          equal to another
//   └────┘
//
// drawn with a transom, a mullion from the slope down to it and a `>` in
// the light below, a line in the opening making glass over a panel. Then
// its sides are given sizes — the right side 150 → 170 cm among them — and
// each time the right edge changes, the slope stays a slope, and every
// other figure is what it was.

/// The outline: the left side 200 cm, the head sloping down to a right side
/// of 150 cm, 100 cm across.
const sloped = [
  Vec2(0, 2000),
  Vec2(0, 0),
  Vec2(1000, 500),
  Vec2(1000, 2000),
  Vec2(0, 2000),
];

Design read(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

/// The design as drawn and read: the frame, a transom at 120 cm down, a
/// mullion from the slope to the transom, the light below marked `>` and
/// divided 40 cm up from its sill, glass above and a white panel below.
Design drawn() {
  var d = read(
    Design.empty(id: 'angled', kind: DesignKind.angled).copyWith(
      name: 'Sloped head',
      sketch: Sketch(
        strokes: [
          pen('outline', sloped),
          pen('transom', const [Vec2(0, 1200), Vec2(1000, 1200)]),
          pen('mullion', const [Vec2(500, 250), Vec2(500, 1200)]),
          pen('mark', chevron(const Vec2(500, 1600))),
        ],
      ),
    ),
  ).copyWith(measured: {});
  final opening = d.openings.single;
  final region = d.sectionById(opening.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(region.centroid.x, region.bottom - 400),
    horizontal: true,
  );
  final lower = d
      .childSectionsOf(opening.sectionId)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return d.withElement(lower.copyWith(finish: PanelColour.white.finish));
}

FrameSide sideCalled(Design d, String label) =>
    FrameSides.of(d).singleWhere((s) => s.label == label);

/// The corner of [d]'s frame nearest [p].
Vec2 corner(Design d, Vec2 p) => d.frame!.outline.corners.reduce(
  (a, b) => a.distanceTo(p) < b.distanceTo(p) ? a : b,
);

/// The upright edge of [d]'s frame nearest [x], as its length.
double heightAt(Design d, double x) {
  final edge = d.frame!.outline.edges
      .where((e) => e.a.x == e.b.x)
      .reduce((a, b) => (a.a.x - x).abs() < (b.a.x - x).abs() ? a : b);
  return (edge.a.y - edge.b.y).abs();
}

/// The one edge of [d]'s frame that is neither level nor upright.
Segment slopeOf(Design d) =>
    d.frame!.outline.edges.singleWhere((e) => e.a.x != e.b.x && e.a.y != e.b.y);

DividerElement bar(Design d, String strokeId) =>
    d.dividers.singleWhere((b) => b.fromStrokeId == strokeId);

void expectNear(Vec2 a, Vec2 b, {String? reason}) {
  expect(a.distanceTo(b), lessThan(1e-6), reason: '$a against $b ($reason)');
}

void expectSameSegment(Segment a, Segment b, {String? reason}) {
  expectNear(a.a, b.a, reason: reason);
  expectNear(a.b, b.b, reason: reason);
}

void expectSameCorners(List<Vec2> a, List<Vec2> b, {String? reason}) {
  expect(a, hasLength(b.length), reason: reason);
  for (var i = 0; i < a.length; i++) {
    expectNear(a[i], b[i], reason: reason);
  }
}

/// Every figure the drawing writes, by what it is.
List<ChainRun> runsOf(Design d, ChainRunOf of) => [
  for (final c in DimensionChains.of(d))
    for (final r in c.runs)
      if (r.of == of) r,
];

Design give(Design d, Map<String, double> values) {
  final outcome = Measurements.apply(d, values);
  expect(outcome.ok, isTrue, reason: '$values: ${outcome.problems}');
  return outcome.design;
}

/// The same design with every line and section where it is — the figures
/// that must not change when one side is given a size.
void expectTheRestTheSame(Design before, Design after, {String? reason}) {
  for (final id in ['transom', 'mullion']) {
    final was = bar(before, id), now = bar(after, id);
    // A bar keeps its line; only an end that met the moving side may move
    // along it.
    expect(now.segment.unit.cross(was.segment.unit).abs(), lessThan(1e-9));
    expect(
      Segment(was.a, was.b).distanceTo(now.segment.midpoint),
      lessThan(1e-6),
      reason: '$id stays on its line ($reason)',
    );
  }
  expectSameSegment(
    after.dividerById('inside')!.segment,
    before.dividerById('inside')!.segment,
    reason: 'the line inside the opening ($reason)',
  );
  final opening = before.openings.single;
  expect(after.openings.single.id, opening.id);
  expect(after.openings.single.sectionId, opening.sectionId);
  expectSameCorners(
    after.sectionById(opening.sectionId)!.outline.corners,
    before.sectionById(opening.sectionId)!.outline.corners,
    reason: 'the opening below the transom ($reason)',
  );
  expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
}

void main() {
  group('the brief\'s three figures are three figures', () {
    test('left 200, right 150, 100 wide: the overall height is the left '
        'side, the right side has its own figure, and neither is made the '
        'other', () {
      final d = drawn();
      expect(heightAt(d, 0), 2000);
      expect(heightAt(d, 1000), 1500);
      expect(d.frame!.outline.width, 1000);

      final sizes = {for (final m in Measurements.of(d)) m.label: m};
      expect(sizes['Overall width']!.currentMm(d), 1000);
      expect(sizes['Overall height']!.currentMm(d), 2000);
      final right = sizes['Right jamb height']!;
      expect(right.currentMm(d), 1500);
      expect(right.asked, isTrue, reason: 'a size of its own, asked for');
      expect(right.axis, MeasureAxis.down);
      // The left side runs the whole height, so it is the overall figure,
      // not a second figure saying the same thing.
      expect(sizes.containsKey('Left jamb height'), isFalse);

      // On the drawing: the width along the foot, the height down the
      // left, the right side down the right — measured on the edge itself.
      final overall = runsOf(d, ChainRunOf.overall);
      expect([
        for (final r in overall) r.valueMm,
      ], unorderedEquals([1000, 2000]));
      final sides = DimensionChains.of(d)
          .where((c) => c.runs.first.of == ChainRunOf.side)
          .toList();
      expect(sides, hasLength(1));
      expect(sides.single.side, DimensionSide.right);
      expect(sides.single.runs.single.fromMm, 500);
      expect(sides.single.runs.single.toMm, 2000);
      expect(sides.single.runs.single.sideLabel, 'Right jamb height');
    });

    test('a slope is not a side: it joins the sides, and nothing claims a '
        'size for it that the edges do not have', () {
      final d = drawn();
      final slope = slopeOf(d);
      for (final side in FrameSides.of(d)) {
        final edge = d.frame!.outline.edges[side.edge];
        expect(edge, isNot(slope));
        expect(edge.a.x == edge.b.x || edge.a.y == edge.b.y, isTrue);
      }
      // Every figure on the drawing is an edge or a section that is there.
      for (final c in DimensionChains.of(d)) {
        for (final r in c.runs) {
          if (r.of != ChainRunOf.side) continue;
          final side = FrameSides.of(d).singleWhere((s) => s.key == r.sideKey);
          expect(r.valueMm, side.lengthOn(d.frame!.outline));
        }
      }
    });

    test('until given, the side is `?`, as every size is; once given, its '
        'figure', () {
      final d = drawn();
      final key = sideCalled(d, 'Right jamb height').key;
      expect(Measurements.knowsMeasure(d, key), isFalse);
      final given = give(d, {key: 1500});
      expect(Measurements.knowsMeasure(given, key), isTrue);
      expect(Measurements.complete(given), isFalse, reason: 'others still');
    });

    test('every asked size given, the design is complete — the side among '
        'them — and nothing moved that was given its own size', () {
      final d = drawn();
      final given = give(d, {
        for (final m in Measurements.of(d))
          if (m.asked) m.key: m.currentMm(d),
      });
      expect(Measurements.complete(given), isTrue);
      expect(heightAt(given, 0), 2000);
      expect(heightAt(given, 1000), 1500);
    });
  });

  group('the right side, 150 → 170 cm', () {
    test('the right edge changes, the left does not, the width does not, and '
        'the head is still a slope — running from the left side\'s top to '
        'the right side\'s new top', () {
      final d = drawn();
      final side = sideCalled(d, 'Right jamb height');
      final after = give(d, {side.key: 1700});

      expect(heightAt(after, 1000), closeTo(1700, 1e-9));
      expect(heightAt(after, 0), 2000);
      expect(after.frame!.outline.width, 1000);
      expect(after.frame!.outline.height, 2000);
      expect(corner(after, const Vec2(0, 0)), const Vec2(0, 0));
      expect(corner(after, const Vec2(0, 2000)), const Vec2(0, 2000));
      expect(corner(after, const Vec2(1000, 2000)), const Vec2(1000, 2000));
      expect(corner(after, const Vec2(1000, 300)), const Vec2(1000, 300));
      final slope = slopeOf(after);
      expect(slope.offAxisDegrees, greaterThan(10));
      expect({slope.a, slope.b}, {const Vec2(0, 0), const Vec2(1000, 300)});
      expect(after.frame!.outline.corners, hasLength(4));
    });

    test('everything else stays connected: the mullion still reaches the '
        'slope, at its own place; the transom, the opening and the line '
        'inside it are where they were', () {
      final d = drawn();
      final after = give(d, {sideCalled(d, 'Right jamb height').key: 1700});
      expectTheRestTheSame(d, after, reason: '170');

      final mullion = bar(after, 'mullion');
      expect(mullion.a.x, 500);
      expect(mullion.b.x, 500);
      final top = mullion.a.y < mullion.b.y ? mullion.a : mullion.b;
      expect(slopeOf(after).distanceTo(top), lessThan(1e-6));
      expect(top.y, closeTo(150, 1e-9), reason: 'half way along the slope');

      // The two lights above the transom keep their widths; only their
      // tops follow the slope.
      final upper = [
        for (final s in after.topLevelSections)
          if (s.outline.bottom < 1200) s,
      ]..sort((a, b) => a.outline.left.compareTo(b.outline.left));
      final upperBefore = [
        for (final s in d.topLevelSections)
          if (s.outline.bottom < 1200) s,
      ]..sort((a, b) => a.outline.left.compareTo(b.outline.left));
      for (var i = 0; i < 2; i++) {
        expect(
          upper[i].outline.left,
          closeTo(upperBefore[i].outline.left, 1e-6),
        );
        expect(
          upper[i].outline.right,
          closeTo(upperBefore[i].outline.right, 1e-6),
        );
        expect(
          upper[i].outline.bottom,
          closeTo(upperBefore[i].outline.bottom, 1e-6),
        );
        expect(upper[i].id, upperBefore[i].id);
      }
    });

    test('every other figure is what it was', () {
      final d = drawn();
      final before = {
        for (final m in Measurements.of(d)) m.key: m.currentMm(d),
      };
      final key = sideCalled(d, 'Right jamb height').key;
      final after = give(d, {key: 1700});
      for (final m in Measurements.of(after)) {
        if (m.key == key) {
          expect(m.currentMm(after), closeTo(1700, 1e-9));
          continue;
        }
        // The upper lights' heights are read off their tallest point, and
        // the slope above them moved: that is the change, followed.
        final s = after.sectionById(m.sectionId ?? '');
        if (s != null &&
            s.outline.bottom < 1200 &&
            m.axis == MeasureAxis.down) {
          continue;
        }
        expect(
          m.currentMm(after),
          closeTo(before[m.key]!, 1e-6),
          reason: m.label,
        );
      }
    });

    test('on the drawing, the right side reads 170.0 cm and the overall '
        'figures what they were', () {
      final d = drawn();
      final key = sideCalled(d, 'Right jamb height').key;
      final after = give(d, {
        Measurements.widthKey: 1000,
        Measurements.heightKey: 2000,
        key: 1700,
      });
      final side = runsOf(after, ChainRunOf.side).single;
      expect(side.valueMm, closeTo(1700, 1e-9));
      expect(Measurements.knowsMeasure(after, key), isTrue);
      expect(
        Measurements.figure(side.valueMm, known: true, places: 1),
        '170.0 cm',
      );
      expect([
        for (final r in runsOf(after, ChainRunOf.overall)) r.valueMm,
      ], unorderedEquals([1000, 2000]));
    });

    test('the solid is built on the new outline: its frame reaches the new '
        'top of the right side and no higher', () {
      final d = drawn();
      final after = give(d, {sideCalled(d, 'Right jamb height').key: 1700});
      final mesh = MeshBuilder.build(after);
      final frame = [
        for (final f in mesh.facets)
          if (f.elementId == after.frame!.id) f,
      ];
      expect(frame, isNotEmpty);
      final atRight = [
        for (final f in frame)
          for (final c in f.corners)
            if ((c.x - 1000).abs() < 1e-6) c.y,
      ];
      expect(atRight.reduce((a, b) => a < b ? a : b), closeTo(300, 1e-6));
    });

    test('read from the sheet again — the ink moved with the frame and the '
        'mullion — and saved and loaded, it is the same', () {
      final d = drawn();
      final after = give(d, {sideCalled(d, 'Right jamb height').key: 1700});
      final again = read(after);
      expect(again.frame!.outline.corners, after.frame!.outline.corners);
      for (final id in ['transom', 'mullion']) {
        expectSameSegment(
          bar(again, id).segment,
          bar(after, id).segment,
          reason: id,
        );
      }
      expectSameSegment(
        again.dividerById('inside')!.segment,
        after.dividerById('inside')!.segment,
      );
      expect(again.measured, after.measured);

      final text = jsonEncode(after.toJson());
      final loaded = Design.fromJson(jsonDecode(text));
      expect(jsonEncode(loaded.toJson()), text);
      expect(heightAt(loaded, 1000), closeTo(1700, 1e-9));
    });

    test('made shorter, 150 → 100 cm, the same: only the right edge and the '
        'slope above it change', () {
      final d = drawn();
      final after = give(d, {sideCalled(d, 'Right jamb height').key: 1000});
      expect(heightAt(after, 1000), closeTo(1000, 1e-9));
      expect(heightAt(after, 0), 2000);
      expect(slopeOf(after).offAxisDegrees, greaterThan(10));
      expectTheRestTheSame(d, after, reason: '100');
    });

    test('made much shorter, 150 → 50 cm — its top below the transom — '
        'the transom now meets the slope, at its own height, and nothing of '
        'the design is left outside the frame', () {
      final d = drawn();
      final after = give(d, {sideCalled(d, 'Right jamb height').key: 500});
      expect(heightAt(after, 1000), closeTo(500, 1e-9));
      final transom = bar(after, 'transom');
      expect(transom.a.y, 1200);
      expect(transom.b.y, 1200);
      final right = transom.a.x > transom.b.x ? transom.a : transom.b;
      expect(slopeOf(after).distanceTo(right), lessThan(1e-6));
      expect(right.x, closeTo(800, 1e-6));
      expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
      final again = read(after);
      expectSameSegment(bar(again, 'transom').segment, transom.segment);
    });

    test('a side shorter than the frame\'s own border is refused, and the '
        'design is as it was', () {
      final d = drawn();
      final key = sideCalled(d, 'Right jamb height').key;
      final outcome = Measurements.apply(d, {key: 100});
      expect(outcome.problems.keys, [key]);
      expect(outcome.design.frame!.outline, d.frame!.outline);
      expect(
        outcome.design.dividers.map((b) => b.segment),
        d.dividers.map((b) => b.segment),
      );
      expect(outcome.design.measured, isNot(contains(key)));
    });
  });

  group('the overall figures leave the sides their own', () {
    test('the overall height 200 → 220: the left side 220, the right side '
        'still 150 — the slope takes the difference, and stays a slope', () {
      final d = drawn();
      final after = give(d, {Measurements.heightKey: 2200});
      expect(heightAt(after, 0), closeTo(2200, 1e-9));
      expect(heightAt(after, 1000), closeTo(1500, 1e-9));
      expect(after.frame!.outline.width, 1000);
      expect(slopeOf(after).offAxisDegrees, greaterThan(10));
      expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
    });

    test('the overall width 100 → 120: both sides their own heights', () {
      final d = drawn();
      final after = give(d, {Measurements.widthKey: 1200});
      expect(after.frame!.outline.width, closeTo(1200, 1e-9));
      expect(heightAt(after, 0), 2000);
      expect(heightAt(after, 1200), closeTo(1500, 1e-9));
      expect(slopeOf(after).offAxisDegrees, greaterThan(10));
      expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
    });

    test('given together, in the form\'s order — 220 high, 120 wide, the '
        'right side 170 — each is exactly what was typed', () {
      final d = drawn();
      final key = sideCalled(d, 'Right jamb height').key;
      final after = give(d, {
        Measurements.heightKey: 2200,
        Measurements.widthKey: 1200,
        key: 1700,
      });
      expect(heightAt(after, 0), closeTo(2200, 1e-9));
      expect(heightAt(after, 1200), closeTo(1700, 1e-9));
      expect(after.frame!.outline.width, closeTo(1200, 1e-9));
      expect(after.frame!.outline.height, closeTo(2200, 1e-9));
      for (final k in [Measurements.heightKey, Measurements.widthKey, key]) {
        expect(after.measured, contains(k));
      }
    });

    test('a rectangle has no sides of its own, and its overall figures '
        'stretch the sheet as they always did', () {
      final rect = read(
        Design.empty(id: 'r', kind: DesignKind.window).copyWith(
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 0),
                Vec2(1000, 0),
                Vec2(1000, 2000),
                Vec2(0, 2000),
                Vec2(0, 0),
              ]),
              pen('transom', const [Vec2(0, 1000), Vec2(1000, 1000)]),
            ],
          ),
        ),
      );
      expect(FrameSides.of(rect), isEmpty);
      expect(runsOf(rect, ChainRunOf.side), isEmpty);
      final taller = give(rect, {Measurements.heightKey: 2200});
      expect(taller.frame!.outline.height, closeTo(2200, 1e-9));
      // Stretched: the transom moved with the sheet.
      expect(taller.dividers.single.a.y, greaterThan(1000));
    });
  });

  group('the window under a stair', () {
    test('its short jamb and its level head are figures of their own; the '
        'tall jamb is the overall height', () {
      final d = under.built();
      final labels = [for (final s in FrameSides.of(d)) s.label];
      expect(labels, unorderedEquals(['Left jamb height', 'Head width']));
      expect(sideCalled(d, 'Left jamb height').lengthOn(d.frame!.outline), 900);
      expect(sideCalled(d, 'Head width').lengthOn(d.frame!.outline), 1300);
      final chains = DimensionChains.of(d)
          .where((c) => c.runs.first.of == ChainRunOf.side)
          .toList();
      expect(
        {for (final c in chains) c.side},
        {DimensionSide.left, DimensionSide.top},
      );
    });

    test('the short jamb 90 → 110 cm: the slope steeper and still a slope, '
        'the tall jamb, the head, the mullion and the opening\'s line where '
        'they were', () {
      final d = under.built();
      final after = give(d, {sideCalled(d, 'Left jamb height').key: 1100});
      expect(heightAt(after, 0), closeTo(1100, 1e-9));
      expect(heightAt(after, 2800), 2200);
      expect(
        sideCalled(after, 'Head width').lengthOn(after.frame!.outline),
        closeTo(1300, 1e-9),
      );
      expect(slopeOf(after).offAxisDegrees, greaterThan(10));
      final mullion = after.topLevelDividers.single;
      expectSameSegment(mullion.segment, d.topLevelDividers.single.segment);
      expectSameSegment(
        after.dividerById('inside')!.segment,
        d.dividerById('inside')!.segment,
      );
      // The panel below the line is untouched; the glass above it is what
      // grew into the room the slope left.
      final opening = after.openings.single.sectionId;
      final panes = after.childSectionsOf(opening);
      final panel = panes.reduce(
        (a, b) => a.outline.top > b.outline.top ? a : b,
      );
      final panelBefore = d
          .childSectionsOf(opening)
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      expectSameCorners(panel.outline.corners, panelBefore.outline.corners);
      expect(panel.finish, PanelColour.white.finish);
      expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
    });

    test('the head 130 → 100 cm: its slope end moves along it, the mullion '
        'stays where it was drawn and now meets the slope, and the two '
        'lights keep their widths', () {
      final d = under.built();
      final after = give(d, {sideCalled(d, 'Head width').key: 1000});
      expect(
        sideCalled(after, 'Head width').lengthOn(after.frame!.outline),
        closeTo(1000, 1e-9),
      );
      expect(corner(after, const Vec2(1800, 200)), const Vec2(1800, 200));
      expect(heightAt(after, 0), 900);
      expect(heightAt(after, 2800), 2200);
      final mullion = after.topLevelDividers.single;
      expect(mullion.a.x, 1500);
      final top = mullion.a.y < mullion.b.y ? mullion.a : mullion.b;
      expect(slopeOf(after).distanceTo(top), lessThan(1e-6));
      final widths = [for (final s in after.topLevelSections) s.outline.width]
        ..sort();
      final widthsBefore = [for (final s in d.topLevelSections) s.outline.width]
        ..sort();
      for (var i = 0; i < widths.length; i++) {
        expect(widths[i], closeTo(widthsBefore[i], 1e-6));
      }
      expect(GeometryNormalizer.validateAngledGeometry(after), isEmpty);
    });

    test('read again after both, the same', () {
      final d = under.built();
      final after = give(d, {
        sideCalled(d, 'Left jamb height').key: 1100,
        sideCalled(d, 'Head width').key: 1000,
      });
      final again = read(after);
      expect(again.frame!.outline.corners, after.frame!.outline.corners);
      expectSameSegment(
        again.topLevelDividers.single.segment,
        after.topLevelDividers.single.segment,
      );
    });
  });

  group('the openings and the divisions inside them', () {
    test('the opening\'s figures are its own region, and its glass and '
        'panel figures its panes, on an angled design as on a square one', () {
      final d = drawn();
      final opening = d.sectionById(d.openings.single.sectionId)!;
      final runs = runsOf(d, ChainRunOf.opening);
      expect(
        runs.map((r) => r.valueMm),
        containsAll([opening.outline.width, opening.outline.height]),
      );
      final divisions = runsOf(d, ChainRunOf.division);
      final panes = d.childSectionsOf(opening.id);
      expect(
        divisions.map((r) => r.sectionId).toSet(),
        containsAll(panes.map((p) => p.id)),
      );
    });

    test('the glass in the opening given a height: the line moves, the '
        'frame\'s sides and the slope do not', () {
      final d = drawn();
      final glass = Measurements.of(d).singleWhere((m) => m.key == 'y:inside');
      final after = give(d, {glass.key: glass.currentMm(d) - 100});
      expect(after.frame!.outline, d.frame!.outline);
      expect(heightAt(after, 1000), 1500);
      expect(
        after.dividerById('inside')!.a.y,
        closeTo(d.dividerById('inside')!.a.y - 100, 1),
      );
    });
  });

  group('a stepped frame', () {
    test('of a step and the jamb beyond it, which add up to the height, one '
        'is asked and the other follows', () {
      final stepped = read(
        Design.empty(id: 's', kind: DesignKind.angled).copyWith(
          sketch: Sketch(
            strokes: [
              pen('outline', const [
                Vec2(0, 0),
                Vec2(1000, 0),
                Vec2(1000, 800),
                Vec2(2000, 800),
                Vec2(2000, 2000),
                Vec2(0, 2000),
                Vec2(0, 0),
              ]),
            ],
          ),
        ),
      ).copyWith(measured: {});
      final sides = FrameSides.of(stepped);
      final asked = FrameSides.askedOf(stepped);
      final heights = [
        for (final s in sides)
          if (s.axis == MeasureAxis.down) s,
      ];
      expect(heights, hasLength(2));
      expect(heights.where((s) => asked.contains(s.edge)), hasLength(1));
      // The one asked, given, leaves the step's level edge level.
      final given = heights.firstWhere((s) => asked.contains(s.edge));
      final after = give(stepped, {
        given.key: given.lengthOn(stepped.frame!.outline) + 200,
      });
      for (final e in after.frame!.outline.edges) {
        expect(e.a.x == e.b.x || e.a.y == e.b.y, isTrue, reason: '$e');
      }
      expect(Polygon(after.frame!.outline.corners).isSimple, isTrue);
    });
  });
}
