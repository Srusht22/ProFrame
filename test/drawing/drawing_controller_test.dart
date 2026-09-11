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

    test('a rectangle is grabbed by its edges, not by its diagonal', () {
      controller.precisionMode = true;
      controller.tool = SketchTool.rectangle;
      controller.beginStroke(const Vec2(100, 100));
      controller.extendStroke(const Vec2(300, 220));
      controller.endStroke();
      controller.tool = SketchTool.select;

      // On the drawn top edge.
      controller.selectAt(const Vec2(200, 100));
      expect(controller.selectedStroke, isNotNull);

      // In the empty middle, where only the diagonal would be.
      controller.selectAt(const Vec2(200, 160));
      expect(controller.selectedStroke, isNull);
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

  group('moving and resizing', () {
    void selectRectangle() {
      controller.precisionMode = true;
      controller.tool = SketchTool.rectangle;
      controller.beginStroke(const Vec2(100, 100));
      controller.extendStroke(const Vec2(300, 220));
      controller.endStroke();
      controller.tool = SketchTool.select;
      controller.selectAt(const Vec2(200, 100));
      expect(controller.selectedStroke, isNotNull);
    }

    test('moving a stroke shifts it without changing its size', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      controller.moveSelectedBy(const Vec2(40, -25));
      controller.endTransform();

      final after = controller.selectedStroke!.bounds;
      expect(after.left, closeTo(before.left + 40, 0.001));
      expect(after.top, closeTo(before.top - 25, 0.001));
      expect(after.width, closeTo(before.width, 0.001));
      expect(after.height, closeTo(before.height, 0.001));
    });

    test('every step of a drag is measured from where it started', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      controller.moveSelectedBy(const Vec2(10, 10));
      controller.moveSelectedBy(const Vec2(60, 45));
      controller.endTransform();

      final after = controller.selectedStroke!.bounds;
      expect(after.left, closeTo(before.left + 60, 0.001));
      expect(after.top, closeTo(before.top + 45, 0.001));
    });

    test('dragging away and back leaves the stroke exactly where it was', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      for (final step in const [Vec2(30, 12), Vec2(-80, 200), Vec2(0, 0)]) {
        controller.moveSelectedBy(step);
      }
      controller.endTransform();

      expect(controller.selectedStroke!.bounds, before);
    });

    test('resizing from a corner keeps the opposite corner anchored', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;
      // Drag the bottom-right corner; the top-left must not move (§26).
      final target = Box2(before.left, before.top, before.right + 90, before.bottom + 40);

      controller.beginTransform();
      controller.resizeSelectedTo(target);
      controller.endTransform();

      final after = controller.selectedStroke!.bounds;
      expect(after.left, closeTo(before.left, 0.001));
      expect(after.top, closeTo(before.top, 0.001));
      expect(after.right, closeTo(before.right + 90, 0.001));
      expect(after.bottom, closeTo(before.bottom + 40, 0.001));
    });

    test('a resize that would collapse the stroke is refused', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      controller.resizeSelectedTo(Box2(before.left, before.top, before.left + 1, before.top + 1));
      controller.endTransform();

      expect(controller.selectedStroke!.bounds, before);
    });

    test('dragging a grip past the opposite edge does not mirror the stroke', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      // Right edge dragged 100 units to the left of the left edge.
      controller.resizeSelectedTo(
        Box2(before.left, before.top, before.left - 100, before.bottom),
      );
      controller.endTransform();

      expect(controller.selectedStroke!.bounds, before);
    });

    test('a whole gesture is one undo step', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.beginTransform();
      controller.moveSelectedBy(const Vec2(15, 0));
      controller.moveSelectedBy(const Vec2(35, 20));
      controller.moveSelectedBy(const Vec2(70, 60));
      controller.endTransform();
      expect(controller.selectedStroke!.bounds, isNot(before));

      controller.undo();
      expect(controller.strokes.single.bounds, before);

      // One more step goes back past the drawing itself — proof the three
      // move calls consumed exactly one step between them.
      controller.undo();
      expect(controller.isEmpty, isTrue);
      expect(controller.canUndo, isFalse);
    });

    test('nothing moves unless a gesture was started', () {
      selectRectangle();
      final before = controller.selectedStroke!.bounds;

      controller.moveSelectedBy(const Vec2(50, 50));
      controller.resizeSelectedTo(const Box2(0, 0, 500, 500));

      expect(controller.selectedStroke!.bounds, before);
      expect(controller.isTransforming, isFalse);
    });

    test('lengthening a line does not give it a thickness', () {
      controller.precisionMode = true;
      drawLine(const Vec2(100, 200), const Vec2(400, 200));
      controller.tool = SketchTool.select;
      controller.selectAt(const Vec2(250, 200));

      controller.beginTransform();
      controller.resizeSelectedTo(const Box2(100, 200, 600, 200));
      controller.endTransform();

      final bounds = controller.selectedStroke!.bounds;
      expect(bounds.left, closeTo(100, 0.001));
      expect(bounds.right, closeTo(600, 0.001));
      expect(bounds.top, closeTo(200, 0.001));
      expect(bounds.height, closeTo(0, 0.001));
    });

    test('a moved rectangle is re-read at its new place', () {
      selectRectangle();

      controller.beginTransform();
      controller.moveSelectedBy(const Vec2(100, 50));
      controller.endTransform();

      final rect = controller.primitives.whereType<RectanglePrimitive>().single;
      expect(rect.bounds.left, closeTo(200, 1));
      expect(rect.bounds.top, closeTo(150, 1));
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
