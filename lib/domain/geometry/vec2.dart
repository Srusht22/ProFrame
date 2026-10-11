import 'dart:math' as math;

/// A point or a vector in millimetres.
///
/// Millimetres, everywhere, always. The screen has pixels and the drawing has
/// millimetres, and the two only meet in one place — the canvas transform —
/// so nothing in the design can ever depend on how big somebody's screen is.
class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double factor) => Vec2(x * factor, y * factor);
  Vec2 operator /(double factor) => Vec2(x / factor, y / factor);
  Vec2 operator -() => Vec2(-x, -y);

  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  Vec2 get normalised {
    final l = length;
    return l == 0 ? zero : Vec2(x / l, y / l);
  }

  /// Turned a quarter turn. Used for the thickness of a bar: a line's own
  /// direction says where it runs, its normal says how wide it is.
  Vec2 get perpendicular => Vec2(-y, x);

  double dot(Vec2 other) => x * other.x + y * other.y;

  /// Positive when [other] turns anticlockwise from this one. The sign is
  /// what orders edges around a vertex, which is what finds the sections.
  double cross(Vec2 other) => x * other.y - y * other.x;

  double distanceTo(Vec2 other) => (this - other).length;
  double distanceSquaredTo(Vec2 other) => (this - other).lengthSquared;

  /// The angle of this vector, in radians, measured the usual way.
  double get angle => math.atan2(y, x);

  Vec2 lerp(Vec2 other, double t) =>
      Vec2(x + (other.x - x) * t, y + (other.y - y) * t);

  Vec2 rounded({double toMm = 1}) =>
      Vec2((x / toMm).roundToDouble() * toMm, (y / toMm).roundToDouble() * toMm);

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  static Vec2 fromJson(Object? json) {
    if (json is! Map) throw const FormatException('A point must be an object');
    final x = json['x'];
    final y = json['y'];
    if (x is! num || y is! num) {
      throw const FormatException('A point needs an x and a y');
    }
    return Vec2(x.toDouble(), y.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}
