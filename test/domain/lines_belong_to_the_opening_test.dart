import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 7}) {
  final random = math.Random(_n + 3);
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 16; i++) {
      final at = through[leg].lerp(through[leg + 1], i / 16);
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

// The phase's design: a 200 x 160 cm window, a mullion putting a 40 cm light
// down the left, a `<` in that light, and a line across it 40 cm down.
const frame = [
  Vec2(0, 0),
  Vec2(2000, 0),
  Vec2(2000, 1600),
  Vec2(0, 1600),
  Vec2(0, 0),
];
const mullion = [Vec2(400, 0), Vec2(400, 1600)];
const mark = [Vec2(280, 700), Vec2(140, 800), Vec2(280, 900)];
const inside = [Vec2(0, 400), Vec2(400, 400)];

/// The same design drawn in whatever order the strokes are given.
Design read(List<List<Vec2>> strokes) {
  _n = 0;
  return SketchInterpreter.interpret(
    sketchOf([for (final stroke in strokes) drawn(stroke)]),
  ).design;
}

SectionElement openingOf(Design design) =>
    design.sectionById(design.openings.single.sectionId)!;

void main() {
  group('a line inside an opening is the opening’s, whenever it was drawn',
      () {
    // The bug: marking the opening last — which is how anybody draws, the
    // design first and the instruction after it — left the line dividing the
    // whole design, cut the opening short, and put the line above it.
    final orders = <String, List<List<Vec2>>>{
      'the mark drawn before the line': [frame, mullion, mark, inside],
      'the mark drawn after the line': [frame, mullion, inside, mark],
      'the line drawn before the mullion': [frame, inside, mullion, mark],
      'the mark drawn between the two lines': [frame, mullion, mark, inside],
    };

    orders.forEach((order, strokes) {
      test('$order — the line is the opening’s', () {
        final design = read(strokes);

        expect(design.openings, hasLength(1));
        final opening = openingOf(design);

        // The mullion divides the design. The line inside does not.
        expect(design.topLevelSections, hasLength(2),
            reason: 'the line did not make a section of the design');
        expect(design.topLevelDividers, hasLength(1));

        final inner = design.childDividersOf(opening.id);
        expect(inner, hasLength(1),
            reason: 'the line belongs to the opening');
        expect(inner.single.parentId, opening.id);
        expect(design.childSectionsOf(opening.id), hasLength(2));
      });

      test('$order — the opening is not cut short by it', () {
        final design = read(strokes);
        final opening = openingOf(design);
        final frameOf = design.frame!.innerOutline;

        // The opening runs the full height of the light it is in: the line
        // divides it, it does not end it.
        expect(opening.heightMm, closeTo(frameOf.height, 2));
        expect(opening.outline.top, closeTo(frameOf.top, 2));
        expect(opening.outline.bottom, closeTo(frameOf.bottom, 2));
      });

      test('$order — the line is inside the opening, not above it', () {
        final design = read(strokes);
        final opening = openingOf(design);
        final bar = design.childDividersOf(opening.id).single;

        final middle = bar.segment.midpoint;
        expect(middle.y, greaterThan(opening.outline.top));
        expect(middle.y, lessThan(opening.outline.bottom));
        expect(middle.x, greaterThan(opening.outline.left - 1));
        expect(middle.x, lessThan(opening.outline.right + 1));
      });
    });

    test('marking before the divisions are drawn marks the whole design', () {
      // Nothing to argue with: at the moment the mark was made the frame was
      // all there was, so the whole daylight is what was marked, and the
      // lines drawn after it are bars of that one big leaf. A bar's own
      // panel is where the user says otherwise.
      final design = read([frame, mark, mullion, inside]);

      expect(design.openings, hasLength(1));
      expect(design.topLevelSections, hasLength(1));
      final opening = openingOf(design);
      expect(design.childDividersOf(opening.id), hasLength(2));
      expect(opening.widthMm, greaterThan(1800));
    });

    test('every order gives the same design', () {
      final shapes = <String>{};
      for (final strokes in orders.values) {
        final design = read(strokes);
        final opening = openingOf(design);
        shapes.add([
          design.topLevelSections.length,
          design.topLevelDividers.length,
          design.childDividersOf(opening.id).length,
          design.childSectionsOf(opening.id).length,
          Units.format(opening.widthMm),
          Units.format(opening.heightMm),
        ].join('|'));
      }
      expect(shapes, hasLength(1),
          reason: 'the order the strokes were made in is not the design');
    });
  });

  group('what reaches across the design still divides the design', () {
    test('a mullion is not swallowed by the opening it bounds', () {
      final design = read([frame, mullion, mark, inside]);
      final mull = design.topLevelDividers.single;

      expect(mull.isVertical, isTrue);
      expect(mull.parentId, isNull);
      expect(mull.lengthMm, greaterThan(1400),
          reason: 'it runs from the head to the sill');
    });

    test('a line in a section nobody marked divides the design', () {
      final design = read([frame, mullion, inside]);

      expect(design.openings, isEmpty);
      // With no mark there is no opening for anything to be inside, so both
      // lines divide the design, exactly as they always did.
      expect(design.topLevelDividers, hasLength(2));
      expect(design.topLevelSections, hasLength(3));
    });

    test('a transom across the whole design is not the opening’s', () {
      final design = read([
        const [Vec2(0, 0), Vec2(1600, 0), Vec2(1600, 2400), Vec2(0, 2400), Vec2(0, 0)],
        const [Vec2(0, 620), Vec2(1600, 620)],
        const [Vec2(400, 900), Vec2(560, 1000), Vec2(400, 1100)],
      ]);

      expect(design.topLevelDividers, hasLength(1));
      expect(design.topLevelSections, hasLength(2));
      // The fixed light above it did not become part of the opening.
      final opening = openingOf(design);
      expect(opening.outline.top, greaterThan(500));
    });
  });

  group('a line drawn past the opening is cut back to it', () {
    test('an overshooting line stops at the opening', () {
      // Drawn with a hand's overshoot: starting a little outside the frame
      // and carrying on a little past the mullion.
      final design = read([
        frame,
        mullion,
        mark,
        const [Vec2(-40, 400), Vec2(460, 400)],
      ]);

      final opening = openingOf(design);
      final inner = design.childDividersOf(opening.id);
      expect(inner, hasLength(1));

      final bar = inner.single;
      expect(bar.a.x, greaterThan(opening.outline.left - 2));
      expect(bar.b.x, lessThan(opening.outline.right + 2));
      expect(design.topLevelSections, hasLength(2),
          reason: 'the overshoot did not divide the design as well');
    });

    test('a line that fits is left exactly where it was drawn', () {
      final design = read([frame, mullion, mark, inside]);
      final opening = openingOf(design);
      final bar = design.childDividersOf(opening.id).single;

      // Its ends are on the opening's own edges, and its height is the
      // height it was drawn at.
      expect(bar.a.x, closeTo(opening.outline.left, 12));
      expect(bar.b.x, closeTo(opening.outline.right, 12));
      expect(bar.segment.midpoint.y, closeTo(400, 12));
    });
  });

  group('vertical lines and several of them', () {
    test('a vertical inside an opening is the opening\u2019s', () {
      // A transom divides the design; the lower light is marked; and a
      // vertical inside it runs from that transom down to the sill, so it
      // reaches nothing but the opening and divides only the opening.
      final design = read([
        const [Vec2(0, 0), Vec2(1600, 0), Vec2(1600, 2400), Vec2(0, 2400),
            Vec2(0, 0)],
        const [Vec2(0, 620), Vec2(1600, 620)],
        const [Vec2(800, 620), Vec2(800, 2400)],
        const [Vec2(400, 1400), Vec2(560, 1500), Vec2(400, 1600)],
      ]);

      final opening = openingOf(design);
      final inner = design.childDividersOf(opening.id);
      expect(inner, hasLength(1));
      expect(inner.single.isVertical, isTrue);
      expect(design.topLevelSections, hasLength(2),
          reason: 'the transom divides the design, the vertical does not');
      expect(design.topLevelDividers, hasLength(1));
      expect(design.childSectionsOf(opening.id), hasLength(2));
    });

    test('a vertical that reaches across the design divides the design', () {
      // The same line taken up to the head instead: it now runs from one
      // side of the frame to the other, which is what a mullion is. It is
      // built as one, and the bar's own panel is where the user says
      // otherwise.
      final design = read([
        frame,
        mullion,
        const [Vec2(200, 0), Vec2(200, 1600)],
        mark,
      ]);

      expect(design.topLevelDividers, hasLength(2));
      expect(design.openings, hasLength(1));
    });

    test('three lines inside make four panes and still one opening', () {
      final design = read([
        frame,
        mullion,
        const [Vec2(0, 400), Vec2(400, 400)],
        const [Vec2(0, 800), Vec2(400, 800)],
        const [Vec2(0, 1200), Vec2(400, 1200)],
        mark,
      ]);

      final opening = openingOf(design);
      expect(design.childDividersOf(opening.id), hasLength(3));
      expect(design.childSectionsOf(opening.id), hasLength(4));
      expect(design.topLevelSections, hasLength(2));
      expect(design.openings, hasLength(1));
    });
  });

  group('the phase’s own scenario, in CAD and in the model', () {
    Design built() {
      var design = read([frame, mullion, inside, mark]);
      final opening = openingOf(design);
      final lower = design
          .childSectionsOf(opening.id)
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      return design = design.withElement(lower.copyWith(
        finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
      ));
    }

    test('the hierarchy is the opening and its children', () {
      final design = built();
      final opening = openingOf(design);

      // Window → the fixed light, and the opening. Nothing else at the top.
      expect(design.topLevelSections, hasLength(2));
      expect(design.topLevelDividers, hasLength(1));

      // Opening → glass, internal divider, panel, hinges, handle.
      expect(design.childSectionsOf(opening.id), hasLength(2));
      expect(design.childDividersOf(opening.id), hasLength(1));
      final kinds = {
        for (final piece in design.hardware)
          if (piece.parentId == opening.id) piece.kind,
      };
      expect(kinds, {HardwareKind.hinge, HardwareKind.handle});
    });

    test('glass above the line and panel below it', () {
      final design = built();
      final opening = openingOf(design);
      final panes = design.childSectionsOf(opening.id);
      final upper = panes.reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final lower = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);

      expect(upper.finish.material.isGlazing, isTrue);
      expect(lower.finish.material, MaterialKind.panel);
      expect(upper.heightMm, lessThan(lower.heightMm),
          reason: 'the line is 40 cm down a 160 cm opening');
    });

    test('the model puts the divider inside the leaf, not above it', () {
      final design = built();
      final opening = openingOf(design);
      final bar = design.childDividersOf(opening.id).single;
      final mesh = MeshBuilder.build(design);

      // The bar is in the model, as a solid.
      final facets = [
        for (final facet in mesh.facets)
          if (facet.elementId == bar.id) facet,
      ];
      expect(facets, isNotEmpty);
      expect(facets.first.role, FacetRole.bar);

      // And it is within the leaf, across and down.
      var top = 1e9, bottom = -1e9, left = 1e9, right = -1e9;
      for (final facet in facets) {
        for (final corner in facet.corners) {
          top = math.min(top, corner.y);
          bottom = math.max(bottom, corner.y);
          left = math.min(left, corner.x);
          right = math.max(right, corner.x);
        }
      }
      expect(top, greaterThan(opening.outline.top - 1));
      expect(bottom, lessThan(opening.outline.bottom + 1));
      expect(left, greaterThan(opening.outline.left - 1));
      expect(right, lessThan(opening.outline.right + 1));
    });

    test('the leaf carries the divider and both panes when it swings', () {
      final design = built();
      final opening = openingOf(design);
      final ids = {
        design.childDividersOf(opening.id).single.id,
        for (final pane in design.childSectionsOf(opening.id)) pane.id,
      };

      double frontOf(double open) {
        var front = -1e9;
        for (final facet
            in MeshBuilder.build(design, openFraction: open).facets) {
          if (!ids.contains(facet.elementId)) continue;
          for (final corner in facet.corners) {
            if (corner.z > front) front = corner.z;
          }
        }
        return front;
      }

      expect(frontOf(0.4), greaterThan(frontOf(0) + 50));
    });

    test('moving the opening takes the line with it', () {
      final before = built();
      final opening = openingOf(before);
      final wasDown = before.childDividersOf(opening.id).single.segment.midpoint.y -
          before.sectionById(opening.id)!.outline.top;

      final after = DesignEdits.moveDivider(
        before,
        before.topLevelDividers.single.id,
        const Vec2(300, 0),
      );

      final box = after.sectionById(opening.id)!.outline;
      final bar = after.childDividersOf(opening.id).single;
      expect(after.childSectionsOf(opening.id), hasLength(2));
      expect(bar.a.x, closeTo(box.left, 4));
      expect(bar.b.x, closeTo(box.right, 4));
      // It kept its place down the opening, in proportion.
      expect(
        (bar.segment.midpoint.y - box.top) / box.height,
        closeTo(wasDown / before.sectionById(opening.id)!.heightMm, 0.02),
      );
    });
  });
}
