import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/product/opening.dart';
import '../../domain/rendering/front_elevation.dart';

/// What to include in an exported drawing (spec section 11D).
class ElevationOptions {
  final bool showDimensions;
  final bool showNotes;

  /// The CH/Z codes. Always on by default: they are what the drawing is for.
  final bool showCodes;

  const ElevationOptions({
    this.showDimensions = true,
    this.showNotes = true,
    this.showCodes = true,
  });

  ElevationOptions copyWith({
    bool? showDimensions,
    bool? showNotes,
    bool? showCodes,
  }) =>
      ElevationOptions(
        showDimensions: showDimensions ?? this.showDimensions,
        showNotes: showNotes ?? this.showNotes,
        showCodes: showCodes ?? this.showCodes,
      );
}

/// Draws the clean front view — the drawing that goes into a PNG, and the
/// preview the user sees before exporting one.
///
/// Takes its geometry from [FrontElevation], the same source the PDF uses, so
/// the two cannot drift apart (spec section 11).
class ElevationPainter extends CustomPainter {
  final FrontElevation elevation;
  final ElevationOptions options;

  final Color inkColor;
  final Color glassColor;
  final Color mutedColor;
  final Color backgroundColor;

  const ElevationPainter({
    required this.elevation,
    required this.inkColor,
    required this.glassColor,
    required this.mutedColor,
    required this.backgroundColor,
    this.options = const ElevationOptions(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final outline = elevation.outline;
    if (outline.width <= 0 || outline.height <= 0) return;

    // Room for dimensions where they are shown; a tight margin where not.
    final leftGutter = options.showDimensions ? size.width * 0.12 : size.width * 0.05;
    final bottomGutter =
        options.showDimensions ? size.height * 0.14 : size.height * 0.05;
    final usableWidth = size.width - leftGutter - size.width * 0.05;
    final usableHeight = size.height - bottomGutter - size.height * 0.05;
    final scale = math.min(
      usableWidth / outline.width,
      usableHeight / outline.height,
    );

    final originX = leftGutter + (usableWidth - outline.width * scale) / 2;
    final originY = size.height * 0.05 +
        (usableHeight - outline.height * scale) / 2;

    double px(double mm) => originX + (mm - outline.left) * scale;
    double py(double mm) => originY + (mm - outline.top) * scale;

    // Glass.
    for (final panel in elevation.panels) {
      if (panel.isEmpty) continue;
      canvas.drawRect(
        Rect.fromLTRB(
          px(panel.rect.left),
          py(panel.rect.top),
          px(panel.rect.right),
          py(panel.rect.bottom),
        ),
        Paint()..color = glassColor,
      );
    }

    // The outline exactly as drawn — not a rectangle when the top slopes.
    final path = Path();
    for (var i = 0; i < elevation.outlineCorners.length; i++) {
      final (x, y) = elevation.outlineCorners[i];
      if (i == 0) {
        path.moveTo(px(x), py(y));
      } else {
        path.lineTo(px(x), py(y));
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppCanvasMetrics.frameWidth
        ..strokeJoin = StrokeJoin.miter
        ..color = inkColor,
    );

    // Dividers.
    for (final divider in elevation.dividers) {
      canvas.drawRect(
        Rect.fromLTRB(
          px(divider.rect.left),
          py(divider.rect.top),
          px(divider.rect.right),
          py(divider.rect.bottom),
        ),
        Paint()..color = inkColor,
      );
    }

    for (final panel in elevation.panels) {
      final opening = panel.opening;
      if (opening != null) _paintGlyph(canvas, panel, opening, px, py);

      if (options.showCodes) {
        _text(
          canvas,
          panel.code,
          Offset(px(panel.rect.centreX), py(panel.rect.centreY)),
          inkColor,
          bold: true,
        );
      }

      if (options.showNotes) {
        // Inset by a share of the panel rather than a fixed number of pixels,
        // so the reference sits inside its own panel at any scale instead of
        // landing on the divider beside it.
        final width = px(panel.rect.right) - px(panel.rect.left);
        final height = py(panel.rect.bottom) - py(panel.rect.top);
        final inset = math.min(width, height) * 0.09;
        for (var i = 0; i < panel.notes.length; i++) {
          _text(
            canvas,
            '${panel.number}.${i + 1}',
            Offset(
              px(panel.rect.right) - inset,
              py(panel.rect.top) + inset + i * 16,
            ),
            mutedColor,
          );
        }
      }
    }

    if (options.showDimensions) {
      _paintDimensions(canvas, px, py);
    }
  }

  void _paintDimensions(
    Canvas canvas,
    double Function(double) px,
    double Function(double) py,
  ) {
    final paint = Paint()
      ..strokeWidth = AppCanvasMetrics.dimensionWidth
      ..color = mutedColor;
    final outline = elevation.outline;

    for (final dimension in elevation.dimensions) {
      final label = dimension.confirmed
          ? '${dimension.valueMm.round()}'
          : '(${dimension.valueMm.round()})';

      if (dimension.horizontal) {
        final y = py(outline.bottom) +
            AppCanvasMetrics.dimensionOffset * dimension.tier;
        canvas.drawLine(
          Offset(px(dimension.fromMm), y),
          Offset(px(dimension.toMm), y),
          paint,
        );
        _tick(canvas, Offset(px(dimension.fromMm), y), paint, vertical: true);
        _tick(canvas, Offset(px(dimension.toMm), y), paint, vertical: true);
        _text(
          canvas,
          label,
          Offset((px(dimension.fromMm) + px(dimension.toMm)) / 2, y - 9),
          mutedColor,
        );
      } else {
        final x = px(outline.left) - AppCanvasMetrics.dimensionOffset;
        canvas.drawLine(
          Offset(x, py(dimension.fromMm)),
          Offset(x, py(dimension.toMm)),
          paint,
        );
        _tick(canvas, Offset(x, py(dimension.fromMm)), paint, vertical: false);
        _tick(canvas, Offset(x, py(dimension.toMm)), paint, vertical: false);
        _text(
          canvas,
          label,
          Offset(x - 20, (py(dimension.fromMm) + py(dimension.toMm)) / 2),
          mutedColor,
        );
      }
    }
  }

  void _tick(Canvas canvas, Offset at, Paint paint, {required bool vertical}) {
    const t = AppCanvasMetrics.dimensionTick;
    canvas.drawLine(
      vertical ? at.translate(0, -t) : at.translate(-t, 0),
      vertical ? at.translate(0, t) : at.translate(t, 0),
      paint,
    );
  }

  void _paintGlyph(
    Canvas canvas,
    ElevationPanel panel,
    OpeningSpec opening,
    double Function(double) px,
    double Function(double) py,
  ) {
    final rect = Rect.fromLTRB(
      px(panel.rect.left),
      py(panel.rect.top),
      px(panel.rect.right),
      py(panel.rect.bottom),
    ).deflate(10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppCanvasMetrics.dividerWidth
      ..color = inkColor;

    void dash(Offset from, Offset to) {
      final total = (to - from).distance;
      if (total <= 0) return;
      final direction = (to - from) / total;
      var travelled = 0.0;
      while (travelled < total) {
        final end = math.min(travelled + 8, total);
        canvas.drawLine(
          from + direction * travelled,
          from + direction * end,
          paint,
        );
        travelled += 13;
      }
    }

    switch (opening.mechanism) {
      case OpeningMechanism.hinged:
        switch (opening.hingeSide) {
          case HingeSide.left:
            dash(rect.topRight, rect.centerLeft);
            dash(rect.bottomRight, rect.centerLeft);
          case HingeSide.right:
            dash(rect.topLeft, rect.centerRight);
            dash(rect.bottomLeft, rect.centerRight);
          case HingeSide.top:
            dash(rect.bottomLeft, rect.topCenter);
            dash(rect.bottomRight, rect.topCenter);
          case HingeSide.bottom:
            dash(rect.topLeft, rect.bottomCenter);
            dash(rect.topRight, rect.bottomCenter);
        }
      case OpeningMechanism.tilt:
        dash(rect.topLeft, rect.bottomCenter);
        dash(rect.topRight, rect.bottomCenter);
      case OpeningMechanism.slidingLeft:
      case OpeningMechanism.slidingRight:
        dash(rect.centerLeft, rect.centerRight);
        final towardsLeft = opening.mechanism == OpeningMechanism.slidingLeft;
        final tip = towardsLeft ? rect.centerLeft : rect.centerRight;
        final barb = towardsLeft ? 14.0 : -14.0;
        dash(tip, tip.translate(barb, -9));
        dash(tip, tip.translate(barb, 9));
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset centre,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          // Named explicitly: a painter draws outside the widget tree, so it
          // does not inherit the theme's font.
          fontFamily: AppFonts.family,
          fontFamilyFallback: AppFonts.fallback,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(ElevationPainter old) =>
      old.elevation != elevation ||
      old.options.showDimensions != options.showDimensions ||
      old.options.showNotes != options.showNotes ||
      old.options.showCodes != options.showCodes;
}

/// Renders a design's front view to PNG bytes.
///
/// Drawn straight onto a picture rather than screen-grabbed from a widget, so
/// the export is the current design at a chosen size — not whatever happened
/// to be visible, at whatever the device's pixel ratio was (spec section 11:
/// exports reflect the current design, not stale geometry).
Future<Uint8List> renderElevationPng(
  DesignDocument design, {
  ElevationOptions options = const ElevationOptions(),
  int width = 1600,
  int height = 1200,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size(width.toDouble(), height.toDouble());

  ElevationPainter(
    elevation: FrontElevation.of(design),
    options: options,
    inkColor: AppColors.deepGreen,
    glassColor: AppColors.glassTint,
    mutedColor: AppColors.mutedText,
    backgroundColor: AppColors.canvasSurface,
  ).paint(canvas, size);

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();

  if (data == null) {
    throw StateError('The drawing could not be turned into an image.');
  }
  return data.buffer.asUint8List();
}
