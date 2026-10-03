import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/geometry_validation.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// An angled design keeps the geometry its user drew. Choosing Angled /
// Asymmetrical is saying, before a line is drawn, that non-standard geometry
// is meant — a left side of 200 cm and a right of 150, a head that slopes, a
// top narrower than the foot, a slope inside an opening or a fixed light —
// so none of it is made square, made equal or made parallel. It is still
// held to what anything built must be, and that is checked rather than
// mended: coordinates that are numbers, an outline that closes without
// crossing itself, bars joined to the design, every child inside its
// parent, openings holding their marks with their ironmongery on their
// leaves, and dimensions that measure what they say.

Interpretation read(
  List<Stroke> strokes, {
  DesignKind kind = DesignKind.angled,
}) => SketchInterpreter.interpret(
  Design.empty(
    id: 'angled',
    kind: kind,
  ).copyWith(sketch: Sketch(strokes: strokes)),
);

bool square(Segment s) => s.a.x == s.b.x || s.a.y == s.b.y;

/// The outline's corner nearest [p].
Vec2 cornerNear(Polygon outline, Vec2 p) =>
    outline.corners.reduce((a, b) => a.distanceTo(p) < b.distanceTo(p) ? a : b);

/// The edge of [outline] from the corner nearest [a] to the one nearest [b].
Segment edgeNear(Polygon outline, Vec2 a, Vec2 b) =>
    Segment(cornerNear(outline, a), cornerNear(outline, b));

/// Every corner of [outline] where [drawn] put it, to within [slack].
void expectAsDrawn(Polygon outline, List<Vec2> drawn, {double slack = 0}) {
  expect(outline.corners, hasLength(drawn.length - 1));
  for (final p in drawn.take(drawn.length - 1)) {
    expect(
      cornerNear(outline, p).distanceTo(p),
      lessThanOrEqualTo(slack),
      reason: '$p in $outline',
    );
  }
}

/// A sloped head: the left side 200 cm, the right 150.
const slopedTop = [
  Vec2(0, 0),
  Vec2(1200, 500),
  Vec2(1200, 2000),
  Vec2(0, 2000),
  Vec2(0, 0),
];

/// Unequal heights and unequal widths: 120 cm across the head, 140 across
/// the foot, the right side 160 cm and the left 210.
const unequal = [
  Vec2(0, 0),
  Vec2(1200, 500),
  Vec2(1400, 2100),
  Vec2(0, 2100),
  Vec2(0, 0),
];

/// Sides that are not parallel, neither of them upright: the left out by
/// 10 cm over 2 m — a hand could do that, but in an angled design it is
/// drawn — and the right by 20.
const nonParallel = [
  Vec2(100, 0),
  Vec2(1100, 0),
  Vec2(1300, 2000),
  Vec2(0, 2000),
  Vec2(100, 0),
];

/// The sloped head with a mullion and a `>` in the light under the slope —
/// or a `<`, [hungRight], which hangs the leaf on its right stile.
List<Stroke> rakedWithOpening({double markX = 300, bool hungRight = false}) => [
  pen('outline', slopedTop),
  pen('mullion', const [Vec2(600, 250), Vec2(600, 2000)]),
  pen('mark', [
    for (final p in chevron(Vec2(markX, 1300)))
      hungRight ? Vec2(2 * markX - p.x, p.y) : p,
  ]),
];

