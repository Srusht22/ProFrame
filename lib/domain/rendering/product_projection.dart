import 'dart:math' as math;

import 'point3.dart';

/// A point on the drawing plane, before it is scaled into pixels.
class ProjectedPoint {
  final double x;
  final double y;

  /// How far from the viewer this point is *after* the product has been
  /// turned. Larger is further away.
  ///
  /// Carried through the projection so the renderer can sort faces back to
  /// front without knowing anything about the projection's maths — and so the
  /// order is right at every angle, including the ones where the near jamb
  /// becomes the far one.
  final double depth;

  const ProjectedPoint(this.x, this.y, this.depth);

  @override
  bool operator ==(Object other) =>
      other is ProjectedPoint &&
      (other.x - x).abs() < 1e-9 &&
      (other.y - y).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Turns the product and flattens it onto the drawing plane.
///
/// **Turned, not skewed.** The product rotates about its own vertical axis by
/// [turnDegrees] and tips by [tiltDegrees], and is then projected straight
/// down the line of sight — an orthographic view of a rotated solid, the way
/// a thing turned in the hand looks. There is no perspective: parallel edges stay
/// parallel, so nothing at the back looks smaller than it is.
///
/// **At zero it is the elevation, exactly.** Turned flat on, the front face
/// projects to precisely the rectangle the user drew at precisely the
/// millimetres they confirmed. That is the app's first rule — a window
/// specified as 1200 wide must not *look* like something else (spec section
/// 2) — and it is why the sketch shown beside this view and this view agree
/// when the product is square on.
///
/// **It is drawn in perspective**, because a window is a genuinely thin
/// thing: seventy millimetres of frame depth against nearly a metre of width
/// is four per cent, and no honest parallel projection can make four per cent
/// look like anything. What does read as solid is convergence — the near jamb
/// drawn taller than the far one, the head and sill leaning towards each
/// other. The camera sits [viewDistanceFactor] times the product's own size
/// away, which is far enough that nothing distorts and near enough to see.
///
/// It replaces an oblique projection that slid depth sideways instead of
/// turning anything at all. That looked equally flat at every angle, so the
/// angle control appeared to do nothing.
class ProductProjection {
  /// How far the product is turned about its vertical axis, in degrees.
  ///
  /// Zero is square on. Positive swings the left jamb towards the viewer, so
  /// the right-hand side of the product recedes.
  final double turnDegrees;

  /// How far the product is tipped, in degrees. A little goes a long way: it
  /// is what shows the head and the sill, and what stops the view reading as
  /// a flat picture.
  final double tiltDegrees;

  /// Which way it turns: 1 shows one side, -1 the other. Turning the product
  /// around is exactly what a fitter checking a hinge side wants
  /// (spec section 7).
  final double turnSign;

  /// The point the product turns about, and the middle of the view. Set from
  /// the scene, so a product turns about itself rather than swinging around
  /// the corner of the sheet.
  final Point3 centre;

  /// How far the camera stands back, in millimetres. Zero is no perspective
  /// at all: parallel, and flat-looking.
  final double viewDistanceMm;

  /// The depth of the nearest point of the product, once turned.
  ///
  /// Perspective is measured from here, so whatever is closest to the eye is
  /// drawn at exactly its own size and everything behind it recedes. Square
  /// on, that is the whole front face — which is how the elevation stays
  /// exactly the elevation while the view is still a perspective one.
  final double nearDepthMm;

  /// How far back the camera stands, as a multiple of the product's own size.
  /// Nearer exaggerates, further flattens; two and a half is a comfortable
  /// look at something on a bench.
  static const double viewDistanceFactor = 2.5;

  const ProductProjection({
    this.turnDegrees = 26,
    this.tiltDegrees = 10,
    this.turnSign = 1,
    this.centre = const Point3(0, 0, 0),
    this.viewDistanceMm = 0,
    this.nearDepthMm = 0,
  });

