import 'dart:math' as math;

/// Framework-independent 2D vector used by the whole recognition and geometry
/// pipeline, so the domain never depends on `dart:ui`.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double s) => Vec2(x * s, y * s);
  Vec2 operator /(double s) => Vec2(x / s, y / s);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  double distanceTo(Vec2 other) => (this - other).length;

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Z component of the 3D cross product — sign tells which side a point is on.
  double cross(Vec2 other) => x * other.y - y * other.x;

  Vec2 lerp(Vec2 other, double t) => Vec2(x + (other.x - x) * t, y + (other.y - y) * t);

  /// Angle in degrees, measured from the +X axis, normalised to [0, 360).
  double get angleDeg {
    final a = math.atan2(y, x) * 180 / math.pi;
    return a < 0 ? a + 360 : a;
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  factory Vec2.fromJson(Map<String, dynamic> json) =>
      Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  @override
  bool operator ==(Object other) =>
      other is Vec2 && (other.x - x).abs() < 1e-9 && (other.y - y).abs() < 1e-9;

  @override
  int get hashCode => Object.hash((x * 1e6).round(), (y * 1e6).round());

  @override
  String toString() => 'Vec2(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Axis-aligned rectangle in sketch space (y grows downwards, screen style).
class Box2 {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const Box2(this.left, this.top, this.right, this.bottom);

  factory Box2.fromPoints(Iterable<Vec2> points) {
    if (points.isEmpty) return const Box2(0, 0, 0, 0);
    var l = double.infinity, t = double.infinity;
    var r = -double.infinity, b = -double.infinity;
    for (final p in points) {
      if (p.x < l) l = p.x;
      if (p.y < t) t = p.y;
      if (p.x > r) r = p.x;
      if (p.y > b) b = p.y;
    }
    return Box2(l, t, r, b);
  }

  factory Box2.fromCorners(Vec2 a, Vec2 b) => Box2(
        math.min(a.x, b.x),
        math.min(a.y, b.y),
        math.max(a.x, b.x),
        math.max(a.y, b.y),
      );

  double get width => right - left;
  double get height => bottom - top;
  double get area => width * height;
  Vec2 get center => Vec2((left + right) / 2, (top + bottom) / 2);
  Vec2 get topLeft => Vec2(left, top);
  Vec2 get bottomRight => Vec2(right, bottom);

  bool contains(Vec2 p, {double tolerance = 0}) =>
      p.x >= left - tolerance &&
      p.x <= right + tolerance &&
      p.y >= top - tolerance &&
      p.y <= bottom + tolerance;

  Box2 inflate(double amount) =>
      Box2(left - amount, top - amount, right + amount, bottom + amount);

  Box2 union(Box2 other) => Box2(
        math.min(left, other.left),
        math.min(top, other.top),
        math.max(right, other.right),
        math.max(bottom, other.bottom),
      );

  /// Fraction of [other]'s area that lies inside this box.
  double overlapRatio(Box2 other) {
    final l = math.max(left, other.left);
    final t = math.max(top, other.top);
    final r = math.min(right, other.right);
    final b = math.min(bottom, other.bottom);
    if (r <= l || b <= t) return 0;
    final inter = (r - l) * (b - t);
    return other.area == 0 ? 0 : inter / other.area;
  }

  Map<String, dynamic> toJson() =>
      {'left': left, 'top': top, 'right': right, 'bottom': bottom};

  factory Box2.fromJson(Map<String, dynamic> json) => Box2(
        (json['left'] as num).toDouble(),
        (json['top'] as num).toDouble(),
        (json['right'] as num).toDouble(),
        (json['bottom'] as num).toDouble(),
      );

  @override
  String toString() =>
      'Box2(${left.toStringAsFixed(1)}, ${top.toStringAsFixed(1)}, '
      '${right.toStringAsFixed(1)}, ${bottom.toStringAsFixed(1)})';
}

/// Pure geometric helpers shared by recognition, snapping and layout.
class GeometryMath {
  GeometryMath._();

  /// Shortest distance from [p] to the *segment* a-b (not the infinite line).
  static double distanceToSegment(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-12) return p.distanceTo(a);
    var t = ((p - a).dot(ab)) / lenSq;
    t = t.clamp(0.0, 1.0).toDouble();
    return p.distanceTo(a + ab * t);
  }

  /// Perpendicular distance from [p] to the infinite line through a-b.
  static double distanceToLine(Vec2 p, Vec2 a, Vec2 b) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-12) return p.distanceTo(a);
    return ((p - a).cross(ab)).abs() / math.sqrt(lenSq);
  }

  /// Total length walked along a polyline.
  static double pathLength(List<Vec2> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += points[i].distanceTo(points[i - 1]);
    }
    return total;
  }

  /// Smallest absolute difference between two headings, in degrees (0..180).
  static double angleDifference(double a, double b) {
    var d = (a - b).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  /// Angle of a segment folded into [0, 180) — direction-agnostic, which is
  /// what "is this line horizontal or vertical" needs.
  static double undirectedAngleDeg(Vec2 a, Vec2 b) {
    final angle = (b - a).angleDeg;
    return angle >= 180 ? angle - 180 : angle;
  }

  /// Intersection of two infinite lines, or null when parallel.
  static Vec2? lineIntersection(Vec2 a1, Vec2 a2, Vec2 b1, Vec2 b2) {
    final d1 = a2 - a1;
    final d2 = b2 - b1;
    final denom = d1.cross(d2);
    if (denom.abs() < 1e-9) return null;
    final t = (b1 - a1).cross(d2) / denom;
    return a1 + d1 * t;
  }

  /// Ramer–Douglas–Peucker polyline simplification. Keeps corners, drops the
  /// dense sampling noise a finger or stylus produces.
  static List<Vec2> simplify(List<Vec2> points, double epsilon) {
    if (points.length < 3) return List<Vec2>.from(points);
    var maxDistance = 0.0;
    var index = 0;
    for (var i = 1; i < points.length - 1; i++) {
      final d = distanceToLine(points[i], points.first, points.last);
      if (d > maxDistance) {
        maxDistance = d;
        index = i;
      }
    }
    if (maxDistance <= epsilon) return [points.first, points.last];
    final left = simplify(points.sublist(0, index + 1), epsilon);
    final right = simplify(points.sublist(index), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }

  /// Distributes [total] over [ratios] so the parts always sum back to
  /// [total] exactly (no accumulated rounding drift across mullions).
  static List<double> distribute(double total, List<double> ratios) {
    final sum = ratios.fold<double>(0, (a, b) => a + b);
    if (sum <= 0 || ratios.isEmpty) {
      return List<double>.filled(ratios.length, ratios.isEmpty ? 0 : total / ratios.length);
    }
    final result = <double>[];
    var used = 0.0;
    for (var i = 0; i < ratios.length; i++) {
      if (i == ratios.length - 1) {
        result.add(total - used);
      } else {
        final part = total * ratios[i] / sum;
        result.add(part);
        used += part;
      }
    }
    return result;
  }

  /// Rounds to a sane number of decimals for millimetre display.
  static double roundMm(double value, {int decimals = 1}) {
    final factor = math.pow(10, decimals);
    return (value * factor).round() / factor;
  }
}
