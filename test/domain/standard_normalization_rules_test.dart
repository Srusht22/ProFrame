import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

import 'geometry_normalizer_test.dart' show pen, runsOf;

// The standard normalisation rules: what the reading corrects in a door, a
// window, a sliding set and a door & window set, drawn by hand. A side
// drawn leaning comes back upright, a head drawn tilted comes back level,
// sides that should be parallel are, a corner drawn a little out is a
// corner, and an outline drawn closed stays closed — while nothing is made
// rectangular that the drawing does not say is, and an angled design keeps
// every slope its user drew.

/// The four categories whose lines are meant level, upright and square.
const standard = [
  DesignKind.door,
  DesignKind.window,
  DesignKind.sliding,
  DesignKind.both,
];

/// The rectangle the brief starts from: 200 × 160 cm, drawn square.
const perfect = [
  Vec2(0, 0),
  Vec2(2000, 0),
  Vec2(2000, 1600),
  Vec2(0, 1600),
  Vec2(0, 0),
];

/// [corners] with the corner at [index] — and the loop's start where it is
/// the same point — moved to [to].
List<Vec2> withCorner(List<Vec2> corners, int index, Vec2 to) => [
  for (var i = 0; i < corners.length; i++)
    i == index || (index == 0 && i == corners.length - 1) ? to : corners[i],
];

NormalizedGeometry normalize(List<DrawnRun> runs, DesignKind kind) =>
    GeometryNormalizer.normalizeStandardGeometry(
      runs,
      NormalizationContext(kind: kind),
    );

Interpretation read(List<Stroke> strokes, DesignKind kind) =>
    SketchInterpreter.interpret(
      Design.empty(
        id: 'drawn',
        kind: kind,
      ).copyWith(sketch: Sketch(strokes: strokes)),
    );

bool square(Segment s) => s.a.x == s.b.x || s.a.y == s.b.y;

/// Each of [runs] starts where the one before it ended, and the last ends
/// where the first began: one closed outline.
void expectClosed(List<DrawnRun> runs) {
  for (var i = 0; i < runs.length; i++) {
    expect(
      runs[i].segment.b,
      runs[(i + 1) % runs.length].segment.a,
      reason: 'run $i ends where run ${(i + 1) % runs.length} begins',
    );
  }
}

/// [corners] as four separate strokes, one a side, as a hand draws a box
/// one line at a time.
List<Stroke> sideBySide(List<Vec2> corners) => [
  for (var i = 1; i < corners.length; i++)
    pen('side-$i', [corners[i - 1], corners[i]]),
];

/// The frame [interpretation] read: square, with no bar along it, its sides
/// within [slack] of [left], [top], [right] and [bottom].
void expectFrame(
  Interpretation interpretation, {
  required double left,
  required double top,
  required double right,
  required double bottom,
  double slack = 0,
  String reason = '',
}) {
  final design = interpretation.design;
  final outline = design.frame!.outline;
  expect(outline.corners, hasLength(4), reason: reason);
  for (final edge in outline.edges) {
    expect(square(edge), isTrue, reason: '$reason: $edge');
  }
  expect(outline.left, closeTo(left, slack), reason: '$reason: left');
  expect(outline.top, closeTo(top, slack), reason: '$reason: top');
  expect(outline.right, closeTo(right, slack), reason: '$reason: right');
  expect(outline.bottom, closeTo(bottom, slack), reason: '$reason: bottom');
  expect(design.dividers, isEmpty, reason: '$reason: no bar nobody drew');
  expect(design.topLevelSections, hasLength(1), reason: reason);
  expect(interpretation.questions, isEmpty, reason: reason);
}

