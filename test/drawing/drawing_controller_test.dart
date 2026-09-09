import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/drawing/state/drawing_controller.dart';
import 'package:proframe/features/recognition/snapping_engine.dart';
import 'package:proframe/shared/models/primitives.dart';
import 'package:proframe/shared/models/sketch.dart';

void main() {
  late DrawingController controller;

  setUp(() {
    controller = DrawingController();
  });

  tearDown(() => controller.dispose());

  void drawLine(Vec2 from, Vec2 to, {SketchTool tool = SketchTool.line}) {
    controller.tool = tool;
    controller.beginStroke(from);
    controller.extendStroke(to);
    controller.endStroke();
  }

  group('drawing', () {
    test('a committed stroke lands in the sketch', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));

      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.tool, SketchTool.line);
    });

    test('the live stroke stays out of the sketch until it is released', () {
      controller.tool = SketchTool.pen;
      controller.beginStroke(const Vec2(0, 0));
      controller.extendStroke(const Vec2(50, 50));

      expect(controller.preview.value, isNotNull);
      expect(controller.strokes, isEmpty);

      controller.endStroke();
      expect(controller.preview.value, isNull);
      expect(controller.strokes, hasLength(1));
    });

    test('a tap with a two-point tool does not create a stroke', () {
      controller.tool = SketchTool.line;
      controller.beginStroke(const Vec2(10, 10));
      controller.extendStroke(const Vec2(11, 11));
      controller.endStroke();

      expect(controller.strokes, isEmpty);
    });

    test('stylus pressure is captured on the ink', () {
      controller.tool = SketchTool.pen;
      controller.beginStroke(const Vec2(0, 0), pressure: 0.2);
      controller.extendStroke(const Vec2(40, 0), pressure: 0.9);
      controller.endStroke();

      final stroke = controller.strokes.single;
      expect(stroke.points.first.pressure, 0.2);
      expect(stroke.points.last.pressure, 0.9);
      expect(stroke.averagePressure, closeTo(0.55, 0.01));
    });

    test('dense finger samples are thinned without losing the shape', () {
      controller.tool = SketchTool.pen;
      controller.beginStroke(const Vec2(0, 0));
      for (var i = 1; i <= 40; i++) {
        controller.extendStroke(Vec2(i * 0.4, 0));
      }
      controller.endStroke();

      final stroke = controller.strokes.single;
      expect(stroke.points.length, lessThan(41));
      expect(stroke.end.x, closeTo(16, 0.5));
    });
  });

  group('snapping while drawing', () {
    test('a nearly vertical drag is constrained to the axis', () {
      controller.tool = SketchTool.line;
      controller.beginStroke(const Vec2(100, 0));
      controller.extendStroke(const Vec2(104, 300));
      controller.endStroke();

      final stroke = controller.strokes.single;
      expect(stroke.start.x, stroke.end.x);
    });

    test('precision mode keeps the line exactly where it was drawn', () {
      controller.precisionMode = true;
      controller.tool = SketchTool.line;
      controller.beginStroke(const Vec2(100, 0));
      controller.extendStroke(const Vec2(104, 300));
      controller.endStroke();

      final stroke = controller.strokes.single;
      expect(stroke.end.x, 104);
    });

    test('a new division snaps to the centre of the frame', () {
      controller.tool = SketchTool.rectangle;
      controller.beginStroke(const Vec2(0, 0));
      controller.extendStroke(const Vec2(400, 300));
      controller.endStroke();

      const snapping = SnappingEngine();
      final snap = snapping.snapPoint(const Vec2(203, 150), controller.primitives);

      expect(snap.snapped, isTrue);
      expect(snap.point.x, closeTo(200, 0.001));
    });

    test('the grid catches a point that has nothing else nearby', () {
      const snapping = SnappingEngine(gridSpacing: 24);
      final snap = snapping.snapPoint(const Vec2(50, 26), const []);

      expect(snap.kind, SnapKind.grid);
      expect(snap.point.x, 48);
      expect(snap.point.y, 24);
    });
  });

  group('editing', () {
    test('the eraser removes only the stroke it touches', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      drawLine(const Vec2(0, 200), const Vec2(200, 200));

      controller.erase(const Vec2(100, 2));

      expect(controller.strokes, hasLength(1));
      expect(controller.strokes.single.start.y, greaterThan(150));
    });

    test('select, duplicate and rotate work on one stroke', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      controller.tool = SketchTool.select;
      controller.selectAt(const Vec2(100, 0));
      expect(controller.selectedStroke, isNotNull);

      controller.duplicateSelected();
      expect(controller.strokes, hasLength(2));

      final before = controller.selectedStroke!.bounds;
      controller.rotateSelected();
      final after = controller.selectedStroke!.bounds;
      expect(after.height, closeTo(before.width, 0.001));
    });

    test('a dimension value is stored on the stroke it belongs to', () {
      controller.tool = SketchTool.dimension;
      controller.beginStroke(const Vec2(0, 0));
      controller.extendStroke(const Vec2(600, 0));
      final stroke = controller.endStroke()!;

      controller.setDimensionValue(stroke.id, 1200);

      final dimension = controller.primitives.whereType<DimensionPrimitive>().single;
      expect(dimension.valueMm, 1200);
      expect(dimension.hasValue, isTrue);
    });

    test('a note is placed with a tap and carries its text', () {
      controller.addNote(const Vec2(20, 20), 'obscure glass');

      final note = controller.primitives.whereType<NotePrimitive>().single;
      expect(note.text, 'obscure glass');
    });
  });

  group('history', () {
    test('undo and redo step through the drawing', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      drawLine(const Vec2(0, 100), const Vec2(200, 100));
      expect(controller.strokes, hasLength(2));

      controller.undo();
      expect(controller.strokes, hasLength(1));

      controller.redo();
      expect(controller.strokes, hasLength(2));
    });

    test('undo brings back a cleared sheet', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      controller.clear();
      expect(controller.isEmpty, isTrue);

      controller.undo();
      expect(controller.strokes, hasLength(1));
    });

    test('a new stroke after undo drops the redo history', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      controller.undo();
      expect(controller.canRedo, isTrue);

      drawLine(const Vec2(0, 50), const Vec2(200, 50));
      expect(controller.canRedo, isFalse);
    });

    test('loading a saved sketch resets the history', () {
      drawLine(const Vec2(0, 0), const Vec2(200, 0));
      controller.loadSketch(const Sketch());

      expect(controller.canUndo, isFalse);
      expect(controller.isEmpty, isTrue);
    });
  });

  test('a sketch survives a save and reload unchanged', () {
    controller.tool = SketchTool.pen;
    controller.beginStroke(const Vec2(0, 0), pressure: 0.4);
    controller.extendStroke(const Vec2(80, 40), pressure: 0.8);
    controller.endStroke();
    controller.addNote(const Vec2(10, 10), 'note');

    final restored = Sketch.fromJson(controller.sketch.toJson());

    expect(restored.strokes, hasLength(2));
    expect(restored.strokes.first.points.first.pressure, 0.4);
    expect(restored.strokes.last.text, 'note');
  });
}
