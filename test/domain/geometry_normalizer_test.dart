import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/geometry_normalizer.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

// The normaliser is where a hand's inaccuracy comes out of a drawing, and
// the only place it does: every run of the drawing at once, before the
// design is built from them. These hold the three things it has to do from
// the start — leave a correct drawing exactly as it is, correct a slightly
// inaccurate one into the geometry the user meant, and leave alone what the
// user drew on purpose — and that the correction lands in the canonical
// geometry without costing the design anything else it holds.

/// A stroke drawn through [corners], sampled along each leg as a pen is.
Stroke pen(String id, List<Vec2> corners) {
  final samples = <StrokeSample>[];
  for (var i = 1; i < corners.length; i++) {
    for (var k = 0; k < 20; k++) {
      samples.add(StrokeSample(corners[i - 1].lerp(corners[i], k / 20)));
    }
  }
  samples.add(StrokeSample(corners.last));
  return Stroke(id: id, samples: samples);
}

/// The runs [corners] make, one stroke's legs in order.
List<DrawnRun> runsOf(String id, List<Vec2> corners) => [
  for (var i = 1; i < corners.length; i++)
    DrawnRun(Segment(corners[i - 1], corners[i]), id),
];

NormalizedGeometry normalize(
  List<DrawnRun> runs, {
  List<Stroke> ink = const [],
  DesignKind kind = DesignKind.window,
}) => GeometryNormalizer.normalizeStandardGeometry(
  runs,
  NormalizationContext(kind: kind, ink: {for (final s in ink) s.id: s}),
);

bool level(Segment s) => s.a.y == s.b.y;
bool upright(Segment s) => s.a.x == s.b.x;

/// How far [s] is off its nearest axis, in degrees.
double offAxis(Segment s) => s.offAxisDegrees;

/// A 200 × 160 cm rectangle drawn square.
const square = [
  Vec2(0, 0),
  Vec2(2000, 0),
  Vec2(2000, 1600),
  Vec2(0, 1600),
  Vec2(0, 0),
];

/// The same rectangle as a hand draws it: every side about a degree out,
/// and the loop closed a little short of where it began.
const handDrawn = [
  Vec2(0, 0),
  Vec2(2000, 35),
  Vec2(1965, 1600),
  Vec2(-30, 1580),
  Vec2(4, 6),
];

Design read(List<Stroke> strokes, {DesignKind kind = DesignKind.window}) =>
    SketchInterpreter.interpret(
      Design.empty(
        id: 'normalised',
        kind: kind,
      ).copyWith(sketch: Sketch(strokes: strokes)),
    ).design;

