import 'dart:math' as math;

import 'mesh.dart';

// The round parts of a solid — a lever, a knob, a hinge's knuckle — are turned
// from rings. These are the rings, worked out in one place, because the
// drawings draw the same parts square on and must draw the same shapes.

/// A ring of [sides] points around [centre], in the plane [u] and [v] span.
///
/// The cross-section of anything round. A lever is not a box and a hinge
/// knuckle is not a box, so neither is built as one; twelve sides is the
/// point where another one stops showing at the size ironmongery is drawn.
List<Vec3> ringAround(
  Vec3 centre,
  Vec3 u,
  Vec3 v,
  double radius, {
  int sides = 12,
}) => [
  for (var i = 0; i < sides; i++)
    () {
      final angle = i / sides * math.pi * 2;
      final c = math.cos(angle) * radius;
      final d = math.sin(angle) * radius;
      return Vec3(
        centre.x + u.x * c + v.x * d,
        centre.y + u.y * c + v.y * d,
        centre.z + u.z * c + v.z * d,
      );
    }(),
];

/// The rings a tube along [path] is turned from, one at each point, of the
/// radius [radii] gives there, each standing square to the way the path goes
/// at that point.
List<List<Vec3>> tubeRings(
  List<Vec3> path,
  List<double> radii, {
  int sides = 10,
}) {
  Vec3 minus(Vec3 a, Vec3 b) => Vec3(a.x - b.x, a.y - b.y, a.z - b.z);
  Vec3 unit(Vec3 v) {
    final len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    return len < 1e-9
        ? const Vec3(0, 0, 1)
        : Vec3(v.x / len, v.y / len, v.z / len);
  }

  Vec3 cross(Vec3 a, Vec3 b) =>
      Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);

  final rings = <List<Vec3>>[];
  for (var i = 0; i < path.length; i++) {
    // The way the path is going here: between its neighbours where it has
    // two, and along the one leg it has at each end.
    final before = i == 0 ? path[0] : path[i - 1];
    final after = i == path.length - 1 ? path[i] : path[i + 1];
    final along = unit(minus(after, before));
    // Any steady reference that is not along the path gives a frame that
    // does not spin as the curve turns.
    final reference = along.z.abs() > 0.9
        ? const Vec3(0, 1, 0)
        : const Vec3(0, 0, 1);
    final u = unit(cross(along, reference));
    final v = cross(along, u);
    rings.add(ringAround(path[i], u, v, radii[i], sides: sides));
  }
  return rings;
}
