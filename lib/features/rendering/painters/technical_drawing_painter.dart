import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/models/opening_model.dart';
import '../../geometry/region_solver.dart';

/// Maps between millimetres on the product and pixels on the canvas.
///
/// The painter and the interactive layer share one projection, so what is drawn
/// and what can be tapped or dragged can never drift apart.
class DrawingProjection {
  final double scale;
  final Offset origin;
  final Size canvasSize;

  const DrawingProjection({
    required this.scale,
    required this.origin,
    required this.canvasSize,
  });

  static const EdgeInsets dimensionedPadding = EdgeInsets.fromLTRB(64, 52, 64, 64);
  static const EdgeInsets plainPadding = EdgeInsets.all(10);

  factory DrawingProjection.fit(
    Size size,
    OpeningModel model, {
    EdgeInsets padding = dimensionedPadding,
  }) {
    final availableWidth = math.max(size.width - padding.horizontal, 1.0);
    final availableHeight = math.max(size.height - padding.vertical, 1.0);
    final scale = math.min(
      availableWidth / math.max(model.widthMm, 1),
      availableHeight / math.max(model.heightMm, 1),
    );
    final drawnWidth = model.widthMm * scale;
    final drawnHeight = model.heightMm * scale;
    return DrawingProjection(
      scale: scale,
      origin: Offset(
        padding.left + (availableWidth - drawnWidth) / 2,
        padding.top + (availableHeight - drawnHeight) / 2,
      ),
      canvasSize: size,
    );
  }

  Offset toCanvas(double xMm, double yMm) =>
      Offset(origin.dx + xMm * scale, origin.dy + yMm * scale);

  Rect rectOf(Box2 box) =>
      Rect.fromPoints(toCanvas(box.left, box.top), toCanvas(box.right, box.bottom));

  /// Canvas pixels back to millimetres — what a tap or a drag means.
  Vec2 toModel(Offset canvasPoint) => Vec2(
        (canvasPoint.dx - origin.dx) / scale,
        (canvasPoint.dy - origin.dy) / scale,
      );

  double toMm(double pixels) => pixels / scale;
}

/// Draws the elevation the way a fabrication drawing looks: profiles as double
/// lines, glass hatched, opening direction with the standard symbols, and the
/// dimensions around the outside.
///
/// It draws whatever the model says, including deliberately unequal sections.
/// Nothing here tidies a design up for presentation.
class TechnicalDrawingPainter extends CustomPainter {
  final OpeningModel model;
  final bool showDimensions;
  final bool showLabels;
  final String? highlightRegionId;

  /// Boundaries the user can drag, drawn as grab handles.
  final bool showHandles;
  final double margin;

  TechnicalDrawingPainter({
    required this.model,
    this.showDimensions = true,
    this.showLabels = true,
    this.highlightRegionId,
    this.showHandles = false,
    this.margin = 0,
  });

  static const Color _ink = AppColors.brandDarkGreen;
  static const Color _thin = Color(0xFF6B7B78);
  static const Color _glass = Color(0xFFD7E6E4);
  static const Color _profile = Color(0xFFF2F1EA);

