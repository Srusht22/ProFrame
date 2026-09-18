import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/recognition/opening_symbol.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

var _n = 0;

/// A stroke drawn by a hand, not a plotter.
Stroke drawn(List<Vec2> through, {double wobble = 8, int seed = 0}) {
  final random = math.Random(seed * 31 + _n + 7);
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

/// A chevron of the given size, pointing right, drawn with [wobble] of hand.
Stroke chevron(Vec2 apex, double reach, {double wobble = 10, int seed = 0}) =>
    drawn(
      [
        Vec2(apex.x - reach, apex.y - reach * 0.9),
        apex,
        Vec2(apex.x - reach * 0.9, apex.y + reach),
      ],
      wobble: wobble,
      seed: seed,
    );

/// The phase's window: 200 cm by 160 cm, a 40 cm light down the left.
List<Stroke> window({int seed = 0}) => [
      drawn(const [
        Vec2(0, 0),
        Vec2(2000, 0),
        Vec2(2000, 1600),
        Vec2(0, 1600),
        Vec2(0, 0),
      ], seed: seed),
      drawn(const [Vec2(400, 0), Vec2(400, 1600)], seed: seed),
    ];

void main() {
  setUp(() => _n = 0);

  // ------------------------------------------------- the mark always works

  group('a mark drawn by a hand is read as a mark', () {
    test('every one of sixty shaky chevrons', () {
      var read = 0;
      for (var seed = 0; seed < 60; seed++) {
        _n = 0;
        final random = math.Random(seed);
        final mark = chevron(
          Vec2(600 + random.nextDouble() * 60, 900 + random.nextDouble() * 60),
          130 + random.nextDouble() * 80,
          wobble: 6 + random.nextDouble() * 9,
          seed: seed,
        );
        if (OpeningSymbolReader.read(mark) != null) read++;
      }
      expect(read, 60,
          reason: 'a mark that is not read becomes two bars, and the '
              'section the user said opens does not open');
    });

    test('and every one of them opens its section', () {
      var opened = 0;
      for (var seed = 0; seed < 40; seed++) {
        _n = 0;
        final random = math.Random(seed + 200);
        final design = SketchInterpreter.interpret(sketchOf([
          ...window(seed: seed),
          chevron(
            Vec2(1000 + random.nextDouble() * 200, 800),
            120 + random.nextDouble() * 60,
            wobble: 6 + random.nextDouble() * 8,
            seed: seed,
          ),
        ]));
        if (design.design.openings.length == 1) opened++;
      }
      expect(opened, 40);
    });

    test('a straight line is still not a mark', () {
      final line = drawn(const [Vec2(100, 100), Vec2(900, 140)], wobble: 6);
      expect(OpeningSymbolReader.read(line), isNull);
    });

    test('a frame corner is still not a mark', () {
      final corner = drawn(
        const [Vec2(100, 900), Vec2(100, 100), Vec2(900, 100)],
        wobble: 5,
      );
      expect(OpeningSymbolReader.read(corner), isNull);
    });

    test('a staircase of lines is still not a mark', () {
      final steps = drawn(
        const [
          Vec2(0, 0),
          Vec2(300, 0),
          Vec2(300, 300),
          Vec2(600, 300),
          Vec2(600, 600),
        ],
        wobble: 4,
      );
      expect(OpeningSymbolReader.read(steps), isNull);
    });

    test('a closed shape is still not a mark', () {
      final box = drawn(const [
        Vec2(0, 0),
        Vec2(800, 0),
        Vec2(800, 800),
        Vec2(0, 800),
        Vec2(0, 0),
      ]);
      expect(OpeningSymbolReader.read(box), isNull);
    });
  });

  // --------------------------------------------------- nothing is asked

  group('the drawing is not asked to say twice what it says once', () {
    test('a plain window is read with no questions at all', () {
      final result = SketchInterpreter.interpret(sketchOf(window()));
      expect(result.design.frame, isNotNull);
      expect(result.questions, isEmpty);
    });

    test('a window with a mark in it is read with no questions at all', () {
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        chevron(const Vec2(1100, 800), 150),
      ]));
      expect(result.design.openings, hasLength(1));
      expect(result.questions, isEmpty);
    });

    test('the size is never asked about; it is on the panel to be typed', () {
      final result = SketchInterpreter.interpret(sketchOf(window()));
      expect(
        result.questions.any((q) => q.id == 'scale'),
        isFalse,
      );
      // And the figure is there, taken straight from the drawing.
      expect(Units.format(result.design.widthMm), isNotEmpty);
    });

    test('a diagonal is never asked about; it is built as a bar', () {
      final result = SketchInterpreter.interpret(sketchOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1000, 0),
          Vec2(1000, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(80, 1900), Vec2(900, 1000)], wobble: 4),
      ]));
      expect(result.questions, isEmpty);
      expect(result.design.openings, isEmpty);
      expect(result.design.dividers, hasLength(1));
    });

    test('reading the same drawing twice asks no more than reading it once',
        () {
      final design = sketchOf([
        ...window(),
        chevron(const Vec2(1100, 800), 150),
      ]);
      final once = SketchInterpreter.interpret(design);
      final twice = SketchInterpreter.interpret(once.design);
      expect(once.questions, isEmpty);
      expect(twice.questions, isEmpty);
      expect(twice.design.openings, hasLength(1));
    });

    test('the one thing still asked is a drawing that does not close', () {
      final result = SketchInterpreter.interpret(sketchOf([
        drawn(const [Vec2(0, 0), Vec2(1400, 0)]),
        drawn(const [Vec2(0, 900), Vec2(1400, 900)]),
      ]));
      expect(result.design.frame, isNull);
      expect(result.questions.map((q) => q.id), ['frame-not-closed']);
    });
  });

  // ------------------------------------------ the mark finds its section

  group('a mark opens the section it is in', () {
    test('a mark near a bar opens the section it is mostly in', () {
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        // Straddling the mullion, body in the wide light on the right.
        chevron(const Vec2(560, 800), 180),
      ]));

      expect(result.design.openings, hasLength(1));
      expect(result.questions, isEmpty);
      final opened =
          result.design.sectionById(result.design.openings.single.sectionId)!;
      expect(opened.outline.centroid.x, greaterThan(400));
    });

    test('a mark almost on the frame still opens its section', () {
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        chevron(const Vec2(330, 1500), 150),
      ]));
      expect(result.design.openings, hasLength(1));
      expect(result.questions, isEmpty);
    });

    test('a mark right off the design is the one that is asked about', () {
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        chevron(const Vec2(3400, 2600), 150),
      ]));
      expect(result.design.openings, isEmpty);
      expect(result.questions.single.id, startsWith('symbol-'));
      expect(
        result.questions.single.options.map((o) => o.key),
        contains('not-a-symbol'),
      );
    });

    test('the section without the mark does not open', () {
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        chevron(const Vec2(1100, 800), 150),
      ]));
      final openedId = result.design.openings.single.sectionId;
      for (final section in result.design.topLevelSections) {
        if (section.id == openedId) continue;
        expect(result.design.openingOf(section.id), isNull);
      }
    });

    test('no mark at all means no opening at all', () {
      final result = SketchInterpreter.interpret(sketchOf(window()));
      expect(result.design.openings, isEmpty);
      expect(result.design.hardware, isEmpty);
    });
  });

  // ------------------------------------------- the whole acceptance test

  group('the phase’s acceptance test, end to end', () {
    Design built() {
      _n = 0;
      // 1–3. Draw the window, the mullion, and a < in the left light.
      var design = SketchInterpreter.interpret(sketchOf([
        ...window(),
        drawn(const [
          Vec2(280, 700),
          Vec2(140, 800),
          Vec2(280, 900),
        ], wobble: 9),
      ])).design;

      // 5. Draw a line inside the opening, 40 cm down it.
      final opening = design.openings.single.sectionId;
      final box = design.sectionById(opening)!.outline;
      design = DesignEdits.addLineInside(
        design,
        opening,
        id: 'inner',
        at: Vec2(box.centroid.x, box.top + 400),
        horizontal: true,
      );

      // 7. The lower pane is a panel.
      final lower = design
          .childSectionsOf(opening)
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      return design.withElement(lower.copyWith(
        finish: const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
      ));
    }

    test('4 — the marked section became a real opening', () {
      final design = built();
      expect(design.openings, hasLength(1));
      expect(design.openings.single.markGlyph, '<');
      expect(design.openings.single.confirmed, isTrue);
      expect(design.openings.single.mechanism.hingeEdge, OpeningEdge.right);

      final opened = design.sectionById(design.openings.single.sectionId)!;
      expect(opened.outline.centroid.x, lessThan(400),
          reason: 'the left light is the one that was marked');
    });

    test('6 — the line stayed inside the opening', () {
      final design = built();
      final opening = design.openings.single.sectionId;

      expect(design.topLevelSections, hasLength(2),
          reason: 'the line did not make a section of its own');
      expect(design.childDividersOf(opening), hasLength(1));
      expect(
          design.sectionHolding(
              design.dividers.firstWhere((d) => d.id == 'inner').parentId),
          opening);
    });

    test('7 — the opening is divided into glass and panel', () {
      final design = built();
      final opening = design.openings.single.sectionId;
      final panes = design.childSectionsOf(opening);

      expect(panes, hasLength(2));
      final upper = panes.reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final lower = panes.reduce((a, b) => a.outline.top > b.outline.top ? a : b);
      expect(upper.finish.material.isGlazing, isTrue);
      expect(lower.finish.material, MaterialKind.panel);
    });

    test('8 — those dimensions can be edited', () {
      var design = built();
      final opening = design.openings.single.sectionId;
      final was = design.sectionById(opening)!.heightMm;
      final upper = design
          .childSectionsOf(opening)
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);

      design = DesignEdits.setSectionHeight(design, upper.id, Units.toMm(50));

      final now = design
          .childSectionsOf(opening)
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      expect(Units.format(now.heightMm), '50');
      expect(design.sectionById(opening)!.heightMm, closeTo(was, 0.5),
          reason: 'the opening itself did not change size');
    });

    test('9 — hinges and a handle are attached to the opening', () {
      final design = built();
      final opening = design.openings.single.sectionId;
      final mine = [
        for (final piece in design.hardware)
          if (piece.parentId == opening) piece.kind,
      ];
      expect(mine, contains(HardwareKind.hinge));
      expect(mine, contains(HardwareKind.handle));
      // And nowhere else.
      for (final piece in design.hardware) {
        expect(piece.parentId, opening);
      }
    });

    test('10 — the model has the same structure', () {
      final design = built();
      final opening = design.openings.single.sectionId;
      final mesh = MeshBuilder.build(design);

      final bars = {
        for (final f in mesh.facets) if (f.role == FacetRole.bar) f.elementId,
      };
      expect(bars, contains('inner'));

      final filled = {
        for (final f in mesh.facets)
          if (f.role == FacetRole.glazing || f.role == FacetRole.panel)
            f.elementId,
      };
      expect(filled, isNot(contains(opening)));
      for (final child in design.childSectionsOf(opening)) {
        expect(filled, contains(child.id));
      }
      expect(
        {for (final f in mesh.facets) if (f.role == FacetRole.sash) f.elementId},
        contains(opening),
      );
    });

    test('11 — moving the opening keeps everything inside it', () {
      final before = built();
      final opening = before.openings.single.sectionId;

      final after = DesignEdits.moveDivider(
        before,
        before.topLevelDividers.single.id,
        const Vec2(250, 0),
      );

      expect(after.openings, hasLength(1));
      expect(after.childDividersOf(opening), hasLength(1));
      expect(after.childSectionsOf(opening), hasLength(2));
      expect(
        [for (final p in after.hardware) p.kind],
        containsAll([HardwareKind.hinge, HardwareKind.handle]),
      );
      // The bar still runs right across the opening it is in, whatever the
      // opening's new width is. The frame is hand-drawn, so its jambs are a
      // degree off square and the bar ends on them rather than on the
      // bounding box — hence the few millimetres of slack.
      final box = after.sectionById(opening)!.outline;
      final bar = after.childDividersOf(opening).single;
      expect(bar.lengthMm, closeTo(box.width, 4));
      expect(bar.a.x, closeTo(box.left, 4));
      expect(bar.b.x, closeTo(box.right, 4));
    });

    test('12 — none of it involved answering a question', () {
      _n = 0;
      final result = SketchInterpreter.interpret(sketchOf([
        ...window(),
        drawn(const [Vec2(280, 700), Vec2(140, 800), Vec2(280, 900)],
            wobble: 9),
      ]));
      expect(result.questions, isEmpty);
    });
  });
}
