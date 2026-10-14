import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/canvas/cad_layers.dart';
import 'package:proframe/app/canvas/cad_painter.dart';
import 'package:proframe/app/canvas/view_transform.dart';
import 'package:proframe/domain/dimensions/dimension_chain.dart';
import 'package:proframe/domain/dimensions/frame_sides.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import '../domain/an_under_stair_design_test.dart' as under;
import '../domain/angled_dimensions_test.dart' as angled;
import '../domain/geometry_normalizer_test.dart' show pen;
import 'pause_and_take_it_back_test.dart' show chevron;

// The technical drawing consumes the canonical geometry directly, and draws
// nothing of its own. Four designs:
//
//   1. a standard rectangle, drawn exactly;
//   2. the same rectangle drawn by hand, every corner a little out — which
//      the reading corrects, so the drawing is of the corrected rectangle;
//   3. an angled window, its head sloping from a left side of 200 cm to a
//      right side of 150 — kept as drawn;
//   4. the window under a stair — kept as drawn.
//
// Each is painted with its frame and its parts alone — no grid and no
// figures — and the picture is held to the design's own geometry: every
// edge of the outline, of the daylight and of every bar's body is inked
// where the geometry puts it, and nothing at all is inked outside the
// outline. A rectangle drawn round an angled shape, a slope straightened, a
// line drawn from a box's corner or a sash's swing laid on its box would
// each put ink where the shape is not. Then the figures, which are the
// geometry's own measures and nothing else.

const _size = Size(900, 900);

ViewTransform viewOf(Design d) => ViewTransform.fit(
  d.frame!.outline,
  _size,
  padding: const EdgeInsets.all(80),
);

/// The frame and the parts, and nothing that is not geometry.
const geometryOnly = CadLayers(
  grid: false,
  dimensions: false,
  annotations: false,
);

