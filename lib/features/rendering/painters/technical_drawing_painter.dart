import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/materials.dart';
import '../../../shared/models/opening_model.dart';

/// Draws the elevation the way a fabrication drawing looks: profiles as double
/// lines, glass hatched, opening direction shown with the standard symbols,
/// and dimension chains around the outside (§18).
///
/// It draws from the solved parametric model, so it always agrees with the 3D
/// view and the price.
class TechnicalDrawingPainter extends CustomPainter {
  final OpeningModel model;
  final bool showDimensions;
  final bool showLabels;
  final String? highlightCellPath;
  final double margin;

  TechnicalDrawingPainter({
    required this.model,
    this.showDimensions = true,
    this.showLabels = true,
    this.highlightCellPath,
    this.margin = 0,
  });

  static const Color _ink = AppColors.brandDarkGreen;
  static const Color _thin = Color(0xFF6B7B78);
  static const Color _glass = Color(0xFFD7E6E4);
  static const Color _profile = Color(0xFFF2F1EA);

  @override
  void paint(Canvas canvas, Size size) {
    final solved = OpeningSolver.solve(model);
    final pad = margin > 0
        ? EdgeInsets.all(margin)
        : (showDimensions
            ? const EdgeInsets.fromLTRB(64, 52, 64, 64)
            : const EdgeInsets.all(10));

    final available = Size(
      math.max(size.width - pad.horizontal, 1),
      math.max(size.height - pad.vertical, 1),
    );
    final scale = math.min(
      available.width / model.widthMm,
      available.height / model.heightMm,
    );
    final drawnWidth = model.widthMm * scale;
    final drawnHeight = model.heightMm * scale;
    final origin = Offset(
      pad.left + (available.width - drawnWidth) / 2,
      pad.top + (available.height - drawnHeight) / 2,
    );

    Offset toCanvas(double x, double y) =>
        Offset(origin.dx + x * scale, origin.dy + y * scale);
    Rect rectOf(Box2 box) => Rect.fromPoints(
          toCanvas(box.left, box.top),
          toCanvas(box.right, box.bottom),
        );

    final profileFill = Paint()..color = _profile;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _ink;
    final hairline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _thin;

    // Frame body: the ring between the outer edge and the inner aperture.
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

    // Mullions and transoms.
    for (final bar in solved.allBars) {
      final r = rectOf(bar.rect);
      canvas.drawRect(r, profileFill);
      canvas.drawRect(r, hairline);
    }

    // Sections.
    for (final cell in solved.leaves) {
      _paintCell(canvas, cell, rectOf, scale);
    }
    for (final cell in solved.allCells.where((c) => !c.isLeaf && c.hasSash)) {
      _paintSashOutline(canvas, cell, rectOf);
      _paintOperationSymbol(canvas, cell, rectOf);
    }

    // Sill / threshold in elevation.
    if (model.hasSill) {
      final sill = Rect.fromLTRB(
        outerRect.left - 60 * scale,
        outerRect.bottom,
        outerRect.right + 60 * scale,
        outerRect.bottom + 32 * scale,
      );
      canvas.drawRect(sill, profileFill);
      canvas.drawRect(sill, hairline);
    }
    if (model.hasThreshold) {
      final threshold = Rect.fromLTRB(
        outerRect.left,
        outerRect.bottom,
        outerRect.right,
        outerRect.bottom + 22 * scale,
      );
      canvas.drawRect(threshold, profileFill);
      canvas.drawRect(threshold, hairline);
    }

    if (showLabels) {
      for (final cell in solved.leaves) {
        _paintCellLabel(canvas, cell, rectOf);
      }
    }

    if (showDimensions) {
      _paintDimensions(canvas, solved, outerRect, toCanvas, scale);
    }
  }

  void _paintCell(
    Canvas canvas,
    SolvedCell cell,
    Rect Function(Box2) rectOf,
    double scale,
  ) {
    if (cell.hasSash) _paintSashOutline(canvas, cell, rectOf);

    final glazing = rectOf(cell.glazingRect);
    if (glazing.width <= 0 || glazing.height <= 0) return;

    switch (cell.spec.infill) {
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

    if (highlightCellPath != null && cell.path == highlightCellPath) {
      canvas.drawRect(
        rectOf(cell.aperture).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = AppColors.brandCreamDeep,
      );
    }

    _paintOperationSymbol(canvas, cell, rectOf);
    if (scale > 0) {
      // no-op guard so the analyzer keeps `scale` meaningful for callers
    }
  }

  void _paintSashOutline(Canvas canvas, SolvedCell cell, Rect Function(Box2) rectOf) {
    final sash = rectOf(cell.sashRect);
    final inner = rectOf(Box2(
      cell.sashRect.left + model.material.sashFaceMm,
      cell.sashRect.top + model.material.sashFaceMm,
      cell.sashRect.right - model.material.sashFaceMm,
      cell.sashRect.bottom - model.material.sashFaceMm,
    ));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(sash),
        Path()..addRect(inner),
      ),
      Paint()..color = _profile,
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _ink.withValues(alpha: 0.85);
    canvas.drawRect(sash.deflate(0.5), stroke);
    canvas.drawRect(inner, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _thin);
  }

