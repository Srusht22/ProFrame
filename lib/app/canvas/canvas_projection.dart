import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/geometry/point2.dart';

/// Maps between model millimetres and canvas pixels.
///
/// The drawing sheet is a fixed size **in millimetres**, fitted into whatever
/// space the widget is given. That is what makes the design independent of the
/// screen (spec section 8): the same gesture on a phone and on a desktop
/// produces the same millimetres, and rotating the device changes the scale
/// without touching a single stored coordinate.
@immutable
class CanvasProjection {
  /// The sheet the user draws on, in millimetres. Large enough for a patio
  /// door with room around it, so a first stroke never runs off the edge.
  static const double sheetWidthMm = 3000;
  static const double sheetHeightMm = 2400;

  /// Fraction of the shorter axis left as margin, so dimension labels drawn
  /// outside the frame stay on screen.
  static const double marginFraction = 0.12;

  /// Pixels per millimetre.
  final double scale;

  /// Where model (0, 0) sits in pixels.
  final Offset origin;

  const CanvasProjection({required this.scale, required this.origin});

  /// Fits the sheet into [size], centred, preserving aspect ratio.
  factory CanvasProjection.fit(Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return const CanvasProjection(scale: 1, origin: Offset.zero);
    }
    final usableWidth = size.width * (1 - marginFraction * 2);
    final usableHeight = size.height * (1 - marginFraction * 2);
    final scale = math.min(
      usableWidth / sheetWidthMm,
      usableHeight / sheetHeightMm,
    );
    return CanvasProjection(
      scale: scale,
      origin: Offset(
        (size.width - sheetWidthMm * scale) / 2,
        (size.height - sheetHeightMm * scale) / 2,
      ),
    );
  }

  Offset toPixels(Point2 point) =>
      Offset(origin.dx + point.x * scale, origin.dy + point.y * scale);

  Point2 toModel(Offset pixels) => Point2(
        (pixels.dx - origin.dx) / scale,
        (pixels.dy - origin.dy) / scale,
      );

  /// Converts a length in millimetres to pixels.
  double lengthToPixels(double millimetres) => millimetres * scale;

  /// Converts a length in pixels to millimetres — for hit-test radii, which
  /// are specified as a finger size on screen rather than a size on the
  /// product.
  double lengthToModel(double pixels) => scale == 0 ? 0 : pixels / scale;

  Rect toPixelRect(double left, double top, double right, double bottom) =>
      Rect.fromPoints(
        toPixels(Point2(left, top)),
        toPixels(Point2(right, bottom)),
      );

  @override
  bool operator ==(Object other) =>
      other is CanvasProjection &&
      other.scale == scale &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(scale, origin);
}
