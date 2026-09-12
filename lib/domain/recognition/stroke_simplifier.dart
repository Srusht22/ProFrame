import 'dart:math' as math;

import '../geometry/point2.dart';

/// Reduces a raw finger stroke to its corner points.
///
/// A finger produces far more samples than the geometry needs, and every one
/// of them carries the wobble of a hand. Ramer–Douglas–Peucker keeps the
/// points that actually change direction and drops the rest, which is what
/// turns "hundreds of samples" into "this stroke has four corners".
///
/// Pure geometry: no Flutter, no state, same input always gives same output.
abstract final class StrokeSimplifier {
  /// Removes samples closer together than [minSpacingMm].
  ///
  /// Run before [simplify]: a cluster of near-identical points where the
  /// finger paused makes the corner test noisy.
  static List<Point2> dropClusteredPoints(
    List<Point2> points, {
    double minSpacingMm = 2,
  }) {
    if (points.length < 2) return List.of(points);
    final result = <Point2>[points.first];
    for (final point in points.skip(1)) {
      if (result.last.distanceTo(point) >= minSpacingMm) result.add(point);
    }
    // The last sample is where the finger actually lifted, so it is kept even
    // if it fell inside the spacing of the one before it.
    if (result.last != points.last) result.add(points.last);
    return result;
  }

  /// Ramer–Douglas–Peucker.
  ///
  /// [toleranceMm] is how far a point may sit from the line between its
  /// neighbours before it counts as a corner rather than wobble.
  static List<Point2> simplify(List<Point2> points, {double toleranceMm = 12}) {
    if (points.length < 3) return List.of(points);

    var furthestIndex = 0;
    var furthestDistance = 0.0;
    final start = points.first;
    final end = points.last;

    for (var i = 1; i < points.length - 1; i++) {
      final distance = _distanceToLine(points[i], start, end);
      if (distance > furthestDistance) {
        furthestDistance = distance;
        furthestIndex = i;
      }
    }

    if (furthestDistance <= toleranceMm) return [start, end];

    final left = simplify(
      points.sublist(0, furthestIndex + 1),
      toleranceMm: toleranceMm,
    );
    final right = simplify(
      points.sublist(furthestIndex),
      toleranceMm: toleranceMm,
    );
    return [...left.sublist(0, left.length - 1), ...right];
  }

  /// Perpendicular distance from [point] to the infinite line through [a], [b].
  /// Falls back to plain distance when the segment has no length.
  static double _distanceToLine(Point2 point, Point2 a, Point2 b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return point.distanceTo(a);
    final cross = (dx * (a.y - point.y) - (a.x - point.x) * dy).abs();
    return cross / math.sqrt(lengthSquared);
  }
}
