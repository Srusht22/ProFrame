import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/configuration/config_enums.dart';
import '../../../../domain/configuration/product_configuration.dart';

/// Engineering-style 2D elevation drawn to scale from the live
/// [ProductConfiguration] — dimension lines top/left like a real shop
/// drawing (matching the hand-sketched dimensioning style factories already
/// use on paper), diagonal swing/slide indicators, mullions/transoms,
/// hinge and handle markers. Every number on this drawing comes from the
/// same configuration the price and 3D view use (spec §83).
class TechnicalDrawingPainter extends CustomPainter {
  final ProductConfiguration config;
  final bool showDimensions;
  final Color frameColor;

  static const double _dimGutterTop = 46;
  static const double _dimGutterLeft = 56;
  static const double _margin = 24;

  TechnicalDrawingPainter({required this.config, this.showDimensions = true, required this.frameColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gutterTop = showDimensions ? _dimGutterTop : 8;
    final gutterLeft = showDimensions ? _dimGutterLeft : 8;
    final availableWidth = size.width - gutterLeft - _margin;
    final availableHeight = size.height - gutterTop - _margin;
    if (availableWidth <= 10 || availableHeight <= 10) return;

    final scale = math.min(availableWidth / config.widthMm, availableHeight / config.heightMm);
    final drawW = config.widthMm * scale;
    final drawH = config.heightMm * scale;
    final origin = Offset(gutterLeft + (availableWidth - drawW) / 2, gutterTop + (availableHeight - drawH) / 2);
    final rect = Rect.fromLTWH(origin.dx, origin.dy, drawW, drawH);

    _paintUnit(canvas, rect, scale);
    if (showDimensions) {
      _paintDimensions(canvas, rect);
    }
  }

  void _paintUnit(Canvas canvas, Rect rect, double scale) {
    final framePaint = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, config.frame.frameThicknessMm * scale * 0.4);
    final fillGlass = Paint()..color = AppColors.info.withValues(alpha: 0.16);
    final fillSolid = Paint()..color = frameColor.withValues(alpha: 0.18);
    final divider = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, config.frame.frameThicknessMm * scale * 0.28);

    // Outer frame.
    canvas.drawRect(rect, Paint()..color = Colors.white);
    canvas.drawRect(rect.deflate(framePaint.strokeWidth / 2), framePaint);

    // Inner (glazed/paneled) rect.
    final inset = math.max(3.0, config.frame.frameThicknessMm * scale * 0.6);
    final inner = rect.deflate(inset);

    final isGlass = config.panel.type == PanelType.glass;
    canvas.drawRect(inner, isGlass ? fillGlass : fillSolid);

