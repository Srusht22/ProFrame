import 'dart:math' as math;

import 'tolerances.dart';

/// A point in model space, in millimetres.
///
/// Model space is the product itself: x runs left to right across the
/// elevation, y runs top to bottom. It has nothing to do with screen pixels,
/// which is what lets the window be resized or the device rotated without the
/// design changing (spec section 8).
class Point2 {
  final double x;
  final double y;

  const Point2(this.x, this.y);

  static const Point2 origin = Point2(0, 0);

  Point2 operator +(Point2 other) => Point2(x + other.x, y + other.y);
  Point2 operator -(Point2 other) => Point2(x - other.x, y - other.y);
  Point2 operator *(double factor) => Point2(x * factor, y * factor);

  double distanceTo(Point2 other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// True when [other] is the same point within [Tolerances.pointCoincidenceMm].
  bool coincidesWith(Point2 other) =>
      distanceTo(other) <= Tolerances.pointCoincidenceMm;

  /// Angle to [other] in degrees, measured from the positive x axis,
  /// in the range (-180, 180].
  double angleTo(Point2 other) =>
      math.atan2(other.y - y, other.x - x) * 180 / math.pi;

  @override
  bool operator ==(Object other) =>
      other is Point2 &&
      (other.x - x).abs() < 1e-9 &&
      (other.y - y).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';

  List<double> toJson() => [x, y];

  static Point2 fromJson(Object? json, {String path = 'point'}) {
    if (json is! List || json.length != 2) {
      throw FormatException('$path must be [x, y], got $json');
    }
    final x = json[0];
    final y = json[1];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
      throw FormatException('$path must hold two finite numbers, got $json');
    }
    return Point2(x.toDouble(), y.toDouble());
  }
}