void main() {
  group('the geometry the user drew is kept', () {
    test('a sloped top: the left side 200 cm, the right 150, never made '
        'equal', () {
      final outline = read([pen('outline', slopedTop)]).design.frame!.outline;
      expectAsDrawn(outline, slopedTop);
      final left = edgeNear(outline, const Vec2(0, 0), const Vec2(0, 2000));
      final right = edgeNear(
        outline,
        const Vec2(1200, 500),
        const Vec2(1200, 2000),
      );
      expect(left.length, 2000);
      expect(right.length, 1500);
      final head = edgeNear(outline, const Vec2(0, 0), const Vec2(1200, 500));
      expect(head.offAxisDegrees, closeTo(22.62, 0.01));
    });

    test('unequal heights and unequal widths, both kept', () {
      final outline = read([pen('outline', unequal)]).design.frame!.outline;
      expectAsDrawn(outline, unequal);
      expect(
        edgeNear(outline, const Vec2(0, 0), const Vec2(1200, 500)).length,
        isNot(
          edgeNear(outline, const Vec2(0, 2100), const Vec2(1400, 2100)).length,
        ),
      );
    });

    test('sides that are not parallel stay so — where a door or a window '
        'squares the slighter one', () {
      final angled = read([pen('outline', nonParallel)]).design.frame!.outline;
      expectAsDrawn(angled, nonParallel);
      final left = edgeNear(angled, const Vec2(100, 0), const Vec2(0, 2000));
      final right = edgeNear(
        angled,
        const Vec2(1100, 0),
        const Vec2(1300, 2000),
      );
      expect(left.offAxisDegrees, greaterThan(2));
      expect(right.offAxisDegrees, greaterThan(5));
      expect(left.direction.cross(right.direction), isNot(0));

      // The same sheet begun as a window: a 10 cm lean over 2 m is the
      // hand's there, and the window comes back square.
      final window = read([
        pen('outline', nonParallel),
      ], kind: DesignKind.window).design.frame!.outline;
      expect(window.edges.every(square), isTrue, reason: '$window');
    });

    test('a hand\'s wobble is still cleaned: a side out by less than a hand '
        'can place a line is squared, and the slope beside it kept', () {
      const wobbled = [
        Vec2(0, 0),
        Vec2(1200, 500),
        Vec2(1200, 2000),
        Vec2(12, 2000),
        Vec2(0, 0),
      ];
      final outline = read([pen('outline', wobbled)]).design.frame!.outline;
      final left = edgeNear(outline, const Vec2(0, 0), const Vec2(12, 2000));
      expect(square(left), isTrue, reason: '$left');
      final head = edgeNear(outline, const Vec2(0, 0), const Vec2(1200, 500));
      expect(head.offAxisDegrees, closeTo(22.6, 0.3));
    });

    test('slopes inside a fixed light and inside an opening are kept too', () {
      // A sloped transom across the fixed light on the right.
      final first = read([
        ...rakedWithOpening(),
        pen('transom', const [Vec2(600, 1100), Vec2(1200, 1000)]),
      ]).design;
      final transom = first.dividers.firstWhere(
        (b) => b.fromStrokeId == 'transom',
      );
      expect(transom.parentId, isNull);
      expect(transom.segment.offAxisDegrees, closeTo(9.46, 0.05));

      // A sloped line drawn inside the opening, on the sheet: the opening's,
      // and at the slope it was drawn.
      final opening = first.openings.single;
      final region = first.sectionById(opening.sectionId)!.outline;
      final y = region.bottom - 500;
      final again = SketchInterpreter.interpret(
        first.copyWith(
          sketch: Sketch(
            strokes: [
              ...first.sketch.strokes,
              pen('inside', [Vec2(region.left, y), Vec2(region.right, y - 80)]),
            ],
          ),
        ),
      ).design;
      final inside = again.dividers.firstWhere(
        (b) => b.fromStrokeId == 'inside',
      );
      expect(inside.parentId, again.openings.single.id);
      expect(inside.segment.offAxisDegrees, greaterThan(5));
      // The opening's own raked head is kept: its region is not a box.
      final leaf = again.sectionById(again.openings.single.sectionId)!.outline;
      expect(leaf.edges.where((e) => !square(e)), isNotEmpty);
    });

    test('read again, saved and opened again: the same geometry', () {
      final first = read(rakedWithOpening()).design;
      final again = SketchInterpreter.interpret(first).design;
      expect(again.frame!.outline, first.frame!.outline);
      expect(
        {for (final b in again.dividers) b.id: b.segment},
        {for (final b in first.dividers) b.id: b.segment},
      );
      final reloaded = Design.fromJson(
        jsonDecode(jsonEncode(again.toJson())) as Map<String, Object?>,
      );
      expect(reloaded.frame!.outline, again.frame!.outline);
      expect(reloaded.category, DesignKind.angled);
    });
  });

  group('and it is valid', () {
    test('every design above reads with no problem at all', () {
      for (final strokes in [
        [pen('outline', slopedTop)],
        [pen('outline', unequal)],
        [pen('outline', nonParallel)],
        rakedWithOpening(),
        rakedWithOpening(markX: 900),
      ]) {
        final result = read(strokes);
        expect(result.problems, isEmpty, reason: '${result.problems}');
        expect(
          GeometryNormalizer.validateAngledGeometry(result.design),
          isEmpty,
        );
      }
    });

    test('a leaf under a raked head carries its ironmongery on itself — '
        'the hinges down its own stile, not the box round it', () {
      // The head falls to the right, so a leaf hung on its right stile hangs
      // on the shorter one, and the box round it is taller than that stile.
      for (final (markX, hungRight) in [
        (300.0, false),
        (300.0, true),
        (900.0, false),
        (900.0, true),
      ]) {
        for (final kind in DesignKind.leafKinds) {
          var d = read(rakedWithOpening(markX: markX, hungRight: hungRight))
              .design;
          expect(
            d.openings.single.mechanism.hingeEdge,
            hungRight ? OpeningEdge.right : OpeningEdge.left,
          );
          d = OpeningHardware.settle(
            d.copyWith(
              openings: [for (final o in d.openings) o.copyWith(kind: kind)],
            ),
          );
          final leaf = d.sectionById(d.openings.single.sectionId)!.outline;
          final pieces = d.hardware.where(
            (h) => d.openingHolding(h.parentId) != null,
          );
          expect(pieces.map((h) => h.kind), contains(HardwareKind.hinge));
          expect(pieces.where((h) => h.kind.isHandle), isNotEmpty);
          for (final piece in pieces) {
            expect(
              leaf.contains(piece.at),
              isTrue,
              reason:
                  '${kind.name} at $markX: ${piece.kind.name} at '
                  '${piece.at}, leaf $leaf',
            );
          }
          expect(GeometryNormalizer.validateAngledGeometry(d), isEmpty);
        }
      }
    });

    test('a leaf hung on a stile drawn leaning has its hinges down that '
        'stile — spread along it, each on the leaf — and its handle on the '
        'stile opposite', () {
      // The right side drawn leaning out, 10 cm over its 150; a `<` in the
      // right light hangs its leaf on that side.
      for (final kind in DesignKind.leafKinds) {
        var d = read([
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
        ]).design;
        d = OpeningHardware.settle(
          d.copyWith(
            openings: [for (final o in d.openings) o.copyWith(kind: kind)],
          ),
        );
        final opening = d.openings.single;
        expect(opening.mechanism.hingeEdge, OpeningEdge.right);
        final leaf = d.sectionById(opening.sectionId)!.outline;
        final stile = OpeningHardware.stileOf(leaf, OpeningEdge.right)!;
        expect(stile.offAxisDegrees, greaterThan(3), reason: 'it leans');
        final hinges = [
          for (final h in d.hardware)
            if (h.parentId == opening.id && h.kind == HardwareKind.hinge) h.at,
        ];
        expect(hinges.length, greaterThanOrEqualTo(2));
        final ys = [for (final h in hinges) h.y]..sort();
        expect(
          ys.last - ys.first,
          greaterThan((stile.b.y - stile.a.y) / 2),
          reason: 'spread down the stile, not gathered at its foot: $hinges',
        );
        for (final h in hinges) {
          expect(stile.distanceTo(h), lessThan(1e-6), reason: 'on the stile');
          expect(leaf.contains(h), isTrue, reason: '$h');
        }
        for (final h in d.hardware) {
          if (h.parentId != opening.id) continue;
          expect(leaf.contains(h.at), isTrue, reason: '${h.kind.name} ${h.at}');
        }
        expect(GeometryNormalizer.validateAngledGeometry(d), isEmpty);
      }
    });

    test('the solid builds the raked leaf\'s glass inside its leaf', () {
      final d = read(rakedWithOpening()).design;
      final leaf = d.sectionById(d.openings.single.sectionId)!.outline;
      final inside = {
        d.openings.single.sectionId,
        for (final s in d.childSectionsOf(d.openings.single.sectionId)) s.id,
      };
      var seen = 0;
      for (final facet in MeshBuilder.build(d).facets) {
        if (!inside.contains(facet.elementId) ||
            !facet.surface.id.contains('glass')) {
          continue;
        }
        seen++;
        for (final c in facet.corners) {
          final p = Vec2(c.x, c.y);
          expect(
            leaf.contains(p) || leaf.awayFrom(p) < 1e-3,
            isTrue,
            reason: '$p',
          );
        }
      }
      expect(seen, greaterThan(0));
    });

    group('what is not valid is reported, and nothing is changed', () {
      final good = read(rakedWithOpening()).design;

      List<GeometryProblemKind> problemsOf(Design d) {
        // Its text, not JSON: a coordinate that is not a number is one of
        // the things checked, and JSON cannot hold one.
        final before = d.toJson().toString();
        final found = GeometryNormalizer.validateAngledGeometry(d);
        expect(d.toJson().toString(), before, reason: 'validating changed it');
        return [for (final p in found) p.kind];
      }

      test('an outline that crosses itself', () {
        final bowTie = read([
          pen('outline', const [
            Vec2(0, 0),
            Vec2(1200, 2000),
            Vec2(1200, 0),
            Vec2(0, 2000),
            Vec2(0, 0),
          ]),
        ]);
        expect(
          bowTie.problems.map((p) => p.kind),
          contains(GeometryProblemKind.selfIntersection),
        );
        expect(
          const Polygon([Vec2(0, 0), Vec2(10, 10), Vec2(10, 0), Vec2(0, 10)])
              .isSimple,
          isFalse,
        );
        expect(Polygon.rect(0, 0, 10, 10).isSimple, isTrue);
      });

      test('a coordinate that is not a number', () {
        final bar = good.dividers.first;
        expect(
          problemsOf(
            good.withElement(bar.copyWith(b: const Vec2(double.nan, 0))),
          ),
          contains(GeometryProblemKind.coordinate),
        );
      });

      test('an outline that encloses nothing', () {
        expect(
          problemsOf(
            good.withElement(
              good.frame!.copyWith(
                outline: const Polygon([Vec2(0, 0), Vec2(100, 0)]),
              ),
            ),
          ),
          contains(GeometryProblemKind.boundary),
        );
      });

      test('a bar of the design hanging from nothing', () {
        final loose = DividerElement(
          id: 'loose',
          a: const Vec2(800, 1500),
          b: const Vec2(1000, 1500),
        );
        expect(
          problemsOf(good.copyWith(dividers: [...good.dividers, loose])),
          contains(GeometryProblemKind.disconnected),
        );
      });

      test('a line of the opening\'s outside it, and a hinge off its leaf', () {
        final opening = good.openings.single;
        final stray = DividerElement(
          id: 'stray',
          a: const Vec2(700, 1500),
          b: const Vec2(1100, 1500),
          parentId: opening.id,
        );
        expect(
          problemsOf(good.copyWith(dividers: [...good.dividers, stray])),
          contains(GeometryProblemKind.child),
        );
        final hinge = good.hardware.firstWhere(
          (h) => h.kind == HardwareKind.hinge,
        );
        expect(
          problemsOf(
            good.copyWith(
              hardware: [
                for (final h in good.hardware)
                  if (h.id == hinge.id)
                    h.copyWith(at: const Vec2(1100, 1500))
                  else
                    h,
              ],
            ),
          ),
          contains(GeometryProblemKind.child),
        );
      });

      test('an opening whose mark is not in its region', () {
        final opening = good.openings.single;
        expect(
          problemsOf(
            good.copyWith(
              openings: [opening.copyWith(markAt: const Vec2(1000, 1500))],
            ),
          ),
          contains(GeometryProblemKind.opening),
        );
      });

      test('a dimension that measures nothing, and one the geometry no '
          'longer agrees with', () {
        expect(
          problemsOf(
            good.copyWith(
              dimensions: const [
                DimensionElement(id: 'nil', a: Vec2(0, 0), b: Vec2(0, 0)),
              ],
            ),
          ),
          contains(GeometryProblemKind.dimension),
        );
        expect(
          problemsOf(
            good.copyWith(
              dimensions: const [
                DimensionElement(
                  id: 'left',
                  a: Vec2(0, 0),
                  b: Vec2(0, 2000),
                  statedMm: 1500,
                ),
              ],
            ),
          ),
          contains(GeometryProblemKind.dimension),
        );
      });
    });
  });
}
