import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/recognition/stroke_recognizer.dart';
import 'package:proframe/shared/models/primitives.dart';
import 'package:proframe/shared/models/sketch.dart';

import '../support/sketch_builders.dart';

void main() {
  const recognizer = StrokeRecognizer();

  Stroke pen(List<(double, double)> points) => Stroke(
        id: 'stroke',
        tool: SketchTool.pen,
        points: points.map((p) => StrokePoint(x: p.$1, y: p.$2)).toList(),
      );

  group('straightening corrects the hand, not the intent', () {
    test('a line drawn at 88 degrees becomes exactly vertical', () {
      final stroke = pen([(100, 0), (103, 100), (107, 200)]);
      final primitive = recognizer.recognize(stroke)! as LinePrimitive;

      expect(primitive.orientation, LineOrientation.vertical);
      expect(primitive.start.x, primitive.end.x);
      expect(primitive.wasStraightened, isTrue);
    });

    test('a line drawn at 89 degrees keeps its length', () {
      final stroke = pen([(0, 0), (2, 200)]);
      final primitive = recognizer.recognize(stroke)! as LinePrimitive;

      expect(primitive.length, closeTo(200, 1));
    });

    test('a deliberate 60 degree line is left alone', () {
      final stroke = pen([(0, 0), (100, 173)]);
      final primitive = recognizer.recognize(stroke)! as LinePrimitive;

      expect(primitive.orientation, LineOrientation.diagonal);
      expect(primitive.angleDeg, closeTo(60, 1.5));
      expect(primitive.wasStraightened, isFalse);
    });

    test('a nearly horizontal line snaps flat', () {
      final stroke = pen([(0, 50), (300, 44)]);
      final primitive = recognizer.recognize(stroke)! as LinePrimitive;

      expect(primitive.orientation, LineOrientation.horizontal);
      expect(primitive.start.y, primitive.end.y);
    });
  });

  group('shape recognition', () {
    test('a closed freehand loop is read as a rectangle', () {
      final stroke = pen([
        (0, 0), (200, 2), (402, 0), (400, 150), (398, 300),
        (200, 302), (2, 300), (0, 150), (1, 4),
      ]);
      final primitive = recognizer.recognize(stroke);

      expect(primitive, isA<RectanglePrimitive>());
      final rect = primitive! as RectanglePrimitive;
      expect(rect.box.width, closeTo(402, 3));
      expect(rect.box.height, closeTo(302, 3));
      expect(rect.confidence, greaterThan(0.5));
    });

    test('a curved open stroke is read as an arc, not a line', () {
      final stroke = pen([
        (0, 200), (30, 120), (80, 60), (150, 20), (220, 6), (300, 0),
      ]);
      final primitive = recognizer.recognize(stroke);

      expect(primitive, isA<ArcPrimitive>());
      expect((primitive! as ArcPrimitive).sagitta, greaterThan(10));
    });

    test('a shaft with a folded-back head is read as an arrow', () {
      final stroke = pen([
        (0, 100), (200, 100), (180, 88), (200, 100), (180, 112),
      ]);
      final primitive = recognizer.recognize(stroke);

      expect(primitive, isA<ArrowPrimitive>());
      final arrow = primitive! as ArrowPrimitive;
      expect(arrow.direction.x, greaterThan(0.9));
    });
  });

  group('roles keep annotation out of the product', () {
    test('a dimension is annotation, never structure', () {
      final sketch = twoPanelWindowSketch();
      final primitives = recognizer.recognizeAll(sketch);
      final dimensions = primitives.whereType<DimensionPrimitive>();

      expect(dimensions, hasLength(2));
      for (final dimension in dimensions) {
        expect(dimension.role, PrimitiveRole.annotation);
      }
    });

    test('a note carries its text and never becomes geometry', () {
      final sketch = (SketchBuilder()..note(10, 10, 'frosted glass')).build();
      final primitive = recognizer.recognizeAll(sketch).single;

      expect(primitive, isA<NotePrimitive>());
      expect((primitive as NotePrimitive).text, 'frosted glass');
      expect(primitive.role, PrimitiveRole.annotation);
    });

    test('a diagonal drawn with the opening tool is an opening mark', () {
      final sketch = (SketchBuilder()..diagonal(0, 0, 100, 100)).build();
      final primitive = recognizer.recognizeAll(sketch).single;

      expect(primitive.role, PrimitiveRole.openingMark);
    });
  });

  test('simplification keeps the corners of a drawn shape', () {
    final points = [
      const Vec2(0, 0),
      const Vec2(50, 0.4),
      const Vec2(100, 0),
      const Vec2(100, 50),
      const Vec2(100, 100),
    ];
    final simplified = GeometryMath.simplify(points, 2);

    expect(simplified.first, points.first);
    expect(simplified.last, points.last);
    expect(simplified.length, 3);
  });
}