    // Vertical mullions (sections) — used for windows and fixed multi-panel doors.
    final sections = config.category == ProductCategory.window ? config.sections : 1;
    if (sections > 1) {
      final step = inner.width / sections;
      for (var i = 1; i < sections; i++) {
        final x = inner.left + step * i;
        canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), divider);
      }
    }

    // Horizontal transoms.
    for (final fraction in config.transomFractions) {
      final y = inner.top + inner.height * fraction;
      canvas.drawLine(Offset(inner.left, y), Offset(inner.right, y), divider);
    }

    if (config.category == ProductCategory.door) {
      _paintDoorLeaf(canvas, inner, divider, scale);
    } else {
      _paintWindowOperation(canvas, inner, sections);
    }
  }

  void _paintDoorLeaf(Canvas canvas, Rect inner, Paint divider, double scale) {
    final leafCount = config.leaf.leafCount <= 0 ? 1 : config.leaf.leafCount;
    final rects = <Rect>[];
    if (leafCount == 1) {
      rects.add(inner);
    } else if (config.leaf.arrangement == LeafArrangement.unequalDouble) {
      final splitX = inner.left + inner.width * config.leaf.primaryLeafRatio;
      rects.add(Rect.fromLTRB(inner.left, inner.top, splitX, inner.bottom));
      rects.add(Rect.fromLTRB(splitX, inner.top, inner.right, inner.bottom));
      canvas.drawLine(Offset(splitX, inner.top), Offset(splitX, inner.bottom), divider);
    } else {
      final step = inner.width / leafCount;
      for (var i = 0; i < leafCount; i++) {
        rects.add(Rect.fromLTWH(inner.left + step * i, inner.top, step, inner.height));
      }
      for (var i = 1; i < leafCount; i++) {
        final x = inner.left + step * i;
        canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), divider);
      }
    }

    final swingPaint = Paint()
      ..color = AppColors.brandDarkGreen.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final hingeOnLeft = config.leaf.openingDirection != OpeningDirection.rightHinge;
    for (var i = 0; i < rects.length; i++) {
      final r = rects[i];
      final hingeLeft = leafCount == 1 ? hingeOnLeft : i == 0;
      final hingeX = hingeLeft ? r.left : r.right;
      final farX = hingeLeft ? r.right : r.left;
      // Swing diagonal (door leaf triangle), like the hand-sketch reference.
      canvas.drawLine(Offset(hingeX, r.top), Offset(farX, r.bottom), swingPaint);
      canvas.drawLine(Offset(hingeX, r.bottom), Offset(farX, r.bottom), swingPaint);

      // Hinge marks.
      final hingeMarkPaint = Paint()..color = AppColors.textPrimary;
      final hingeCount = config.hardware.hingeCount.clamp(2, 5);
      for (var h = 0; h < hingeCount; h++) {
        final t = (h + 1) / (hingeCount + 1);
        final y = r.top + r.height * t;
        canvas.drawRect(Rect.fromCenter(center: Offset(hingeX, y), width: 6, height: 10), hingeMarkPaint);
      }

      // Handle mark ~1050mm from floor, opposite the hinge side.
      final handleFractionFromTop = 1 - (1050 / config.heightMm).clamp(0.1, 0.95);
      final handleY = r.top + r.height * handleFractionFromTop;
      canvas.drawCircle(Offset(farX - (hingeLeft ? 10 : -10), handleY), 3.4, Paint()..color = AppColors.brandDarkGreenDeep);
    }
  }

  void _paintWindowOperation(Canvas canvas, Rect inner, int sections) {
    final arrowPaint = Paint()
      ..color = AppColors.brandDarkGreen.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final step = inner.width / sections;

    if (config.windowType == WindowType.sliding) {
      for (var i = 0; i < sections; i++) {
        final cx = inner.left + step * (i + 0.5);
        final cy = inner.top + inner.height / 2;
        final dir = i.isEven ? -1 : 1;
        final start = Offset(cx - dir * step * 0.28, cy);
        final end = Offset(cx + dir * step * 0.28, cy);
        canvas.drawLine(start, end, arrowPaint);
        _drawArrowHead(canvas, end, dir > 0 ? 0 : math.pi, arrowPaint);
      }
      return;
    }

    // Casement / tilt-turn / awning: diagonal opening indicator like the
    // door leaf, one per section, hinge on the outer edge.
    for (var i = 0; i < sections; i++) {
      final r = Rect.fromLTWH(inner.left + step * i, inner.top, step, inner.height);
      final hingeLeft = i < sections / 2;
      final hingeX = hingeLeft ? r.left : r.right;
      final farX = hingeLeft ? r.right : r.left;
      canvas.drawLine(Offset(hingeX, r.top), Offset(farX, r.bottom), arrowPaint);
      canvas.drawLine(Offset(hingeX, r.bottom), Offset(farX, r.bottom), arrowPaint);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
    const size = 6.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size * math.cos(angle - 0.4), tip.dy - size * math.sin(angle - 0.4))
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - size * math.cos(angle + 0.4), tip.dy - size * math.sin(angle + 0.4));
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  void _paintDimensions(Canvas canvas, Rect rect) {
    final linePaint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1;
    const textStyle = TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600);

    void drawText(String text, Offset center, {bool vertical = false}) {
      final tp = TextPainter(text: TextSpan(text: text, style: textStyle), textDirection: TextDirection.ltr)..layout();
      canvas.save();
      canvas.translate(center.dx, center.dy);
      if (vertical) canvas.rotate(-math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Top dimension (width).
    final topY = rect.top - 22;
    canvas.drawLine(Offset(rect.left, rect.top - 6), Offset(rect.left, topY), linePaint);
    canvas.drawLine(Offset(rect.right, rect.top - 6), Offset(rect.right, topY), linePaint);
    canvas.drawLine(Offset(rect.left, topY), Offset(rect.right, topY), linePaint);
    drawText('${config.widthMm.toInt()} mm', Offset((rect.left + rect.right) / 2, topY - 10));

    // Left dimension (height).
    final leftX = rect.left - 22;
    canvas.drawLine(Offset(rect.left - 6, rect.top), Offset(leftX, rect.top), linePaint);
    canvas.drawLine(Offset(rect.left - 6, rect.bottom), Offset(leftX, rect.bottom), linePaint);
    canvas.drawLine(Offset(leftX, rect.top), Offset(leftX, rect.bottom), linePaint);
    drawText('${config.heightMm.toInt()} mm', Offset(leftX - 12, (rect.top + rect.bottom) / 2), vertical: true);
  }

  @override
  bool shouldRepaint(covariant TechnicalDrawingPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.showDimensions != showDimensions ||
        oldDelegate.frameColor != frameColor;
  }
}
