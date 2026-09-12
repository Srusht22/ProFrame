import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/rendering/isometric_projection.dart';
import '../../domain/rendering/point3.dart';
import '../../domain/rendering/scene.dart';
import 'surface_shading.dart';

/// Maps a projected scene into the viewport, and back again for hit testing.
///
/// Kept as its own value so the painter and the gesture handler use exactly
/// the same transform — a tap can never land on a different panel from the one
/// under the finger.
@immutable
class SceneViewport {
  final IsometricProjection projection;
  final double scale;
  final Offset origin;

  const SceneViewport({
    required this.projection,
    required this.scale,
    required this.origin,
  });

  /// Fits [scene] into [size], leaving a margin for sashes to swing into.
  factory SceneViewport.fit(
    RenderScene scene,
    Size size, {
    IsometricProjection projection = const IsometricProjection(),
    double zoom = 1,
    Offset pan = Offset.zero,
  }) {
    if (scene.extent.isEmpty || size.isEmpty) {
      return SceneViewport(
        projection: projection,
        scale: 1,
        origin: Offset.zero,
      );
    }

    final (left, top, right, bottom) = projection.projectedBounds(scene.extent);
    final width = (right - left).abs();
    final height = (bottom - top).abs();
    if (width <= 0 || height <= 0) {
      return SceneViewport(projection: projection, scale: 1, origin: Offset.zero);
    }

    const margin = AppViewerMetrics.viewportMargin;
    final fit = <double>[
      size.width * (1 - margin * 2) / width,
      size.height * (1 - margin * 2) / height,
    ].reduce((a, b) => a < b ? a : b);
    final scale = fit * zoom;

    return SceneViewport(
      projection: projection,
      scale: scale,
      origin: Offset(
            (size.width - width * scale) / 2 - left * scale,
            (size.height - height * scale) / 2 - top * scale,
          ) +
          pan,
    );
  }

  Offset toPixels(Point3 point) {
    final projected = projection.project(point);
    return Offset(
      origin.dx + projected.x * scale,
      origin.dy + projected.y * scale,
    );
  }

  Path pathOf(List<Point3> corners) {
    final path = Path();
    for (var i = 0; i < corners.length; i++) {
      final pixel = toPixels(corners[i]);
      if (i == 0) {
        path.moveTo(pixel.dx, pixel.dy);
      } else {
        path.lineTo(pixel.dx, pixel.dy);
      }
    }
    return path..close();
  }

  @override
  bool operator ==(Object other) =>
      other is SceneViewport &&
      other.scale == scale &&
      other.origin == origin &&
      other.projection.depthAngleDegrees == projection.depthAngleDegrees &&
      other.projection.depthScale == projection.depthScale;

  @override
  int get hashCode => Object.hash(
        scale,
        origin,
        projection.depthAngleDegrees,
        projection.depthScale,
      );

  /// The panel under [pixels], nearest first, or null.
  ///
  /// Walks the faces in reverse so the thing drawn last — the thing on top —
  /// is the thing that answers a tap.
  String? panelAt(RenderScene scene, Offset pixels) {
    for (final face in scene.faces.reversed) {
      final panelId = face.panelId;
      if (panelId == null) continue;
      if (pathOf(face.corners).contains(pixels)) return panelId;
    }
    return null;
  }
}

/// Draws a [RenderScene].
///
/// Knows nothing about doors and windows: it draws faces and lines by their
/// [PartRole], which is what lets the whole product model change without this
/// file being touched.
class ScenePainter extends CustomPainter {
  final RenderScene scene;
  final SceneViewport viewport;

  /// Tones derived from the product finish the user chose.
  final SurfaceShading shading;

  /// Theme colours, passed in so the painter never reaches for a context.
  final Color glassColor;
  final Color glassHighlight;
  final Color glyphColor;
  final Color meshColor;
  final Color noteMarkerColor;
  final Color noteMarkerInk;

  const ScenePainter({
    required this.scene,
    required this.viewport,
    required this.shading,
    required this.glassColor,
    required this.glassHighlight,
    required this.glyphColor,
    required this.meshColor,
    required this.noteMarkerColor,
    required this.noteMarkerInk,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in scene.faces) {
      _paintFace(canvas, face);
    }
    for (final line in scene.lines) {
      _paintLine(canvas, line);
    }
  }

  void _paintFace(Canvas canvas, SceneFace face) {
    final path = viewport.pathOf(face.corners);

    switch (face.role) {
      case PartRole.frame:
      case PartRole.divider:
      case PartRole.sash:
        canvas.drawPath(path, Paint()..color = shading.forFace(face.kind));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppViewerMetrics.surfaceEdge
            ..color = shading.edge,
        );

      case PartRole.glass:
        // A shallow gradient across the pane reads as a reflection without
        // pretending to be a real one.
        final bounds = path.getBounds();
        canvas.drawPath(
          path,
          Paint()
            // The colour is set as well as the shader: a Paint carrying only
            // a shader reports black, so a pane would render black rather
            // than as glass if the gradient ever failed to apply.
            ..color = glassColor
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [glassHighlight, glassColor],
            ).createShader(bounds),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppViewerMetrics.surfaceEdge
            ..color = shading.edge,
        );

      case PartRole.panel:
        canvas.drawPath(path, Paint()..color = shading.verticalSide);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppViewerMetrics.surfaceEdge
            ..color = shading.edge,
        );

      case PartRole.noteMarker:
        canvas.drawPath(path, Paint()..color = noteMarkerColor);
        final centre = path.getBounds().center;
        _paintText(canvas, '!', centre, noteMarkerInk);

      case PartRole.mesh:
      case PartRole.openingGlyph:
        // Drawn as lines, not faces.
        break;
    }
  }

  void _paintLine(Canvas canvas, SceneLine line) {
    final from = viewport.toPixels(line.from);
    final to = viewport.toPixels(line.to);

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = line.role == PartRole.mesh
          ? AppViewerMetrics.meshWidth
          : AppViewerMetrics.glyphWidth
      ..color = line.role == PartRole.mesh ? meshColor : glyphColor;

    if (line.dashed) {
      _paintDashed(canvas, from, to, paint);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  void _paintDashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final total = (to - from).distance;
    if (total <= 0) return;
    final step = AppViewerMetrics.glyphDash + AppViewerMetrics.glyphGap;
    final direction = (to - from) / total;

    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + AppViewerMetrics.glyphDash).clamp(0.0, total);
      canvas.drawLine(
        from + direction * travelled,
        from + direction * end,
        paint,
      );
      travelled += step;
    }
  }

  void _paintText(Canvas canvas, String text, Offset centre, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(ScenePainter old) =>
      old.scene != scene ||
      old.viewport != viewport ||
      old.shading.base != shading.base;
}
