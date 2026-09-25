import 'dart:math' as math;

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

  /// The colours above, together: the drawing on paper.
  static const CadColours paper = CadColours(
    sheet: sheet,
    border: border,
    heavy: heavy,
    medium: medium,
    light: light,
    dimension: dimension,
    hidden: hidden,
    glass: glass,
    glassLine: glassLine,
    hatch: hatch,
    grid: grid,
    gridStrong: gridStrong,
    selection: selection,
    grip: grip,
    snap: snap,
  );

  /// The same drawing on a dark sheet, for the dark appearance.
  ///
  /// Every colour keeps its meaning and its rank: the heaviest line is
  /// still the one that stands out most and annotation still the one that
  /// stands out least, now light on dark rather than dark on light. Each is
  /// chosen to be read against [CadColours.sheet] rather than inverted, so
  /// nothing that carried meaning on paper fades into the sheet here — the
  /// faintest line on the drawing, the hatch, is still well clear of it.
  static const CadColours night = CadColours(
    sheet: Color(0xFF141C1A),
    border: Color(0xFF34413D),
    heavy: Color(0xFFE8EFEC),
    medium: Color(0xFFC2CEC9),
    light: Color(0xFF93A39E),
    dimension: Color(0xFFE0B35A),
    hidden: Color(0xFF7E8E89),
    glass: Color(0xFF1D2C31),
    glassLine: Color(0xFF6E97A4),
    hatch: Color(0xFF6D7B77),
    grid: Color(0xFF1C2523),
    gridStrong: Color(0xFF26322F),
    selection: Color(0xFFE8B84A),
    grip: Color(0xFF7FD3C2),
    snap: Color(0xFF4FD0B3),
  );

  /// Line weights in pixels, at any zoom: a drawing's line weights do not
  /// change when you look closer at it.
  static const double outline = 2.0;
  static const double profile = 1.4;
  static const double bar = 1.3;

  /// A bar drawn inside a section — a glazing bar within a sash or a light,
  /// which is a smaller member than the mullion beside it and is drawn as
  /// one. The weight is how a reader tells the two apart.
  static const double glazingBar = 1.0;
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

  static Paint fill(Color colour) => Paint()
    ..style = PaintingStyle.fill
    ..color = colour;

  /// A dashed version of a path, for the lines a drawing shows as hidden:
  /// an opening's swing, a centre line, anything behind something else.
  static Path dashed(Path source, {double dash = 7, double gap = 4.5}) {
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
  }) => TextPainter(
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

/// The colours a technical drawing is drawn in, as one set: [Cad.paper] on
/// a light sheet and [Cad.night] on a dark one. A painter is handed one and
/// draws everything in it, so the two appearances are the same drawing with
/// the same weights and nothing else.
@immutable
class CadColours {
  /// Paper.
  final Color sheet;
  final Color border;

  /// The drawing itself.
  final Color heavy;
  final Color medium;
  final Color light;

  /// Annotation.
  final Color dimension;
  final Color hidden;

  /// Materials, as a drawing shows them rather than as they look.
  final Color glass;
  final Color glassLine;
  final Color hatch;

  final Color grid;
  final Color gridStrong;

  final Color selection;
  final Color grip;
  final Color snap;

  const CadColours({
    required this.sheet,
    required this.border,
    required this.heavy,
    required this.medium,
    required this.light,
    required this.dimension,
    required this.hidden,
    required this.glass,
    required this.glassLine,
    required this.hatch,
    required this.grid,
    required this.gridStrong,
    required this.selection,
    required this.grip,
    required this.snap,
  });

  /// Whether this is a dark sheet.
  bool get isDark => sheet.computeLuminance() < 0.2;

  /// [colour] as it should be drawn on this sheet: exactly itself wherever
  /// it can be read there, and otherwise the same hue at the opposite
  /// lightness. See [legibleOn].
  Color legible(Color colour) => legibleOn(sheet, colour);
}

/// [colour] as it has to be drawn on [ground] to be seen.
///
/// The user's own ink, notes and arrows keep the colour they were made in,
/// and on paper that is always exactly what is drawn — the light appearance
/// is untouched by this. On a dark sheet a pen colour chosen on white — the
/// house green, black — would all but vanish, so where [colour] is too
/// close to [ground] to read it is drawn at the mirrored lightness, keeping
/// its hue: dark green ink shows as pale green, black as near white. Only
/// how it is shown changes; the design keeps the colour it was given.
Color legibleOn(Color ground, Color colour) {
  if (ground.computeLuminance() >= 0.2) return colour;
  if (_contrast(ground, colour) >= 3) return colour;
  final hsl = HSLColor.fromColor(colour);
  // Light enough to read, and softened, so a vivid ink does not glare.
  return hsl
      .withLightness((1 - hsl.lightness).clamp(0.7, 0.84))
      .withSaturation(math.min(hsl.saturation, 0.6))
      .toColor()
      .withValues(alpha: colour.a);
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}
