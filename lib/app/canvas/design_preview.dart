import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/geometry/polygon.dart';
import '../../domain/model/design.dart';
import '../theme/app_theme.dart';
import 'cad_layers.dart';
import 'cad_painter.dart';
import 'cad_style.dart';
import 'view_transform.dart';

/// A small picture of a saved design, for finding it again among many.
///
/// **It is the design, drawn.** A design that has been read is drawn by the
/// same `CadPainter` as the technical drawing — the frame, the bars, the
/// panes and the openings exactly as they are in the document — with the
/// figures, the grid and the handles left off, because at this size they
/// are noise. A design not read yet is its own sketch, the user's strokes
/// as they drew them. Nothing here is ever a picture of a door or a window
/// in general: a design with nothing drawn in it says so.
class DesignPreview extends StatelessWidget {
  final Design design;

  const DesignPreview({super.key, required this.design});

  /// True when the design has anything to draw.
  static bool shows(Design design) =>
      design.frame != null ||
      design.sketch.strokes.any((stroke) => !stroke.isEmpty);

  @override
  Widget build(BuildContext context) {
    if (!shows(design)) {
      return const ColoredBox(
        color: Cad.sheet,
        child: Center(
          child: Text(
            'Nothing drawn yet',
            style: TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
        ),
      );
    }
    return CustomPaint(
      painter: DesignPreviewPainter(design),
      child: const SizedBox.expand(),
    );
  }
}

/// Paints [design] fitted to the space it is given.
class DesignPreviewPainter extends CustomPainter {
  final Design design;

  const DesignPreviewPainter(this.design);

  /// The drawing's layers for a preview: the design itself, and nothing
  /// that is there to work on it with.
  static const layers = CadLayers(
    grid: false,
    dimensions: false,
    annotations: false,
    grips: false,
    snap: false,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Cad.fill(Cad.sheet));
    if (design.frame != null) {
      final view = ViewTransform.fit(design.bounds, size, marginFraction: 0.12);
      CadPainter(
        design: design,
        view: view,
        layers: layers,
      ).paint(canvas, size);
      return;
    }
    _sketch(canvas, size);
  }

  /// The strokes the user drew, where nothing has been read from them yet.
  void _sketch(Canvas canvas, Size size) {
    final strokes = [
      for (final stroke in design.sketch.strokes)
        if (!stroke.isEmpty) stroke,
    ];
    if (strokes.isEmpty) return;
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final stroke in strokes) {
      for (final point in stroke.points) {
        left = math.min(left, point.x);
        top = math.min(top, point.y);
        right = math.max(right, point.x);
        bottom = math.max(bottom, point.y);
      }
    }
    final view = ViewTransform.fit(
      Polygon.rect(left, top, right, bottom),
      size,
      marginFraction: 0.12,
    );
    final ink = Cad.stroke(AppTheme.drawnInk, 1.3, round: true);
    for (final stroke in strokes) {
      final path = Path();
      final first = view.toScreen(stroke.start);
      path.moveTo(first.dx, first.dy);
      for (final point in stroke.points.skip(1)) {
        final at = view.toScreen(point);
        path.lineTo(at.dx, at.dy);
      }
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(DesignPreviewPainter old) =>
      old.design.id != design.id || old.design.updatedAt != design.updatedAt;
}