void main() {
  test('only an angled design is not standard — and a design of a category '
      'this version does not know is never read as one', () {
    for (final kind in DesignKind.values) {
      expect(
        NormalizationContext(kind: kind).isStandard,
        kind != DesignKind.angled && kind != DesignKind.unsupported,
        reason: kind.name,
      );
    }
  });

  group('1 — a perfect rectangle', () {
    test('comes back exactly as drawn, with nothing corrected, in every '
        'category', () {
      for (final kind in DesignKind.values) {
        final out = normalize(runsOf('frame', perfect), kind);
        expect(
          out.changed,
          isFalse,
          reason: '${kind.name}: ${out.corrections}',
        );
        expect(
          [for (final r in out.runs) r.segment],
          [for (final r in runsOf('frame', perfect)) r.segment],
        );
        final drawn = read([pen('frame', perfect)], kind);
        expect(drawn.corrections, isEmpty, reason: kind.name);
        expectFrame(
          drawn,
          left: 0,
          top: 0,
          right: 2000,
          bottom: 1600,
          reason: kind.name,
        );
      }
    });

    test('drawn a side at a time, it is the same rectangle', () {
      for (final kind in standard) {
        expectFrame(
          read(sideBySide(perfect), kind),
          left: 0,
          top: 0,
          right: 2000,
          bottom: 1600,
          reason: kind.name,
        );
      }
    });
  });

  group('2 — a slightly tilted side', () {
    // The brief's example: the right side drawn leaning out, 3° and 7°.
    final leaning = {
      3: withCorner(perfect, 2, const Vec2(2084, 1600)),
      7: withCorner(perfect, 2, const Vec2(2196, 1600)),
    };

    test('comes back upright, between where its two ends were drawn, and '
        'every other side where it was', () {
      for (final MapEntry(key: degrees, value: corners) in leaning.entries) {
        for (final kind in standard) {
          final out = normalize(runsOf('frame', corners), kind);
          final why = '${kind.name}, $degrees°';
          for (final run in out.runs) {
            expect(square(run.segment), isTrue, reason: '$why: ${run.segment}');
          }
          expectClosed(out.runs);
          final right = out.runs[1].segment;
          expect(right.a.x, greaterThan(2000), reason: why);
          expect(right.a.x, lessThan(corners[2].x), reason: why);
          expect(out.runs[3].segment.a.x, 0, reason: '$why: the left side');
          expect(out.runs[0].segment.a.y, 0, reason: '$why: the head');
          expect(out.runs[2].segment.a.y, 1600, reason: '$why: the sill');
          expect(
            {for (final c in out.corrections) c.kind},
            contains(
              degrees < 5 ? CorrectionKind.squared : CorrectionKind.leaning,
            ),
            reason: why,
          );

          for (final strokes in [
            [pen('frame', corners)],
            sideBySide(corners),
          ]) {
            expectFrame(
              read(strokes, kind),
              left: 0,
              top: 0,
              right: (2000 + corners[2].x) / 2,
              bottom: 1600,
              slack: 1,
              reason: '$why, ${strokes.length} stroke(s)',
            );
          }
        }
      }
    });

    test('in an angled design a lean past a hand\'s wobble is a slope, and '
        'kept', () {
      final out = normalize(runsOf('frame', leaning[7]!), DesignKind.angled);
      expect(out.changed, isFalse, reason: out.corrections.join('\n'));
      final drawn = read([pen('frame', leaning[7]!)], DesignKind.angled);
      expect(
        drawn.design.frame!.outline.edges.where((e) => !square(e)),
        hasLength(1),
        reason: 'the right side kept at its slope',
      );
      // Three degrees — 84 mm over the side's 160 cm — is kept too: more
      // than the hand's precision, so in a design whose slopes are meant it
      // is one of them (see tolerance_based_detection_test.dart). Only a
      // side out by less than a hand can place a line is cleaned.
      final three = normalize(runsOf('frame', leaning[3]!), DesignKind.angled);
      expect(three.changed, isFalse, reason: three.corrections.join('\n'));
      final hair = normalize(
        runsOf('frame', withCorner(perfect, 2, const Vec2(2015, 1600))),
        DesignKind.angled,
      );
      for (final run in hair.runs) {
        expect(square(run.segment), isTrue, reason: '${run.segment}');
      }
    });
  });

  group('3 — a slightly tilted top', () {
    final tilted = {
      3: withCorner(perfect, 1, const Vec2(2000, 105)),
      7: withCorner(perfect, 1, const Vec2(2000, 245)),
    };

    test('comes back level, between where its ends were drawn, the sill and '
        'the sides where they were', () {
      for (final MapEntry(key: degrees, value: corners) in tilted.entries) {
        for (final kind in standard) {
          final why = '${kind.name}, $degrees°';
          final out = normalize(runsOf('frame', corners), kind);
          final head = out.runs[0].segment;
          expect(head.a.y, head.b.y, reason: why);
          expect(head.a.y, greaterThan(0), reason: why);
          expect(head.a.y, lessThan(corners[1].y), reason: why);
          expectClosed(out.runs);
          expectFrame(
            read([pen('frame', corners)], kind),
            left: 0,
            top: corners[1].y / 2,
            right: 2000,
            bottom: 1600,
            slack: 1,
            reason: why,
          );
        }
      }
    });

    test('a head tilted past a lean is a slope, and kept, in every design', () {
      final pitched = withCorner(perfect, 1, const Vec2(2000, 425)); // 12°
      for (final kind in DesignKind.values) {
        final out = normalize(runsOf('frame', pitched), kind);
        expect(out.changed, isFalse, reason: kind.name);
      }
    });
  });

  group('4 — a slightly inaccurate corner', () {
    test('ends drawn a little apart meet, and the corner is square', () {
      final apart = [
        pen('head', const [Vec2(0, 0), Vec2(2000, 0)]),
        pen('jamb', const [Vec2(2040, 50), Vec2(2040, 1600)]),
        pen('sill', const [Vec2(2040, 1600), Vec2(0, 1600)]),
        pen('left', const [Vec2(0, 1600), Vec2(0, 0)]),
      ];
      for (final kind in standard) {
        expectFrame(
          read(apart, kind),
          left: 0,
          top: 25,
          right: 2020,
          bottom: 1600,
          slack: 15,
          reason: kind.name,
        );
      }
    });

    test('a corner drawn past is trimmed back to it — no stub, no bar along '
        'the frame', () {
      final overshot = [
        pen('head', const [Vec2(0, 0), Vec2(2150, 0)]),
        pen('jamb', const [Vec2(2000, -10), Vec2(2000, 1600)]),
        pen('sill', const [Vec2(2000, 1600), Vec2(0, 1600)]),
        pen('left', const [Vec2(0, 1600), Vec2(0, 0)]),
      ];
      final runs = [
        for (final s in overshot)
          DrawnRun(Segment(s.points.first, s.points.last), s.id),
      ];
      for (final kind in DesignKind.values) {
        final out = normalize(runs, kind);
        expect(
          out.runs[0].segment,
          const Segment(Vec2(0, 0), Vec2(2000, 0)),
          reason: kind.name,
        );
        expect(out.runs[1].segment.a, const Vec2(2000, 0), reason: kind.name);
        expect(
          [
            for (final c in out.corrections)
              if (c.kind == CorrectionKind.trimmed) c.strokeId,
          ],
          ['head', 'jamb'],
        );
        expectFrame(
          read(overshot, kind),
          left: 0,
          top: 0,
          right: 2000,
          bottom: 1600,
          reason: kind.name,
        );
      }
    });

    test('a loop closed past where it began is trimmed to its corner', () {
      final pastStart = [...perfect.take(4), const Vec2(0, -120)];
      for (final kind in standard) {
        final out = normalize(runsOf('frame', pastStart), kind);
        expect(out.runs.last.segment.b, const Vec2(0, 0), reason: kind.name);
        expect(out.runs.first.segment.a, const Vec2(0, 0), reason: kind.name);
        expectFrame(
          read([pen('frame', pastStart)], kind),
          left: 0,
          top: 0,
          right: 2000,
          bottom: 1600,
          reason: kind.name,
        );
      }
    });

    test('a corner drawn a few degrees off square is square', () {
      // The jamb leaves the head at 86°, and the sill meets it at 94°.
      final off = withCorner(perfect, 2, const Vec2(1888, 1600));
      for (final kind in standard) {
        final out = normalize(runsOf('frame', off), kind);
        final head = out.runs[0].segment;
        final jamb = out.runs[1].segment;
        expect(head.direction.dot(jamb.direction), 0, reason: kind.name);
        expectClosed(out.runs);
      }
    });

    test('an end stopped short of the line it was heading for is not '
        'closed — that is an outline left open, and it is asked about', () {
      // A door with no sill: the jambs stop on the floor, nothing across.
      final noSill = [
        pen('frame', const [
          Vec2(0, 2000),
          Vec2(0, 0),
          Vec2(900, 0),
          Vec2(900, 2000),
        ]),
      ];
      final out = read(noSill, DesignKind.door);
      expect([
        for (final q in out.questions) q.id,
      ], contains(SketchInterpreter.outlineGapQuestion));
      expect(
        out.corrections.where((c) => c.kind == CorrectionKind.trimmed),
        isEmpty,
      );
    });
  });

  group('5 — slightly non-parallel sides', () {
    test('both jambs drawn leaning, the opposite ways, come back upright '
        'and parallel', () {
      // Left 3° one way, right 4° the other, and the head and sill out too.
      const skewed = [
        Vec2(0, 0),
        Vec2(2000, 70),
        Vec2(1888, 1600),
        Vec2(84, 1544),
        Vec2(0, 0),
      ];
      for (final kind in standard) {
        final out = normalize(runsOf('frame', skewed), kind);
        for (final run in out.runs) {
          expect(square(run.segment), isTrue, reason: '${run.segment}');
        }
        expectClosed(out.runs);
        final left = out.runs[3].segment, right = out.runs[1].segment;
        expect(left.direction.cross(right.direction), 0, reason: kind.name);
        expectFrame(
          read([pen('frame', skewed)], kind),
          left: 42,
          top: 35,
          right: 1944,
          bottom: 1572,
          slack: 1,
          reason: kind.name,
        );
      }
    });

    test('one side within a wobble and the other leaning further: both '
        'upright', () {
      const skewed = [
        Vec2(0, 0),
        Vec2(2000, 0),
        Vec2(2225, 1600),
        Vec2(84, 1600),
        Vec2(0, 0),
      ];
      for (final kind in standard) {
        final out = normalize(runsOf('frame', skewed), kind);
        for (final run in out.runs) {
          expect(square(run.segment), isTrue, reason: '${run.segment}');
        }
        expectClosed(out.runs);
      }
    });

    test('a parallelogram — both jambs leaning the same way under a level '
        'head — is a rectangle', () {
      final slanted = [
        perfect[0],
        perfect[1],
        const Vec2(2196, 1600),
        const Vec2(196, 1600),
        perfect[0],
      ];
      for (final kind in standard) {
        expectFrame(
          read([pen('frame', slanted)], kind),
          left: 98,
          top: 0,
          right: 2098,
          bottom: 1600,
          slack: 1,
          reason: kind.name,
        );
      }
    });
  });

  group('what is not made rectangular', () {
    test('a narrow light drawn tapering is a taper: the lean is too much of '
        'its width to be a wobble', () {
      // 40 cm across at the head, 60 at the sill: 7°, a half of its width.
      final taper = withCorner(
        withCorner(perfect, 1, const Vec2(400, 0)),
        2,
        const Vec2(596, 1600),
      );
      for (final kind in standard) {
        final out = normalize(runsOf('frame', taper), kind);
        expect(out.changed, isFalse, reason: kind.name);
      }
    });

    test('a rectangle drawn turned altogether has nothing square to go by, '
        'and is kept as drawn', () {
      // Every side 7° off: no side is square, so no lean is squared.
      const turned = [
        Vec2(0, 0),
        Vec2(1985, 244),
        Vec2(1790, 1832),
        Vec2(-195, 1588),
        Vec2(0, 0),
      ];
      for (final kind in standard) {
        expect(
          normalize(runsOf('frame', turned), kind).changed,
          isFalse,
          reason: kind.name,
        );
      }
    });

    test('a gable keeps its slopes, and a diagonal bar its angle', () {
      const gable = [
        Vec2(0, 600),
        Vec2(1000, 0),
        Vec2(2000, 600),
        Vec2(2000, 2200),
        Vec2(0, 2200),
        Vec2(0, 600),
      ];
      for (final kind in DesignKind.values) {
        final out = normalize([
          ...runsOf('frame', gable),
          ...runsOf('bar', const [Vec2(0, 2200), Vec2(1000, 600)]),
        ], kind);
        expect(out.changed, isFalse, reason: kind.name);
      }
    });

    test('unequal lights stay unequal and a mullion where it was drawn', () {
      final drawn = read([
        pen('frame', perfect),
        pen('mullion', const [Vec2(430, 0), Vec2(430, 1600)]),
      ], DesignKind.window).design;
      expect(drawn.dividers.single.segment.a.x, 430);
    });

    test('the same drawing gives the same runs every time', () {
      final corners = withCorner(perfect, 2, const Vec2(2196, 1600));
      final once = normalize(runsOf('frame', corners), DesignKind.door);
      final twice = normalize(runsOf('frame', corners), DesignKind.door);
      expect(
        [for (final r in twice.runs) r.segment],
        [for (final r in once.runs) r.segment],
      );
    });
  });
}
