import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 4}) {
  final random = math.Random(_n + 23);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 14; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 14);
      samples.add(StrokeSample(Vec2(
        at.x + (random.nextDouble() - 0.5) * wobble * 2,
        at.y + (random.nextDouble() - 0.5) * wobble * 2,
      )));
    }
  }
  samples.add(StrokeSample(through.last));
  return Stroke(id: 'stroke-${_n++}', samples: samples);
}

Design sketchOf(List<Stroke> strokes) {
  final at = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: strokes),
  );
}

/// The design from the specification:
///
/// ```
/// ┌──────────────────────┐
/// │       FIXED          │
/// ├──────────────────────┤
/// │        >             │
/// │                      │
/// │   ─────────────────  │
/// │                      │
/// │   ─────────────────  │
/// └──────────────────────┘
/// ```
///
/// The transom is drawn on the sheet, so it divides the design. The mark
/// makes the region below it the opening. The two lines inside the opening
/// are put there with the line tool, which is how a line becomes an
/// opening's: a line drawn on the sheet divides the design, because reading
/// it as anything else is how an opening grows to swallow what is beside it.
Design fixedOverOpening() {
  final read = SketchInterpreter.interpret(sketchOf([
    drawn(const [
      Vec2(0, 0),
      Vec2(1600, 0),
      Vec2(1600, 2400),
      Vec2(0, 2400),
      Vec2(0, 0),
    ]),
    drawn(const [Vec2(0, 620), Vec2(1600, 620)]),
    drawn(const [Vec2(400, 900), Vec2(560, 1000), Vec2(400, 1100)]),
  ])).design;

  final opening = read.openings.single.sectionId;
  final box = read.sectionById(opening)!.outline;
  var design = DesignEdits.addLineInside(read, opening,
      id: 'inner-a', at: Vec2(box.centroid.x, box.top + 730), horizontal: true);
  design = DesignEdits.addLineInside(design, opening,
      id: 'inner-b', at: Vec2(box.centroid.x, box.top + 1280), horizontal: true);
  return design;
}

