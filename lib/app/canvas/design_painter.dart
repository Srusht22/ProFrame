import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/dimensions/units.dart';
import '../../domain/geometry/polygon.dart';
import '../../domain/geometry/segment.dart';
import '../../domain/geometry/vec2.dart';
import '../../domain/hardware/opening_hardware.dart';
import '../../domain/model/design.dart';
import '../../domain/model/elements.dart';
import '../theme/app_theme.dart';
import 'view_transform.dart';

/// Draws the design, and the user's own ink underneath it.
///
/// **What is drawn on the design is drawn in the design's colours; what is
/// drawn on the sheet is drawn in the sheet's.** The frame's edges, the bars'
/// outlines and an opening's triangle lie over the finishes the user chose
/// — usually light — so they keep the house green in either appearance. A
/// figure, a note, an arrow and ink with nothing built under it lie on the
/// sheet, and follow the [palette].
///
/// The ink is never thrown away and never hidden without the user asking,
/// so they can always see their drawing and what was made of it in the same
/// place, and judge for themselves whether it matches.
class DesignPainter extends CustomPainter {
  final Design design;
  final ViewTransform view;
  final String? selectedId;
  final bool showSketch;
  final bool showGeometry;

  /// The stroke being drawn right now, before it is committed.
  final List<Vec2> liveStroke;
  final int liveColour;

  /// Ids to draw attention to — what a question is asking about.
  final Set<String> highlighted;

  /// The colours of the appearance in effect.
  final Palette palette;

  const DesignPainter({
    required this.design,
    required this.view,
    this.selectedId,
    this.showSketch = true,
    this.showGeometry = true,
    this.liveStroke = const [],
    this.liveColour = 0xFF013E37,
    this.highlighted = const {},
    this.palette = Palette.light,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGeometry) {
      _paintSections(canvas);
      _paintFrame(canvas);
      _paintDividers(canvas);
      _paintOpenings(canvas);
      _paintHardware(canvas);
    }
    if (showSketch) _paintSketch(canvas);
    _paintDimensions(canvas);
    _paintArrows(canvas);
    _paintTexts(canvas);
    _paintLive(canvas);
    if (showGeometry) _paintSelection(canvas);
  }

  // ------------------------------------------------------------- geometry

