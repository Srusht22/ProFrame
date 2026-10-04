import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/dimensions/scale.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../domain/geometry_normalizer_test.dart' show pen;

// Standard rectangle correction: a door, a window, a sliding set or a door &
// window set drawn as a slightly inaccurate rectangle — the brief's own, a
// left side of 200 cm and a right side of about 185 — comes back as a
// rectangle. Which height it comes back at is never the larger side's, never
// the smaller's and never a figure made up: it is the figure the user stated
// where they stated one, and where they have not, the line that best fits
// what they drew, with its size `?` until they give it. Then the geometry,
// the figures, the technical drawing and the solid all say the same thing.

/// The four categories whose drawings are meant rectangular.
const standard = [
  DesignKind.door,
  DesignKind.window,
  DesignKind.sliding,
  DesignKind.both,
];

/// The brief's rectangle, drawn by hand [width] across: the left side 200
/// cm, the right about 185 — the head drawn sloping down to the right —
/// and every other side and corner a little out.
List<Vec2> handDrawn(double width) => [
  const Vec2(2, 6),
  Vec2(width + 12, 150),
  Vec2(width - 8, 2000),
  const Vec2(5, 1990),
  const Vec2(2, 6),
];

/// The workspace, with [kind] begun and [width]'s rectangle on the sheet.
WorkspaceController begin(DesignKind kind, double width) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final controller = c.read(workspaceProvider.notifier)..startDesign(kind);
  controller.state = controller.state.copyWith(
    design: controller.state.design.copyWith(
      sketch: Sketch(strokes: [pen('outline', handDrawn(width))]),
    ),
  );
  return controller;
}

/// A dimension the user drags from [a] to [b] and types [mm] on.
void stateDimension(WorkspaceController c, Vec2 a, Vec2 b, double mm) {
  c.addDimension(a, b);
  c.setDimensionValue(c.state.design.dimensions.last.id, mm);
}

/// Level or upright — to a micrometre, because a design scaled by a typed
/// figure carries the last bits of a double in every corner.
bool square(Segment s) =>
    (s.a.x - s.b.x).abs() < 1e-6 || (s.a.y - s.b.y).abs() < 1e-6;

/// The frame a rectangle, every edge level or upright.
void expectRectangle(Design d, String why) {
  final outline = d.frame!.outline;
  expect(outline.corners, hasLength(4), reason: why);
  for (final edge in outline.edges) {
    expect(square(edge), isTrue, reason: '$why: $edge');
  }
}

/// The overall height the technical drawing writes, and whether it is
/// written as a figure or as `?`.
(double, String) cadHeight(Design d) {
  final run = DimensionChains.of(d)
      .where((c) => c.axis == DimensionAxis.vertical)
      .expand((c) => c.runs)
      .where((r) => r.of == ChainRunOf.overall)
      .single;
  return (
    run.valueMm,
    Measurements.figure(
      run.valueMm,
      known: Measurements.knowsOverall(d, MeasureAxis.down),
    ),
  );
}

/// How tall the solid is.
double solidHeight(Design d) {
  var top = double.infinity, bottom = -double.infinity;
  for (final facet in MeshBuilder.build(d).facets) {
    for (final p in facet.corners) {
      top = math.min(top, p.y);
      bottom = math.max(bottom, p.y);
    }
  }
  return bottom - top;
}

/// The geometry, the figures, the technical drawing and the solid all
/// [heightMm] high, and every figure the user stated still true.
void expectConsistent(Design d, double heightMm, String why) {
  expectRectangle(d, why);
  expect(d.frame!.outline.height, closeTo(heightMm, 1e-6), reason: why);
  final (cad, _) = cadHeight(d);
  expect(cad, closeTo(heightMm, 1e-6), reason: '$why: the drawing');
  expect(solidHeight(d), closeTo(heightMm, 1e-6), reason: '$why: the solid');
  expect(DesignScale.conflicts(d), isEmpty, reason: '$why: every figure true');
}

