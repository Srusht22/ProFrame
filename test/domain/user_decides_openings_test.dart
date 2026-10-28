import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';

var _n = 0;

Stroke drawn(List<Vec2> through, {double wobble = 5}) {
  final random = math.Random(_n + 5);
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

Design designOf(List<Stroke> strokes) {
  final at = DateTime(2026);
  return Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.door,
    createdAt: at,
    updatedAt: at,
    sketch: Sketch(strokes: strokes),
  );
}

/// The specification's first example: glass above, door part below, with the
/// `>` drawn in the lower section.
List<Stroke> glassOverDoor({required String glyph, required bool inUpper}) {
  final y = inUpper ? 500.0 : 1600.0;
  return [
    drawn(const [
      Vec2(0, 0),
      Vec2(1000, 0),
      Vec2(1000, 2200),
      Vec2(0, 2200),
      Vec2(0, 0),
    ]),
    drawn(const [Vec2(0, 1000), Vec2(1000, 1000)]),
    if (glyph == '>')
      drawn([Vec2(380, y - 170), Vec2(620, y), Vec2(380, y + 170)])
    else
      drawn([Vec2(620, y - 170), Vec2(380, y), Vec2(620, y + 170)]),
  ];
}

void main() {
  setUp(() => _n = 0);

  group('the user decides, by marking a section', () {
    test('a > in the lower section opens the lower section and no other', () {
      final result = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '>', inUpper: false)),
      );
      final design = result.design;

      expect(design.sections, hasLength(2));
      expect(design.openings, hasLength(1));

      final opened = design.sectionById(design.openings.single.sectionId)!;
      final upper = design.sections
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      final lower = design.sections
          .reduce((a, b) => a.outline.top > b.outline.top ? a : b);

      expect(opened.id, lower.id);
      expect(design.openingOf(upper.id), isNull);
    });

    test('a > in the upper section opens the upper one instead', () {
      final result = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '>', inUpper: true)),
      );
      final design = result.design;
      final opened = design.sectionById(design.openings.single.sectionId)!;
      final upper = design.sections
          .reduce((a, b) => a.outline.top < b.outline.top ? a : b);
      expect(opened.id, upper.id);
    });

    test('> hinges left and < hinges right', () {
      final rightwards = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '>', inUpper: false)),
      ).design;
      expect(rightwards.openings.single.mechanism,
          OpeningMechanism.hingedLeft);
      expect(rightwards.openings.single.markGlyph, '>');

      _n = 0;
      final leftwards = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '<', inUpper: false)),
      ).design;
      expect(leftwards.openings.single.mechanism,
          OpeningMechanism.hingedRight);
      expect(leftwards.openings.single.markGlyph, '<');
    });

    test('the specification\'s second example: < in the left column', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 1200),
          Vec2(0, 1200),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(760, 0), Vec2(760, 1200)]),
        drawn(const [Vec2(500, 420), Vec2(280, 600), Vec2(500, 780)]),
      ]));
      final design = result.design;

      expect(design.sections, hasLength(2));
      expect(design.openings, hasLength(1));

      final opened = design.sectionById(design.openings.single.sectionId)!;
      expect(opened.outline.right, lessThan(760));
      expect(design.openings.single.mechanism, OpeningMechanism.hingedRight);
    });

    test('the mark is kept where it was made', () {
      final result = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '>', inUpper: false)),
      );
      final opening = result.design.openings.single;
      expect(opening.markAt, isNotNull);
      expect(opening.markAt!.y, greaterThan(1000));
      expect(opening.markAt!.x, closeTo(460, 120));
      expect(opening.confirmed, isTrue);
    });

    test('the mark never becomes bars', () {
      final result = SketchInterpreter.interpret(
        designOf(glassOverDoor(glyph: '>', inUpper: false)),
      );
      // The frame and the one transom. The chevron's two strokes-worth of
      // line are an instruction, not something to build.
      expect(result.design.dividers, hasLength(1));
      expect(result.design.dividers.single.isHorizontal, isTrue);
      expect(result.design.sections, hasLength(2));
    });

    test('the mark stays in the sketch, like every other stroke', () {
      final before = designOf(glassOverDoor(glyph: '>', inUpper: false));
      final result = SketchInterpreter.interpret(before);
      expect(result.design.sketch.strokes, hasLength(3));
      expect(result.symbols, hasLength(1));
    });
  });

  group('nothing opens on its own', () {
    test('no mark means no opening, however door-like the design', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(900, 0),
          Vec2(900, 2100),
          Vec2(0, 2100),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(0, 700), Vec2(900, 700)]),
      ]));
      expect(result.design.sections, hasLength(2));
      expect(result.design.openings, isEmpty);
    });

    test('one mark opens one section, not every section like it', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(600, 0), Vec2(600, 2000)]),
        drawn(const [Vec2(1200, 0), Vec2(1200, 2000)]),
        // Marked in the middle column only.
        drawn(const [Vec2(760, 830), Vec2(1000, 1000), Vec2(760, 1170)]),
      ]));
      final design = result.design;
      expect(design.sections, hasLength(3));
      expect(design.openings, hasLength(1));

      final opened = design.sectionById(design.openings.single.sectionId)!;
      expect(opened.outline.left, greaterThan(600));
      expect(opened.outline.right, lessThan(1200));
    });

    test('two marks open exactly those two sections', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 2000),
          Vec2(0, 2000),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(600, 0), Vec2(600, 2000)]),
        drawn(const [Vec2(1200, 0), Vec2(1200, 2000)]),
        drawn(const [Vec2(200, 830), Vec2(440, 1000), Vec2(200, 1170)]),
        drawn(const [Vec2(1560, 830), Vec2(1320, 1000), Vec2(1560, 1170)]),
      ]));
      final design = result.design;
      expect(design.openings, hasLength(2));

      final opened = {
        for (final o in design.openings) design.sectionById(o.sectionId)!,
      };
      // The left one and the right one. The middle was not marked.
      expect(opened.any((s) => s.outline.right <= 600), isTrue);
      expect(opened.any((s) => s.outline.left >= 1200), isTrue);
      expect(opened.any((s) => s.outline.left > 600 && s.outline.right < 1200),
          isFalse);
    });
  });

  group('when it cannot tell, it asks', () {
    test('a mark across a bar opens the section it is in', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1800, 0),
          Vec2(1800, 1200),
          Vec2(0, 1200),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(900, 0), Vec2(900, 1200)]),
        // Straddling the mullion: its arms are one side, its point the
        // other. A mark is in the section its middle is in, which is what
        // being in a section means, so the user is not asked to say again
        // what they said by drawing it there.
        drawn(const [Vec2(700, 430), Vec2(1050, 600), Vec2(700, 770)]),
      ]));

      expect(result.design.openings, hasLength(1));
      expect(result.questions.any((q) => q.id.startsWith('symbol-')), isFalse);

      final opened =
          result.design.sectionById(result.design.openings.single.sectionId)!;
      expect(opened.outline.centroid.x, lessThan(900));
      // The other section did not open with it.
      expect(result.design.topLevelSections, hasLength(2));
      expect(result.design.openings.single.markGlyph, '>');
    });

    test('a mark outside every section asks rather than picking one', () {
      final result = SketchInterpreter.interpret(designOf([
        drawn(const [
          Vec2(0, 0),
          Vec2(1200, 0),
          Vec2(1200, 1200),
          Vec2(0, 1200),
          Vec2(0, 0),
        ]),
        // Drawn out in the margin, well clear of the frame.
        drawn(const [Vec2(1700, 430), Vec2(1940, 600), Vec2(1700, 770)]),
      ]));
      expect(result.design.openings, isEmpty);
      expect(
        result.questions.any((q) => q.id.startsWith('symbol-')),
        isTrue,
      );
    });

    test('a stroke the user says is not a mark is built as lines', () {
      final strokes = [
        drawn(const [
          Vec2(0, 0),
          Vec2(1200, 0),
          Vec2(1200, 1200),
          Vec2(0, 1200),
          Vec2(0, 0),
        ]),
        drawn(const [Vec2(300, 300), Vec2(700, 600), Vec2(300, 900)]),
      ];

      final asMark = SketchInterpreter.interpret(designOf(strokes));
      expect(asMark.design.openings, hasLength(1));
      expect(asMark.design.dividers, isEmpty);

      final asLines = SketchInterpreter.interpret(
        designOf(strokes),
        notSymbols: {strokes.last.id},
      );
      expect(asLines.design.openings, isEmpty);
      expect(asLines.design.dividers, hasLength(2));
    });
  });

  group('an opening never drifts', () {
    test('reading the same drawing twice gives the same opening', () {
      final strokes = glassOverDoor(glyph: '<', inUpper: false);

      final once = SketchInterpreter.interpret(designOf(strokes)).design;
      final twice = SketchInterpreter.interpret(once).design;

      expect(twice.openings, hasLength(1));
      expect(twice.openings.single.mechanism,
          once.openings.single.mechanism);
      expect(
        twice.sectionById(twice.openings.single.sectionId)!.outline.top,
        closeTo(
          once.sectionById(once.openings.single.sectionId)!.outline.top,
          0.01,
        ),
      );
    });

    test('reading again does not change the side it hinges on', () {
      final strokes = glassOverDoor(glyph: '>', inUpper: false);
      var design = SketchInterpreter.interpret(designOf(strokes)).design;
      for (var i = 0; i < 4; i++) {
        design = SketchInterpreter.interpret(design).design;
        expect(design.openings, hasLength(1));
        expect(design.openings.single.mechanism,
            OpeningMechanism.hingedLeft);
      }
    });
  });
}
