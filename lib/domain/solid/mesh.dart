import 'dart:math' as math;

import '../geometry/vec2.dart';

/// A point in space, in millimetres. X across, Y down the elevation, Z out
/// towards the viewer.
class Vec3 {
  final double x;
  final double y;
  final double z;

  const Vec3(this.x, this.y, this.z);

  static const Vec3 zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double f) => Vec3(x * f, y * f, z * f);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 get normalised {
    final l = length;
    return l == 0 ? zero : Vec3(x / l, y / l, z / l);
  }

  Vec2 get flat => Vec2(x, y);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${z.toStringAsFixed(1)})';
}

/// One flat face of the model.
///
/// A face knows which element of the design it came from, so tapping it in
/// the 3D view selects the same part the user would tap in the drawing, and
/// so a colour change on one shows on the other.
class Facet {
  final List<Vec3> corners;

  /// The element this face belongs to.
  final String elementId;

  /// 0xAARRGGBB, as the user set it.
  final int colour;

  /// 0 opaque to 1 clear.
  final double transparency;

  /// 0 matt to 1 mirror.
  final double gloss;

  /// What the face is, for the renderer to treat glass differently from a
  /// frame without having to look the material up again.
  final FacetRole role;

  const Facet({
    required this.corners,
    required this.elementId,
    required this.colour,
    this.transparency = 0,
    this.gloss = 0.3,
    this.role = FacetRole.frame,
  });

  Vec3 get centre {
    var sum = Vec3.zero;
    for (final c in corners) {
      sum = sum + c;
    }
    return sum * (1 / corners.length);
  }

  /// The outward normal, from the first three corners.
  Vec3 get normal {
    if (corners.length < 3) return const Vec3(0, 0, 1);
    return (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalised;
  }
}

enum FacetRole { frame, bar, sash, glazing, panel, hardware }

/// The whole model: every face of it, and where it sits.
class Mesh {
  final List<Facet> facets;

  const Mesh(this.facets);

  static const Mesh empty = Mesh([]);

  bool get isEmpty => facets.isEmpty;

  /// The middle of the model, to turn the view about.
  Vec3 get centre {
    if (facets.isEmpty) return Vec3.zero;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final facet in facets) {
      for (final c in facet.corners) {
        minX = math.min(minX, c.x);
        maxX = math.max(maxX, c.x);
        minY = math.min(minY, c.y);
        maxY = math.max(maxY, c.y);
        minZ = math.min(minZ, c.z);
        maxZ = math.max(maxZ, c.z);
      }
    }
    return Vec3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2);
  }

  /// How big the model is, corner to corner.
  double get span {
    if (facets.isEmpty) return 0;
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    var minZ = double.infinity, maxZ = -double.infinity;
    for (final facet in facets) {
      for (final c in facet.corners) {
        minX = math.min(minX, c.x);
        maxX = math.max(maxX, c.x);
        minY = math.min(minY, c.y);
        maxY = math.max(maxY, c.y);
        minZ = math.min(minZ, c.z);
        maxZ = math.max(maxZ, c.z);
      }
    }
    final w = maxX - minX, h = maxY - minY, d = maxZ - minZ;
    return math.sqrt(w * w + h * h + d * d);
  }
}
