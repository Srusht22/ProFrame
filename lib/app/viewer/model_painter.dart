import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/geometry/vec2.dart';
import '../../domain/solid/camera.dart';
import '../../domain/solid/shading.dart';
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

  /// How [face] looks: its material under the light, from `Shading.of` —
  /// the one place that decides how glass, panel, frame, metal and rubber
  /// look. Nothing here chooses a colour.
  ///
  /// The light is the same in either appearance: the backdrop darkens with
  /// the app, the design's own finishes do not.
  Shaded shadeOf(ProjectedFacet face) {
    final source = face.source;
    return Shading.of(
      surface: style.usesFinishes
          ? source.surface
          : Shading.clay(source.surface),
      colour: style.usesFinishes ? source.colour : _clay,
      normal: face.normal,
      environment: Environment.daylight,
      side: source.isSide,
    );
  }

  /// The one colour a monochrome view is in.
  static const _clay = 0xFFDCE0DE;

  /// A face, in the three layers `Shaded` describes: what it lets through
  /// multiplies what is behind it, what it shows of itself is laid over,
  /// and what it reflects is added.
  void _face(Canvas canvas, Path path, ProjectedFacet face) {
    final shaded = shadeOf(face);
    if (shaded.filter case final filter?) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.multiply
          ..color = Color(filter),
      );
    }
    if (shaded.opacity > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Color(shaded.colour).withValues(alpha: shaded.opacity),
      );
    }
    if (shaded.reflection case final reflection?) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.plus
          ..color = Color(reflection),
      );
    }
  }

  /// A face's edges, as its material shows them: hard and dark on an
  /// extrusion or a metal, barely there on glass, which is seen through.
  void _edges(Canvas canvas, Path path, ProjectedFacet face) {
    if (style == DisplayStyle.wireframe) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          // A wireframe has no faces; its edges are read against the
          // backdrop.
          ..color = palette.ink.withValues(alpha: 0.5),
      );
      return;
    }
    final darkness = face.source.surface.edge.darkness;
    final own = Color(shadeOf(face).colour);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        // Edges between faces are dark in either appearance, because the
        // faces are the design's own colours.
        ..color = Color.lerp(own, palette.modelEdge, darkness)!
            .withValues(alpha: 0.35 + 0.45 * darkness),
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
