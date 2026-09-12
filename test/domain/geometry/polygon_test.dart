import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/tolerances.dart';

void main() {
  group('rectangles', () {
    test('a rectangle knows its size and that it is one', () {
      final rect = Polygon.rectangle(width: 1200, height: 800);

      expect(rect.cornerCount, 4);
      expect(rect.width, 1200);
      expect(rect.height, 800);
      expect(rect.isRectangle, isTrue);
      expect(rect.area.abs(), 1200 * 800);
      expect(rect.slopingEdges, isEmpty);
    });

    test('a point inside is inside and a point outside is not', () {
      final rect = Polygon.rectangle(width: 1000, height: 1000);

      expect(rect.contains(const Point2(500, 500)), isTrue);
      expect(rect.contains(const Point2(1500, 500)), isFalse);
      // A point on the edge belongs to the shape.
      expect(rect.contains(const Point2(0, 500)), isTrue);
    });
  });

  group('sloping tops are kept, shaky lines are not', () {
    test('a sloping-top frame keeps both side heights exactly', () {
      final frame = Polygon.slopingTop(
        width: 1000,
        leftHeight: 2100,
        rightHeight: 1700,
      );

      expect(frame.height, 2100);
      expect(frame.width, 1000);
      // The left edge is the full 2100 and the right is the full 1700 —
      // neither was averaged (spec section 2).
      final left = frame.edges.firstWhere((e) => e.start.x == 0 && e.end.x == 0);
      final right =
          frame.edges.firstWhere((e) => e.start.x == 1000 && e.end.x == 1000);
      expect(left.length, closeTo(2100, 0.001));
      expect(right.length, closeTo(1700, 0.001));
    });

    test('the sloping head is reported as sloping, not flattened', () {
      final frame = Polygon.slopingTop(
        width: 1000,
        leftHeight: 2100,
        rightHeight: 1700,
      );

      expect(frame.isRectilinear, isFalse);
      expect(frame.slopingEdges, hasLength(1));
      // 400 mm of fall over 1000 mm is about 21.8 degrees.
      expect(
        frame.slopingEdges.single.slopeFromNearestAxisDegrees,
        closeTo(21.8, 0.1),
      );
    });

    test('a hand-drawn wobble under the tolerance counts as horizontal', () {
      // 1000 mm across with a 10 mm rise is 0.57 degrees — a shaky stroke.
      const wobble = Edge(Point2(0, 0), Point2(1000, 10));

      expect(wobble.orientation, EdgeOrientation.horizontal);
      expect(
        wobble.slopeFromNearestAxisDegrees,
        lessThan(Tolerances.axisAlignmentDegrees),
      );
    });

    test('a deliberate slope above the tolerance is left alone', () {
      // 1000 mm across with a 200 mm fall is 11.3 degrees — intended.
      const slope = Edge(Point2(0, 0), Point2(1000, 200));

      expect(slope.orientation, EdgeOrientation.sloping);
      expect(
        slope.slopeFromNearestAxisDegrees,
        greaterThan(Tolerances.axisAlignmentDegrees),
      );
    });

    test('the tolerance sits between a wobble and a real slope', () {
      // The whole rule depends on there being daylight between the two, so it
      // is asserted rather than left as a comment.
      expect(Tolerances.axisAlignmentDegrees, greaterThan(3));
      expect(Tolerances.axisAlignmentDegrees, lessThan(8));
    });
  });

  group('a bad outline is refused rather than repaired', () {
    test('fewer than three corners is not an outline', () {
      expect(
        () => Polygon([const Point2(0, 0), const Point2(100, 0)]),
        throwsA(isA<GeometryException>()),
      );
    });

    test('an outline with no area is refused', () {
      expect(
        () => Polygon([
          const Point2(0, 0),
          const Point2(100, 0),
          const Point2(200, 0),
        ]),
        throwsA(isA<GeometryException>()),
      );
    });

    test('a bow-tie that crosses itself is refused', () {
      expect(
        () => Polygon([
          const Point2(0, 0),
          const Point2(100, 100),
          const Point2(100, 0),
          const Point2(0, 100),
        ]),
        throwsA(isA<GeometryException>()),
      );
    });

    test('a repeated closing point is tidied, not treated as a corner', () {
      // Users of this class may or may not repeat the first point at the end.
      final polygon = Polygon([
        const Point2(0, 0),
        const Point2(100, 0),
        const Point2(100, 100),
        const Point2(0, 100),
        const Point2(0, 0),
      ]);

      expect(polygon.cornerCount, 4);
    });

    test('two corners closer than the tolerance are one corner', () {
      final polygon = Polygon([
        const Point2(0, 0),
        const Point2(1000, 0),
        // 0.2 mm apart: the same point as far as the factory is concerned.
        const Point2(1000.2, 0.1),
        const Point2(1000, 1000),
        const Point2(0, 1000),
      ]);

      expect(polygon.cornerCount, 4);
    });
  });

  test('a polygon survives a save and reload unchanged', () {
    final original = Polygon.slopingTop(
      width: 1234,
      leftHeight: 2101,
      rightHeight: 1699,
    );
    final restored = Polygon.fromJson(original.toJson());

    expect(restored, original);
    expect(restored.slopingEdges, hasLength(1));
  });

  test('a damaged polygon is refused', () {
    expect(() => Polygon.fromJson('not a polygon'), throwsFormatException);
    expect(
      () => Polygon.fromJson([
        [0, 0],
        [1, 'x'],
        [2, 2],
      ]),
      throwsFormatException,
    );
  });
}
