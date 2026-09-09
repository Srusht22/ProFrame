import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/geometry_math.dart';
import '../../../shared/models/sketch.dart';
import '../../recognition/snapping_engine.dart';

/// Paints the committed ink. Repaints only when the stroke list changes —
/// the stroke under the finger is drawn by [LiveStrokePainter] on its own
/// layer.
class SketchPainter extends CustomPainter {
  final List<Stroke> strokes;
  final String? selectedStrokeId;
  final bool showGrid;
  final double gridSpacing;

  const SketchPainter({
    required this.strokes,
    this.selectedStrokeId,
    this.showGrid = true,
    this.gridSpacing = 24,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    for (final stroke in strokes) {
      paintStroke(canvas, stroke, selected: stroke.id == selectedStrokeId);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = AppColors.neutralBorder.withValues(alpha: 0.55)
      ..strokeWidth = 0.6;
    final major = Paint()
      ..color = AppColors.neutralBorder
      ..strokeWidth = 1.0;

    for (var x = 0.0; x <= size.width; x += gridSpacing) {
      final isMajor = (x / gridSpacing).round() % 5 == 0;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), isMajor ? major : minor);
    }
    for (var y = 0.0; y <= size.height; y += gridSpacing) {
      final isMajor = (y / gridSpacing).round() % 5 == 0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), isMajor ? major : minor);
    }
  }

  /// Shared by the committed and the live layer so ink looks identical the
  /// instant it is released.
  static void paintStroke(Canvas canvas, Stroke stroke, {bool selected = false, bool live = false}) {
    if (stroke.points.isEmpty) return;
    final color = _colorFor(stroke.tool, live: live);
    final paint = Paint()
      ..color = selected ? AppColors.brandCreamDeep : color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.width;

    switch (stroke.tool) {
      case SketchTool.rectangle:
        canvas.drawRect(
          Rect.fromPoints(_offset(stroke.start), _offset(stroke.end)),
          paint,
        );
      case SketchTool.dimension:
        _paintDimension(canvas, stroke, paint);
      case SketchTool.arrow:
        _paintArrow(canvas, stroke, paint);
      case SketchTool.diagonal:
        _paintDashed(canvas, _offset(stroke.start), _offset(stroke.end), paint);
      case SketchTool.note:
        _paintNote(canvas, stroke, selected: selected);
      case SketchTool.line:
      case SketchTool.division:
        canvas.drawLine(_offset(stroke.start), _offset(stroke.end), paint);
      default:
        _paintFreehand(canvas, stroke, paint);
    }

    if (selected) {
      canvas.drawRect(
        Rect.fromLTRB(
          stroke.bounds.left - 8,
          stroke.bounds.top - 8,
          stroke.bounds.right + 8,
          stroke.bounds.bottom + 8,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = AppColors.brandDarkGreen.withValues(alpha: 0.6),
      );
    }
  }

  /// Freehand ink tapers with reported stylus pressure.
  static void _paintFreehand(Canvas canvas, Stroke stroke, Paint paint) {
    final points = stroke.points;
    if (points.length == 1) {
      canvas.drawCircle(_offset(points.first.position), stroke.width / 2, paint..style = PaintingStyle.fill);
      return;
    }
    final varies = points.any((p) => (p.pressure - points.first.pressure).abs() > 0.08);
    if (!varies) {
      final path = Path()..moveTo(points.first.x, points.first.y);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].x, points[i].y);
      }
      canvas.drawPath(path, paint);
      return;
    }
    for (var i = 1; i < points.length; i++) {
      final pressure = (points[i].pressure + points[i - 1].pressure) / 2;
      paint.strokeWidth = stroke.width * (0.55 + pressure * 0.75);
      canvas.drawLine(_offset(points[i - 1].position), _offset(points[i].position), paint);
    }
  }

  static void _paintDimension(Canvas canvas, Stroke stroke, Paint paint) {
    final a = _offset(stroke.start);
    final b = _offset(stroke.end);
    paint.strokeWidth = math.max(stroke.width * 0.6, 1.2);
    canvas.drawLine(a, b, paint);

    final direction = (b - a);
    final length = direction.distance;
    if (length < 1) return;
    final normal = Offset(-direction.dy, direction.dx) / length * 6;
    canvas.drawLine(a - normal, a + normal, paint);
    canvas.drawLine(b - normal, b + normal, paint);

    final label = stroke.dimensionMm != null
        ? '${stroke.dimensionMm!.round()} mm'
        : 'tap to set';
    _paintLabel(
      canvas,
      label,
      (a + b) / 2 - normal * 2.2,
      color: stroke.dimensionMm != null ? AppColors.brandDarkGreen : AppColors.warning,
    );
  }

  static void _paintArrow(Canvas canvas, Stroke stroke, Paint paint) {
    final a = _offset(stroke.start);
    final b = _offset(stroke.end);
    canvas.drawLine(a, b, paint);
    final direction = b - a;
    final length = direction.distance;
    if (length < 1) return;
    final unit = direction / length;
    final normal = Offset(-unit.dy, unit.dx);
    const head = 14.0;
    canvas.drawLine(b, b - unit * head + normal * (head * 0.45), paint);
    canvas.drawLine(b, b - unit * head - normal * (head * 0.45), paint);
  }

  static void _paintDashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 8.0;
    const gap = 5.0;
    final total = (b - a).distance;
    if (total <= 0) return;
    final unit = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + unit * travelled, a + unit * end, paint);
      travelled = end + gap;
    }
  }

  static void _paintNote(Canvas canvas, Stroke stroke, {bool selected = false}) {
    _paintLabel(
      canvas,
      stroke.text?.isNotEmpty == true ? stroke.text! : 'note',
      _offset(stroke.start),
      color: AppColors.textPrimary,
      background: selected
          ? AppColors.brandCreamDeep.withValues(alpha: 0.9)
          : AppColors.brandCreamSoft,
      align: Alignment.centerLeft,
    );
  }

  static void _paintLabel(
    Canvas canvas,
    String text,
    Offset position, {
    Color color = AppColors.brandDarkGreen,
    Color? background,
    Alignment align = Alignment.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final width = painter.width + 10;
    final height = painter.height + 6;
    final rect = align == Alignment.centerLeft
        ? Rect.fromLTWH(position.dx, position.dy - height / 2, width, height)
        : Rect.fromCenter(center: position, width: width, height: height);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = background ?? Colors.white.withValues(alpha: 0.88),
    );
    painter.paint(canvas, Offset(rect.left + 5, rect.top + 3));
  }

  static Offset _offset(Vec2 v) => Offset(v.x, v.y);

  static Color _colorFor(SketchTool tool, {bool live = false}) {
    final base = switch (tool) {
      SketchTool.dimension => AppColors.info,
      SketchTool.diagonal => AppColors.brandDarkGreenLight,
      SketchTool.arrow => AppColors.brandDarkGreenLight,
      SketchTool.note => AppColors.textPrimary,
      _ => AppColors.textPrimary,
    };
    return live ? base.withValues(alpha: 0.75) : base;
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) =>
      !identical(oldDelegate.strokes, strokes) ||
      oldDelegate.strokes.length != strokes.length ||
      oldDelegate.selectedStrokeId != selectedStrokeId ||
      oldDelegate.showGrid != showGrid;
}

/// Paints only the stroke currently being drawn plus the snapping guide.
class LiveStrokePainter extends CustomPainter {
  final Stroke? stroke;
  final SnapResult? snap;

  const LiveStrokePainter({required this.stroke, this.snap});

  @override
  void paint(Canvas canvas, Size size) {
    final guide = snap;
    if (guide != null) {
      final paint = Paint()
        ..color = AppColors.brandCreamDeep
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final start = guide.guideStart;
      final end = guide.guideEnd;
      if (start != null && end != null) {
        SketchPainter._paintDashed(
          canvas,
          Offset(start.x, start.y),
          Offset(end.x, end.y),
          paint,
        );
      }
      final marker = Offset(guide.point.x, guide.point.y);
      canvas.drawCircle(marker, 5, paint);
      SketchPainter._paintLabel(
        canvas,
        guide.kind.hint,
        marker + const Offset(0, -20),
        color: AppColors.brandDarkGreen,
        background: AppColors.brandCreamSoft,
      );
    }

    final current = stroke;
    if (current != null) {
      SketchPainter.paintStroke(canvas, current, live: true);
    }
  }

  @override
  bool shouldRepaint(covariant LiveStrokePainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.snap != snap;
}
