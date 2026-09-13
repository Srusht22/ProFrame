import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/rendering/point3.dart';
import 'package:proframe/domain/rendering/product_projection.dart';

/// A 1200 × 900 window, 70 mm deep, as the scene builder would lay it out.
const window = [
  Point3(0, 0, 0),
  Point3(1200, 0, 0),
  Point3(1200, 900, 0),
  Point3(0, 900, 0),
  Point3(0, 0, 70),
  Point3(1200, 0, 70),
  Point3(1200, 900, 70),
  Point3(0, 900, 70),
];

void main() {
  group('square on, it is the elevation exactly', () {
    const squareOn = ProductProjection(turnDegrees: 0, tiltDegrees: 0);

    test('the front face projects to precisely what was drawn', () {
      // The first rule of this app: the design is not redrawn into something
      // else (spec section 2). A 1200 mm rectangle stays a 1200 mm rectangle.
      final projection = squareOn.forExtent(window);
      final corners = projection.projectAll(const [
        Point3(0, 0, 0),
        Point3(1200, 0, 0),
        Point3(1200, 900, 0),
        Point3(0, 900, 0),
      ]);

      expect(corners[1].x - corners[0].x, closeTo(1200, 1e-6));
      expect(corners[2].y - corners[1].y, closeTo(900, 1e-6));
      // No lean: the top edge is exactly horizontal, the side exactly upright.
      expect(corners[1].y - corners[0].y, closeTo(0, 1e-6));
      expect(corners[2].x - corners[1].x, closeTo(0, 1e-6));
    });

    test('it says so itself', () {
      expect(squareOn.isSquareOn, isTrue);
      expect(const ProductProjection().isSquareOn, isFalse);
    });
  });

  group('turning shows the side of the product', () {
    test('the jamb is nothing square on and something turned', () {
      const squareOn = ProductProjection(turnDegrees: 0, tiltDegrees: 0);
      const turned = ProductProjection(turnDegrees: 40, tiltDegrees: 0);

      double jambWidth(ProductProjection view) {
        final bound = view.forExtent(window);
        final front = bound.project(const Point3(0, 0, 0));
        final back = bound.project(const Point3(0, 0, 70));
        return (back.x - front.x).abs();
      }

      // Square on, the frame is a shallow box seen straight into: the back of
      // it is a little smaller than the front, which shows as a hint of the
      // reveal and nothing more.
      expect(jambWidth(squareOn), lessThan(15));
      // Turned, the jamb itself is on show.
      expect(jambWidth(turned), greaterThan(jambWidth(squareOn) * 3));
    });

    test('turning further shows more of it', () {
      double jambWidth(double degrees) {
        final bound =
            ProductProjection(turnDegrees: degrees, tiltDegrees: 0)
                .forExtent(window);
        return (bound.project(const Point3(0, 0, 70)).x -
                bound.project(const Point3(0, 0, 0)).x)
            .abs();
      }

      expect(jambWidth(45), greaterThan(jambWidth(20)));
      expect(jambWidth(20), greaterThan(jambWidth(5)));
    });

    test('turning it around shows the other side', () {
      const view = ProductProjection(turnDegrees: 40, tiltDegrees: 0);
      final left = view.forExtent(window);
      final right = view.mirrored.forExtent(window);

      final depthShiftLeft =
          left.project(const Point3(600, 450, 70)).x - 600;
      final depthShiftRight =
          right.project(const Point3(600, 450, 70)).x - 600;

      expect(depthShiftLeft * depthShiftRight, lessThan(0));
    });

    test('tipping it shows the head and the sill', () {
      const flat = ProductProjection(turnDegrees: 20, tiltDegrees: 0);
      const tipped = ProductProjection(turnDegrees: 20, tiltDegrees: 14);

      double sillDrop(ProductProjection view) {
        final bound = view.forExtent(window);
        return (bound.project(const Point3(600, 900, 70)).y -
                bound.project(const Point3(600, 900, 0)).y)
            .abs();
      }

      expect(sillDrop(flat), lessThan(sillDrop(tipped)));
      expect(sillDrop(tipped), greaterThan(5));
    });
  });

  group('perspective is what makes a thin product read as solid', () {
    test('the near jamb is drawn taller than the far one', () {
      final view = const ProductProjection(turnDegrees: 35).forExtent(window);

      double heightAt(double x, double z) =>
          (view.project(Point3(x, 900, z)).y - view.project(Point3(x, 0, z)).y)
              .abs();

      // The two upright edges of the same jamb: the front one is nearer the
      // eye than the back one, so it is drawn taller.
      expect(heightAt(0, 0), greaterThan(heightAt(0, 70)));
    });

    test('without it, everything is the same size however far away it is', () {
      const flat = ProductProjection(turnDegrees: 35);
      // forExtent is what fits a camera distance; unbound, it is parallel.
      double heightAt(double z) => (flat.project(Point3(0, 900, z)).y -
              flat.project(Point3(0, 0, z)).y)
          .abs();

      expect(heightAt(0), closeTo(heightAt(70), 1e-6));
    });

    test('the camera stands back in proportion to the product', () {
      final small = const ProductProjection().forExtent(window);
      final large = const ProductProjection().forExtent(const [
        Point3(0, 0, 0),
        Point3(4000, 0, 0),
        Point3(4000, 2400, 0),
        Point3(0, 2400, 0),
      ]);

      expect(large.viewDistanceMm, greaterThan(small.viewDistanceMm));
      // A patio door is not looked at from a window's distance, so neither is
      // distorted more than the other.
      expect(
        large.viewDistanceMm / 4664,
        closeTo(small.viewDistanceMm / 1500, 0.05),
      );
    });

    test('it turns about its own middle, not the corner of the sheet', () {
      final view = const ProductProjection(turnDegrees: 40).forExtent(window);
      // The middle of the product is the middle of its depth as well.
      final centre = view.project(const Point3(600, 450, 35));

      expect(centre.x, closeTo(600, 1));
      expect(centre.y, closeTo(450, 1));
    });
  });

  group('depth is carried through for sorting', () {
    test('a point further into the room sorts further away', () {
      final view = const ProductProjection(turnDegrees: 30).forExtent(window);

      expect(
        view.project(const Point3(600, 450, 70)).depth,
        greaterThan(view.project(const Point3(600, 450, 0)).depth),
      );
    });

    test('turned far enough, the near jamb becomes the far one', () {
      // Which is why the renderer sorts by this rather than by a key worked
      // out before the angle was known.
      final view = const ProductProjection(turnDegrees: 60).forExtent(window);
      final leftJamb = view.project(const Point3(0, 450, 35)).depth;
      final rightJamb = view.project(const Point3(1200, 450, 35)).depth;

      expect(leftJamb, isNot(closeTo(rightJamb, 1)));
    });
  });

  group('bounds', () {
    test('they cover the whole turned product, not just the elevation', () {
      final view = const ProductProjection(turnDegrees: 40).forExtent(window);
      final (left, top, right, bottom) = view.projectedBounds(window);

      expect(right - left, greaterThan(0));
      expect(bottom - top, greaterThan(0));
      for (final point in window) {
        final projected = view.project(point);
        expect(projected.x, inInclusiveRange(left - 1e-6, right + 1e-6));
        expect(projected.y, inInclusiveRange(top - 1e-6, bottom + 1e-6));
      }
    });

    test('an empty scene has empty bounds rather than throwing', () {
      expect(
        const ProductProjection().projectedBounds(const []),
        (0.0, 0.0, 0.0, 0.0),
      );
      expect(const ProductProjection().forExtent(const []).centre,
          const Point3(0, 0, 0));
    });
  });
}
