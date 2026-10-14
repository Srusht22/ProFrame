import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/scale.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// ---------------------------------------------------------------------------
// THE USER'S DRAWING IS THE SOURCE OF TRUTH.
//
// This file is that rule, written as assertions. It is not a test of a
// feature; it is the thing the application exists to do. Do not weaken it to
// make a change pass. If a change cannot keep it true, the change is wrong.
// ---------------------------------------------------------------------------

var _n = 0;

/// A stroke drawn by an unsteady hand.
Stroke drawn(List<Vec2> through, {double wobble = 6, int seed = 0}) {
  final random = math.Random(seed * 31 + _n + 17);
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

Design sketchOf(List<Stroke> strokes, {DesignKind kind = DesignKind.window}) {
  final at = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: kind,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: strokes),
  );
}

/// The drawing from the specification: a narrow left column split by a
/// transom, and a wide right column running the full height.
///
/// ```
/// ┌───────────────────┐
/// │     │             │
/// │     │             │
/// ├─────┤             │
/// │     │             │
/// │     │             │
/// └─────┴─────────────┘
/// ```
Design theDrawing({double wobble = 6}) => sketchOf([
      drawn(const [
        Vec2(0, 0),
        Vec2(1900, 0),
        Vec2(1900, 1500),
        Vec2(0, 1500),
        Vec2(0, 0),
      ], wobble: wobble),
      // The mullion, at barely a quarter of the way across.
      drawn(const [Vec2(500, 0), Vec2(500, 1500)], wobble: wobble),
      // The transom, across the left column only, and not at its middle.
      drawn(const [Vec2(0, 620), Vec2(500, 620)], wobble: wobble),
    ]);

/// Each section as a fraction of the design, so proportions can be compared
/// across any scale.
List<({double x, double y, double w, double h})> proportionsOf(Design design) {
  final frame = design.frame!;
  final width = frame.widthMm;
  final height = frame.heightMm;
  final out = [
    for (final section in design.sections)
      (
        x: (section.outline.left - frame.outline.left) / width,
        y: (section.outline.top - frame.outline.top) / height,
        w: section.widthMm / width,
        h: section.heightMm / height,
      ),
  ];
  out.sort((a, b) {
    final byY = a.y.compareTo(b.y);
    return byY != 0 ? byY : a.x.compareTo(b.x);
  });
  return out;
}

void expectSameProportions(
  List<({double x, double y, double w, double h})> after,
  List<({double x, double y, double w, double h})> before, {
  double within = 0.002,
  String? reason,
}) {
  expect(after, hasLength(before.length), reason: reason);
  for (var i = 0; i < before.length; i++) {
    expect(after[i].x, closeTo(before[i].x, within), reason: reason);
    expect(after[i].y, closeTo(before[i].y, within), reason: reason);
    expect(after[i].w, closeTo(before[i].w, within), reason: reason);
    expect(after[i].h, closeTo(before[i].h, within), reason: reason);
  }
}