  /// This view, bound to the product it is looking at: turning about its
  /// middle, with the camera a sensible distance from something that size.
  ProductProjection forExtent(List<Point3> extent) {
    if (extent.isEmpty) return this;
    var left = extent.first.x;
    var right = extent.first.x;
    var top = extent.first.y;
    var bottom = extent.first.y;
    var near = extent.first.z;
    var far = extent.first.z;
    for (final point in extent) {
      left = math.min(left, point.x);
      right = math.max(right, point.x);
      top = math.min(top, point.y);
      bottom = math.max(bottom, point.y);
      near = math.min(near, point.z);
      far = math.max(far, point.z);
    }

    final width = right - left;
    final height = bottom - top;
    final size = math.sqrt(width * width + height * height);

    final turned = ProductProjection(
      turnDegrees: turnDegrees,
      tiltDegrees: tiltDegrees,
      turnSign: turnSign,
      centre: Point3((left + right) / 2, (top + bottom) / 2, (near + far) / 2),
    );

    // Which corner is nearest depends on the angle, so it is worked out here,
    // once the angle is known.
    var nearest = double.infinity;
    for (final point in extent) {
      nearest = math.min(nearest, turned.project(point).depth);
    }

    return ProductProjection(
      turnDegrees: turnDegrees,
      tiltDegrees: tiltDegrees,
      turnSign: turnSign,
      centre: turned.centre,
      viewDistanceMm: size * viewDistanceFactor,
      nearDepthMm: nearest,
    );
  }

  /// The same product seen from the other side.
  ProductProjection get mirrored => ProductProjection(
        turnDegrees: turnDegrees,
        tiltDegrees: tiltDegrees,
        turnSign: -turnSign,
        centre: centre,
        viewDistanceMm: viewDistanceMm,
      );

  ProductProjection withTurn(double degrees) => ProductProjection(
        turnDegrees: degrees,
        tiltDegrees: tiltDegrees,
        turnSign: turnSign,
        centre: centre,
        viewDistanceMm: viewDistanceMm,
      );

  double get _turn => turnDegrees * turnSign * math.pi / 180;
  double get _tilt => tiltDegrees * math.pi / 180;

  /// True when the product is square on, and the front face is the exact
  /// elevation.
  bool get isSquareOn => turnDegrees.abs() < 1e-9 && tiltDegrees.abs() < 1e-9;

  ProjectedPoint project(Point3 point) {
    // Everything happens about the middle of the product, so it turns on the
    // spot instead of swinging around the corner of the sheet.
    final x0 = point.x - centre.x;
    final y0 = point.y - centre.y;
    final z0 = point.z - centre.z;

    // Turn about the vertical axis. The model's y runs down the elevation, so
    // the vertical axis is y and the turn mixes x and z.
    final cosTurn = math.cos(_turn);
    final sinTurn = math.sin(_turn);
    final x1 = x0 * cosTurn + z0 * sinTurn;
    final z1 = -x0 * sinTurn + z0 * cosTurn;

    // Then tip it, which mixes what is left of depth into the vertical.
    final cosTilt = math.cos(_tilt);
    final sinTilt = math.sin(_tilt);
    final y2 = y0 * cosTilt - z1 * sinTilt;
    final z2 = y0 * sinTilt + z1 * cosTilt;

    // Perspective: further away is drawn smaller. This is what makes a thin
    // product read as solid — the near jamb taller than the far one. Measured
    // from the nearest point, so that point is drawn true and everything
    // behind it recedes from there.
    final shrink = viewDistanceMm > 0
        ? viewDistanceMm / (viewDistanceMm + z2 - nearDepthMm)
        : 1.0;

    return ProjectedPoint(
      centre.x + x1 * shrink,
      centre.y + y2 * shrink,
      z2,
    );
  }

  /// Projects a whole face.
  List<ProjectedPoint> projectAll(List<Point3> points) =>
      [for (final point in points) project(point)];

  /// The bounding box of [points] once projected, as
  /// (left, top, right, bottom).
  ///
  /// Computed from the projected geometry rather than from the model, because
  /// a turned product is wider and taller on the plane than its elevation.
  (double, double, double, double) projectedBounds(List<Point3> points) {
    if (points.isEmpty) return (0, 0, 0, 0);
    final projected = projectAll(points);
    var left = projected.first.x;
    var right = projected.first.x;
    var top = projected.first.y;
    var bottom = projected.first.y;
    for (final point in projected) {
      left = math.min(left, point.x);
      right = math.max(right, point.x);
      top = math.min(top, point.y);
      bottom = math.max(bottom, point.y);
    }
    return (left, top, right, bottom);
  }
}