void main() {
  group('an already correct rectangle', () {
    test('comes back exactly as it went in, with nothing corrected', () {
      final runs = runsOf('frame', square);
      final out = normalize(runs, ink: [pen('frame', square)]);
      expect(out.changed, isFalse, reason: out.corrections.join('\n'));
      expect(out.runs, hasLength(runs.length));
      for (var i = 0; i < runs.length; i++) {
        expect(out.runs[i].segment, runs[i].segment);
        expect(out.runs[i].strokeId, runs[i].strokeId);
      }
    });

    test('read as a design, its frame is the rectangle drawn', () {
      final result = SketchInterpreter.interpret(
        Design.empty(
          id: 'n',
          kind: DesignKind.window,
        ).copyWith(sketch: Sketch(strokes: [pen('frame', square)])),
      );
      expect(result.corrections, isEmpty);
      final outline = result.design.frame!.outline;
      expect(outline.left, 0);
      expect(outline.top, 0);
      expect(outline.right, 2000);
      expect(outline.bottom, 1600);
      for (final edge in outline.edges) {
        expect(level(edge) || upright(edge), isTrue, reason: '$edge');
      }
    });
  });

  group('slightly inaccurate geometry is corrected', () {
    test('a rectangle drawn a degree out comes back square, every corner '
        'still a corner', () {
      final runs = runsOf('frame', handDrawn);
      final out = normalize(runs, ink: [pen('frame', handDrawn)]);
      expect(out.changed, isTrue);
      expect(out.runs, hasLength(4));
      for (final run in out.runs) {
        expect(
          level(run.segment) || upright(run.segment),
          isTrue,
          reason: '${run.segment}',
        );
        expect(run.squaredTo, isNotNull);
      }
      // Still one closed shape: each run starts where the last one ended.
      for (var i = 0; i < 4; i++) {
        expect(out.runs[i].segment.b, out.runs[(i + 1) % 4].segment.a);
      }
      // And it is the rectangle the hand drew, not a different one: every
      // corner within the hand's own wobble of where it was put.
      for (var i = 0; i < 4; i++) {
        expect(
          out.runs[i].segment.a.distanceTo(handDrawn[i]),
          lessThan(40),
          reason: 'corner $i',
        );
      }
    });

    test('read as a design, the frame is square — the fault the audit found, '
        'where joining the corners undid the squaring', () {
      final design = read([pen('frame', handDrawn)]);
      for (final edge in design.frame!.outline.edges) {
        expect(level(edge) || upright(edge), isTrue, reason: '$edge');
      }
    });

    test('two transoms drawn level either side of a mullion, a hand apart in '
        'height, come back level and still meeting', () {
      final runs = [
        ...runsOf('frame', square),
        ...runsOf('mullion', const [Vec2(1000, 0), Vec2(1000, 1600)]),
        ...runsOf('left', const [Vec2(0, 500), Vec2(1000, 500)]),
        ...runsOf('right', const [Vec2(1000, 515), Vec2(2000, 515)]),
      ];
      final out = normalize(runs);
      final left = out.runs.firstWhere((r) => r.strokeId == 'left').segment;
      final right = out.runs.firstWhere((r) => r.strokeId == 'right').segment;
      expect(level(left), isTrue, reason: '$left');
      expect(level(right), isTrue, reason: '$right');
      expect(left.b, right.a, reason: 'they still meet');
    });

    test('every change is recorded, before and after, against its stroke', () {
      final out = normalize(
        runsOf('frame', handDrawn),
        ink: [pen('frame', handDrawn)],
      );
      final kinds = {for (final c in out.corrections) c.kind};
      expect(
        kinds,
        containsAll([CorrectionKind.squared, CorrectionKind.joined]),
      );
      for (final c in out.corrections) {
        expect(c.strokeId, 'frame');
        expect(c.after, isNotNull);
        expect(c.before, isNot(c.after));
      }
    });
  });

  group('geometry that is meant stays as it was drawn', () {
    test('a slope keeps its angle exactly: past a lean in any design, and '
        'at any angle in an angled one', () {
      // A head drawn at seven degrees is a lean in a window (see
      // standard_normalization_rules_test.dart); in a design begun as
      // angled the user said slopes are meant, so it is kept.
      const pitched = [
        Vec2(0, 0),
        Vec2(2000, 245),
        Vec2(2000, 1600),
        Vec2(0, 1600),
        Vec2(0, 0),
      ];
      final angled = normalize(
        runsOf('frame', pitched),
        kind: DesignKind.angled,
      );
      expect(angled.changed, isFalse, reason: angled.corrections.join('\n'));
      expect(
        angled.runs.first.segment,
        const Segment(Vec2(0, 0), Vec2(2000, 245)),
      );
      expect(angled.runs.first.squaredTo, isNull);

      // Twelve degrees is past any lean of the hand: a window keeps it too.
      const steep = [
        Vec2(0, 0),
        Vec2(2000, 425),
        Vec2(2000, 1600),
        Vec2(0, 1600),
        Vec2(0, 0),
      ];
      final window = normalize(runsOf('frame', steep));
      expect(window.changed, isFalse, reason: window.corrections.join('\n'));
      expect(
        window.runs.first.segment,
        const Segment(Vec2(0, 0), Vec2(2000, 425)),
      );
    });

    test('a gable and a diagonal glazing bar are left exactly as drawn', () {
      const gable = [
        Vec2(0, 600),
        Vec2(1000, 0),
        Vec2(2000, 600),
        Vec2(2000, 2200),
        Vec2(0, 2200),
        Vec2(0, 600),
      ];
      final runs = [
        ...runsOf('frame', gable),
        ...runsOf('diagonal', const [Vec2(0, 2200), Vec2(1000, 600)]),
      ];
      final out = normalize(runs);
      expect(out.changed, isFalse, reason: out.corrections.join('\n'));
      for (var i = 0; i < runs.length; i++) {
        expect(out.runs[i].segment, runs[i].segment);
      }
      final design = read([
        pen('frame', gable),
        pen('diagonal', const [Vec2(60, 2140), Vec2(1000, 700)]),
      ]);
      final rakes = design.frame!.outline.edges
          .where((e) => offAxis(e) > 5)
          .toList();
      expect(rakes, hasLength(2), reason: 'both slopes of the gable kept');
      final bar = design.dividers.single.segment;
      expect(offAxis(bar), greaterThan(30), reason: 'the diagonal kept');
    });

    test(
      'unequal parts stay unequal — nothing is made equal or symmetrical',
      () {
        final runs = [
          ...runsOf('frame', square),
          ...runsOf('mullion', const [Vec2(430, 0), Vec2(430, 1600)]),
          ...runsOf('transom', const [Vec2(0, 1170), Vec2(430, 1170)]),
        ];
        final out = normalize(runs);
        expect(out.changed, isFalse);
        final mullion = out.runs.firstWhere((r) => r.strokeId == 'mullion');
        final transom = out.runs.firstWhere((r) => r.strokeId == 'transom');
        expect(mullion.segment.a.x, 430);
        expect(transom.segment.a.y, 1170);
      },
    );

    test(
      'the same drawing gives the same runs, in the same order, every time',
      () {
        final runs = [
          ...runsOf('frame', handDrawn),
          ...runsOf('mullion', const [Vec2(990, 20), Vec2(1003, 1590)]),
        ];
        final ink = [pen('frame', handDrawn)];
        final once = normalize(runs, ink: ink).runs;
        final twice = normalize(runs, ink: ink).runs;
        expect(
          [for (final r in twice) r.segment],
          [for (final r in once) r.segment],
        );
        expect(
          [for (final r in once) r.strokeId],
          ['frame', 'frame', 'frame', 'frame', 'mullion'],
        );
      },
    );
  });

  group(
    'the correction is in the canonical geometry, and costs nothing else',
    () {
      /// A window drawn by hand a degree out: a mullion, a `<` in the left
      /// light, a line drawn inside that opening, glass over a brown panel, a
      /// dimension, and a customer.
      Design worked() {
        var design = SketchInterpreter.interpret(
          Design.empty(id: 'design-7', kind: DesignKind.window).copyWith(
            customerId: 'customer-3',
            sketch: Sketch(
              strokes: [
                pen('frame', handDrawn),
                pen('mullion', const [Vec2(800, 18), Vec2(812, 1590)]),
                pen('mark', const [
                  Vec2(560, 650),
                  Vec2(260, 800),
                  Vec2(560, 950),
                ]),
              ],
            ),
          ),
        ).design;
        final opening = design.openings.single;
        final box = design.sectionById(opening.sectionId)!.outline;
        design = DesignEdits.addLineInside(
          design,
          opening.sectionId,
          id: 'inside',
          at: Vec2(box.centroid.x, box.top + 500),
          horizontal: true,
        );
        final lower = design
            .childSectionsOf(opening.sectionId)
            .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
        design = design.withElement(
          lower.copyWith(
            finish: const Finish(
              colour: 0xFF7B4A2B,
              material: MaterialKind.panel,
            ),
          ),
        );
        return design.copyWith(
          dimensions: [
            const DimensionElement(
              id: 'dim-width',
              a: Vec2(0, -300),
              b: Vec2(2000, -300),
              offsetMm: 0,
              statedMm: 2000,
            ),
          ],
        );
      }

      String fingerprint(Design d) => jsonEncode({
        'id': d.id,
        'customerId': d.customerId,
        'openings': [
          for (final o in d.openings) [o.id, o.mechanism.name, o.markGlyph],
        ],
        'inside': [
          for (final b in d.dividers)
            if (b.parentId != null) [b.id, b.parentId],
        ],
        'finishes': [
          for (final s in d.sections) [s.parentId != null, s.finish.toJson()],
        ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
        'hardware': [
          for (final h in d.hardware) [h.kind.name, h.parentId],
        ]..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b))),
        'dimensions': [for (final m in d.dimensions) m.toJson()],
      });

      test('the frame read from the hand-drawn sheet is square', () {
        final design = worked();
        for (final edge in design.frame!.outline.edges) {
          expect(level(edge) || upright(edge), isTrue, reason: '$edge');
        }
        final mullion = design.topLevelDividers.single.segment;
        expect(upright(mullion), isTrue, reason: '$mullion');
      });

      test('openings, the line inside, glass, panel, hinges, handle, '
          'dimensions and both ids survive a second reading', () {
        final before = worked();
        expect(before.openings, hasLength(1));
        expect(before.dividers.where((d) => d.parentId != null), hasLength(1));
        expect(
          before.sections.where((s) => s.finish.material == MaterialKind.panel),
          hasLength(1),
        );
        expect([
          for (final h in before.hardware) h.kind,
        ], containsAll([HardwareKind.hinge]));
        expect(before.hardware.where((h) => h.kind.isHandle), isNotEmpty);

        final again = SketchInterpreter.interpret(before).design;
        expect(fingerprint(again), fingerprint(before));
        expect(again.frame!.outline, before.frame!.outline);
        expect(
          {for (final d in again.dividers) d.id: d.segment},
          {for (final d in before.dividers) d.id: d.segment},
        );
      });
    },
  );

  group('the geometry underneath', () {
    test('two collinear edges are parallel, whatever rounding noise they '
        'carry', () {
      // The body of a mullion lying along the frame's daylight edge, both
      // exactly level but for the last bits of a double.
      const edge = Segment(
        Vec2(56.30773067665789, 63.39391208409802),
        Vec2(1935.682687491367, 63.393912084097934),
      );
      const body = Segment(
        Vec2(423.457, 63.39391208409802),
        Vec2(375.457, 63.393912084097934),
      );
      expect(edge.crossing(body, tolerance: 10.25), isNull);
      // A real crossing is still found.
      const upright = Segment(Vec2(375.457, 63.39), Vec2(375.457, 1542.3));
      expect(
        edge.crossing(upright, tolerance: 10.25)!.at.x,
        closeTo(375.457, 1e-6),
      );
    });

    test('a square drawing with a mullion gives exactly square sections, '
        'the mullion\'s faces where the mullion is', () {
      final design = read([
        pen('frame', square),
        pen('mullion', const [Vec2(400, 0), Vec2(400, 1600)]),
      ]);
      final bar = design.dividers.single;
      final half = bar.widthMm / 2;
      final left = design.topLevelSections.reduce(
        (a, b) => a.outline.left < b.outline.left ? a : b,
      );
      for (final corner in left.outline.corners) {
        expect(
          [
            design.frame!.innerOutline.left,
            bar.a.x - half,
          ].any((x) => (corner.x - x).abs() < 1e-6),
          isTrue,
          reason: '$corner',
        );
      }
      expect(left.outline.corners, hasLength(4));
      expect(
        left.outline.width,
        closeTo(bar.a.x - half - design.frame!.innerOutline.left, 1e-6),
      );
    });
  });
}
