import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/geometry/point2.dart';
import '../../domain/panel.dart';
import '../../domain/product/infill.dart';
import '../../domain/product/opening.dart';
import 'canvas_projection.dart';
import 'dimension_labels.dart';

/// Draws the design: the frame, its dividers, each panel's state, the
/// dimension lines, and whatever ink has not been read yet.
///
/// Every colour comes from the theme and every size from [AppCanvasMetrics];
/// the painter declares none of its own (spec section 7).
class DesignPainter extends CustomPainter {
  final DesignDocument design;

  /// The stroke currently under the finger, before it is classified.
  final List<Point2> wetInk;

  final String? selectedPanelId;
  final String? selectedDividerId;

  /// Whether note labels are drawn. Hiding them never touches the design.
  final bool notesVisible;

  /// Colours, taken from the theme by the widget so the painter stays free of
  /// context lookups.
  final Color frameColor;
  final Color inkColor;
  final Color glassColor;
  final Color panelFillColor;
  final Color selectionColor;
  final Color labelColor;

  const DesignPainter({
    required this.design,
    required this.wetInk,
    required this.frameColor,
    required this.inkColor,
    required this.glassColor,
    required this.panelFillColor,
    required this.selectionColor,
    required this.labelColor,
    this.selectedPanelId,
    this.selectedDividerId,
    this.notesVisible = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projection = CanvasProjection.fit(size);

    _paintPanels(canvas, projection);
    _paintFrame(canvas, projection);
    _paintDividers(canvas, projection);
    _paintDimensions(canvas, projection);
    _paintWetInk(canvas, projection);
  }

  // -- the product ----------------------------------------------------------

  void _paintPanels(Canvas canvas, CanvasProjection projection) {
    for (final panel in design.panels) {
      final box = panel.boundary;
      final rect = projection.toPixelRect(box.left, box.top, box.right, box.bottom);

      // Empty panels are drawn hollow: no fill at all, which is the difference
      // the user asked to see (فارغ). Glass gets a tint, a solid board gets the
      // opaque panel colour.
      if (!panel.isEmpty) {
        canvas.drawRect(
          rect,
          Paint()
            ..color = panel.infill is SolidPanel ? panelFillColor : glassColor,
        );
      }

      if (panel.id == selectedPanelId) {
        canvas.drawRect(
          rect.deflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = AppCanvasMetrics.selectedDividerWidth
            ..color = selectionColor,
        );
      }

      _paintPanelMarks(canvas, projection, panel, rect);
    }
  }

  /// The marks that say what a panel is: its CH/Z code, the opening symbol,
  /// the mesh hatch and the note dot.
  ///
  /// Every one of them is a shape or a word, never a colour on its own
  /// (spec section 7, accessibility).
  void _paintPanelMarks(
    Canvas canvas,
    CanvasProjection projection,
    Panel panel,
    Rect rect,
  ) {
    // The opening symbol: the chevron the user drew, redrawn cleanly, its
    // point on the hinge edge.
    final opening = panel.opening;
    if (opening != null) {
      final inset = AppCanvasMetrics.openingSymbolInset;
      final apexOnLeft = opening.hingeSide == HingeSide.left;
      final apexX = apexOnLeft ? rect.left + inset : rect.right - inset;
      final backX = apexOnLeft ? rect.right - inset : rect.left + inset;
      final path = Path()
        ..moveTo(backX, rect.top + inset)
        ..lineTo(apexX, rect.center.dy)
        ..lineTo(backX, rect.bottom - inset);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = AppCanvasMetrics.dividerWidth
          ..color = frameColor,
      );
    }

    if (panel.hasMesh) _paintMeshHatch(canvas, rect);

    // The CH / Z code, so the state is readable without interpreting a symbol.
    _paintText(
      canvas,
      panel.behaviour.code,
      rect.center,
      labelColor,
      bold: true,
    );

    // Note labels, each where the user put it inside the panel.
    if (notesVisible) {
      for (final note in panel.visibleNotes) {
        final at = note.clampedPosition;
        final centre = Offset(
          rect.left + rect.width * at.x,
          rect.top + rect.height * at.y,
        );
        _paintText(
          canvas,
          note.text,
          centre,
          frameColor,
          background: panelFillColor,
        );
      }
    }

    // A marker in the corner whenever there is a note, shown or hidden, so a
    // hidden note is never forgotten about.
    if (panel.hasNote) {
      final centre = Offset(
        rect.right - AppCanvasMetrics.noteMarkerRadius - 6,
        rect.top + AppCanvasMetrics.noteMarkerRadius + 6,
      );
      canvas.drawCircle(
        centre,
        AppCanvasMetrics.noteMarkerRadius,
        Paint()..color = panel.visibleNotes.isEmpty
            ? frameColor.withValues(alpha: 0.4)
            : frameColor,
      );
      _paintText(canvas, '!', centre, panelFillColor, bold: true);
    }
  }