Future<Uint8List> paint(Design d, CadLayers layers) async {
  final recorder = ui.PictureRecorder();
  CadPainter(
    design: d,
    view: viewOf(d),
    layers: layers,
  ).paint(Canvas(recorder), _size);
  final image = await recorder.endRecording().toImage(
    _size.width.round(),
    _size.height.round(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

int _at(int x, int y) => (y * _size.width.round() + x) * 4;

/// The paper: the colour of a corner of the sheet nowhere near the design.
List<int> paperOf(Uint8List rgba) => [rgba[0], rgba[1], rgba[2]];

bool inked(Uint8List rgba, List<int> paper, int x, int y) {
  if (x < 0 || y < 0 || x >= _size.width || y >= _size.height) return false;
  final i = _at(x, y);
  return (rgba[i] - paper[0]).abs() +
          (rgba[i + 1] - paper[1]).abs() +
          (rgba[i + 2] - paper[2]).abs() >
      24;
}

/// Whether there is ink within [reach] pixels of [p].
bool inkNear(Uint8List rgba, List<int> paper, Offset p, {int reach = 2}) {
  for (var dy = -reach; dy <= reach; dy++) {
    for (var dx = -reach; dx <= reach; dx++) {
      if (inked(rgba, paper, p.dx.round() + dx, p.dy.round() + dy)) {
        return true;
      }
    }
  }
  return false;
}

/// [edge] as it lies on the screen, sampled every few pixels short of its
/// ends — where every line of it ought to be inked.
Iterable<Offset> along(ViewTransform view, Segment edge) sync* {
  final a = view.toScreen(edge.a), b = view.toScreen(edge.b);
  final length = (b - a).distance;
  if (length < 8) return;
  final steps = (length / 5).floor();
  for (var i = 1; i < steps; i++) {
    yield Offset.lerp(a, b, i / steps)!;
  }
}

/// How far [p] on the screen is from [shape] there: 0 inside it.
double outside(ViewTransform view, Polygon shape, Offset p) {
  final corners = [for (final c in shape.corners) view.toScreen(c)];
  final path = Path()..addPolygon(corners, true);
  if (path.contains(p)) return 0;
  var nearest = double.infinity;
  for (var i = 0; i < corners.length; i++) {
    final a = corners[i], b = corners[(i + 1) % corners.length];
    final ab = b - a;
    final t = ab.distanceSquared == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / ab.distanceSquared)
              .clamp(0.0, 1.0);
    nearest = math.min(nearest, (p - (a + ab * t)).distance);
  }
  return nearest;
}

Design read(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

/// A 120 × 150 cm window: a transom 50 cm down, a mullion in the lower
/// light, and the lower left marked `>`. [corners] is how its outline was
/// drawn.
Design window(List<Vec2> corners) => read(
  Design.empty(id: 'w', kind: DesignKind.window).copyWith(
    sketch: Sketch(
      strokes: [
        pen('outline', [...corners, corners.first]),
        pen('transom', const [Vec2(0, 500), Vec2(1200, 500)]),
        pen('mullion', const [Vec2(600, 500), Vec2(600, 1500)]),
        pen('mark', chevron(const Vec2(300, 1000))),
      ],
    ),
  ),
);

/// Drawn exactly.
const exact = [Vec2(0, 0), Vec2(1200, 0), Vec2(1200, 1500), Vec2(0, 1500)];

/// Drawn by hand: every corner a little out — the head rising 15 mm, the
/// right side leaning out 30 mm, the sill dipping and the left side
/// leaning in.
const byHand = [Vec2(0, 0), Vec2(1200, 15), Vec2(1230, 1500), Vec2(-20, 1490)];

final designs = <String, Design Function()>{
  'a standard rectangle': () => window(exact),
  'an inaccurate standard rectangle': () => window(byHand),
  'an angled window': angled.drawn,
  'a window under a stair': under.built,
};

bool square(Segment e) => e.a.x == e.b.x || e.a.y == e.b.y;

void main() {
  group('the drawing is the canonical geometry', () {
    for (final MapEntry(key: name, value: make) in designs.entries) {
      testWidgets('$name: every line of the outline, the daylight and '
          'every bar is inked where the geometry puts it', (tester) async {
        final d = make();
        final view = viewOf(d);
        final rgba = await tester.runAsync(() => paint(d, geometryOnly));
        final paper = paperOf(rgba!);
        final frame = d.frame!;
        final geometry = DesignGeometry.of(d);
        final lines = <(String, Segment)>[
          for (final e in frame.lines.outside) ('outline', e),
          for (final e in frame.lines.daylight) ('daylight', e),
          for (final bar in d.dividers)
            for (final e in geometry.barBody(bar).edges) ('bar ${bar.id}', e),
        ];
        // Ironmongery stands in front of the leaf and what is behind it,
        // as on any elevation: a line under a handle is covered by it.
        final covered = [
          for (final piece in d.hardware)
            if (!d.isConcealed(piece))
              for (final shape in geometry.hardwareOf(piece))
                if (!shape.isEmpty) view.pathOf(shape).getBounds().inflate(3),
        ];
        for (final (what, edge) in lines) {
          for (final p in along(view, edge)) {
            if (covered.any((r) => r.contains(p))) continue;
            expect(
              inkNear(rgba, paper, p),
              isTrue,
              reason: '$name: $what at $p, on $edge',
            );
          }
        }
      });

      testWidgets('$name: nothing is inked outside the outline — no box '
          'round it, no straightened slope, no line from a box\'s corner', (
        tester,
      ) async {
        final d = make();
        final view = viewOf(d);
        final rgba = await tester.runAsync(() => paint(d, geometryOnly));
        final paper = paperOf(rgba!);
        final outline = d.frame!.outline;
        var stray = 0;
        Offset? first;
        for (var y = 0; y < _size.height; y += 2) {
          for (var x = 0; x < _size.width; x += 2) {
            if (!inked(rgba, paper, x, y)) continue;
            final p = Offset(x.toDouble(), y.toDouble());
            if (outside(view, outline, p) > 3) {
              stray++;
              first ??= p;
            }
          }
        }
        expect(stray, 0, reason: '$name: ink outside the outline, at $first');
      });
    }
  });

  group('the corrected geometry, and the kept geometry', () {
    test('the rectangle drawn by hand is read as a rectangle, and it is the '
        'one the technical drawing is of', () {
      final d = window(byHand);
      final outline = d.frame!.outline;
      expect(outline.corners, hasLength(4));
      for (final e in outline.edges) {
        expect(square(e), isTrue, reason: '$e');
      }
      // Its painter is handed the design itself: no copy, nothing rebuilt.
      final painter = CadPainter(
        design: d,
        view: viewOf(d),
        layers: geometryOnly,
      );
      expect(identical(painter.design, d), isTrue);
    });

    testWidgets('the hand\'s own leaning lines are not drawn — a corner the '
        'hand put 30 mm out is not inked where the hand put it', (
      tester,
    ) async {
      final d = window(byHand);
      final view = viewOf(d);
      final rgba = await tester.runAsync(() => paint(d, geometryOnly));
      final paper = paperOf(rgba!);
      for (final drawn in byHand) {
        final p = view.toScreen(drawn);
        if (outside(view, d.frame!.outline, p) <= 4) continue;
        expect(inkNear(rgba, paper, p, reach: 1), isFalse, reason: '$drawn');
      }
    });

    test('an angled window keeps its slope and its unequal sides: its '
        'outline is not a rectangle, and the box round it is not the '
        'drawing', () {
      for (final d in [angled.drawn(), under.built()]) {
        final outline = d.frame!.outline;
        expect(outline.edges.where((e) => !square(e)), isNotEmpty);
        expect(outline.area, lessThan(outline.width * outline.height * 0.95));
      }
    });

    testWidgets('a raked leaf\'s swing is drawn on its own stiles: inside '
        'its region, from the ends of the stile it hangs on', (tester) async {
      for (final d in [angled.drawn(), under.built()]) {
        final opening = d.openings.single;
        final region = d.sectionById(opening.sectionId)!.outline;
        final edge = opening.mechanism.hingeEdge!;
        final (a, b, apex) = OpeningHardware.swingOf(region, edge);
        for (final p in [a, b, apex]) {
          expect(
            region.contains(p) ||
                region.edges.any((e) => e.distanceTo(p) < 1e-6),
            isTrue,
            reason: '$p of the swing',
          );
        }
        final stile = OpeningHardware.stileOf(region, edge)!;
        expect({a, b}, {stile.a, stile.b});
      }
      // On a rectangle it is exactly the box's.
      final box = Polygon.rect(100, 200, 700, 1400);
      expect(OpeningHardware.swingOf(box, OpeningEdge.left), (
        const Vec2(100, 200),
        const Vec2(100, 1400),
        const Vec2(700, 800),
      ));
      expect(OpeningHardware.swingOf(box, OpeningEdge.top), (
        const Vec2(100, 200),
        const Vec2(700, 200),
        const Vec2(400, 1400),
      ));
    });
  });

  group('the figures are the geometry\'s own measures', () {
    for (final MapEntry(key: name, value: make) in designs.entries) {
      test('$name: every run measures something the design has, and '
          'nothing is invented', () {
        final d = make();
        final outline = d.frame!.outline;
        final sides = {for (final s in FrameSides.of(d)) s.key: s};
        for (final chain in DimensionChains.of(d)) {
          final across = chain.axis == DimensionAxis.horizontal;
          for (final run in chain.runs) {
            switch (run.of) {
              case ChainRunOf.overall:
                expect(run.fromMm, across ? outline.left : outline.top);
                expect(run.toMm, across ? outline.right : outline.bottom);
              case ChainRunOf.side:
                expect(
                  run.valueMm,
                  closeTo(sides[run.sideKey]!.lengthOn(outline), 1e-9),
                );
              case ChainRunOf.daylight ||
                  ChainRunOf.opening ||
                  ChainRunOf.division:
                final box = d.sectionById(run.sectionId!)!.outline;
                expect(run.fromMm, across ? box.left : box.top);
                expect(run.toMm, across ? box.right : box.bottom);
            }
          }
        }
        // A side of its own on every shape that has one, and on no other.
        final hasSides = DimensionChains.of(d)
            .any((c) => c.runs.first.of == ChainRunOf.side);
        expect(hasSides, !FrameSides.isRectangle(outline), reason: name);
      });
    }

    test('the angled window\'s two sides are two figures, 200 and 150, and '
        'the under-stair window\'s short jamb is 90 beside its 220', () {
      double sideOf(Design d) => [
        for (final c in DimensionChains.of(d))
          for (final r in c.runs)
            if (r.of == ChainRunOf.side && c.axis == DimensionAxis.vertical)
              r.valueMm,
      ].single;
      final a = angled.drawn();
      expect(a.frame!.outline.height, 2000);
      expect(sideOf(a), 1500);
      final u = under.built();
      expect(u.frame!.outline.height, 2200);
      expect(sideOf(u), 900);
    });
  });
}