  void _paintSections(Canvas canvas) {
    for (final section in design.sections) {
      final path = view.pathOf(section.outline);
      final colour = Color(section.finish.colour);
      final glazing = section.finish.material.isGlazing;

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..shader = ui.Gradient.linear(
            view.toScreen(section.outline.topLeft),
            view.toScreen(
              Vec2(section.outline.right, section.outline.bottom),
            ),
            glazing
                ? [
                    Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.55), colour),
                    colour,
                  ]
                : [
                    Color.alphaBlend(
                        Colors.white.withValues(alpha: 0.18), colour),
                    colour,
                  ],
          ),
      );

      if (glazing) {
        // The diagonal flash that says glass on a drawing, inside the pane
        // and nowhere else.
        canvas.save();
        canvas.clipPath(path);
        final from = view.toScreen(section.outline.topLeft);
        final across = view.lengthToScreen(section.widthMm);
        final down = view.lengthToScreen(section.heightMm);
        canvas.drawLine(
          from + Offset(across * 0.12, down),
          from + Offset(across * 0.62, 0),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.4)
            ..strokeWidth = math.max(1, across * 0.05),
        );
        canvas.restore();
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppTheme.hairline,
      );
    }
  }

  void _paintFrame(Canvas canvas) {
    final frame = design.frame;
    if (frame == null) return;

    final outer = view.pathOf(frame.outline);
    final inner = view.pathOf(frame.innerOutline);
    final ring = Path.combine(PathOperation.difference, outer, inner);

    canvas.drawPath(
      ring,
      Paint()
        ..style = PaintingStyle.fill
        ..color = Color(frame.finish.colour),
    );
    // Edge by edge rather than round the ring, because a side the user
    // left open has no member and so no line.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppTheme.primary.withValues(alpha: 0.75);
    final lines = frame.lines;
    for (final line in [...lines.outside, ...lines.daylight]) {
      canvas.drawLine(view.toScreen(line.a), view.toScreen(line.b), edge);
    }
  }

  void _paintDividers(Canvas canvas) {
    for (final divider in design.dividers) {
      final half = divider.widthMm / 2;
      final side = divider.segment.unit.perpendicular * half;
      final bar = Polygon([
        divider.a + side,
        divider.b + side,
        divider.b - side,
        divider.a - side,
      ]);
      canvas.drawPath(
        view.pathOf(bar),
        Paint()
          ..style = PaintingStyle.fill
          ..color = Color(divider.finish.colour),
      );
      canvas.drawPath(
        view.pathOf(bar),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppTheme.primary.withValues(alpha: 0.7),
      );
    }
  }

  /// The opening symbol: the triangle that points at the hinge, as it is
  /// drawn on a real elevation.
  void _paintOpenings(Canvas canvas) {
    for (final opening in design.openings) {
      final section = design.sectionById(opening.sectionId);
      if (section == null) continue;
      final box = section.outline;
      final edge = opening.mechanism.hingeEdge;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppTheme.primary.withValues(alpha: 0.65);

      if (edge == null) {
        // Sliding and the rest: an arrow the way it goes.
        final middle = view.toScreen(box.centroid);
        final reach = view.lengthToScreen(box.width * 0.3);
        final towards =
            opening.mechanism == OpeningMechanism.slidingLeft ? -1.0 : 1.0;
        canvas.drawLine(
          middle - Offset(reach * towards, 0),
          middle + Offset(reach * towards, 0),
          paint,
        );
        canvas.drawLine(
          middle + Offset(reach * towards, 0),
          middle + Offset(reach * towards * 0.72, -reach * 0.22),
          paint,
        );
        canvas.drawLine(
          middle + Offset(reach * towards, 0),
          middle + Offset(reach * towards * 0.72, reach * 0.22),
          paint,
        );
        continue;
      }

      final (Vec2 hingeA, Vec2 hingeB, Vec2 apex) = switch (edge) {
        OpeningEdge.left => (
            Vec2(box.left, box.top),
            Vec2(box.left, box.bottom),
            Vec2(box.right, (box.top + box.bottom) / 2),
          ),
        OpeningEdge.right => (
            Vec2(box.right, box.top),
            Vec2(box.right, box.bottom),
            Vec2(box.left, (box.top + box.bottom) / 2),
          ),
        OpeningEdge.top => (
            Vec2(box.left, box.top),
            Vec2(box.right, box.top),
            Vec2((box.left + box.right) / 2, box.bottom),
          ),
        OpeningEdge.bottom => (
            Vec2(box.left, box.bottom),
            Vec2(box.right, box.bottom),
            Vec2((box.left + box.right) / 2, box.top),
          ),
      };

      canvas.drawLine(view.toScreen(hingeA), view.toScreen(apex), paint);
      canvas.drawLine(view.toScreen(hingeB), view.toScreen(apex), paint);
    }
  }

  void _paintHardware(Canvas canvas) {
    for (final piece in design.hardware) {
      // **The drawing is of the face you are standing at**, and a piece on
      // the other face is not something you can see from there. A design
      // with a door in it is met from outside, so its hinges are round the
      // back: out of sight here, as they are in the solid. `isConcealed` is
      // the one answer every view reads.
      if (design.isConcealed(piece)) continue;

      // A screen's cassette and a sensor are fixed to the frame, and drawn
      // as the shapes they are — from the same footprint the solid builds.
      final footprint = OpeningHardware.footprintOf(design, piece);
      if (footprint != null) {
        final path = Path()
          ..addPolygon(
            [for (final c in footprint.corners) view.toScreen(c)],
            true,
          );
        canvas.drawPath(path, Paint()..color = Color(piece.finish.colour));
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1
            ..color = AppTheme.ink.withValues(alpha: 0.45),
        );
        continue;
      }
      final at = view.toScreen(piece.at);
      final scale = math.max(design.widthMm, design.heightMm);
      final length = view.lengthToScreen(
        (switch (piece.kind) {
          HardwareKind.lever => scale * 0.07,
          HardwareKind.handle => scale * 0.09,
          HardwareKind.letterplate => scale * 0.22,
          HardwareKind.pull => OpeningHardware.pullLengthOf(design, piece),
          _ => scale * 0.035,
        })
            .clamp(24.0, 420.0),
      );
      // A pull is a slender bar, not a plate: its width is a small part of
      // its length, where a lever's backplate is a good part of it.
      final width = math.max(
        3.0,
        length * (piece.kind == HardwareKind.pull ? 0.06 : 0.26),
      );

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(piece.rotation * math.pi / 180);
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: length,
          height: width,
        ),
        Radius.circular(width / 2),
      );
      canvas.drawRRect(
        body,
        Paint()..color = Color(piece.finish.colour),
      );
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = AppTheme.ink.withValues(alpha: 0.45),
      );
      canvas.restore();
    }
  }

  // ------------------------------------------------------------------ ink

  void _paintSketch(Canvas canvas) {
    for (final stroke in design.sketch.strokes) {
      if (stroke.isEmpty) continue;
      final path = Path();
      final first = view.toScreen(stroke.samples.first.at);
      path.moveTo(first.dx, first.dy);
      for (final sample in stroke.samples.skip(1)) {
        final at = view.toScreen(sample.at);
        path.lineTo(at.dx, at.dy);
      }
      final faded = showGeometry && design.frame != null;
      final colour = Color(stroke.colour);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth =
              math.max(1.2, view.lengthToScreen(stroke.widthMm) * 0.9)
          ..color = faded
              ? _underDesign(colour)
              : palette.legible(colour).withValues(alpha: 0.92),
      );
    }
  }

  /// Ink shown faded under the design read from it. It lies partly over
  /// the design's own fills and partly on the sheet — a mark drawn off the
  /// design is only on the sheet — so it has to be seen against both. On
  /// paper both are light, and it is the ink's own colour, faint. On a dark
  /// sheet the two are opposite, so it is the ink's hue at a middle
  /// lightness, which stands clear of either.
  Color _underDesign(Color colour) {
    if (!palette.isDark) return colour.withValues(alpha: 0.32);
    final hsl = HSLColor.fromColor(colour);
    return hsl
        .withLightness(0.55)
        .withSaturation(math.min(hsl.saturation, 0.45))
        .toColor()
        .withValues(alpha: 0.6);
  }

  void _paintLive(Canvas canvas) {
    if (liveStroke.length < 2) return;
    final path = Path();
    final first = view.toScreen(liveStroke.first);
    path.moveTo(first.dx, first.dy);
    for (final point in liveStroke.skip(1)) {
      final at = view.toScreen(point);
      path.lineTo(at.dx, at.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3
        ..color = palette.legible(Color(liveColour)),
    );
  }

  // ---------------------------------------------------------- annotation

  void _paintDimensions(Canvas canvas) {
    for (final dimension in design.dimensions) {
      final line = Segment(dimension.a, dimension.b);
      if (line.length < 1e-6) continue;
      final off = line.unit.perpendicular * dimension.offsetMm;
      final from = view.toScreen(dimension.a + off);
      final to = view.toScreen(dimension.b + off);

      final paint = Paint()
        ..strokeWidth = 1.3
        ..color = palette.muted;
      canvas.drawLine(from, to, paint);

      final tick = to - from;
      final length = tick.distance;
      if (length > 1) {
        final unit = tick / length;
        final across = Offset(-unit.dy, unit.dx) * 5;
        canvas.drawLine(from - across, from + across, paint);
        canvas.drawLine(to - across, to + across, paint);
      }

      _label(
        canvas,
        // Centimetres, like every other figure the user sees. The geometry
        // is millimetres and this is a figure, so it goes through Units.
        Units.label(dimension.valueMm),
        Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
        emphasis: dimension.isStated,
      );
    }
  }

  void _paintArrows(Canvas canvas) {
    for (final arrow in design.arrows) {
      final from = view.toScreen(arrow.from);
      final to = view.toScreen(arrow.to);
      final paint = Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = palette.legible(Color(arrow.colour));
      canvas.drawLine(from, to, paint);

      final delta = to - from;
      final length = delta.distance;
      if (length < 1) continue;
      final unit = delta / length;
      final across = Offset(-unit.dy, unit.dx);
      final head = math.min(14.0, length * 0.3);
      canvas.drawLine(to, to - unit * head + across * head * 0.45, paint);
      canvas.drawLine(to, to - unit * head - across * head * 0.45, paint);
    }
  }

  void _paintTexts(Canvas canvas) {
    for (final text in design.texts) {
      // At the sheet's size, with no floor: see `ViewTransform.letteringFor`.
      // Below a pixel there is nothing to read and nothing to lay out.
      final size = view.letteringFor(text.sizeMm);
      if (size < 1) continue;
      _label(
        canvas,
        text.text,
        view.toScreen(text.at),
        colour: palette.legible(Color(text.colour)),
        size: size,
        emphasis: true,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    Color? colour,
    double size = 12,
    bool emphasis = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: size,
          height: 1.1,
          fontWeight: emphasis ? FontWeight.w600 : FontWeight.w500,
          color: colour ?? palette.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final box = Rect.fromCenter(
      center: at,
      width: painter.width + 10,
      height: painter.height + 5,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = palette.canvas.withValues(alpha: 0.88),
    );
    painter.paint(canvas, box.center - Offset(painter.width, painter.height) / 2);
  }

  // ------------------------------------------------------------ selection

  void _paintSelection(Canvas canvas) {
    final ids = {...highlighted, ?selectedId};
    for (final id in ids) {
      final element = design.elementById(id);
      if (element == null) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = id == selectedId ? 2.6 : 1.8
        ..color = palette.selection
            .withValues(alpha: id == selectedId ? 1 : 0.6);

      switch (element) {
        case FrameElement():
          canvas.drawPath(view.pathOf(element.outline), paint);
        case SectionElement():
          canvas.drawPath(view.pathOf(element.outline), paint);
        case DividerElement():
          canvas.drawLine(
            view.toScreen(element.a),
            view.toScreen(element.b),
            paint..strokeWidth = math.max(3, view.lengthToScreen(element.widthMm)),
          );
        case HardwareElement():
          canvas.drawCircle(view.toScreen(element.at), 16, paint);
        case DimensionElement():
          canvas.drawLine(
            view.toScreen(element.a),
            view.toScreen(element.b),
            paint,
          );
        case ArrowElement():
          canvas.drawLine(
            view.toScreen(element.from),
            view.toScreen(element.to),
            paint,
          );
        case TextElement():
          canvas.drawCircle(view.toScreen(element.at), 18, paint);
        case FrameMemberElement():
          canvas.drawLine(
            view.toScreen(element.run.a),
            view.toScreen(element.run.b),
            paint,
          );
        case OpeningElement():
          final section = design.sectionById(element.sectionId);
          if (section != null) {
            canvas.drawPath(view.pathOf(section.outline), paint);
          }
      }
    }
  }

  @override
  bool shouldRepaint(DesignPainter old) =>
      old.design != design ||
      old.view.scale != view.scale ||
      old.view.origin != view.origin ||
      old.selectedId != selectedId ||
      old.showSketch != showSketch ||
      old.showGeometry != showGeometry ||
      old.palette != palette ||
      old.liveStroke.length != liveStroke.length ||
      old.highlighted.length != highlighted.length;
}
