import 'dart:math' as math;

import '../../core/errors/app_exception.dart';
import 'point2.dart';
import 'tolerances.dart';

/// How an edge sits relative to the elevation.
enum EdgeOrientation {
  horizontal,
  vertical,

  /// Deliberately at an angle — the top of a sloping-head frame. Never
  /// snapped to an axis (spec section 2).
  sloping,
}

/// One edge of a closed outline.
class Edge {
  final Point2 start;
  final Point2 end;

  const Edge(this.start, this.end);

  double get length => start.distanceTo(end);

  /// Angle in degrees from the positive x axis, normalised to [0, 180) so an
  /// edge and its reverse classify identically.
  double get headingDegrees {
    final angle = start.angleTo(end) % 180;
    return angle < 0 ? angle + 180 : angle;
  }

  EdgeOrientation get orientation {
    final heading = headingDegrees;
    if (heading <= Tolerances.axisAlignmentDegrees ||
        heading >= 180 - Tolerances.axisAlignmentDegrees) {
      return EdgeOrientation.horizontal;
    }
    if ((heading - 90).abs() <= Tolerances.axisAlignmentDegrees) {
      return EdgeOrientation.vertical;
    }
    return EdgeOrientation.sloping;
  }

  /// How far off axis this edge is, in degrees. Used to explain to the user
  /// why a line was straightened, or why one was left alone.
  double get slopeFromNearestAxisDegrees {
    final heading = headingDegrees;
    final fromHorizontal = math.min(heading, 180 - heading);
    final fromVertical = (heading - 90).abs();
    return math.min(fromHorizontal, fromVertical);
  }

  @override
  String toString() => 'Edge($start -> $end, ${orientation.name})';
}

/// A closed, non-self-intersecting outline in model space.
///
/// This is the shape of the product, not a rectangle with optional extras:
/// a straight sloping top or unequal side heights are ordinary polygons here
/// rather than special cases bolted onto a rect (spec section 3B).
///
/// Vertices are stored in the order given, without an explicit repeat of the
/// first point at the end.
class Polygon {
  final List<Point2> vertices;

  const Polygon._(this.vertices);

  /// Validates and creates a polygon.
  ///
  /// Throws [GeometryException] rather than returning null or silently
  /// repairing the shape, because a boundary that does not close is a bug or a
  /// drawing the user must fix — not something to guess at (spec section 2).
  factory Polygon(List<Point2> vertices) {
    if (vertices.length < 3) {
      throw const GeometryException(
        'A closed outline needs at least three corners.',
      );
    }
    final cleaned = _dropRepeatedPoints(vertices);
    if (cleaned.length < 3) {
      throw const GeometryException(
        'This outline collapses to a line once duplicate corners are merged.',
      );
    }
    final polygon = Polygon._(List.unmodifiable(cleaned));
    if (polygon.area.abs() < Tolerances.minimumSectionAreaMmSq) {
      throw const GeometryException('This outline encloses no usable area.');
    }
    if (polygon._selfIntersects()) {
      throw const GeometryException(
        'This outline crosses itself. Edges may meet at corners but must not '
        'cross.',
      );
    }
    return polygon;
  }

  /// An axis-aligned rectangle, the most common outline by far.
  factory Polygon.rectangle({
    required double width,
    required double height,
    Point2 topLeft = Point2.origin,
  }) =>
      Polygon([
        topLeft,
        Point2(topLeft.x + width, topLeft.y),
        Point2(topLeft.x + width, topLeft.y + height),
        Point2(topLeft.x, topLeft.y + height),
      ]);

  /// A frame with a straight sloping top and unequal side heights
  /// (spec section 3D).
  ///
  /// The slope is whatever the two heights make it — it is never levelled,
  /// and the app does not care which side is taller.
  factory Polygon.slopingTop({
    required double width,
    required double leftHeight,
    required double rightHeight,
    Point2 baseLeft = Point2.origin,
  }) {
    if (leftHeight <= 0 || rightHeight <= 0) {
      throw const GeometryException('Both side heights must be greater than zero.');
    }
    final tallest = math.max(leftHeight, rightHeight);
    // y grows downwards, so the taller side starts higher up the page.
    return Polygon([
      Point2(baseLeft.x, baseLeft.y + tallest - leftHeight),
      Point2(baseLeft.x + width, baseLeft.y + tallest - rightHeight),
      Point2(baseLeft.x + width, baseLeft.y + tallest),
      Point2(baseLeft.x, baseLeft.y + tallest),
    ]);
  }

  int get cornerCount => vertices.length;

  List<Edge> get edges => [
        for (var i = 0; i < vertices.length; i++)
          Edge(vertices[i], vertices[(i + 1) % vertices.length]),
      ];

