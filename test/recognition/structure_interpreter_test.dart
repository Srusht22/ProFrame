import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/features/recognition/stroke_recognizer.dart';
import 'package:proframe/features/recognition/structure_interpreter.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/sketch.dart';

import '../support/sketch_builders.dart';

void main() {
  const recognizer = StrokeRecognizer();
  const interpreter = StructureInterpreter();

  group('reading the drawing as a product', () {
    test('a mullion splits the frame into two sections', () {
      final structure = interpreter.interpret(
        recognizer.recognizeAll(twoPanelWindowSketch()),
        kind: OpeningKind.window,
      );

      expect(structure.rows, hasLength(1));
      expect(structure.rows.single.cells, hasLength(2));
      expect(structure.mullionCount, 1);
      expect(structure.outline.width, 600);
    });

    test('converging diagonals put the hinges on the correct side', () {
      final structure = interpreter.interpret(
        recognizer.recognizeAll(twoPanelWindowSketch()),
        kind: OpeningKind.window,
      );
      final cells = structure.rows.single.cells;

      expect(cells[0].operation, CellOperation.casementLeft);
      expect(cells[0].confidence, greaterThanOrEqualTo(0.75));
      expect(cells[0].evidence, contains('left'));
      expect(cells[1].operation, CellOperation.fixed);
    });

    test('a transom makes a separate band, and the leaf below is a door leaf', () {
      final structure = interpreter.interpret(
        recognizer.recognizeAll(doorWithTransomSketch()),
        kind: OpeningKind.door,
      );

      expect(structure.rows, hasLength(2));
      expect(structure.transomYs.single, closeTo(200, 1));
      expect(structure.rows[0].cells.single.operation, CellOperation.fixed);
      expect(structure.rows[1].cells.single.operation, CellOperation.doorLeafRight);
    });

    test('a horizontal arrow is read as a sliding leaf', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..arrow(60, 200, 260, 200))
          .build();

      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );

      expect(structure.rows.single.cells[0].operation, CellOperation.slidingRight);
    });

    test('a section with no marks stays fixed and says so', () {
      final sketch = (SketchBuilder()..rectangle(0, 0, 500, 500)).build();
      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );

      final cell = structure.rows.single.cells.single;
      expect(cell.operation, CellOperation.fixed);
      expect(cell.evidence, contains('No opening marks'));
    });

    test('a single diagonal is reported as a low-confidence guess', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 400, 400)
            ..diagonal(400, 0, 0, 200))
          .build();

      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );
      final cell = structure.rows.single.cells.single;

      expect(cell.confidence, lessThan(0.75));
      expect(cell.evidence, contains('single line cannot say'));
    });

    test('two strokes for the same mullion do not become two bars', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 0, 300, 400)
            ..division(303, 0, 303, 400))
          .build();

      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );

      expect(structure.mullionCount, 1);
      expect(structure.rows.single.cells, hasLength(2));
    });

    test('a short line inside the frame is not treated as a division', () {
      final sketch = (SketchBuilder()
            ..rectangle(0, 0, 600, 400)
            ..division(300, 170, 300, 230))
          .build();

      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );

      expect(structure.mullionCount, 0);
    });

    test('four freehand lines can form the outline without a rectangle stroke', () {
      final sketch = (SketchBuilder()
            ..twoPoint(SketchTool.line, 0, 0, 500, 0)
            ..twoPoint(SketchTool.line, 500, 0, 500, 400)
            ..twoPoint(SketchTool.line, 500, 400, 0, 400)
            ..twoPoint(SketchTool.line, 0, 400, 0, 0))
          .build();

      final structure = interpreter.interpret(
        recognizer.recognizeAll(sketch),
        kind: OpeningKind.window,
      );

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
  });
}