void main() {
  setUp(() => _n = 0);

  group('the marked region is the opening, and it keeps what is in it', () {
    test('there are two main divisions, not four', () {
      final design = fixedOverOpening();

      expect(design.topLevelSections, hasLength(2),
          reason: 'the fixed light above, and the opening below');
      expect(design.topLevelDividers, hasLength(1),
          reason: 'only the transom divides the design itself');
    });

    test('the opening is the whole region below the transom', () {
      final design = fixedOverOpening();
      expect(design.openings, hasLength(1));

      final opening = design.sectionById(design.openings.single.sectionId)!;
      expect(opening.parentId, isNull, reason: 'it is a main division');
      // It runs from the transom right down to the sill, through both of the
      // lines drawn inside it.
      expect(opening.outline.top, closeTo(620, 40));
      expect(opening.outline.bottom, closeTo(2400 - 60, 60));
      expect(opening.heightMm, greaterThan(1600));
    });

    test('the lines drawn inside it belong to it', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;

      final inside = design.childDividersOf(opening.id);
      expect(inside, hasLength(2),
          reason: 'both lines drawn after the mark are the opening\'s');
      for (final bar in inside) {
        expect(bar.isInternal, isTrue);
        expect(bar.parentId, opening.id);
      }
    });

    test('they do not become main divisions', () {
      final design = fixedOverOpening();
      for (final section in design.topLevelSections) {
        expect(section.heightMm, greaterThan(400),
            reason: 'a slice made by an internal line has appeared at the '
                'top level');
      }
      expect(design.topLevelSections, hasLength(2));
    });

    test('the opening is divided inside itself', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;

      final panes = design.childSectionsOf(opening.id);
      expect(panes, hasLength(3),
          reason: 'two lines inside the opening make three panes of it');
      for (final pane in panes) {
        expect(pane.parentId, opening.id);
        expect(opening.outline.contains(pane.outline.centroid), isTrue);
      }
      expect(design.hasChildren(opening.id), isTrue);
    });

    test('the fixed light above is untouched and has nothing in it', () {
      final design = fixedOverOpening();
      final fixed = design.topLevelSections
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

      expect(design.openingOf(fixed.id), isNull);
      expect(design.childDividersOf(fixed.id), isEmpty);
      expect(design.hasChildren(fixed.id), isFalse);
      expect(fixed.heightMm, closeTo(560, 60));
    });

    test('the whole tree reads the way the specification draws it', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;

      expect(design.descendantsOf(opening.id), hasLength(5),
          reason: 'two lines and the three panes they make');
      final fixed = design.topLevelSections.firstWhere((s) => s.id != opening.id);
      expect(design.descendantsOf(fixed.id), isEmpty);
    });
  });

  group('a single leaf, and the bars inside it', () {
    /// ```
    /// ┌──────────────────────┐
    /// │         >            │
    /// │──────────────────────│ ← put in with the line tool
    /// │──────────────────────│ ← put in with the line tool
    /// └──────────────────────┘
    /// ```
    Design wholeFrame() {
      final read = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2400),
          Vec2(0, 2400),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(500, 400), Vec2(660, 500), Vec2(500, 600)]),
      ])).design;

      final opening = read.openings.single.sectionId;
      final box = read.sectionById(opening)!.outline;
      final once = DesignEdits.addLineInside(read, opening,
          id: 'a', at: Vec2(box.centroid.x, box.top + 1000), horizontal: true);
      return DesignEdits.addLineInside(once, opening,
          id: 'b', at: Vec2(box.centroid.x, box.top + 1700), horizontal: true);
    }

    test('a mark in a frame with nothing else in it opens the daylight', () {
      // Nothing divides this design, so the section the mark is in *is* the
      // whole daylight. That is the smallest region holding the mark, not an
      // opening grown to fit the window.
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2400),
          Vec2(0, 2400),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(500, 400), Vec2(660, 500), Vec2(500, 600)]),
      ])).design;

      expect(design.topLevelSections, hasLength(1));
      expect(design.openings, hasLength(1));
      expect(design.topLevelDividers, isEmpty);
    });

    test('lines drawn on the sheet divide it instead', () {
      // The same design with two lines drawn on the sheet. They are
      // divisions of the design, and the mark opens the one region it is in
      // — never all three.
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 2400),
          Vec2(0, 2400),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(500, 400), Vec2(660, 500), Vec2(500, 600)]),
        drawn(const [Vec2(0, 1000), Vec2(1600, 1000)]),
        drawn(const [Vec2(0, 1700), Vec2(1600, 1700)]),
      ])).design;

      expect(design.topLevelSections, hasLength(3));
      expect(design.openings, hasLength(1));
      final opening = design.sectionById(design.openings.single.sectionId)!;
      expect(opening.outline.bottom, lessThan(1100),
          reason: 'the mark is in the top band, so the top band opens');
      expect(opening.areaMmSq, lessThan(design.frame!.innerOutline.area * 0.6));
    });

    test('bars put inside the leaf do not cancel or terminate it', () {
      final design = wholeFrame();
      final opening = design.sectionById(design.openings.single.sectionId)!;

      expect(design.topLevelDividers, isEmpty);
      expect(design.childDividersOf(opening.id), hasLength(2));
      expect(design.childSectionsOf(opening.id), hasLength(3));

      // The opening continues through both bars: every pane it is divided
      // into is inside it, top to bottom.
      final panes = design.childSectionsOf(opening.id)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(panes.first.outline.top, closeTo(opening.outline.top, 2));
      expect(panes.last.outline.bottom, closeTo(opening.outline.bottom, 2));
    });
  });

  group('the model follows the same hierarchy', () {
    /// Where every face belonging to [elementId] sits.
    ({double left, double right, double top, double bottom, double z}) boxOf(
      Design design,
      String elementId, {
      double openFraction = 0,
    }) {
      var left = 1e9, right = -1e9, top = 1e9, bottom = -1e9, z = 0.0;
      for (final facet in
          MeshBuilder.build(design, openFraction: openFraction).facets) {
        if (facet.elementId != elementId) continue;
        for (final c in facet.corners) {
          if (c.x < left) left = c.x;
          if (c.x > right) right = c.x;
          if (c.y < top) top = c.y;
          if (c.y > bottom) bottom = c.y;
          if (c.z.abs() > z.abs()) z = c.z;
        }
      }
      return (left: left, right: right, top: top, bottom: bottom, z: z);
    }

    test('the opening contains its bars and its panes, not the design', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final mesh = MeshBuilder.build(design);

      // The opening's own leaf, the two bars inside it, and the three panes
      // they make — and nothing standing in for the opening as a whole.
      expect(
        {for (final f in mesh.facets) if (f.role == FacetRole.sash) f.elementId},
        {opening.id},
      );
      // Every bar in the drawing, once each: the transom that divides the
      // design, and the two drawn inside the opening.
      final bars = {
        for (final f in mesh.facets) if (f.role == FacetRole.bar) f.elementId,
      };
      expect(bars, {for (final d in design.dividers) d.id});
      expect(bars, hasLength(3));

      final panes = {
        for (final f in mesh.facets)
          if (f.role == FacetRole.glazing || f.role == FacetRole.panel)
            f.elementId,
      };
      expect(panes, {
        for (final s in design.childSectionsOf(opening.id)) s.id,
        design.topLevelSections.firstWhere((s) => s.id != opening.id).id,
      });
      // The opening itself is not glazed: what is inside it fills it.
      expect(panes.contains(opening.id), isFalse);
    });

    test('everything inside the leaf swings with the leaf', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final inside = design.childDividersOf(opening.id);
      final panes = design.childSectionsOf(opening.id);

      for (final part in [...inside.map((d) => d.id), ...panes.map((s) => s.id)]) {
        final shut = boxOf(design, part);
        final open = boxOf(design, part, openFraction: 1);
        expect(open.z.abs(), greaterThan(shut.z.abs() + 100),
            reason: 'the internal part $part stayed behind on the frame');
      }
    });

    test('the fixed light does not swing with it', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final fixed =
          design.topLevelSections.firstWhere((s) => s.id != opening.id);

      final shut = boxOf(design, fixed.id);
      final open = boxOf(design, fixed.id, openFraction: 1);
      expect(open.z, closeTo(shut.z, 0.01));
      expect(open.left, closeTo(shut.left, 0.01));
    });

    test('the internal bars hinge on the same edge as their leaf', () {
      final design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final bar = design.childDividersOf(opening.id).first;

      // Hinged left by the `>`. Measured part way open, where the geometry
      // still reads: the end near the hinge barely moves, the far end comes
      // away. At a full right angle every point projects onto the hinge
      // line, which is correct but says nothing about which edge it was.
      final shut = boxOf(design, bar.id);
      final open = boxOf(design, bar.id, openFraction: 0.35);
      final span = shut.right - shut.left;

      expect((open.left - shut.left).abs(), lessThan(span * 0.08),
          reason: 'the hinged end of the bar moved');
      expect(shut.right - open.right, greaterThan(span * 0.1),
          reason: 'the free end of the bar did not come away');
    });

    test('moving the opening takes its contents with it', () {
      var design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final bar = design.childDividersOf(opening.id).first;
      final before = bar.a.y;

      // The transom above the opening is what bounds it, so moving that
      // moves the opening — and everything in it must come along.
      final transom = design.topLevelDividers.single;
      design = DesignEdits.moveDividerAcross(
        design,
        transom.id,
        Vec2(transom.segment.midpoint.x, transom.segment.midpoint.y - 300),
      );

      final moved = design.dividers.firstWhere((d) => d.id == bar.id);
      expect(moved.a.y, lessThan(before - 100),
          reason: 'the bar inside the opening was left behind');
      expect(moved.parentId, opening.id);

      // And it is still inside the opening it belongs to.
      final grown = design.sectionById(opening.id)!;
      expect(grown.outline.contains(moved.segment.midpoint), isTrue);
      expect(design.childSectionsOf(opening.id), hasLength(3));
    });

    test('the fixed light keeps its own contents — it has none', () {
      var design = fixedOverOpening();
      final opening = design.sectionById(design.openings.single.sectionId)!;
      final fixed =
          design.topLevelSections.firstWhere((s) => s.id != opening.id);

      final transom = design.topLevelDividers.single;
      design = DesignEdits.moveDividerAcross(
        design,
        transom.id,
        Vec2(transom.segment.midpoint.x, transom.segment.midpoint.y + 200),
      );

      expect(design.childDividersOf(fixed.id), isEmpty);
      expect(design.childDividersOf(opening.id), hasLength(2));
    });
  });

  group('lines drawn before a mark still divide the design', () {
    test('a mullion drawn first is a main division, not an opening\'s', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 1400),
          Vec2(0, 1400),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(700, 0), Vec2(700, 1400)]),
        drawn(const [Vec2(1100, 500), Vec2(1260, 620), Vec2(1100, 740)]),
      ])).design;

      expect(design.topLevelSections, hasLength(2));
      expect(design.topLevelDividers, hasLength(1));

      final opening = design.sectionById(design.openings.single.sectionId)!;
      expect(opening.outline.left, greaterThan(700));
      expect(design.childDividersOf(opening.id), isEmpty);
    });
  });
}
