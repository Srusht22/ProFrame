import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/tolerances.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/recognition/stroke_fit.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'geometry_normalizer_test.dart' show pen, runsOf;
import 'standard_normalization_rules_test.dart' show standard;

// Tolerance-based detection: the normaliser tells a hand's small accidental
// deviation from geometry the user meant, by how far a line is actually out
// against the size of the drawing it is in — not by its angle alone. Any
// angle is not automatically a rectangle. These draw the same shapes with
// deviations growing step by step and require the tiny ones corrected, the
// larger ones settled by what is round them, and the meaningful ones kept.

/// A 200 × 160 cm rectangle whose right side is drawn with its foot [out]
/// millimetres further right than its head, every corner scaled by [scale].
List<Vec2> leaningRight(double out, {double scale = 1}) => [
  for (final p in [
    const Vec2(0, 0),
    const Vec2(2000, 0),
    Vec2(2000 + out, 1600),
    const Vec2(0, 1600),
    const Vec2(0, 0),
  ])
    p * scale,
];

NormalizedGeometry normalize(List<DrawnRun> runs, DesignKind kind) =>
    GeometryNormalizer.normalizeStandardGeometry(
      runs,
      NormalizationContext(kind: kind),
    );

bool square(Segment s) => s.a.x == s.b.x || s.a.y == s.b.y;

/// The right side of [corners], as the normaliser in a [kind] of design
/// leaves it.
Segment rightSide(List<Vec2> corners, DesignKind kind) =>
    normalize(runsOf('frame', corners), kind).runs[1].segment;

/// The deviations, step by step, of the right side's foot: what each is,
/// and what a standard design and an angled one do with it.
const steps =
    <(double, DeviationKind, {bool standardSquares, bool angledSquares})>[
      (2, DeviationKind.wobble, standardSquares: true, angledSquares: true),
      (10, DeviationKind.wobble, standardSquares: true, angledSquares: true),
      (25, DeviationKind.wobble, standardSquares: true, angledSquares: true),
      (60, DeviationKind.wobble, standardSquares: true, angledSquares: true),
      (120, DeviationKind.wobble, standardSquares: true, angledSquares: true),
      // Five degrees on the drawing's full height: within the snap angle, but a
      // twentieth of the drawing out, which the eye sees. A lean.
      (140, DeviationKind.lean, standardSquares: true, angledSquares: false),
      (200, DeviationKind.lean, standardSquares: true, angledSquares: false),
      (280, DeviationKind.lean, standardSquares: true, angledSquares: false),
      (350, DeviationKind.slope, standardSquares: false, angledSquares: false),
      (600, DeviationKind.slope, standardSquares: false, angledSquares: false),
      (1000, DeviationKind.slope, standardSquares: false, angledSquares: false),
    ];

