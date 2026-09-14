import 'dart:math' as math;
import 'dart:ui';

import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/vec2.dart';

/// Between millimetres on the sheet and pixels on the screen.
///
/// One object does both directions, and the painter and the hit-test both
/// use this one. Painting through one transform and hit-testing through
/// another is the bug where everything looks right and nothing can be
/// tapped.
class ViewTransform {
  /// Pixels per millimetre.
  final double scale;

  /// Where the sheet origin lands on screen, in pixels.
  final Offset origin;

  const ViewTransform({required this.scale, required this.origin});

  /// A view that fits [content] into [size] with a margin.
  factory ViewTransform.fit(
    Polygon? content,
    Size size, {
    double marginFraction = 0.1,
    double fallbackWidthMm = 2000,
  }) {
    final width = (content?.width ?? fallbackWidthMm).clamp(1.0, 1e9);
    final height =
        (content?.height ?? fallbackWidthMm * 1.2).clamp(1.0, 1e9);
    final usable = Size(
      math.max(size.width * (1 - marginFraction * 2), 1),
      math.max(size.height * (1 - marginFraction * 2), 1),
    );
    final scale = math.min(usable.width / width, usable.height / height);
    final left = content?.left ?? 0;
    final top = content?.top ?? 0;
    return ViewTransform(
      scale: scale,
      origin: Offset(
        size.width / 2 - (left + width / 2) * scale,
        size.height / 2 - (top + height / 2) * scale,
      ),
    );
  }

  Offset toScreen(Vec2 point) =>
      Offset(origin.dx + point.x * scale, origin.dy + point.y * scale);

  Vec2 toSheet(Offset pixel) => Vec2(
        (pixel.dx - origin.dx) / scale,
        (pixel.dy - origin.dy) / scale,
      );

  /// A length in millimetres, in pixels.
  double lengthToScreen(double mm) => mm * scale;

  /// A length in pixels, in millimetres. Used for tap tolerances, so that
  /// how near the user has to tap is the same on screen whatever the zoom.
  double lengthToSheet(double pixels) => pixels / scale;

  ViewTransform zoomed(double by, Offset about) {
    final next = (scale * by).clamp(1e-4, 1e3);
    final factor = next / scale;
    return ViewTransform(
      scale: next,
      origin: Offset(
        about.dx - (about.dx - origin.dx) * factor,
        about.dy - (about.dy - origin.dy) * factor,
      ),
    );
  }

  ViewTransform panned(Offset by) =>
      ViewTransform(scale: scale, origin: origin + by);

  Path pathOf(Polygon polygon) {
    final path = Path();
    if (polygon.corners.isEmpty) return path;
    path.moveTo(
      toScreen(polygon.corners.first).dx,
      toScreen(polygon.corners.first).dy,
    );
    for (final corner in polygon.corners.skip(1)) {
      final at = toScreen(corner);
      path.lineTo(at.dx, at.dy);
    }
    path.close();
    return path;
  }
}
