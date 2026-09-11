import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/features/recognition/stroke_recognizer.dart';
import 'package:proframe/features/recognition/structure_interpreter.dart';
import 'package:proframe/shared/models/geometry_structure.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/sketch.dart';

import '../support/sketch_builders.dart';

const recognizer = StrokeRecognizer();
const interpreter = StructureInterpreter();

GeometryStructure read(Sketch sketch, {OpeningKind kind = OpeningKind.window}) =>
    interpreter.interpret(recognizer.recognizeAll(sketch), kind: kind);

/// Sections sorted top-to-bottom then left-to-right, for readable assertions.
List<StructureSection> ordered(GeometryStructure structure) => structure.sections;

void main() {
  group('the drawing is the design', () {
    test('a divider crossing only half the design is not dropped', () {
      // A full-height vertical, and a horizontal that stops at it. Three
      // sections — not four, and not two.
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(0, 200, 300, 200))
          .build();

      final structure = read(sketch);
      expect(structure.sectionCount, 3);

      final right = structure.sections.firstWhere((s) => s.box.left >= 299);
      expect(
        right.box.height,
        closeTo(400, 1),
        reason: 'the right side must stay full height — nothing divides it',
      );
      expect(structure.sections.where((s) => s.box.right <= 301), hasLength(2));
    });

    test('a partial divider is not straightened into a full cross', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(0, 200, 300, 200))
          .build();

      final structure = read(sketch);
      // A full cross would be four equal quarters.
      final quarters = structure.sections
          .where((s) => (s.box.width - 300).abs() < 2 && (s.box.height - 200).abs() < 2)
          .length;
      expect(quarters, lessThan(4));
    });

    test('a rectangle drawn inside the frame stays its own section', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..rectangle(420, 40, 560, 160))
          .build();

      final structure = read(sketch);
      final drawn = structure.sections.where((s) => s.drawnExplicitly).toList();

      expect(drawn, hasLength(1));
      expect(drawn.single.box.left, closeTo(420, 1));
      expect(drawn.single.box.top, closeTo(40, 1));
      expect(drawn.single.box.width, closeTo(140, 1));
      expect(drawn.single.box.height, closeTo(120, 1));
    });

    test('an asymmetric split keeps its proportions', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(150, 0, 150, 400))
          .build();

      final structure = read(sketch);
      final widths = structure.sections.map((s) => s.box.width).toList()..sort();

      expect(widths, hasLength(2));
      expect(widths.first, closeTo(150, 1));
      expect(widths.last, closeTo(450, 1));
    });

    test('two dividers that both cross make four sections', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(0, 200, 600, 200))
          .build();

      expect(read(sketch).sectionCount, 4);
    });

    test('sections cover the outline exactly, with no overlap', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(0, 200, 300, 200)
            ..rectangle(420, 250, 560, 360))
          .build();

      final structure = read(sketch);
      final area = structure.sections
          .fold<double>(0, (sum, s) => sum + s.box.width * s.box.height);
      expect(area, closeTo(600 * 400, 1));

      for (var i = 0; i < structure.sections.length; i++) {
        for (var j = i + 1; j < structure.sections.length; j++) {
          expect(
            structure.sections[i].box.overlaps(structure.sections[j].box),
            isFalse,
          );
        }
      }
    });
  });

  group('reading how sections open', () {
    test('converging diagonals put the hinges on the correct side', () {
      final structure = read(twoPanelWindowSketch());
      final left = structure.sections.firstWhere((s) => s.box.left < 1);

      expect(left.operation, CellOperation.casementLeft);
      expect(left.confidence, greaterThanOrEqualTo(0.75));
      expect(left.evidence, contains('left'));
    });

    test('a transom band and the door leaf below it', () {
      final structure = read(doorWithTransomSketch(), kind: OpeningKind.door);

      expect(structure.sectionCount, 2);
      final leaf = structure.sections.firstWhere((s) => s.box.height > 400);
      expect(leaf.operation, CellOperation.doorLeafRight);
    });

    test('a horizontal arrow is read as a sliding leaf', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..arrow(60, 200, 260, 200))
          .build();

      final structure = read(sketch);
      final left = structure.sections.firstWhere((s) => s.box.left < 1);
      expect(left.operation, CellOperation.slidingRight);
    });

    test('a section with no marks stays fixed and says so', () {
      final sketch = (SketchBuilder()..rectangle(0, 0, 500, 500)).build();
      final section = read(sketch).sections.single;

      expect(section.operation, CellOperation.fixed);
      expect(section.evidence, contains('No opening marks'));
    });

    test('a single diagonal is reported as a low-confidence guess', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 400, 400)
            ..diagonal(400, 0, 0, 200))
          .build();

      final section = read(sketch).sections.single;
      expect(section.confidence, lessThan(0.75));
      expect(section.evidence, contains('single line cannot say'));
    });

    test('a section the user drew but did not mark asks rather than assumes', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..rectangle(420, 40, 560, 160))
          .build();

      final drawn = read(sketch).sections.firstWhere((s) => s.drawnExplicitly);
      expect(drawn.confidence, lessThan(0.75));
      expect(drawn.evidence, contains('did not mark how it opens'));
    });
  });

  group('reading the frame', () {
    test('two strokes for the same divider do not become two', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(303, 0, 303, 400))
          .build();

      expect(read(sketch).sectionCount, 2);
    });

    test('four freehand lines can form the outline without a rectangle stroke', () {
      final sketch = (SketchBuilder()
            ..twoPoint(SketchTool.line, 0, 0, 500, 0)
            ..twoPoint(SketchTool.line, 500, 0, 500, 400)
            ..twoPoint(SketchTool.line, 500, 400, 0, 400)
            ..twoPoint(SketchTool.line, 0, 400, 0, 0))
          .build();

      final structure = read(sketch);
      expect(structure.outline.width, closeTo(500, 1));
      expect(structure.outline.height, closeTo(400, 1));
    });

    test('an empty sketch fails with a message a person can act on', () {
      expect(
        () => interpreter.interpret(const [], kind: OpeningKind.window),
        throwsA(isA<InterpretationException>().having(
          (e) => e.message,
          'message',
          contains('Draw the outside shape'),
        )),
      );
    });

    test('the extent fallback is only used when asked for, and is flagged', () {
      final primitives = recognizer.recognizeAll(
        (SketchBuilder()
              ..twoPoint(SketchTool.line, 0, 0, 300, 0)
              ..twoPoint(SketchTool.line, 0, 160, 300, 160))
            .build(),
      );

      expect(
        () => interpreter.interpret(primitives, kind: OpeningKind.window),
        throwsA(isA<InterpretationException>()),
      );

      final structure = interpreter.interpret(
        primitives,
        kind: OpeningKind.window,
        useDrawingExtent: true,
      );
      expect(structure.outlineFromExtent, isTrue);
      expect(structure.outline.width, closeTo(300, 2));
    });
  });
}