void main() {
  group('a side drawn further and further out', () {
    test('is measured by how far it is out, against the drawing', () {
      for (final (out, kind, standardSquares: _, angledSquares: _) in steps) {
        final corners = leaningRight(out);
        final side = Segment(corners[1], corners[2]);
        final deviation = Deviation.of(
          side,
          GeometryNormalizer.spanOf(runsOf('frame', corners)),
        );
        expect(deviation.kind, kind, reason: '$out mm: $deviation');
        expect(deviation.axis, RunAxis.upright);
        expect(deviation.errorMm, closeTo(out, 1e-9));
      }
    });

    test('tiny deviations are corrected in every design; leans in a '
        'standard one; meaningful geometry is kept', () {
      for (final (out, _, standardSquares: inStandard, angledSquares: inAngled)
          in steps) {
        for (final kind in [...standard, DesignKind.angled]) {
          final squares = kind == DesignKind.angled ? inAngled : inStandard;
          final side = rightSide(leaningRight(out), kind);
          expect(square(side), squares, reason: '$out mm in ${kind.name}');
          if (!squares) {
            expect(
              side,
              Segment(const Vec2(2000, 0), Vec2(2000 + out, 1600)),
              reason: '$out mm in ${kind.name}: kept exactly as drawn',
            );
          }
        }
      }
    });

    test('a correction is recorded as what it was: a wobble squared, a lean '
        'squared because of what is round it', () {
      List<CorrectionKind> on(double out) => [
        for (final c in normalize(
          runsOf('frame', leaningRight(out)),
          DesignKind.window,
        ).corrections)
          c.kind,
      ];
      expect(on(25), contains(CorrectionKind.squared));
      expect(on(25), isNot(contains(CorrectionKind.leaning)));
      expect(on(200), contains(CorrectionKind.leaning));
      expect(on(200), isNot(contains(CorrectionKind.squared)));
      expect(on(600), isEmpty);
    });

    test('read from the sheet, the same', () {
      for (final (out, kind) in [
        (25.0, DesignKind.angled),
        (200.0, DesignKind.door),
        (200.0, DesignKind.angled),
        (600.0, DesignKind.window),
      ]) {
        final frame = SketchInterpreter.interpret(
          Design.empty(id: 'd', kind: kind).copyWith(
            sketch: Sketch(strokes: [pen('frame', leaningRight(out))]),
          ),
        ).design.frame!;
        final kept = frame.outline.edges.where((e) => !square(e)).length;
        final step = steps.firstWhere((s) => s.$1 == out);
        final squares = kind == DesignKind.angled
            ? step.angledSquares
            : step.standardSquares;
        expect(kept, squares ? 0 : 1, reason: '$out mm in ${kind.name}');
      }
    });
  });

  group('the scale of the drawing', () {
    test('the same drawing at a tenth, the same and ten times the size is '
        'read the same — the tolerance is the drawing\'s own', () {
      for (final (out, kind, standardSquares: _, angledSquares: _) in steps) {
        for (final scale in [0.1, 1.0, 10.0]) {
          final corners = leaningRight(out, scale: scale);
          final deviation = Deviation.of(
            Segment(corners[1], corners[2]),
            GeometryNormalizer.spanOf(runsOf('frame', corners)),
          );
          expect(deviation.kind, kind, reason: '$out mm at ×$scale');
        }
      }
    });
  });

  group('the actual distance, not the angle alone', () {
    test('at one angle, a short bar is a wobble and a long one is not', () {
      // Seven degrees each, in a 200 × 160 cm drawing.
      const span = 2561.0;
      const short = Segment(Vec2(800, 600), Vec2(818.4, 750)); // 15 cm long
      const long = Segment(Vec2(1000, 0), Vec2(1184, 1500)); // 150 cm long
      expect(short.offAxisDegrees, closeTo(long.offAxisDegrees, 0.1));
      expect(Deviation.of(short, span).kind, DeviationKind.wobble);
      expect(Deviation.of(long, span).kind, DeviationKind.lean);
    });

    test('within the snap angle, a full-height jamb of a tall narrow design '
        'is a lean while a rail in it is a wobble — so an angled design '
        'keeps the jamb and squares the rail', () {
      // 60 × 240 cm, the right jamb 3.5° out and a rail 3.5° out.
      final jambOut = 2400 * 0.0612; // tan 3.5°
      final corners = [
        const Vec2(0, 0),
        const Vec2(600, 0),
        Vec2(600 + jambOut, 2400),
        const Vec2(0, 2400),
        const Vec2(0, 0),
      ];
      final runs = [
        ...runsOf('frame', corners),
        ...runsOf('rail', const [Vec2(0, 1000), Vec2(500, 1030.6)]),
      ];
      final span = GeometryNormalizer.spanOf(runs);
      expect(
        Deviation.of(runs[1].segment, span).kind,
        DeviationKind.lean,
        reason: '${Deviation.of(runs[1].segment, span)}',
      );
      expect(Deviation.of(runs.last.segment, span).kind, DeviationKind.wobble);

      final angled = normalize(runs, DesignKind.angled).runs;
      expect(square(angled[1].segment), isFalse, reason: 'the jamb kept');
      expect(square(angled.last.segment), isTrue, reason: 'the rail squared');

      final door = normalize(runs, DesignKind.door).runs;
      expect(square(door[1].segment), isTrue, reason: 'a lean, in a door');
      expect(square(door.last.segment), isTrue);
    });
  });

  group('the size of what a line bounds', () {
    test('the same lean is squared across a wide light and kept on a narrow '
        'one, where it is half the width', () {
      for (final (width, squares) in [(2000.0, true), (400.0, false)]) {
        final corners = [
          const Vec2(0, 0),
          Vec2(width, 0),
          Vec2(width + 196, 1600),
          const Vec2(0, 1600),
          const Vec2(0, 0),
        ];
        expect(
          square(rightSide(corners, DesignKind.window)),
          squares,
          reason: '${width / 10} cm wide',
        );
      }
    });
  });

  group('any angle is not a rectangle', () {
    test(
      'a slope at 12°, 20°, 30° or 45° is kept exactly, in every design',
      () {
        for (final degrees in [12, 20, 30, 45]) {
          final out = 1600 * _tan(degrees);
          for (final kind in DesignKind.values) {
            final runs = runsOf('frame', leaningRight(out));
            final result = normalize(runs, kind);
            expect(
              result.changed,
              isFalse,
              reason: '$degrees° in ${kind.name}',
            );
          }
        }
      },
    );

    test('nothing is squared that is not near an axis by both measures', () {
      for (final (out, kind, standardSquares: _, angledSquares: _) in steps) {
        final corners = leaningRight(out);
        final d = Deviation.of(
          Segment(corners[1], corners[2]),
          GeometryNormalizer.spanOf(runsOf('frame', corners)),
        );
        if (kind == DeviationKind.slope) {
          expect(d.degrees, greaterThan(Tol.leanDegrees));
        } else {
          expect(d.degrees, lessThanOrEqualTo(Tol.leanDegrees));
        }
        if (kind == DeviationKind.wobble && d.degrees > Tol.axisSnapDegrees) {
          expect(d.errorMm, lessThanOrEqualTo(d.precisionMm));
        }
      }
    });
  });

  group('the snapping that already exists', () {
    test('a line already square — as the pen\'s pause or a tool leaves it — '
        'is not a deviation, and nothing is recorded for it', () {
      const level = Segment(Vec2(0, 500), Vec2(2000, 500));
      expect(Deviation.of(level, 2561).kind, DeviationKind.none);
      final out = normalize(
        runsOf('frame', leaningRight(0)),
        DesignKind.angled,
      );
      expect(out.changed, isFalse);
    });

    test('the pause to straighten is the user asking, and still squares by '
        'the snap angle alone', () {
      // A full-height jamb 4.9° out: a lean to the reading, but the user
      // paused on it, which says straighten it.
      const jamb = Segment(Vec2(2000, 0), Vec2(2137, 1600));
      expect(Deviation.of(jamb, 2561).kind, DeviationKind.lean);
      expect(square(StrokeFitter.straightened(jamb)), isTrue);
    });
  });
}

double _tan(int degrees) => math.tan(degrees * math.pi / 180);
