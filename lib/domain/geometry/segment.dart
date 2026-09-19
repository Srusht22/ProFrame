import 'dart:math' as math;

import 'tolerances.dart';
import 'vec2.dart';

/// Where two segments meet.
class Crossing {
  /// The point, in millimetres.
  final Vec2 at;

  /// How far along each segment it is, 0 at the start and 1 at the end.
  final double onA;
  final double onB;

  const Crossing(this.at, this.onA, this.onB);
}

/// A straight run between two points.
class Segment {
  final Vec2 a;
  final Vec2 b;

  const Segment(this.a, this.b);

  Vec2 get direction => b - a;
  Vec2 get unit => direction.normalised;
  double get length => direction.length;
  Vec2 get midpoint => a.lerp(b, 0.5);

  /// The angle from horizontal, 0 to 180 — a line has no front or back.
  double get headingDegrees {
    final degrees = math.atan2(b.y - a.y, b.x - a.x) * 180 / math.pi;
    return (degrees + 180) % 180;
  }

  /// How far this line is from the nearest axis, in degrees.
  double get offAxisDegrees {
    final heading = headingDegrees;
    final fromHorizontal = math.min(heading, 180 - heading);
    final fromVertical = (heading - 90).abs();
    return math.min(fromHorizontal, fromVertical);
  }

  bool get isHorizontalish =>
      (a.y - b.y).abs() <= (a.x - b.x).abs() &&
      offAxisDegrees <= Tol.axisSnapDegrees;

  bool get isVerticalish =>
      (a.x - b.x).abs() < (a.y - b.y).abs() &&
      offAxisDegrees <= Tol.axisSnapDegrees;

  Segment get reversed => Segment(b, a);

  /// The point [t] of the way along.
  Vec2 pointAt(double t) => a.lerp(b, t);

  /// How far along this segment [point] falls, 0 at [a] and 1 at [b].
  /// Outside 0..1 when the point is beyond an end.
  double parameterOf(Vec2 point) {
    final d = direction;
    final lengthSquared = d.lengthSquared;
    if (lengthSquared == 0) return 0;
    return (point - a).dot(d) / lengthSquared;
  }

  /// The nearest point on this segment to [point] — on the segment, not on
  /// the infinite line through it.
  Vec2 nearestTo(Vec2 point) => pointAt(parameterOf(point).clamp(0.0, 1.0));

  double distanceTo(Vec2 point) => nearestTo(point).distanceTo(point);

  /// Where this segment crosses [other], or null when they do not cross.
  ///
  /// Touching counts: a line drawn up to another one, not through it, is a
  /// T-junction, and a T-junction divides a section just as a crossing does.
  Crossing? crossing(Segment other, {double tolerance = Tol.samePointMm}) {
    final r = direction;
    final s = other.direction;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-12) return null; // Parallel.

    final t = (other.a - a).cross(s) / denominator;
    final u = (other.a - a).cross(r) / denominator;

    // A little slack at the ends, so a line drawn *almost* to another one
    // still meets it. Expressed in each segment's own parameter space.
    final slackT = length == 0 ? 0.0 : tolerance / length;
    final slackU = other.length == 0 ? 0.0 : tolerance / other.length;

    if (t < -slackT || t > 1 + slackT) return null;
    if (u < -slackU || u > 1 + slackU) return null;

    return Crossing(pointAt(t.clamp(0.0, 1.0)), t.clamp(0.0, 1.0), u.clamp(0.0, 1.0));
  }

  @override
  bool operator ==(Object other) =>
      other is Segment && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'Segment($a → $b)';
}