  /// Signed area by the shoelace formula. Positive is clockwise in this
  /// coordinate system, where y grows downwards.
  double get area {
    var sum = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum / 2;
  }

  double get width {
    final xs = vertices.map((v) => v.x);
    return xs.reduce(math.max) - xs.reduce(math.min);
  }

  double get height {
    final ys = vertices.map((v) => v.y);
    return ys.reduce(math.max) - ys.reduce(math.min);
  }

  double get left => vertices.map((v) => v.x).reduce(math.min);
  double get top => vertices.map((v) => v.y).reduce(math.min);
  double get right => vertices.map((v) => v.x).reduce(math.max);
  double get bottom => vertices.map((v) => v.y).reduce(math.max);

  /// True when every edge is horizontal or vertical.
  bool get isRectilinear =>
      edges.every((e) => e.orientation != EdgeOrientation.sloping);

  /// True when this is a four-cornered axis-aligned rectangle.
  bool get isRectangle => cornerCount == 4 && isRectilinear;

  /// The edges the user meant to be at an angle. Used by the UI to show that a
  /// slope was kept, and by validation to confirm it was never flattened.
  List<Edge> get slopingEdges =>
      edges.where((e) => e.orientation == EdgeOrientation.sloping).toList();

  /// Whether [point] is inside, by the even-odd rule. Points on an edge count
  /// as inside.
  bool contains(Point2 point) {
    for (final edge in edges) {
      if (_isOnSegment(point, edge.start, edge.end)) return true;
    }
    var inside = false;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      final straddles = (a.y > point.y) != (b.y > point.y);
      if (!straddles) continue;
      final crossingX = a.x + (point.y - a.y) / (b.y - a.y) * (b.x - a.x);
      if (point.x < crossingX) inside = !inside;
    }
    return inside;
  }

  Polygon translated(Point2 delta) =>
      Polygon._([for (final v in vertices) v + delta]);

  static List<Point2> _dropRepeatedPoints(List<Point2> input) {
    final result = <Point2>[];
    for (final point in input) {
      if (result.isNotEmpty && result.last.coincidesWith(point)) continue;
      result.add(point);
    }
    // The caller may or may not have repeated the first point at the end.
    while (result.length > 1 && result.first.coincidesWith(result.last)) {
      result.removeLast();
    }
    return result;
  }

  bool _selfIntersects() {
    final all = edges;
    for (var i = 0; i < all.length; i++) {
      for (var j = i + 1; j < all.length; j++) {
        final adjacent = j == i + 1 || (i == 0 && j == all.length - 1);
        if (adjacent) continue;
        if (_segmentsCross(all[i], all[j])) return true;
      }
    }
    return false;
  }

  static bool _segmentsCross(Edge a, Edge b) {
    double cross(Point2 o, Point2 p, Point2 q) =>
        (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);

    final d1 = cross(a.start, a.end, b.start);
    final d2 = cross(a.start, a.end, b.end);
    final d3 = cross(b.start, b.end, a.start);
    final d4 = cross(b.start, b.end, a.end);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    // Collinear overlap counts as crossing; touching at a shared endpoint does
    // not, and adjacent edges were already excluded by the caller.
    return (d1 == 0 && _isOnSegment(b.start, a.start, a.end)) ||
        (d2 == 0 && _isOnSegment(b.end, a.start, a.end)) ||
        (d3 == 0 && _isOnSegment(a.start, b.start, b.end)) ||
        (d4 == 0 && _isOnSegment(a.end, b.start, b.end));
  }

  static bool _isOnSegment(Point2 point, Point2 start, Point2 end) {
    final cross = (end.x - start.x) * (point.y - start.y) -
        (end.y - start.y) * (point.x - start.x);
    final length = start.distanceTo(end);
    if (length == 0) return point.coincidesWith(start);
    if ((cross / length).abs() > Tolerances.pointCoincidenceMm) return false;
    final dot = (point.x - start.x) * (end.x - start.x) +
        (point.y - start.y) * (end.y - start.y);
    return dot >= -Tolerances.pointCoincidenceMm &&
        dot <= length * length + Tolerances.pointCoincidenceMm;
  }

  @override
  bool operator ==(Object other) {
    if (other is! Polygon || other.vertices.length != vertices.length) {
      return false;
    }
    for (var i = 0; i < vertices.length; i++) {
      if (vertices[i] != other.vertices[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(vertices);

  @override
  String toString() => 'Polygon(${vertices.join(', ')})';

  List<List<double>> toJson() => [for (final v in vertices) v.toJson()];

  static Polygon fromJson(Object? json, {String path = 'polygon'}) {
    if (json is! List) {
      throw FormatException('$path must be a list of points, got $json');
    }
    return Polygon([
      for (var i = 0; i < json.length; i++)
        Point2.fromJson(json[i], path: '$path[$i]'),
    ]);
  }
}