void main() {
  setUp(() => _n = 0);

  group('the drawing from the specification', () {
    test('is read as the structure it is', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;

      expect(design.sections, hasLength(3),
          reason: 'two on the left of the mullion, one tall on the right');
      expect(design.dividers, hasLength(2));

      final left = [
        for (final s in design.sections) if (s.outline.right < 500) s,
      ];
      final right = [
        for (final s in design.sections) if (s.outline.left > 500) s,
      ];
      expect(left, hasLength(2), reason: 'the left column is split');
      expect(right, hasLength(1), reason: 'the right column is not');

      // The right column runs the full height of the opening.
      expect(right.single.heightMm, closeTo(design.heightMm - 120, 25));
    });

    test('is NOT made equal', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;

      final leftWidth = design.sections
          .firstWhere((s) => s.outline.right < 500)
          .widthMm;
      final rightWidth = design.sections
          .firstWhere((s) => s.outline.left > 500)
          .widthMm;

      // Drawn at roughly 500 : 1400. Anything approaching equal would mean
      // the application had decided it looked better that way.
      expect(rightWidth / leftWidth, greaterThan(2.5));
    });

    test('is NOT made symmetrical', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final frame = design.frame!;

      // Mirror the design about its own vertical centre line and ask whether
      // it lands on itself. A design that has been forced symmetrical would.
      final middle = (frame.outline.left + frame.outline.right) / 2;
      final mirrored = {
        for (final s in design.sections)
          '${(2 * middle - s.outline.right).round()}:'
              '${s.outline.top.round()}:${s.widthMm.round()}',
      };
      final asDrawn = {
        for (final s in design.sections)
          '${s.outline.left.round()}:${s.outline.top.round()}:'
              '${s.widthMm.round()}',
      };
      expect(mirrored, isNot(asDrawn));
    });

    test('the transom stays on the left column only', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final transom =
          design.dividers.firstWhere((d) => d.isHorizontal);

      expect(transom.segment.a.x, closeTo(0, 40));
      expect(transom.segment.b.x, closeTo(500, 40));
      // It was not run across the whole design to tidy the drawing up.
      expect(transom.lengthMm, lessThan(design.widthMm * 0.45));
    });

    test('the transom is NOT moved to the middle of its column', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final upper = design.sections
          .where((s) => s.outline.right < 500)
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final lower = design.sections
          .where((s) => s.outline.right < 500)
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

      // Drawn at 620 of 1500 — above the middle, and it stays there.
      expect(upper.heightMm, lessThan(lower.heightMm * 0.85));
    });

    test('survives being read again, and again, and again', () {
      var design = SketchInterpreter.interpret(theDrawing()).design;
      final before = proportionsOf(design);

      for (var i = 0; i < 6; i++) {
        design = SketchInterpreter.interpret(design).design;
        expectSameProportions(proportionsOf(design), before,
            reason: 'reading ${i + 2} times must not drift');
      }
    });

    test('survives being given a real size', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final before = proportionsOf(design);

      for (final width in [900.0, 2400.0, 6000.0]) {
        expectSameProportions(
          proportionsOf(DesignScale.toWidth(design, width)),
          before,
          reason: 'scaling to $width must keep every proportion',
        );
      }
    });

    test('survives being saved and read back', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final before = proportionsOf(design);
      final after = Design.fromJson(design.toJson());

      expectSameProportions(proportionsOf(after), before);
      expect(after.sketch.strokes, hasLength(design.sketch.strokes.length));
    });

    test('survives being turned into a solid', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final mesh = MeshBuilder.build(design);

      // Every pane in the drawing is a pane in the solid, in the same place
      // and at the same size, and there are no others.
      final panes = {
        for (final f in mesh.facets)
          if (f.role == FacetRole.glazing || f.role == FacetRole.panel)
            f.elementId,
      };
      expect(panes, {for (final s in design.sections) s.id});

      for (final section in design.sections) {
        var left = 1e9, right = -1e9;
        for (final facet in mesh.facets) {
          if (facet.elementId != section.id) continue;
          for (final c in facet.corners) {
            if (c.x < left) left = c.x;
            if (c.x > right) right = c.x;
          }
        }
        expect(right - left, closeTo(section.widthMm, 1));
      }
    });

    test('survives a run of unrelated edits', () {
      var design = SketchInterpreter.interpret(theDrawing()).design;
      final before = proportionsOf(design);

      final tall = design.sections
          .reduce((a, b) => a.heightMm > b.heightMm ? a : b);

      // Colours, materials, hardware, depth, notes: none of these is a
      // change of shape, so none of them may move anything.
      design = design.withElement(tall.copyWith(
        finish: const Finish(colour: 0xFF8C1E20, material: MaterialKind.panel),
      ));
      design = design.copyWith(depthMm: 180);
      design = design.copyWith(hardware: [
        const HardwareElement(
          id: 'h',
          kind: HardwareKind.lever,
          at: Vec2(1700, 750),
        ),
      ]);
      design = DesignEdits.setOpening(
        design,
        tall.id,
        openingId: 'o',
        mechanism: OpeningMechanism.hingedRight,
      );

      expectSameProportions(proportionsOf(design), before);
    });
  });

  group('nothing is added and nothing is taken away', () {
    test('an empty sketch yields nothing at all', () {
      final design = SketchInterpreter.interpret(sketchOf([])).design;
      expect(design.frame, isNull);
      expect(design.sections, isEmpty);
      expect(design.dividers, isEmpty);
      expect(design.openings, isEmpty);
      expect(design.hardware, isEmpty);
    });

    test('a plain box gains no bars, no panels and no hardware', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(900, 0),
          Vec2(900, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
      ], kind: DesignKind.door)).design;

      expect(design.dividers, isEmpty,
          reason: 'a door is not given panels it was not drawn with');
      expect(design.sections, hasLength(1));
      expect(design.hardware, isEmpty,
          reason: 'a door is not given a handle to look complete');
      expect(design.openings, isEmpty,
          reason: 'a door does not open until the user says it does');
    });

    test('every line drawn comes back as a line', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(310, 0), Vec2(310, 1600)]),
        drawn(const [Vec2(690, 0), Vec2(690, 1600)]),
        drawn(const [Vec2(1450, 0), Vec2(1450, 1600)]),
        drawn(const [Vec2(690, 900), Vec2(1450, 900)]),
      ])).design;

      expect(design.dividers, hasLength(4),
          reason: 'four lines drawn, four bars built');
      expect(design.sections, hasLength(5));
      // And the user's own marks are all still there.
      expect(design.sketch.strokes, hasLength(5));
    });

    test('a line close to another is not swallowed by it', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(800, 0), Vec2(800, 1600)], wobble: 3),
        drawn(const [Vec2(1000, 0), Vec2(1000, 1600)], wobble: 3),
      ])).design;

      expect(design.dividers, hasLength(2));
      final gap = (design.dividers[0].a.x - design.dividers[1].a.x).abs();
      expect(gap, closeTo(200, 30));
    });
  });

  group('no design drifts towards any other', () {
    test('forty unequal designs each come back as themselves', () {
      final random = math.Random(4);
      final ratios = <double>[];
      var checked = 0;

      for (var trial = 0; trial < 40; trial++) {
        _n = 0;
        final width = 1200 + random.nextDouble() * 2400;
        final height = 900 + random.nextDouble() * 1800;

        // Two columns and one row, at genuinely arbitrary fractions, kept
        // clear of each other and of the edges.
        final atX1 = 0.12 + random.nextDouble() * 0.3;
        final atX2 = atX1 + 0.2 + random.nextDouble() * 0.3;
        final atY = 0.18 + random.nextDouble() * 0.55;

        final x1 = width * atX1;
        final x2 = width * atX2;
        final y = height * atY;

        final design = SketchInterpreter.interpret(sketchOf([
          drawn([
            const Vec2(0, 0),
            Vec2(width, 0),
            Vec2(width, height),
            Vec2(0, height),
            const Vec2(0, 0),
          ], wobble: 4, seed: trial),
          drawn([Vec2(x1, 0), Vec2(x1, height)], wobble: 4, seed: trial),
          drawn([Vec2(x2, 0), Vec2(x2, height)], wobble: 4, seed: trial),
          drawn([Vec2(0, y), Vec2(width, y)], wobble: 4, seed: trial),
        ])).design;

        expect(design.sections, hasLength(6),
            reason: 'trial $trial: three columns by two rows');

        // Every bar came back where it was drawn, not at a tidier figure.
        final verticals = [
          for (final d in design.dividers)
            if (d.isVertical) (d.a.x + d.b.x) / 2,
        ]..sort();
        expect(verticals, hasLength(2));
        expect(verticals[0], closeTo(x1, width * 0.02),
            reason: 'trial $trial: the first mullion moved');
        expect(verticals[1], closeTo(x2, width * 0.02),
            reason: 'trial $trial: the second mullion moved');

        final horizontal = design.dividers
            .firstWhere((d) => d.isHorizontal);
        expect((horizontal.a.y + horizontal.b.y) / 2,
            closeTo(y, height * 0.02),
            reason: 'trial $trial: the transom moved');

        // And each column is exactly the daylight the drawing leaves: from
        // one bar's face to the next, with the frame taken off at the ends.
        // Comparing the ratios of the drawn spacing would be wrong, because
        // a column is narrower than its spacing by the material either side
        // of it — that is arithmetic, not redesign.
        final frame = design.frame!;
        final inner = frame.innerOutline;
        final bars = [
          for (final d in design.dividers)
            if (d.isVertical) d,
        ]..sort((a, b) => a.a.x.compareTo(b.a.x));

        final stations = <double>[
          inner.left,
          for (final bar in bars) ...[
            (bar.a.x + bar.b.x) / 2 - bar.widthMm / 2,
            (bar.a.x + bar.b.x) / 2 + bar.widthMm / 2,
          ],
          inner.right,
        ];
        final expected = [
          for (var i = 0; i < stations.length; i += 2)
            stations[i + 1] - stations[i],
        ]..sort();

        final topRow = design.sections
            .map((s) => s.outline.top)
            .reduce(math.min);
        // Banded rather than matched exactly, for the same reason: three
        // panes in one row of a hand-drawn frame have tops a millimetre or
        // two apart.
        final widths = [
          for (final s in design.sections)
            if ((s.outline.top - topRow).abs() < height * 0.02) s.widthMm,
        ]..sort();

        expect(widths, hasLength(3), reason: 'trial $trial');
        for (var i = 0; i < 3; i++) {
          // A few millimetres of slack for the frame being hand-drawn and so
          // not perfectly square: its daylight edge is not quite parallel to
          // itself, so a column's width varies a little down its length.
          // Evening columns out would move them by hundreds of millimetres,
          // so the check keeps all its teeth.
          expect(widths[i], closeTo(expected[i], 8),
              reason: 'trial $trial: a column is not the daylight it should '
                  'be — something was evened out');
        }

        ratios.add(widths[0] / widths[2]);

        checked++;
      }

      expect(checked, 40);

      // And the forty designs are still forty different designs. If anything
      // were quietly pulling them towards a house shape, the narrowest and
      // the widest ratio would have converged.
      ratios.sort();
      expect(ratios.first, lessThan(0.45),
          reason: 'no design came back strongly unequal');
      expect(ratios.last, greaterThan(0.85),
          reason: 'no design came back nearly equal');
      expect(ratios.last - ratios.first, greaterThan(0.5),
          reason: 'the designs drifted towards one another');
    });

    test('a design is never nudged towards its own mirror image', () {
      final random = math.Random(9);
      for (var trial = 0; trial < 12; trial++) {
        _n = 0;
        // A mullion deliberately off centre, in both directions.
        final at = trial.isEven
            ? 0.2 + random.nextDouble() * 0.2
            : 0.6 + random.nextDouble() * 0.2;

        final design = SketchInterpreter.interpret(sketchOf([
          drawn(const [
            Vec2(0, 0),
            Vec2(2000, 0),
            Vec2(2000, 1400),
            Vec2(0, 1400),
            Vec2(0, 0),
          ], wobble: 4, seed: trial),
          drawn([Vec2(2000 * at, 0), Vec2(2000 * at, 1400)],
              wobble: 4, seed: trial),
        ])).design;

        final widths = [for (final s in design.sections) s.widthMm]..sort();
        // Equal columns would mean the mullion had been centred.
        expect((widths[1] - widths[0]).abs(), greaterThan(200),
            reason: 'trial $trial: the mullion drifted towards the middle');
      }
    });
  });

  group('cleaning is allowed, redesigning is not', () {
    test('a wobble along a line is smoothed', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1400, 0),
          Vec2(1400, 1400),
          Vec2(0, 1400),
          Vec2(0, 0),
        ], wobble: 9),
      ])).design;

      // Four sides, not one per wobble.
      expect(design.frame!.outline.corners, hasLength(4));
    });

    test('a line two degrees off vertical is squared to it', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1400, 0),
          Vec2(1400, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(600, 0), Vec2(640, 2000)], wobble: 3),
      ])).design;

      expect(design.dividers.single.isVertical, isTrue);
    });

    test('a line ten degrees off vertical keeps its slope', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1400, 0),
          Vec2(1400, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(500, 0), Vec2(860, 2000)], wobble: 3),
      ])).design;

      final bar = design.dividers.single;
      expect(bar.isVertical, isFalse,
          reason: 'a slope the user meant must not be squared away');
      expect((bar.b.x - bar.a.x).abs(), greaterThan(280));
    });

    test('a deliberately diagonal bar stays diagonal all the way to the 3D',
        () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1600, 0),
          Vec2(1600, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(80, 80), Vec2(1520, 1520)], wobble: 3),
      ])).design;

      final bar = design.dividers.single;
      expect(bar.segment.headingDegrees, closeTo(45, 6));

      var across = 0.0, down = 0.0;
      var left = 1e9, right = -1e9, top = 1e9, bottom = -1e9;
      for (final facet in MeshBuilder.build(design).facets) {
        if (facet.elementId != bar.id) continue;
        for (final c in facet.corners) {
          if (c.x < left) left = c.x;
          if (c.x > right) right = c.x;
          if (c.y < top) top = c.y;
          if (c.y > bottom) bottom = c.y;
        }
      }
      across = right - left;
      down = bottom - top;
      expect(across, greaterThan(1000));
      expect(down, greaterThan(1000));
    });

    test('a five-sided opening is not squared off into four', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 500),
          Vec2(700, 0),
          Vec2(1400, 500),
          Vec2(1400, 2000),
          Vec2(0, 2000),
          Vec2(0, 500),
        ], wobble: 4),
      ])).design;

      expect(design.frame!.outline.corners, hasLength(5));
      expect(design.frameMembers, hasLength(5));
      expect(
        design.frameMembers.where((m) => m.label.startsWith('Raking')),
        hasLength(2),
      );
    });
  });

  group('when it cannot tell, it asks', () {
    test('lines that do not close produce a question, not a frame', () {
      final result = SketchInterpreter.interpret(sketchOf([
        drawn(const [Vec2(0, 0), Vec2(1400, 0)]),
        drawn(const [Vec2(0, 900), Vec2(1400, 900)]),
      ]));
      expect(result.design.frame, isNull);
      expect(result.questions, isNotEmpty);
    });

    test('a mark across a bar opens the section it is in, not both', () {
      final result = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 1200),
          Vec2(0, 1200),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(900, 0), Vec2(900, 1200)], wobble: 3),
        // Straddling the mullion: its body is in the left light, its point
        // pokes over the bar. The user has said which section opens by
        // drawing the mark in it, so it opens, and it is not asked about.
        drawn(const [Vec2(700, 430), Vec2(1050, 600), Vec2(700, 770)],
            wobble: 3),
      ]));

      // Exactly one opening, on the section the mark is in — never both,
      // and never the whole design.
      expect(result.design.openings, hasLength(1));
      final opened = result.design
          .sectionById(result.design.openings.single.sectionId)!;
      expect(opened.outline.centroid.x, lessThan(900),
          reason: 'the mark sits in the left light');
      expect(result.design.topLevelSections, hasLength(2));
      expect(result.questions.any((q) => q.id.startsWith('symbol-')), isFalse,
          reason: 'the drawing already said which section opens');
    });

    test('every question offers the choices and takes none of them', () {
      final result = SketchInterpreter.interpret(theDrawing());
      for (final question in result.questions) {
        expect(question.options, isNotEmpty,
            reason: 'a question with no options is a decision in disguise');
        expect(question.prompt, isNotEmpty);
      }
      // Nothing was opened, coloured or added on the strength of a question.
      expect(result.design.openings, isEmpty);
      expect(result.design.hardware, isEmpty);
    });
  });

  group('editing obeys the rule too', () {
    test('resizing the frame keeps every bar where it was in proportion', () {
      final design = SectionBuilder.rebuild(
        SketchInterpreter.interpret(theDrawing()).design,
      );

      /// Each bar's centre line as a fraction across and down the frame.
      List<double> fractions(Design d) {
        final frame = d.frame!;
        return [
          for (final bar in d.dividers)
            if (bar.isVertical)
              ((bar.a.x + bar.b.x) / 2 - frame.outline.left) / frame.widthMm
            else
              ((bar.a.y + bar.b.y) / 2 - frame.outline.top) / frame.heightMm,
        ];
      }

      final before = fractions(design);

      for (final wider in [
        DesignEdits.resizeFrame(design, widthMm: 3200),
        DesignEdits.resizeFrame(design, heightMm: 2600),
        DesignEdits.resizeFrame(design, widthMm: 800, heightMm: 700),
      ]) {
        final after = fractions(wider);
        expect(after, hasLength(before.length));
        for (var i = 0; i < before.length; i++) {
          expect(after[i], closeTo(before[i], 0.001),
              reason: 'a bar moved relative to the frame it sits in');
        }
        // The bars did not get thicker because the window did: a bar is a
        // real piece of material. That is why the daylight proportions are
        // allowed to shift a little and the bar positions are not.
        for (var i = 0; i < design.dividers.length; i++) {
          expect(wider.dividers[i].widthMm,
              closeTo(design.dividers[i].widthMm, 0.01));
        }
      }
    });

    test('moving one bar leaves the other exactly where it was', () {
      final design = SketchInterpreter.interpret(theDrawing()).design;
      final mullion = design.dividers.firstWhere((d) => d.isVertical);
      final transom = design.dividers.firstWhere((d) => d.isHorizontal);

      final after = DesignEdits.moveDividerAcross(
        design,
        mullion.id,
        const Vec2(900, 700),
      );

      final stayed = after.dividers.firstWhere((d) => d.id == transom.id);
      expect(stayed.a.y, closeTo(transom.a.y, 0.01));
      expect(stayed.b.y, closeTo(transom.b.y, 0.01));
    });

    test('deleting a bar does not rearrange the ones that remain', () {
      final design = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(2000, 0),
          Vec2(2000, 1600),
          Vec2(0, 1600),
          Vec2(0, 0),
        ], wobble: 3),
        drawn(const [Vec2(340, 0), Vec2(340, 1600)], wobble: 3),
        drawn(const [Vec2(1300, 0), Vec2(1300, 1600)], wobble: 3),
      ])).design;

      final kept = design.dividers
          .reduce((a, b) => a.a.x < b.a.x ? a : b);
      final removed = design.dividers
          .reduce((a, b) => a.a.x > b.a.x ? a : b);

      final after = DesignEdits.delete(design, removed.id);

      expect(after.dividers, hasLength(1));
      expect(after.dividers.single.a.x, closeTo(kept.a.x, 0.01),
          reason: 'the remaining bar must not be recentred');
    });
  });
}
