import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/rendering/isometric_projection.dart';
import 'package:proframe/domain/rendering/point3.dart';

void main() {
  const projection = IsometricProjection();

  group('the elevation is kept true', () {
    test('the front face projects to exactly what was drawn', () {
      // The first rule of this app is that the design is not redrawn into
      // something else (spec section 2). A textbook isometric would skew a
      // 1200 mm rectangle into a rhombus; this one must not.
      const corners = [
        Point3(0, 0, 0),
        Point3(1200, 0, 0),
        Point3(1200, 900, 0),
        Point3(0, 900, 0),
      ];

      final projected = projection.projectAll(corners);

      expect(projected[0], const ProjectedPoint(0, 0, 0));
      expect(projected[1], const ProjectedPoint(1200, 0, 0));
      expect(projected[2], const ProjectedPoint(1200, 900, 0));
      expect(projected[3], const ProjectedPoint(0, 900, 0));
    });

    test('a square at z = 0 stays square', () {
      final a = projection.project(const Point3(100, 100, 0));
      final b = projection.project(const Point3(600, 100, 0));
      final c = projection.project(const Point3(600, 600, 0));

      expect(b.x - a.x, closeTo(500, 1e-9));
      expect(c.y - b.y, closeTo(500, 1e-9));
      // No skew: the top edge is exactly horizontal.
      expect(b.y - a.y, closeTo(0, 1e-9));
    });
  });

  group('depth recedes up and to the right', () {
    test('a deeper point shifts right and up', () {
      final front = projection.project(const Point3(0, 0, 0));
      final back = projection.project(const Point3(0, 0, 100));

      expect(back.x, greaterThan(front.x));
      // Up the page is a smaller y.
      expect(back.y, lessThan(front.y));
    });

    test('the offset matches the stated angle and scale', () {
      // 30 degrees at half scale: cos30 * 0.5 across, sin30 * 0.5 up.
      final back = projection.project(const Point3(0, 0, 100));

      expect(back.x, closeTo(100 * 0.8660254 * 0.5, 1e-6));
      expect(back.y, closeTo(-100 * 0.5 * 0.5, 1e-6));
    });

    test('depth is proportional, so a deeper profile reads deeper', () {
      // A 70 mm PVC frame must project further back than a 65 mm aluminium
      // one, which is what makes the two materials look different.
      final pvc = projection.project(const Point3(0, 0, 70));
      final aluminium = projection.project(const Point3(0, 0, 65));

      expect(pvc.x, greaterThan(aluminium.x));
      expect(pvc.x / aluminium.x, closeTo(70 / 65, 1e-9));
    });

    test('the depth of a point is carried through for sorting', () {
      expect(projection.project(const Point3(0, 0, 42)).depth, 42);
    });
  });

  group('the projection is configurable', () {
    test('a steeper angle pushes depth further up than across', () {
      const steep = IsometricProjection(depthAngleDegrees: 60);

      expect(steep.depthDy, greaterThan(steep.depthDx));
    });

    test('a larger scale lengthens the depth axis', () {
      const full = IsometricProjection(depthScale: 1);

      expect(full.depthDx, closeTo(0.8660254, 1e-6));
      expect(full.project(const Point3(0, 0, 100)).x,
          greaterThan(projection.project(const Point3(0, 0, 100)).x));
    });

    test('zero depth scale flattens it to a plain elevation', () {
      const flat = IsometricProjection(depthScale: 0);

      expect(flat.project(const Point3(50, 60, 900)),
          const ProjectedPoint(50, 60, 900));
    });
  });

  group('bounds', () {
    test('they cover the depth offset, not just the elevation', () {
      const corners = [
        Point3(0, 0, 0),
        Point3(1000, 0, 0),
        Point3(1000, 800, 0),
        Point3(0, 800, 0),
        Point3(1000, 0, 70),
      ];

      final (left, top, right, bottom) = projection.projectedBounds(corners);

      expect(left, 0);
      expect(bottom, 800);
      // Wider and taller than the elevation, because of the depth corner.
      expect(right, greaterThan(1000));
      expect(top, lessThan(0));
    });

    test('an empty scene has empty bounds rather than throwing', () {
      expect(projection.projectedBounds(const []), (0.0, 0.0, 0.0, 0.0));
    });
  });
}