void main() {
  for (final kind in standard) {
    group(kind.label, () {
      for (final width in [900.0, 2000.0]) {
        test('${width / 10} cm wide, nothing stated: a rectangle at neither '
            'side\'s height, its height `?` until it is given', () {
          final c = begin(kind, width)..readDrawing();
          final d = c.state.design;
          final why = '${kind.name} $width';
          expectRectangle(d, why);
          final outline = d.frame!.outline;
          // Not the larger side, not the smaller: the line that best fits
          // both ends of the head as drawn, and the other sides likewise.
          expect(outline.height, isNot(closeTo(1994, 1)), reason: why);
          expect(outline.height, isNot(closeTo(1850, 1)), reason: why);
          expect(outline.top, closeTo((6 + 150) / 2, 1e-6), reason: why);
          expect(outline.bottom, closeTo((2000 + 1990) / 2, 1e-6), reason: why);
          // And no size is written as known that nobody gave.
          expect(Measurements.knowsOverall(d, MeasureAxis.down), isFalse);
          expect(Measurements.knowsOverall(d, MeasureAxis.across), isFalse);
          expect(cadHeight(d).$2, '? cm');
          expect(solidHeight(d), closeTo(outline.height, 1e-6));
        });
      }

      test('the left side stated 200 cm: the rectangle is 200 cm high, the '
          'right side too, and every view says so', () {
        final c = begin(kind, 900);
        stateDimension(c, Vec2.zero, const Vec2(0, 2000), 2000);
        c.readDrawing();
        final d = c.state.design;
        expectConsistent(d, 2000, kind.name);
        final outline = d.frame!.outline;
        expect(outline.top, 0);
        expect(outline.bottom, 2000);
        // The height is the user's, so it is known and written as given; the
        // width nobody gave, so it is not.
        expect(Measurements.knowsOverall(d, MeasureAxis.down), isTrue);
        expect(Measurements.knowsOverall(d, MeasureAxis.across), isFalse);
        expect(cadHeight(d).$2, '200 cm');
        // The figure's ends are on the frame's corners.
        final dimension = d.dimensions.single;
        expect({dimension.a.y, dimension.b.y}, {outline.top, outline.bottom});
      });

      test('the right side stated 185 cm instead: the rectangle is 185 cm '
          'high — the stated figure decides, not the larger side', () {
        final c = begin(kind, 900);
        stateDimension(c, const Vec2(912, 150), const Vec2(912, 2000), 1850);
        c.readDrawing();
        final d = c.state.design;
        expectConsistent(d, 1850, kind.name);
        expect(d.frame!.outline.top, 150);
        expect(cadHeight(d).$2, '185 cm');
      });

      test('a figure drawn short of the side it measures and typed as 200 cm '
          'scales the drawing, and the rectangle is exactly 200 cm', () {
        final c = begin(kind, 900);
        stateDimension(c, Vec2.zero, const Vec2(0, 1950), 2000);
        c.readDrawing();
        expectConsistent(c.state.design, 2000, kind.name);
      });

      test('both sides stated, 200 and 185: the user\'s own figures say it '
          'is not a rectangle, so it is not made one, and nothing is '
          'chosen between them', () {
        final c = begin(kind, 900);
        stateDimension(c, Vec2.zero, const Vec2(0, 2000), 2000);
        stateDimension(c, const Vec2(912, 150), const Vec2(912, 2000), 1850);
        c.readDrawing();
        final d = c.state.design;
        final sloped = d.frame!.outline.edges.where((e) => !square(e));
        expect(sloped, hasLength(1), reason: 'the head kept as drawn');
        expect(DesignScale.conflicts(d), isEmpty, reason: 'both figures true');
      });

      test('the sizes given in the form are kept through every later '
          'reading, and every view agrees', () {
        final c = begin(kind, 900)..readDrawing();
        final read = c.state.design;
        final given = Measurements.apply(read, {
          for (final m in Measurements.of(read))
            if (m.asked)
              m.key: switch (m.key) {
                Measurements.widthKey => 900,
                Measurements.heightKey => 2000,
                _ => m.currentMm(read),
              },
        });
        expect(given.ok, isTrue, reason: '${given.problems}');
        c.state = c.state.copyWith(design: given.design);
        expectConsistent(c.state.design, 2000, '${kind.name}, given');
        expect(c.state.design.frame!.outline.width, closeTo(900, 1e-6));

        // Read again, and again after a mullion is drawn.
        c.readDrawing();
        expectConsistent(c.state.design, 2000, '${kind.name}, read again');
        final o = c.state.design.frame!.outline;
        c.state = c.state.copyWith(
          design: c.state.design.copyWith(
            sketch: Sketch(
              strokes: [
                ...c.state.design.sketch.strokes,
                pen('mullion', [
                  Vec2(o.left + 450, o.top),
                  Vec2(o.left + 452, o.bottom),
                ]),
              ],
            ),
          ),
        );
        c.readDrawing();
        final after = c.state.design;
        expectConsistent(after, 2000, '${kind.name}, after a mullion');
        expect(after.frame!.outline.width, closeTo(900, 1e-6));
        expect(after.dividers, hasLength(1));
        expect(Measurements.knowsOverall(after, MeasureAxis.down), isTrue);
      });
    });
  }

  test('an angled design is not made rectangular, whatever is stated', () {
    final c = begin(DesignKind.angled, 900);
    stateDimension(c, Vec2.zero, const Vec2(0, 2000), 2000);
    c.readDrawing();
    final sloped = c.state.design.frame!.outline.edges.where((e) => !square(e));
    expect(sloped, hasLength(1), reason: 'the head kept at its slope');
  });
}
