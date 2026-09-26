import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/geometry/vec2.dart';
import '../../domain/solid/camera.dart';
import '../theme/app_theme.dart';
import 'display_style.dart';

/// Paints the projected model, far faces first.
///
/// The scale is fixed by the model and the zoom, not by what happens to be
/// on screen. A painter that refits every frame cancels out panning and
/// zooming, and makes the model feel like a picture being resized rather
/// than an object being looked at.
class ModelPainter extends CustomPainter {
  final List<ProjectedFacet> faces;
  final Size size;
  final String? selectedId;

  /// Everything else outlined with the selection.
  ///
  /// An opening is one thing made of several: its sash, the bars drawn in
  /// it, the panes those bars make, its hinges and its handle. Picking it
  /// picks all of that, so all of it is outlined — otherwise the model shows
  /// a sash ring lit up with its own glass and its own panel dark inside it,
  /// which says the opposite of what the design means. The set comes from
  /// the design's own hierarchy; nothing here works out what belongs to what.
  final Set<String> highlighted;

  final DisplayStyle style;
  final bool groundPlane;

  /// The colours of the appearance in effect.
  final Palette palette;

  /// View units across the model. Fixed by the model, not by the zoom and
  /// not by what happens to be on screen.
  final double viewSpan;

  const ModelPainter({
    required this.faces,
    required this.size,
    required this.viewSpan,
    required this.style,
    this.groundPlane = true,
    this.selectedId,
    this.highlighted = const {},
    this.palette = Palette.light,
  });

  /// Pixels per view unit.
  double get _scale {
    final fit = math.min(size.width, size.height);
    if (viewSpan <= 0 || fit <= 0) return 1;
    return fit * 0.92 / viewSpan;
  }

  Offset get _centre => Offset(size.width / 2, size.height / 2);

  Offset _place(Vec2 at) =>
      Offset(_centre.dx + at.x * _scale, _centre.dy + at.y * _scale);

  Path _pathOf(ProjectedFacet face) {
    final path = Path();
    final first = _place(face.corners.first);
    path.moveTo(first.dx, first.dy);
    for (final corner in face.corners.skip(1)) {
      final at = _place(corner);
      path.lineTo(at.dx, at.dy);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _sky(canvas, size);
    if (faces.isEmpty) return;
    if (groundPlane) _ground(canvas, size);

    final lit = {...highlighted, ?selectedId};
    for (final face in faces) {
      final path = _pathOf(face);
      if (style.drawsFaces) _face(canvas, path, face);
      if (style.drawsEdges) _edges(canvas, path, face);
      if (lit.contains(face.elementId)) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = palette.selection,
        );
      }
    }
  }

  void _sky(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          palette.skyTop,
          palette.skyBottom,
        ]),
    );
  }

  /// The floor the thing is standing on, and its shadow.
  ///
  /// A model floating in nothing has no size. A ground line gives it one.
  void _ground(Canvas canvas, Size size) {
    var lowest = -double.infinity;
    var left = double.infinity, right = -double.infinity;
    for (final face in faces) {
      for (final c in face.corners) {
        lowest = math.max(lowest, c.y);
        left = math.min(left, c.x);
        right = math.max(right, c.x);
      }
    }
    if (!lowest.isFinite) return;

    final base = _place(Vec2((left + right) / 2, lowest));
    final width = (right - left) * _scale;

    canvas.drawOval(
      Rect.fromCenter(
        center: base + Offset(width * 0.04, 8),
        width: width * 0.98,
        height: math.max(10, width * 0.1),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: palette.isDark ? 0.35 : 0.13)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 16),
    );

    canvas.drawLine(
      Offset(base.dx - width * 0.85, base.dy + 1),
      Offset(base.dx + width * 0.85, base.dy + 1),
      Paint()
        ..strokeWidth = 1
        ..color = palette.groundLine.withValues(alpha: 0.13),
    );
  }

  void _face(Canvas canvas, Path path, ProjectedFacet face) {
    final base = style.usesFinishes
        ? Color(face.source.colour)
        : const Color(0xFFDCE0DE);
    final lit = Color.from(
      alpha: base.a,
      red: (base.r * face.light).clamp(0.0, 1.0),
      green: (base.g * face.light).clamp(0.0, 1.0),
      blue: (base.b * face.light).clamp(0.0, 1.0),
    );
    final transparency = style.usesFinishes
        ? face.source.transparency
        : face.source.transparency * 0.6;
    final opacity = 1 - transparency;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.fill
        ..color = lit.withValues(alpha: opacity.clamp(0.12, 1.0)),
    );

    // Glass is mostly what it reflects. Without this it is a hole showing the
    // dark inside of the frame, which reads as grey metal rather than a pane.
    if (transparency > 0.2) {
      final bounds = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            bounds.topLeft,
            bounds.bottomRight,
            [
              const Color(0xFFEAF3F8).withValues(alpha: 0.72 * transparency),
              const Color(0xFFBFD4DE).withValues(alpha: 0.34 * transparency),
              const Color(0xFFE8F1F4).withValues(alpha: 0.52 * transparency),
            ],
            const [0, 0.55, 1],
          ),
      );
    }

    if (style.usesFinishes && face.source.gloss > 0.4 && face.light > 0.72) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.white.withValues(
            alpha: (face.source.gloss - 0.4) * 0.3,
          ),
      );
    }
  }

  void _edges(Canvas canvas, Path path, ProjectedFacet face) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style == DisplayStyle.wireframe ? 1.0 : 0.9
        // Edges between faces are dark in either appearance, because the
        // faces are the design's own colours; a wireframe has no faces,
        // and its edges are drawn to be read against the backdrop instead.
        ..color = (style.drawsFaces ? palette.modelEdge : palette.ink)
            .withValues(alpha: style == DisplayStyle.wireframe ? 0.5 : 0.62),
    );
  }

  /// Which part of the design is under [pixel] — the nearest face, since the
  /// list is painted far to near.
  String? elementAt(Offset pixel) {
    for (final face in faces.reversed) {
      if (_pathOf(face).contains(pixel)) return face.elementId;
    }
    return null;
  }

  /// How many millimetres of model one pixel covers, for turning a drag into
  /// a pan.
  double get millimetresPerPixel => _scale <= 0 ? 1 : 1 / _scale;

  @override
  bool shouldRepaint(ModelPainter old) =>
      old.faces.length != faces.length ||
      old.selectedId != selectedId ||
      old.highlighted.length != highlighted.length ||
      old.size != size ||
      old.style != style ||
      old.groundPlane != groundPlane ||
      old.palette != palette ||
      old.viewSpan != viewSpan ||
      (faces.isNotEmpty &&
          old.faces.isNotEmpty &&
          (old.faces.first.depth != faces.first.depth ||
              old.faces.first.corners.first.x != faces.first.corners.first.x ||
              old.faces.first.corners.first.y != faces.first.corners.first.y));
}
