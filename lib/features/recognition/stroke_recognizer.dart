import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/primitives.dart';
import '../../shared/models/sketch.dart';

/// Turns raw ink into clean primitives.
///
/// The rule the whole recogniser follows: **correct the hand, never the
/// intent** (§7). A line drawn at 88° becomes exactly vertical because that is
/// obviously what was meant; a line drawn at 60° is left at 60° because that
/// is clearly deliberate.
class StrokeRecognizer {
  final double axisSnapDeg;
  final double straightnessRatio;

  const StrokeRecognizer({
    this.axisSnapDeg = RecognitionThresholds.axisSnapDeg,
    this.straightnessRatio = RecognitionThresholds.straightnessRatio,
  });

  List<SketchPrimitive> recognizeAll(Sketch sketch) {
    final result = <SketchPrimitive>[];
    for (final stroke in sketch.strokes) {
      final primitive = recognize(stroke);
      if (primitive != null) result.add(primitive);
    }
    return result;
  }

  SketchPrimitive? recognize(Stroke stroke) {
    if (stroke.points.isEmpty) return null;
    final id = 'p_${stroke.id}';

    switch (stroke.tool) {
      case SketchTool.note:
        return NotePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          anchor: stroke.start,
          text: stroke.text ?? '',
        );
      case SketchTool.dimension:
        final line = _straighten(stroke.start, stroke.end);
        return DimensionPrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          start: line.$1,
          end: line.$2,
          valueMm: stroke.dimensionMm,
        );
      case SketchTool.rectangle:
        return RectanglePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          box: Box2.fromCorners(stroke.start, stroke.end),
        );
      case SketchTool.arrow:
        return ArrowPrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          tail: stroke.start,
          head: stroke.end,
        );
      case SketchTool.line:
      case SketchTool.division:
        final line = _straighten(stroke.start, stroke.end);
        return LinePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          start: line.$1,
          end: line.$2,
          originalAngleDeg: GeometryMath.undirectedAngleDeg(stroke.start, stroke.end),
        );
      case SketchTool.diagonal:
        return LinePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: 1,
          start: stroke.start,
          end: stroke.end,
          originalAngleDeg: GeometryMath.undirectedAngleDeg(stroke.start, stroke.end),
          lineRole: PrimitiveRole.openingMark,
        );
      case SketchTool.arc:
        return _buildArc(stroke, id, 1);
      case SketchTool.pen:
        return _recognizeFreehand(stroke, id);
      case SketchTool.eraser:
      case SketchTool.select:
      case SketchTool.pan:
        return null;
    }
  }

  // -- freehand analysis ----------------------------------------------------

  SketchPrimitive? _recognizeFreehand(Stroke stroke, String id) {
    final raw = stroke.positions;
    if (raw.length < 2) return null;

    final box = Box2.fromPoints(raw);
    final diagonal = math.sqrt(box.width * box.width + box.height * box.height);
    if (diagonal < 4) return null;

    final simplified = GeometryMath.simplify(raw, math.max(diagonal * 0.035, 1.5));
    final pathLength = GeometryMath.pathLength(raw);
    final closure = raw.first.distanceTo(raw.last);
    final isClosed = pathLength > 0 && closure < pathLength * 0.22 && simplified.length >= 4;

    if (isClosed) {
      // A closed loop that fills most of its bounding box is a rectangle —
      // exactly how frames and panels are sketched on paper.
      final corners = simplified.length - 1;
      final fill = pathLength / (2 * (box.width + box.height)).clamp(1, double.infinity);
      final confidence = (corners >= 3 && corners <= 6) ? 0.92 : 0.6;
      if (fill > 0.8 && fill < 1.6) {
        return RectanglePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: confidence,
          box: box,
        );
      }
      return RectanglePrimitive(
        id: id,
        strokeId: stroke.id,
        confidence: 0.55,
        box: box,
      );
    }

    final arrow = _detectArrow(simplified);
    if (arrow != null) {
      return ArrowPrimitive(
        id: id,
        strokeId: stroke.id,
        confidence: 0.78,
        tail: arrow.$1,
        head: arrow.$2,
      );
    }

    final chord = raw.first.distanceTo(raw.last);
    if (chord > 1) {
      var maxDeviation = 0.0;
      for (final p in raw) {
        final d = GeometryMath.distanceToLine(p, raw.first, raw.last);
        if (d > maxDeviation) maxDeviation = d;
      }
      final deviationRatio = maxDeviation / chord;
      if (deviationRatio <= straightnessRatio) {
        final line = _straighten(raw.first, raw.last);
        // Straight but wobbly ink is still a line, just less certain.
        final confidence = (1 - deviationRatio / straightnessRatio * 0.3).clamp(0.6, 1.0);
        return LinePrimitive(
          id: id,
          strokeId: stroke.id,
          confidence: confidence.toDouble(),
          start: line.$1,
          end: line.$2,
          originalAngleDeg: GeometryMath.undirectedAngleDeg(raw.first, raw.last),
        );
      }
    }

    return _buildArc(stroke, id, 0.7);
  }

  ArcPrimitive _buildArc(Stroke stroke, String id, double confidence) {
    final raw = stroke.positions;
    var apex = raw[raw.length ~/ 2];
    var maxDeviation = -1.0;
    for (final p in raw) {
      final d = GeometryMath.distanceToLine(p, raw.first, raw.last);
      if (d > maxDeviation) {
        maxDeviation = d;
        apex = p;
      }
    }
    return ArcPrimitive(
      id: id,
      strokeId: stroke.id,
      confidence: confidence,
      start: raw.first,
      end: raw.last,
      apex: apex,
    );
  }

  /// Finds a shaft-plus-head arrow: a long straight run followed by one or two
  /// short strokes that fold sharply back on it.
  (Vec2, Vec2)? _detectArrow(List<Vec2> simplified) {
    if (simplified.length < 4) return null;
    final total = GeometryMath.pathLength(simplified);
    if (total <= 0) return null;

    // Longest segment is the shaft.
    var shaftIndex = 0;
    var shaftLength = 0.0;
    for (var i = 1; i < simplified.length; i++) {
      final len = simplified[i].distanceTo(simplified[i - 1]);
      if (len > shaftLength) {
        shaftLength = len;
        shaftIndex = i - 1;
      }
    }
    if (shaftLength < total * 0.45) return null;

    final tail = simplified[shaftIndex];
    final head = simplified[shaftIndex + 1];
    final shaftDir = (head - tail).normalized;

    // Everything after the shaft must be short and turn back sharply.
    var trailing = 0.0;
    var foldedBack = false;
    for (var i = shaftIndex + 2; i < simplified.length; i++) {
      final seg = simplified[i] - simplified[i - 1];
      trailing += seg.length;
      if (seg.normalized.dot(shaftDir) < -0.2) foldedBack = true;
    }
    if (!foldedBack || trailing > shaftLength * 0.6 || trailing < shaftLength * 0.08) {
      return null;
    }
    return (tail, head);
  }

  /// Snaps a segment onto the nearest axis when it is close enough to one.
  (Vec2, Vec2) _straighten(Vec2 a, Vec2 b) {
    final angle = GeometryMath.undirectedAngleDeg(a, b);
    final toHorizontal = math.min(angle, 180 - angle);
    final toVertical = (angle - 90).abs();

    if (toHorizontal <= axisSnapDeg && toHorizontal <= toVertical) {
      final y = (a.y + b.y) / 2;
      return (Vec2(a.x, y), Vec2(b.x, y));
    }
    if (toVertical <= axisSnapDeg) {
      final x = (a.x + b.x) / 2;
      return (Vec2(x, a.y), Vec2(x, b.y));
    }
    return (a, b);
  }
}
