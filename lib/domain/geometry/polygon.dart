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

  /// A plate with radiused ends — a stadium — centred on [centre], running
  /// [length] along [along] and [width] across it: the shape pressed metal
  /// is, because it has no sharp corners. [corner] is how many straight
  /// pieces each rounded end is made of.
  ///
  /// It is here rather than with the solid because the elevation and the
  /// solid both draw the plate a piece of ironmongery stands on, and they
  /// must draw the same one.
  factory Polygon.stadium(
    Vec2 centre,
    Vec2 along,
    double length,
    double width, {
    int corner = 5,
  }) {
    final u = along.length < 1e-9 ? const Vec2(1, 0) : along.normalised;
    final v = u.perpendicular;
    final radius = width / 2;
    final straight = math.max(0.0, length / 2 - radius);

    final corners = <Vec2>[];
    for (final end in [1.0, -1.0]) {
      final hub = centre + u * (straight * end);
      for (var i = 0; i <= corner; i++) {
        final angle = (i / corner - 0.5) * math.pi * end;
        final c = math.cos(angle) * end;
        final d = math.sin(angle);
        corners.add(Vec2(
          hub.x + u.x * radius * c + v.x * radius * d,
          hub.y + u.y * radius * c + v.y * radius * d,
        ));
      }
    }
    return Polygon(corners);
  }

  /// A circle of [sides] straight pieces round [centre] — the same corners
  /// the solid turns a round part from, so a boss, a rose or a keyhole seen
  /// square on is the shape it is built as.
  factory Polygon.circle(Vec2 centre, double radius, {int sides = 12}) =>
      Polygon([
        for (var i = 0; i < sides; i++)
          Vec2(
            centre.x + math.cos(i / sides * math.pi * 2) * radius,
            centre.y + math.sin(i / sides * math.pi * 2) * radius,
          ),
      ]);

  /// The smallest convex shape holding every one of [points] — what a
  /// round part turned along a path covers, seen square on.
  factory Polygon.hullOf(Iterable<Vec2> points) {
    final sorted = points.toList()
      ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
    if (sorted.length < 3) return Polygon(sorted);
    double turn(Vec2 o, Vec2 a, Vec2 b) => (a - o).cross(b - o);
    final lower = <Vec2>[], upper = <Vec2>[];
    for (final p in sorted) {
      while (lower.length >= 2 &&
          turn(lower[lower.length - 2], lower.last, p) <= 0) {
        lower.removeLast();
      }
      lower.add(p);
    }
    for (final p in sorted.reversed) {
      while (upper.length >= 2 &&
          turn(upper[upper.length - 2], upper.last, p) <= 0) {
        upper.removeLast();
      }
      upper.add(p);
    }
    return Polygon([
      ...lower.sublist(0, lower.length - 1),
      ...upper.sublist(0, upper.length - 1),
    ]);
  }

  bool get isEmpty => corners.length < 3;

  /// Whether every corner turns the same way — which is what makes clipping
  /// to this shape exact (see [clippedTo]).
  bool get isConvex {
    if (isEmpty) return false;
    var sign = 0.0;
    final n = corners.length;
    for (var i = 0; i < n; i++) {
      final a = corners[i], b = corners[(i + 1) % n], c = corners[(i + 2) % n];
      final turn = (b - a).cross(c - b);
      if (turn.abs() < 1e-9) continue;
      if (sign == 0) {
        sign = turn.sign;
      } else if (turn.sign != sign) {
        return false;
      }
    }
    return true;
  }

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

  /// Whether the outline goes round once without touching itself: no corner
  /// visited twice and no two edges meeting except neighbours at the corner
  /// they share. A bow tie, or an outline pinched to a point, is not — it is
  /// two shapes drawn as one, and nothing can be built in the pinch.
  bool get isSimple {
    final n = corners.length;
    if (n < 3) return false;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        if (corners[i].distanceTo(corners[j]) <= Tol.samePointMm) return false;
      }
    }
    final sides = edges;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final neighbours = j == i + 1 || (i == 0 && j == n - 1);
        if (neighbours) continue;
        if (sides[i].crossing(sides[j]) != null) return false;
      }
    }
    return true;
  }

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
  ///
  /// **It is measured from the sides that bound the shape square**, along
  /// each axis: between its level head and its level sill, between its two
  /// upright sides. On a rectangle those are its box, and this is the box's
  /// proportion. On a light under a slope there is no level head — its top
  /// is wherever the slope happens to meet the bar beside it — and carrying
  /// in proportion to that box moved everything inside up or down whenever
  /// the bar moved sideways: the rail in a raked sash rode up the leaf and
  /// its panel grew, with nothing that bounds the panel having moved. So
  /// where only one side along an axis is square, what is inside goes with
  /// that side; where neither is, with the box, as before.
  Vec2 sameIn(Polygon other, Vec2 point) {
    if (width <= 0 || height <= 0) return point;
    return Vec2(
      _alongIn(other, point.x, across: true),
      _alongIn(other, point.y, across: false),
    );
  }

  double _alongIn(Polygon other, double v, {required bool across}) {
    final (lo, hi) = _squareBounds(across: across);
    final (toLo, toHi) = other._squareBounds(across: across);
    if (lo != null && hi != null && toLo != null && toHi != null) {
      return toLo + (v - lo) * ((toHi - toLo) / (hi - lo));
    }
    if (hi != null && toHi != null) return v + (toHi - hi);
    if (lo != null && toLo != null) return v + (toLo - lo);
    final (from, size) = across ? (left, width) : (top, height);
    final (to, toSize) = across
        ? (other.left, other.width)
        : (other.top, other.height);
    return to + (v - from) * (toSize / size);
  }

  /// Where this shape's box is bounded by a side square to [across]'s axis:
  /// an upright side at its left and right, a level one at its top and
  /// bottom. Null for an extreme that is only a corner of a slope.
  (double?, double?) _squareBounds({required bool across}) {
    const on = Tol.samePointMm;
    final (low, high) = across ? (left, right) : (top, bottom);
    double? lo, hi;
    for (final e in edges) {
      final square = across
          ? (e.a.x - e.b.x).abs() <= on && (e.a.y - e.b.y).abs() > on
          : (e.a.y - e.b.y).abs() <= on && (e.a.x - e.b.x).abs() > on;
      if (!square) continue;
      final at = across ? e.a.x : e.a.y;
      if ((at - low).abs() <= on) lo = low;
      if ((at - high).abs() <= on) hi = high;
    }
    if (lo != null && hi != null && hi - lo <= on) return (null, hi);
    return (lo, hi);
  }

  /// [line] where it lands when this shape becomes [other]: each end the
  /// same place in the new shape as in this one, by [sameIn] — and an end
  /// that met this shape's boundary, within [onEdge], still meeting the new
  /// one, where the line it is on now reaches it.
  ///
  /// A line dropped from the slope of a raked light to its sill ends on the
  /// slope. Carried to the light as it is after a bar beside it moved, its
  /// foot is still on the sill but its head can come off the slope, and a
  /// line that stops short of what it was drawn to divides nothing: the
  /// glass and the panel either side of it were lost. Its head is put back
  /// on the slope along its own line, so it keeps its angle and its place.
  Segment lineIn(Polygon other, Segment line, {required double onEdge}) {
    final a = sameIn(other, line.a), b = sameIn(other, line.b);
    Vec2 end(Vec2 was, Vec2 now, Vec2 far) {
      if (_boundaryDistance(was) > onEdge) return now;
      if (other._boundaryDistance(now) <= 1e-6) return now;
      final r = now - far;
      if (r.length < 1e-9) return now;
      Vec2? best;
      var nearest = double.infinity;
      for (final edge in other.edges) {
        final s = edge.direction;
        final denominator = r.cross(s);
        if (denominator.abs() < 1e-9 * r.length * s.length) continue;
        final u = (far - edge.a).cross(r) / -denominator;
        final slack = 1e-6 / math.max(s.length, 1e-9);
        if (u < -slack || u > 1 + slack) continue;
        final at = edge.pointAt(u.clamp(0.0, 1.0));
        final d = at.distanceTo(now);
        if (d < nearest) {
          best = at;
          nearest = d;
        }
      }
      return best ?? now;
    }

    return Segment(end(line.a, a, b), end(line.b, b, a));
  }

  double _boundaryDistance(Vec2 p) =>
      edges.map((e) => e.distanceTo(p)).fold(double.infinity, math.min);

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

  /// The part of [line] inside this shape, from where it first comes in to
  /// where it last goes out — null when none of it is. The line is cut, never
  /// moved: an end already inside stays exactly where it was.
  Segment? portionOf(Segment line) {
    if (isEmpty) return line;
    final aIn = contains(line.a);
    final bIn = contains(line.b);
    if (aIn && bIn) return line;

    final hits = <double>[];
    for (final edge in edges) {
      final crossing = line.crossing(edge);
      if (crossing != null) hits.add(crossing.onA);
    }
    if (hits.isEmpty) return aIn || bIn ? line : null;
    hits.sort();

    final from = aIn ? 0.0 : hits.first;
    final to = bIn ? 1.0 : hits.last;
    if (to - from < 1e-6) return null;
    return Segment(line.pointAt(from), line.pointAt(to));
  }

  /// The same shape brought in by [by] millimetres all round.
  ///
  /// Straight-skeleton insetting is overkill for the shapes a window is made
  /// of, so each edge is moved along its own inward normal and the new
  /// corners are where the moved edges meet. For a convex shape — which every
  /// section of a window is — that is exact.
  Polygon inset(double by) {
    if (isEmpty || by == 0) return this;
    return insetEach([for (var i = 0; i < corners.length; i++) by]);
  }

  /// [inset], with each edge moved in by its own distance — `by[i]` for the
  /// edge from corner `i` to the next.
  ///
  /// A frame left open on one side has no member there, so its daylight
  /// runs right out to the outline on that side and is inset by the profile
  /// everywhere else.
  Polygon insetEach(List<double> by) {
    if (isEmpty) return this;
    final clockwise = signedArea > 0;
    final moved = <Segment>[];
    final sides = edges;
    for (var i = 0; i < sides.length; i++) {
      final edge = sides[i];
      final normal = edge.unit.perpendicular * (clockwise ? 1.0 : -1.0);
      final shift = normal * by[i];
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
