import 'package:flutter/material.dart';

/// The conventions a technical drawing is drawn to.
///
/// Line weight carries meaning on a drawing: the heaviest line is what the
/// section is cut through, the lightest is annotation. Keeping them in one
/// place is what stops a drawing turning into a picture.
abstract final class Cad {
  /// Paper.
  static const Color sheet = Color(0xFFFDFDFB);
  static const Color border = Color(0xFFCBD2CF);

  /// The drawing itself.
  static const Color heavy = Color(0xFF0B1512);
  static const Color medium = Color(0xFF243330);
  static const Color light = Color(0xFF5E6D68);

  /// Annotation.
  static const Color dimension = Color(0xFF9A6B13);
  static const Color hidden = Color(0xFF8A9793);

  /// Materials, as a drawing shows them rather than as they look.
  static const Color glass = Color(0xFFE9F1F4);
  static const Color glassLine = Color(0xFF9FB9C2);
  static const Color hatch = Color(0xFF9AA5A1);

  static const Color grid = Color(0xFFE6EBE8);
  static const Color gridStrong = Color(0xFFD3DBD7);

  static const Color selection = Color(0xFFB8860B);
  static const Color grip = Color(0xFF013E37);
  static const Color snap = Color(0xFF0E7C6B);

  /// Line weights in pixels, at any zoom: a drawing's line weights do not
  /// change when you look closer at it.
  static const double outline = 2.0;
  static const double profile = 1.4;
  static const double bar = 1.3;
  static const double detail = 0.9;
  static const double annotation = 0.8;
  static const double hairline = 0.6;

  static const double textSize = 11.5;
  static const double smallTextSize = 10;

  /// How far the first row of dimensions sits outside the drawing, and the
  /// step out to each row after it, in pixels.
  static const double dimensionGap = 46;
  static const double dimensionStep = 34;

  /// The gap between the geometry and the start of its witness line, so the
  /// dimension never touches what it measures.
  static const double witnessGap = 5;

  /// How far the witness line runs past the dimension line.
  static const double witnessOvershoot = 6;

  static Paint stroke(Color colour, double width, {bool round = false}) =>
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = colour
        ..strokeCap = round ? StrokeCap.round : StrokeCap.butt;

  static Paint fill(Color colour) =>
      Paint()
        ..style = PaintingStyle.fill
        ..color = colour;

  /// A dashed version of a path, for the lines a drawing shows as hidden:
  /// an opening's swing, a centre line, anything behind something else.
  static Path dashed(
    Path source, {
    double dash = 7,
    double gap = 4.5,
  }) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var at = 0.0;
      while (at < metric.length) {
        final next = at + dash;
        out.addPath(
          metric.extractPath(at, next.clamp(0, metric.length)),
          Offset.zero,
        );
        at = next + gap;
      }
    }
    return out;
  }

  static TextPainter label(
    String text, {
    Color colour = heavy,
    double size = textSize,
    FontWeight weight = FontWeight.w500,
  }) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Noto Sans',
            fontSize: size,
            height: 1.1,
            fontWeight: weight,
            color: colour,
            letterSpacing: 0.2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
}
