/// A point in the product's own 3D space, in millimetres.
///
/// - **x** runs across the elevation, left to right.
/// - **y** runs down the elevation, top to bottom — the same sense as the 2D
///   model, so a panel's rectangle needs no flipping to become a face.
/// - **z** runs into the wall: 0 is the outside face of the frame, positive is
///   inward (towards the room).
///
/// Nothing here knows about pixels or about any projection; that is
/// [IsometricProjection]'s job, which is what lets a real 3D engine consume
/// exactly this and draw it differently.
class Point3 {
  final double x;
  final double y;
  final double z;

  const Point3(this.x, this.y, this.z);

  static const Point3 origin = Point3(0, 0, 0);

  Point3 operator +(Point3 other) =>
      Point3(x + other.x, y + other.y, z + other.z);

  Point3 operator -(Point3 other) =>
      Point3(x - other.x, y - other.y, z - other.z);

  Point3 translated({double dx = 0, double dy = 0, double dz = 0}) =>
      Point3(x + dx, y + dy, z + dz);

  @override
  bool operator ==(Object other) =>
      other is Point3 &&
      (other.x - x).abs() < 1e-9 &&
      (other.y - y).abs() < 1e-9 &&
      (other.z - z).abs() < 1e-9;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, '
      '${z.toStringAsFixed(1)})';
}
