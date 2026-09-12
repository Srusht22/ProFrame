import 'dart:math' as math;

import 'point3.dart';

/// A point on the drawing plane, before it is scaled into pixels.
class ProjectedPoint {
  final double x;
  final double y;

  /// How far from the viewer this point is. Larger is further away.
  ///
  /// Carried through the projection so the renderer can sort faces back to
  /// front without knowing anything about the projection's maths.
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

/// Flattens the product's 3D space onto a drawing plane.
///
/// **The elevation is kept true.** Depth recedes at an angle while the front
/// face (z = 0) projects to exactly the rectangle the user drew, at exactly
/// the millimetres they confirmed. A textbook isometric would skew that
/// rectangle into a rhombus, and this application's first rule is that the
/// user's design is not redrawn into something else (spec section 2) — a
/// window they specified as 1200 wide must not *look* like it leans.
///
/// So depth is an oblique offset, in the axonometric family: front face true,
/// depth at [depthAngleDegrees] scaled by [depthScale]. The scale is below 1
/// because a full-length depth axis reads as distorted to the eye; a half
/// scale is the classic cabinet convention and is what makes the profile
/// thickness legible without swamping the elevation.
class IsometricProjection {
  /// The angle depth recedes at, measured up from the horizontal.
  final double depthAngleDegrees;

  /// How much of a millimetre of depth becomes a millimetre on the plane.
  final double depthScale;

  /// Which side the depth recedes towards: 1 is to the right, -1 to the left.
  ///
  /// Turning the product around is what "rotate the camera" means in an
  /// axonometric view — there is no perspective to swing through. Flipping
  /// this shows the other jamb, which is exactly what a fitter checking a
  /// hinge side wants (spec section 7).
  final double depthSign;

  const IsometricProjection({
    this.depthAngleDegrees = 30,
    this.depthScale = 0.5,
    this.depthSign = 1,
  });

  /// The same view seen from the other side.
  IsometricProjection get mirrored => IsometricProjection(
        depthAngleDegrees: depthAngleDegrees,
        depthScale: depthScale,
        depthSign: -depthSign,
      );

  IsometricProjection withAngle(double degrees) => IsometricProjection(
        depthAngleDegrees: degrees,
        depthScale: depthScale,
        depthSign: depthSign,
      );

  double get _radians => depthAngleDegrees * math.pi / 180;

  /// How far one millimetre of depth shifts a point across the plane.
  double get depthDx => math.cos(_radians) * depthScale * depthSign;

  /// How far one millimetre of depth shifts a point up the plane.
  ///
  /// Negative in screen terms: depth goes up and to the right, so a deeper
  /// point sits higher, which is what reads as "further back".
  double get depthDy => math.sin(_radians) * depthScale;

  ProjectedPoint project(Point3 point) => ProjectedPoint(
        point.x + point.z * depthDx,
        point.y - point.z * depthDy,
        point.z,
      );

  /// Projects a whole face.
  List<ProjectedPoint> projectAll(List<Point3> points) =>
      [for (final point in points) project(point)];

  /// The bounding box of [points] once projected, as
  /// (left, top, right, bottom).
  ///
  /// Used to fit a whole design into the viewport. Computed from the projected
  /// geometry rather than from the model, because the depth offset makes the
  /// drawing wider and taller than the elevation alone.
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
