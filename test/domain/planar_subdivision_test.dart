import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/segment.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/sections/planar_graph.dart';

List<Segment> boxAt(double l, double t, double r, double b) => [
      Segment(Vec2(l, t), Vec2(r, t)),
      Segment(Vec2(r, t), Vec2(r, b)),
      Segment(Vec2(r, b), Vec2(l, b)),
      Segment(Vec2(l, b), Vec2(l, t)),
    ];

void main() {
  group('planar subdivision', () {
    test('a plain box is one section', () {
      final faces = PlanarSubdivision.facesOf(boxAt(0, 0, 1000, 2000));
      expect(faces, hasLength(1));
      expect(faces.single.area, closeTo(1000 * 2000, 1));
    });

    test('an off-centre divider keeps its exact proportions', () {
      // 48/52, the split §10 says must survive untouched.
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 2000),
        Segment(const Vec2(480, 0), const Vec2(480, 2000)),
      ]);
      expect(faces, hasLength(2));
      final areas = [for (final f in faces) f.area]..sort();
      expect(areas[0], closeTo(480 * 2000, 1));
      expect(areas[1], closeTo(520 * 2000, 1));
    });

    test('a line stopping just short still divides', () {
      // A T-junction drawn by hand rarely lands exactly on the other line.
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 2000),
        Segment(const Vec2(300, 0.4), const Vec2(300, 1999.6)),
      ]);
      expect(faces, hasLength(2));
    });

    test('a diagonal makes triangles, not rectangles', () {
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 1000),
        Segment(const Vec2(0, 0), const Vec2(1000, 1000)),
      ]);
      expect(faces, hasLength(2));
      for (final face in faces) {
        expect(face.corners, hasLength(3));
        expect(face.area, closeTo(500000, 1));
      }
    });

    test('unequal sections in both directions stay unequal', () {
      // Three columns at 200/300/500 and two rows at 1400/600 — nothing here
      // is symmetric and none of it may be tidied up.
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 2000),
        Segment(const Vec2(200, 0), const Vec2(200, 2000)),
        Segment(const Vec2(500, 0), const Vec2(500, 2000)),
        Segment(const Vec2(0, 1400), const Vec2(1000, 1400)),
      ]);
      expect(faces, hasLength(6));
      final areas = [for (final f in faces) f.area.round()]..sort();
      expect(areas, [120000, 180000, 280000, 300000, 420000, 700000]);
    });

    test('a T-junction divides only the side it reaches', () {
      // One transom across the left half only: two sections on the left,
      // one tall one on the right.
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 2000),
        Segment(const Vec2(400, 0), const Vec2(400, 2000)),
        Segment(const Vec2(0, 700), const Vec2(400, 700)),
      ]);
      expect(faces, hasLength(3));
      final areas = [for (final f in faces) f.area.round()]..sort();
      expect(areas, [280000, 520000, 1200000]);
    });

    test('lines that enclose nothing produce no sections', () {
      final faces = PlanarSubdivision.facesOf([
        Segment(const Vec2(0, 0), const Vec2(1000, 0)),
        Segment(const Vec2(0, 500), const Vec2(1000, 500)),
      ]);
      expect(faces, isEmpty);
    });

    test('a sliver where two lines nearly met is not a section', () {
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 2000),
        Segment(const Vec2(500, 0), const Vec2(500, 2000)),
        Segment(const Vec2(500.1, 0), const Vec2(500.1, 2000)),
      ]);
      expect(faces, hasLength(2));
    });

    test('a five-sided opening is kept as five sides', () {
      final faces = PlanarSubdivision.facesOf([
        Segment(const Vec2(0, 400), const Vec2(500, 0)),
        Segment(const Vec2(500, 0), const Vec2(1000, 400)),
        Segment(const Vec2(1000, 400), const Vec2(1000, 2000)),
        Segment(const Vec2(1000, 2000), const Vec2(0, 2000)),
        Segment(const Vec2(0, 2000), const Vec2(0, 400)),
      ]);
      expect(faces, hasLength(1));
      expect(faces.single.corners, hasLength(5));
    });

    test('a cross of two diagonals makes four triangles', () {
      final faces = PlanarSubdivision.facesOf([
        ...boxAt(0, 0, 1000, 1000),
        Segment(const Vec2(0, 0), const Vec2(1000, 1000)),
        Segment(const Vec2(1000, 0), const Vec2(0, 1000)),
      ]);
      expect(faces, hasLength(4));
      for (final face in faces) {
        expect(face.area, closeTo(250000, 1));
      }
    });
  });

  group('polygon', () {
    test('contains is true on the edge and false outside', () {
      final square = Polygon.rect(0, 0, 100, 100);
      expect(square.contains(const Vec2(50, 50)), isTrue);
      expect(square.contains(const Vec2(0, 50)), isTrue);
      expect(square.contains(const Vec2(-1, 50)), isFalse);
      expect(square.contains(const Vec2(101, 50)), isFalse);
    });

    test('inset moves every edge inwards by the same amount', () {
      final inner = Polygon.rect(0, 0, 1000, 2000).inset(60);
      expect(inner.left, closeTo(60, 0.001));
      expect(inner.top, closeTo(60, 0.001));
      expect(inner.right, closeTo(940, 0.001));
      expect(inner.bottom, closeTo(1940, 0.001));
    });
  });

  group('segment', () {
    test('crossing finds a true intersection', () {
      final crossing = Segment(const Vec2(0, 50), const Vec2(100, 50))
          .crossing(Segment(const Vec2(50, 0), const Vec2(50, 100)));
      expect(crossing, isNotNull);
      expect(crossing!.at.x, closeTo(50, 0.001));
      expect(crossing.at.y, closeTo(50, 0.001));
    });

    test('crossing tolerates a line drawn almost to another', () {
      final crossing = Segment(const Vec2(0, 50), const Vec2(100, 50))
          .crossing(Segment(const Vec2(50, 0), const Vec2(50, 49.7)));
      expect(crossing, isNotNull);
    });

    test('crossing is null when the lines genuinely miss', () {
      final crossing = Segment(const Vec2(0, 50), const Vec2(100, 50))
          .crossing(Segment(const Vec2(50, 0), const Vec2(50, 20)));
      expect(crossing, isNull);
    });

    test('parallel lines never cross', () {
      final crossing = Segment(const Vec2(0, 0), const Vec2(100, 0))
          .crossing(Segment(const Vec2(0, 10), const Vec2(100, 10)));
      expect(crossing, isNull);
    });

    test('a hand-drawn line three degrees off is still horizontal', () {
      expect(Segment(const Vec2(0, 0), const Vec2(1000, 52)).isHorizontalish,
          isTrue);
      expect(Segment(const Vec2(0, 0), const Vec2(1000, 300)).isHorizontalish,
          isFalse);
    });
  });
}