  /// A light cross-hatch marking an insect screen (توري).
  void _paintMeshHatch(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..color = frameColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    const step = 10.0;
    canvas.save();
    canvas.clipRect(rect);
    for (var x = rect.left - rect.height; x < rect.right; x += step) {
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x + rect.height, rect.top),
        paint,
      );
    }
    canvas.restore();
  }

  void _paintFrame(Canvas canvas, CanvasProjection projection) {
    final outline = design.outline;
    if (outline == null) return;

    final path = Path();
    for (var i = 0; i < outline.vertices.length; i++) {
      final point = projection.toPixels(outline.vertices[i]);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppCanvasMetrics.frameWidth
        ..strokeJoin = StrokeJoin.miter
        ..color = frameColor,
    );
  }

  void _paintDividers(Canvas canvas, CanvasProjection projection) {
    for (final divider in design.dividers) {
      final selected = divider.id == selectedDividerId;
      canvas.drawLine(
        projection.toPixels(divider.start),
        projection.toPixels(divider.end),
        Paint()
          ..strokeWidth = selected
              ? AppCanvasMetrics.selectedDividerWidth
              : AppCanvasMetrics.dividerWidth
          ..strokeCap = StrokeCap.round
          ..color = selected ? selectionColor : frameColor,
      );
    }
  }

  // -- dimensions -----------------------------------------------------------

  /// Draws the dimension lines laid out by [DimensionLabels].
  ///
  /// The positions come from there rather than being worked out here, so what
  /// is drawn is exactly what the canvas lets the user tap
  /// (spec Phase 2, item 4).
  void _paintDimensions(Canvas canvas, CanvasProjection projection) {
    final unit = design.displayUnit;

    for (final label in DimensionLabels.of(design, projection)) {
      final paint = Paint()
        ..strokeWidth = AppCanvasMetrics.dimensionWidth
        ..color = labelColor;

      canvas.drawLine(label.from, label.to, paint);

      const tick = AppCanvasMetrics.dimensionTick;
      if (label.horizontal) {
        canvas.drawLine(
          label.from.translate(0, -tick),
          label.from.translate(0, tick),
          paint,
        );
        canvas.drawLine(
          label.to.translate(0, -tick),
          label.to.translate(0, tick),
          paint,
        );
      } else {
        canvas.drawLine(
          label.from.translate(-tick, 0),
          label.from.translate(tick, 0),
          paint,
        );
        canvas.drawLine(
          label.to.translate(-tick, 0),
          label.to.translate(tick, 0),
          paint,
        );
      }

      final text = unit.format(label.valueMm);
      _paintText(
        canvas,
        label.confirmed ? text : '($text)',
        label.centre,
        labelColor,
        background: panelFillColor,
      );
    }
  }

  // -- ink ------------------------------------------------------------------

  void _paintWetInk(Canvas canvas, CanvasProjection projection) {
    if (wetInk.length < 2) return;
    final path = Path()
      ..moveTo(
        projection.toPixels(wetInk.first).dx,
        projection.toPixels(wetInk.first).dy,
      );
    for (final point in wetInk.skip(1)) {
      final pixel = projection.toPixels(point);
      path.lineTo(pixel.dx, pixel.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppCanvasMetrics.inkWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = inkColor,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset centre,
    Color color, {
    bool bold = false,
    Color? background,
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

    final offset = centre - Offset(painter.width / 2, painter.height / 2);
    if (background != null) {
      canvas.drawRect(
        Rect.fromLTWH(offset.dx, offset.dy, painter.width, painter.height)
            .inflate(3),
        Paint()..color = background,
      );
    }
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(DesignPainter old) =>
      old.design != design ||
      old.notesVisible != notesVisible ||
      old.wetInk.length != wetInk.length ||
      old.selectedPanelId != selectedPanelId ||
      old.selectedDividerId != selectedDividerId;
}
