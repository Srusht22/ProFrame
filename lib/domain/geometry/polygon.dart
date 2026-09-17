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
  /// How far [point] is from the nearest edge of this shape, whether it is
  /// inside or out.
  double awayFrom(Vec2 point) {
    var least = double.infinity;
    for (final edge in edges) {
      final away = edge.distanceTo(point);
      if (away < least) least = away;
    }
    return least;
  }

  /// True when [line] lies within this shape: every part of it inside, or
  /// near enough to an edge — within [reach] — to count as lying along the
  /// boundary.
  ///
  /// Sampled along the line, not tested at its middle alone. A line whose
  /// middle happens to fall inside while its ends reach away out of the
  /// shape is not within it, and that is the whole difference between a bar
  /// belonging to a section and a bar merely passing through it.
  bool holds(Segment line, {double reach = 0}) {
    const samples = 12;
    for (var i = 1; i < samples; i++) {
      final at = line.pointAt(i / samples);
      if (contains(at)) continue;
      if (reach > 0 && awayFrom(at) <= reach) continue;
      return false;
    }
    return true;
  }

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

  /// Where [point] lands when this shape becomes [other]: the same place in
  /// the new shape as it had in this one.
  ///
  /// This is what it means for something to be inside a section rather than
  /// on the sheet. A bar a quarter of the way down an opening is a quarter
  /// of the way down it wherever the opening is and whatever size it has
  /// been made, because it is the opening's. Both the carrying that follows
  /// a resize and the carrying that follows an opening to another section go
  /// through here, so there is one answer to where the inside of a section
  /// goes, not two.
  Vec2 sameIn(Polygon other, Vec2 point) {
    if (width <= 0 || height <= 0) return point;
    return Vec2(
      other.left + (point.x - left) * (other.width / width),
      other.top + (point.y - top) * (other.height / height),
    );
  }

  /// [shape] where it lands when this shape becomes [other] — the same
  /// place in the new shape as it had in this one, corner by corner.
  Polygon sameShapeIn(Polygon other, Polygon shape) =>
      Polygon([for (final c in shape.corners) sameIn(other, c)]);

  /// The part of this shape that lies inside [convex].
  ///
  /// Sutherland–Hodgman, which is exact against a convex clip — and a sash
  /// of a window is convex. The result keeps this shape's own corners where
  /// they are inside and takes the crossings where they are not: nothing is
  /// rounded off, squared up or nudged. Empty when the two do not overlap.
  Polygon clippedTo(Polygon convex) {
    if (isEmpty || convex.isEmpty) return this;
    final sign = convex.signedArea > 0 ? 1.0 : -1.0;

    var kept = corners;
    for (final edge in convex.edges) {
      if (kept.length < 3) return const Polygon([]);
      final along = edge.direction;
      double side(Vec2 point) => sign * along.cross(point - edge.a);

      final next = <Vec2>[];
      for (var i = 0; i < kept.length; i++) {
        final here = kept[i];
        final there = kept[(i + 1) % kept.length];
        final onHere = side(here);
        final onThere = side(there);
        if (onHere >= 0) next.add(here);
        if ((onHere >= 0) != (onThere >= 0)) {
          final gap = onHere - onThere;
          if (gap.abs() > 1e-9) {
            next.add(here + (there - here) * (onHere / gap));
          }
        }
      }
      kept = next;
    }

    return kept.length >= 3 ? Polygon(kept) : const Polygon([]);
  }

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
