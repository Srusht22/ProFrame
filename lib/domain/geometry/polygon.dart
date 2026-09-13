import 'dart:math' as math;

import 'segment.dart';
import 'tolerances.dart';
import 'vec2.dart';

/// A closed shape, as drawn.
///
/// It keeps the corners it was given, in the order it was given them. Nothing
/// here squares anything up, centres anything or evens anything out: a
/// four-sided shape with one sloping side stays a four-sided shape with one
/// sloping side.
class Polygon {
  final List<Vec2> corners;

  const Polygon(this.corners);

  factory Polygon.rect(double left, double top, double right, double bottom) =>
      Polygon([
        Vec2(left, top),
        Vec2(right, top),
        Vec2(right, bottom),
        Vec2(left, bottom),
      ]);

  bool get isEmpty => corners.length < 3;

  List<Segment> get edges => [
        for (var i = 0; i < corners.length; i++)
          Segment(corners[i], corners[(i + 1) % corners.length]),
      ];

  double get left => corners.map((c) => c.x).reduce(math.min);
  double get right => corners.map((c) => c.x).reduce(math.max);
  double get top => corners.map((c) => c.y).reduce(math.min);
  double get bottom => corners.map((c) => c.y).reduce(math.max);

  double get width => right - left;
  double get height => bottom - top;
  Vec2 get topLeft => Vec2(left, top);

  /// The signed area. Positive when the corners run clockwise on a screen,
  /// where y points down.
  double get signedArea {
    var total = 0.0;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      total += a.x * b.y - b.x * a.y;
    }
    return total / 2;
  }

  double get area => signedArea.abs();

  Vec2 get centroid {
    if (corners.isEmpty) return Vec2.zero;
    final doubleArea = signedArea * 2;
    if (doubleArea.abs() < 1e-9) {
      // Degenerate: fall back to the average of the corners rather than
      // dividing by nothing.
      var sum = Vec2.zero;
      for (final corner in corners) {
        sum += corner;
      }
      return sum / corners.length.toDouble();
    }
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final f = a.x * b.y - b.x * a.y;
      cx += (a.x + b.x) * f;
      cy += (a.y + b.y) * f;
    }
    return Vec2(cx / (3 * doubleArea), cy / (3 * doubleArea));
  }

  /// True when [point] is inside, by the winding rule. Points on the edge
  /// count as inside: a tap on a boundary should select something.
  bool contains(Vec2 point) {
    for (final edge in edges) {
      if (edge.distanceTo(point) <= Tol.samePointMm) return true;
    }
    var inside = false;
    for (var i = 0; i < corners.length; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % corners.length];
      final crossesRay = (a.y > point.y) != (b.y > point.y);
      if (!crossesRay) continue;
      final x = a.x + (point.y - a.y) / (b.y - a.y) * (b.x - a.x);
      if (point.x < x) inside = !inside;
    }
    return inside;
  }

  /// The same shape with its corners the other way round.
  /// The same shape with corners that are not corners taken out.
  ///
  /// A junction where a bar meets the frame lands on the outline as a point
  /// in the middle of a straight edge. It is a real junction, but it is not a
  /// corner of the shape, and leaving it in makes a four-sided frame report
  /// ten sides. Only points that lie on the line between their neighbours are
  /// dropped; a real corner, at any angle, is kept.
  Polygon simplified(double tolerance) {
    if (corners.length < 4) return this;
    final kept = <Vec2>[];
    for (var i = 0; i < corners.length; i++) {
      final before = kept.isNotEmpty
          ? kept.last
          : corners[(i - 1 + corners.length) % corners.length];
      final after = corners[(i + 1) % corners.length];
      if (Segment(before, after).distanceTo(corners[i]) > tolerance) {
        kept.add(corners[i]);
      }
    }
    return kept.length >= 3 ? Polygon(kept) : this;
  }

  Polygon get reversed => Polygon(corners.reversed.toList());

  /// The same shape, moved.
  Polygon translated(Vec2 by) => Polygon([for (final c in corners) c + by]);

  /// The same shape, scaled about [origin].
  Polygon scaled(double sx, double sy, {Vec2 origin = Vec2.zero}) => Polygon([
        for (final c in corners)
          Vec2(origin.x + (c.x - origin.x) * sx, origin.y + (c.y - origin.y) * sy),
      ]);

  /// The same shape brought in by [by] millimetres all round.
  ///
  /// Straight-skeleton insetting is overkill for the shapes a window is made
  /// of, so each edge is moved along its own inward normal and the new
  /// corners are where the moved edges meet. For a convex shape — which every
  /// section of a window is — that is exact.
  Polygon inset(double by) {
    if (isEmpty || by == 0) return this;
    final clockwise = signedArea > 0;
    final moved = <Segment>[];
    for (final edge in edges) {
      final normal = edge.unit.perpendicular * (clockwise ? 1.0 : -1.0);
      final shift = normal * by;
      moved.add(Segment(edge.a + shift, edge.b + shift));
    }

    final result = <Vec2>[];
    for (var i = 0; i < moved.length; i++) {
      final previous = moved[(i - 1 + moved.length) % moved.length];
      final current = moved[i];
      final meeting = _intersectLines(previous, current);
      result.add(meeting ?? current.a);
    }
    return Polygon(result);
  }

  static Vec2? _intersectLines(Segment p, Segment q) {
    final r = p.direction;
    final s = q.direction;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-9) return null;
    final t = (q.a - p.a).cross(s) / denominator;
    return p.pointAt(t);
  }

  List<Map<String, Object?>> toJson() => [for (final c in corners) c.toJson()];

  static Polygon fromJson(Object? json) {
    if (json is! List) throw const FormatException('A shape must be a list');
    return Polygon([for (final c in json) Vec2.fromJson(c)]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Polygon || other.corners.length != corners.length) {
      return false;
    }
    for (var i = 0; i < corners.length; i++) {
      if (other.corners[i] != corners[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(corners);

  @override
  String toString() => 'Polygon(${corners.join(', ')})';
}