  DrawingProjection projectionFor(Size size) => DrawingProjection.fit(
        size,
        model,
        padding: margin > 0
            ? EdgeInsets.all(margin)
            : (showDimensions
                ? DrawingProjection.dimensionedPadding
                : DrawingProjection.plainPadding),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final solved = RegionSolver.solve(model);
    final projection = projectionFor(size);
    Rect rectOf(Box2 box) => projection.rectOf(box);

    final profileFill = Paint()..color = _profile;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _ink;
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _thin;

    final outerRect = rectOf(solved.outerRect);
    final innerRect = rectOf(solved.innerRect);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(outerRect),
        Path()..addRect(innerRect),
      ),
      profileFill,
    );
    canvas.drawRect(outerRect, outline);
    canvas.drawRect(innerRect, hairline);

    // Whatever no section claims is structure.
    for (final bar in solved.allBars) {
      final r = rectOf(bar.rect);
      canvas.drawRect(r, profileFill);
      canvas.drawRect(r, hairline);
    }

    for (final region in solved.leaves) {
      _paintRegion(canvas, region, rectOf);
    }
    for (final region in solved.allRegions.where((r) => !r.isLeaf && r.hasSash)) {
      _paintSashOutline(canvas, region, rectOf);
      _paintOperationSymbol(canvas, region, rectOf);
    }

    if (model.hasSill) {
      final sill = Rect.fromLTRB(
        outerRect.left - 60 * projection.scale,
        outerRect.bottom,
        outerRect.right + 60 * projection.scale,
        outerRect.bottom + 32 * projection.scale,
      );
      canvas.drawRect(sill, profileFill);
      canvas.drawRect(sill, hairline);
    }
    if (model.hasThreshold) {
      final threshold = Rect.fromLTRB(
        outerRect.left,
        outerRect.bottom,
        outerRect.right,
        outerRect.bottom + 22 * projection.scale,
      );
      canvas.drawRect(threshold, profileFill);
      canvas.drawRect(threshold, hairline);
    }

    if (showLabels) {
      for (final region in solved.leaves) {
        _paintRegionLabel(canvas, region, rectOf);
      }
    }

    final selected = highlightRegionId == null ? null : solved.byId(highlightRegionId!);
    if (selected != null) {
      canvas.drawRect(
        rectOf(selected.rect).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = AppColors.brandCreamDeep,
      );
      if (showDimensions) _paintSelectedDimensions(canvas, selected, projection);
    }

    if (showHandles) _paintDragHandles(canvas, solved, projection);

    if (showDimensions) {
      _paintOverallDimensions(canvas, outerRect, projection);
    }
  }

  void _paintRegion(Canvas canvas, SolvedRegion region, Rect Function(Box2) rectOf) {
    if (region.hasSash) _paintSashOutline(canvas, region, rectOf);

    final glazing = rectOf(region.glazingRect);
    if (glazing.width <= 0 || glazing.height <= 0) return;

    switch (region.spec.infill) {
      case CellInfill.glass:
        canvas.drawRect(glazing, Paint()..color = _glass.withValues(alpha: 0.55));
        _paintGlassSheen(canvas, glazing);
      case CellInfill.panel:
        canvas.drawRect(glazing, Paint()..color = const Color(0xFFE7E3D8));
        _paintPanelHatch(canvas, glazing);
      case CellInfill.louvre:
        canvas.drawRect(glazing, Paint()..color = const Color(0xFFEDEAE0));
        _paintLouvres(canvas, glazing);
      case CellInfill.mesh:
        canvas.drawRect(glazing, Paint()..color = const Color(0xFFE4E6E4));
        _paintMesh(canvas, glazing);
      case CellInfill.open:
        break;
    }
    canvas.drawRect(
      glazing,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = _thin,
    );

    _paintOperationSymbol(canvas, region, rectOf);
  }

  void _paintSashOutline(
    Canvas canvas,
    SolvedRegion region,
    Rect Function(Box2) rectOf,
  ) {
    final face = model.sashFaceMm;
    final sash = rectOf(region.sashRect);
    final inner = rectOf(region.sashRect.deflateEdges(
      left: face,
      top: face,
      right: face,
      bottom: face,
    ));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(sash),
        Path()..addRect(inner),
      ),
      Paint()..color = _profile,
    );
    canvas.drawRect(
      sash.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _ink.withValues(alpha: 0.85),
    );
    canvas.drawRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _thin,
    );
  }

  /// The standard elevation symbols: the apex of the V sits on the hinge side,
  /// solid when the leaf opens towards the viewer and dashed when it opens away.
  void _paintOperationSymbol(
    Canvas canvas,
    SolvedRegion region,
    Rect Function(Box2) rectOf,
  ) {
    final operation = region.spec.operation;
    if (!operation.isOperable) return;

    final rect = rectOf(region.sashRect).deflate(6);
    if (rect.width <= 4 || rect.height <= 4) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _ink.withValues(alpha: 0.7);
    final dashed = region.spec.swing == SwingDirection.outward;

    if (operation.isSliding) {
      final y = rect.center.dy;
      final toRight = operation == CellOperation.slidingRight;
      final from = Offset(toRight ? rect.left + 12 : rect.right - 12, y);
      final to = Offset(toRight ? rect.right - 12 : rect.left + 12, y);
      _line(canvas, from, to, paint);
      final dir = toRight ? 1.0 : -1.0;
      _line(canvas, to, to + Offset(-14 * dir, -8), paint);
      _line(canvas, to, to + Offset(-14 * dir, 8), paint);
      return;
    }

    final Offset apex;
    final List<Offset> base;
    switch (operation.hingeSide) {
      case HingeSide.left:
        apex = Offset(rect.left, rect.center.dy);
        base = [rect.topRight, rect.bottomRight];
      case HingeSide.right:
        apex = Offset(rect.right, rect.center.dy);
        base = [rect.topLeft, rect.bottomLeft];
      case HingeSide.top:
        apex = Offset(rect.center.dx, rect.top);
        base = [rect.bottomLeft, rect.bottomRight];
      case HingeSide.bottom:
        apex = Offset(rect.center.dx, rect.bottom);
        base = [rect.topLeft, rect.topRight];
      case HingeSide.none:
        return;
    }
    for (final corner in base) {
      _line(canvas, corner, apex, paint, dashed: dashed);
    }
  }

  void _paintRegionLabel(
    Canvas canvas,
    SolvedRegion region,
    Rect Function(Box2) rectOf,
  ) {
    final rect = rectOf(region.rect);
    if (rect.width < 46 || rect.height < 26) return;
    final label = region.spec.label;
    final text = label ?? '${region.rect.width.round()}×${region.rect.height.round()}';
    _text(
      canvas,
      text,
      rect.center,
      fontSize: 9.5,
      color: _thin,
      background: Colors.white.withValues(alpha: 0.72),
    );
  }

  void _paintGlassSheen(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.9);
    final span = math.min(rect.width, rect.height) * 0.55;
    canvas.save();
    canvas.clipRect(rect);
    for (var i = 0; i < 2; i++) {
      final offset = rect.topLeft + Offset(10.0 + i * 12, 10);
      canvas.drawLine(offset, offset + Offset(span, span), paint);
    }
    canvas.restore();
  }

  void _paintPanelHatch(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = _thin.withValues(alpha: 0.5);
    canvas.save();
    canvas.clipRect(rect);
    for (var x = rect.left - rect.height; x < rect.right; x += 9) {
      canvas.drawLine(Offset(x, rect.bottom), Offset(x + rect.height, rect.top), paint);
    }
    canvas.restore();
  }

  void _paintLouvres(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _thin;
    for (var y = rect.top + 6; y < rect.bottom; y += 8) {
      canvas.drawLine(Offset(rect.left + 2, y), Offset(rect.right - 2, y), paint);
    }
  }

  void _paintMesh(Canvas canvas, Rect rect) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.4
      ..color = _thin.withValues(alpha: 0.6);
    canvas.save();
    canvas.clipRect(rect);
    for (var x = rect.left; x < rect.right; x += 5) {
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), paint);
    }
    for (var y = rect.top; y < rect.bottom; y += 5) {
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    }
    canvas.restore();
  }

  // -- dimensions -----------------------------------------------------------

  void _paintOverallDimensions(
    Canvas canvas,
    Rect outerRect,
    DrawingProjection projection,
  ) {
    _dimensionLine(
      canvas,
      Offset(outerRect.left, outerRect.bottom + 40),
      Offset(outerRect.right, outerRect.bottom + 40),
      '${model.widthMm.round()}',
      horizontal: true,
    );
    _dimensionLine(
      canvas,
      Offset(outerRect.right + 40, outerRect.top),
      Offset(outerRect.right + 40, outerRect.bottom),
      '${model.heightMm.round()}',
      horizontal: false,
    );
    _text(
      canvas,
      '${model.material.label} · ${model.finish.label} · '
      'frame ${model.frameDepthMm.round()} mm deep',
      Offset(outerRect.center.dx, outerRect.bottom + 62),
      fontSize: 10,
      color: _thin,
    );
  }

  /// The selected section always shows its own size, whatever shape the design
  /// is — a dimension chain only works on a regular grid.
  void _paintSelectedDimensions(
    Canvas canvas,
    SolvedRegion region,
    DrawingProjection projection,
  ) {
    final rect = projection.rectOf(region.rect);
    _dimensionLine(
      canvas,
      Offset(rect.left, rect.top - 14),
      Offset(rect.right, rect.top - 14),
      '${region.rect.width.round()}',
      horizontal: true,
      small: true,
    );
    _dimensionLine(
      canvas,
      Offset(rect.left - 14, rect.top),
      Offset(rect.left - 14, rect.bottom),
      '${region.rect.height.round()}',
      horizontal: false,
      small: true,
    );
  }

  /// Small grabs on every internal boundary, so it is obvious what can be
  /// dragged.
  void _paintDragHandles(
    Canvas canvas,
    SolvedOpening solved,
    DrawingProjection projection,
  ) {
    final paint = Paint()..color = AppColors.brandDarkGreen.withValues(alpha: 0.55);
    for (final bar in solved.allBars) {
      final rect = projection.rectOf(bar.rect);
      final centre = rect.center;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: centre,
            width: bar.vertical ? 6 : 22,
            height: bar.vertical ? 22 : 6,
          ),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  void _dimensionLine(
    Canvas canvas,
    Offset from,
    Offset to,
    String label, {
    required bool horizontal,
    bool small = false,
  }) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _ink.withValues(alpha: 0.75);
    canvas.drawLine(from, to, paint);

    const tick = 5.0;
    final tickOffset = horizontal ? const Offset(0, tick) : const Offset(tick, 0);
    canvas.drawLine(from - tickOffset, from + tickOffset, paint);
    canvas.drawLine(to - tickOffset, to + tickOffset, paint);

    final centre = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    _text(
      canvas,
      label,
      horizontal ? centre - const Offset(0, 10) : centre,
      fontSize: small ? 9.5 : 11,
      color: _ink,
      rotateQuarter: !horizontal,
      background: Colors.white.withValues(alpha: 0.85),
    );
  }

  void _line(Canvas canvas, Offset a, Offset b, Paint paint, {bool dashed = false}) {
    if (!dashed) {
      canvas.drawLine(a, b, paint);
      return;
    }
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final direction = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + direction * travelled, a + direction * end, paint);
      travelled = end + gap;
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset centre, {
    double fontSize = 11,
    Color color = _ink,
    bool rotateQuarter = false,
    Color? background,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    if (rotateQuarter) canvas.rotate(-math.pi / 2);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: painter.width + 6,
      height: painter.height + 2,
    );
    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = background,
      );
    }
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TechnicalDrawingPainter oldDelegate) =>
      oldDelegate.model != model ||
      oldDelegate.showDimensions != showDimensions ||
      oldDelegate.showLabels != showLabels ||
      oldDelegate.showHandles != showHandles ||
      oldDelegate.highlightRegionId != highlightRegionId;
}