  /// The standard elevation symbols: the apex of the V sits on the hinge side,
  /// solid when the leaf opens towards the viewer and dashed when it opens
  /// away — the convention on every joinery drawing.
  void _paintOperationSymbol(Canvas canvas, SolvedCell cell, Rect Function(Box2) rectOf) {
    final operation = cell.spec.operation;
    if (!operation.isOperable) return;

    final rect = rectOf(cell.sashRect).deflate(6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _ink.withValues(alpha: 0.7);
    final dashed = cell.spec.swing == SwingDirection.outward;

    if (operation.isSliding) {
      final y = rect.center.dy;
      final toRight = operation == CellOperation.slidingRight;
      final from = Offset(toRight ? rect.left + 12 : rect.right - 12, y);
      final to = Offset(toRight ? rect.right - 12 : rect.left + 12, y);
      _line(canvas, from, to, paint, dashed: false);
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

  void _paintCellLabel(Canvas canvas, SolvedCell cell, Rect Function(Box2) rectOf) {
    final rect = rectOf(cell.aperture);
    if (rect.width < 46 || rect.height < 26) return;
    final text = '${cell.aperture.width.round()}×${cell.aperture.height.round()}';
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

  // -- dimension chains -----------------------------------------------------

  void _paintDimensions(
    Canvas canvas,
    SolvedOpening solved,
    Rect outerRect,
    Offset Function(double, double) toCanvas,
    double scale,
  ) {
    // Overall width, below the drawing.
    _dimensionLine(
      canvas,
      Offset(outerRect.left, outerRect.bottom + 40),
      Offset(outerRect.right, outerRect.bottom + 40),
      '${model.widthMm.round()}',
      horizontal: true,
    );
    // Overall height, to the right.
    _dimensionLine(
      canvas,
      Offset(outerRect.right + 40, outerRect.top),
      Offset(outerRect.right + 40, outerRect.bottom),
      '${model.heightMm.round()}',
      horizontal: false,
    );

    // Section widths, above the drawing — only for the row that has the most
    // divisions, so the chain stays readable.
    final rows = solved.topCells.isEmpty
        ? <int, List<SolvedCell>>{}
        : <int, List<SolvedCell>>{};
    for (final cell in solved.topCells) {
      rows.putIfAbsent(cell.rowIndex, () => []).add(cell);
    }
    if (rows.isNotEmpty) {
      final busiest = rows.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b);
      if (busiest.value.length > 1) {
        for (final cell in busiest.value) {
          final left = toCanvas(cell.aperture.left, 0).dx;
          final right = toCanvas(cell.aperture.right, 0).dx;
          _dimensionLine(
            canvas,
            Offset(left, outerRect.top - 26),
            Offset(right, outerRect.top - 26),
            '${cell.aperture.width.round()}',
            horizontal: true,
            small: true,
          );
        }
      }
    }

    // Row heights, to the left.
    if (model.layout.rows.length > 1) {
      for (final cell in solved.topCells.where((c) => c.columnIndex == 0)) {
        final top = toCanvas(0, cell.aperture.top).dy;
        final bottom = toCanvas(0, cell.aperture.bottom).dy;
        _dimensionLine(
          canvas,
          Offset(outerRect.left - 26, top),
          Offset(outerRect.left - 26, bottom),
          '${cell.aperture.height.round()}',
          horizontal: false,
          small: true,
        );
      }
    }

    if (scale > 0) {
      _text(
        canvas,
        '${model.material.label} · ${model.finish.label} · '
        'frame ${model.material.frameDepthMm.round()} mm deep',
        Offset(outerRect.center.dx, outerRect.bottom + 62),
        fontSize: 10,
        color: _thin,
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
      oldDelegate.highlightCellPath != highlightCellPath;
}
