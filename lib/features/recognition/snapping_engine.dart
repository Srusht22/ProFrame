import 'dart:math' as math;

import '../../core/utilities/geometry_math.dart';
import '../../shared/models/primitives.dart';

enum SnapKind {
  none,
  grid,
  endpoint,
  intersection,
  edge,
  centre,
  axis,
  equalSpacing,
}

extension SnapKindInfo on SnapKind {
  String get hint => switch (this) {
        SnapKind.none => '',
        SnapKind.grid => 'Grid',
        SnapKind.endpoint => 'Endpoint',
        SnapKind.intersection => 'Intersection',
        SnapKind.edge => 'Frame edge',
        SnapKind.centre => 'Centre',
        SnapKind.axis => 'Aligned',
        SnapKind.equalSpacing => 'Equal spacing',
      };
}

/// The snapped position plus an optional guide the canvas draws so the user
/// can see *why* the point moved (§7).
class SnapResult {
  final Vec2 point;
  final SnapKind kind;
  final Vec2? guideStart;
  final Vec2? guideEnd;

  const SnapResult({
    required this.point,
    this.kind = SnapKind.none,
    this.guideStart,
    this.guideEnd,
  });

  bool get snapped => kind != SnapKind.none;
}

/// Live snapping while the user draws. Runs on every pointer move, so it stays
/// simple arithmetic over the existing primitives — no allocation-heavy work.
class SnappingEngine {
  final bool gridEnabled;
  final double gridSpacing;
  final double tolerance;

  const SnappingEngine({
    this.gridEnabled = true,
    this.gridSpacing = 24,
    this.tolerance = 14,
  });

  SnappingEngine copyWith({bool? gridEnabled, double? gridSpacing, double? tolerance}) =>
      SnappingEngine(
        gridEnabled: gridEnabled ?? this.gridEnabled,
        gridSpacing: gridSpacing ?? this.gridSpacing,
        tolerance: tolerance ?? this.tolerance,
      );

  /// Snaps a free point against everything already on the canvas.
  SnapResult snapPoint(Vec2 raw, List<SketchPrimitive> context) {
    final candidates = <_Candidate>[];

    for (final primitive in context) {
      switch (primitive) {
        case LinePrimitive line:
          _addPoint(candidates, raw, line.start, SnapKind.endpoint, 0);
          _addPoint(candidates, raw, line.end, SnapKind.endpoint, 0);
          _addPoint(candidates, raw, line.start.lerp(line.end, 0.5), SnapKind.centre, 2);
        case RectanglePrimitive rect:
          final b = rect.box;
          for (final corner in [
            b.topLeft,
            Vec2(b.right, b.top),
            b.bottomRight,
            Vec2(b.left, b.bottom),
          ]) {
            _addPoint(candidates, raw, corner, SnapKind.endpoint, 0);
          }
          _addPoint(candidates, raw, b.center, SnapKind.centre, 2);
          // Projections onto the four edges keep divisions attached to the frame.
          _addPoint(candidates, raw, Vec2(raw.x.clamp(b.left, b.right).toDouble(), b.top),
              SnapKind.edge, 1);
          _addPoint(candidates, raw, Vec2(raw.x.clamp(b.left, b.right).toDouble(), b.bottom),
              SnapKind.edge, 1);
          _addPoint(candidates, raw, Vec2(b.left, raw.y.clamp(b.top, b.bottom).toDouble()),
              SnapKind.edge, 1);
          _addPoint(candidates, raw, Vec2(b.right, raw.y.clamp(b.top, b.bottom).toDouble()),
              SnapKind.edge, 1);
        case ArcPrimitive arc:
          _addPoint(candidates, raw, arc.start, SnapKind.endpoint, 0);
          _addPoint(candidates, raw, arc.end, SnapKind.endpoint, 0);
        case ArrowPrimitive arrow:
          _addPoint(candidates, raw, arrow.tail, SnapKind.endpoint, 0);
          _addPoint(candidates, raw, arrow.head, SnapKind.endpoint, 0);
        case DimensionPrimitive dim:
          _addPoint(candidates, raw, dim.start, SnapKind.endpoint, 0);
          _addPoint(candidates, raw, dim.end, SnapKind.endpoint, 0);
        case NotePrimitive():
          break;
      }
    }

    _addIntersections(candidates, raw, context);
    _addEqualSpacing(candidates, raw, context);

    if (candidates.isNotEmpty) {
      candidates.sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        return byPriority != 0 ? byPriority : a.distance.compareTo(b.distance);
      });
      final best = candidates.first;
      return SnapResult(point: best.point, kind: best.kind, guideStart: best.guideStart, guideEnd: best.guideEnd);
    }

    if (gridEnabled) {
      final snapped = Vec2(
        (raw.x / gridSpacing).round() * gridSpacing,
        (raw.y / gridSpacing).round() * gridSpacing,
      );
      if (snapped.distanceTo(raw) <= tolerance) {
        return SnapResult(point: snapped, kind: SnapKind.grid);
      }
    }

    return SnapResult(point: raw);
  }

  /// Constrains a dragged segment to an axis when it is nearly axis-aligned,
  /// then snaps the moving end against the drawing.
  SnapResult snapSegmentEnd(Vec2 anchor, Vec2 raw, List<SketchPrimitive> context) {
    final dx = (raw.x - anchor.x).abs();
    final dy = (raw.y - anchor.y).abs();
    final length = math.sqrt(dx * dx + dy * dy);

    var candidate = raw;
    var kind = SnapKind.none;
    if (length > 1) {
      final angle = GeometryMath.undirectedAngleDeg(anchor, raw);
      final toHorizontal = math.min(angle, 180 - angle);
      final toVertical = (angle - 90).abs();
      if (toHorizontal <= RecognitionThresholds.axisSnapDeg && toHorizontal <= toVertical) {
        candidate = Vec2(raw.x, anchor.y);
        kind = SnapKind.axis;
      } else if (toVertical <= RecognitionThresholds.axisSnapDeg) {
        candidate = Vec2(anchor.x, raw.y);
        kind = SnapKind.axis;
      }
    }

    final pointSnap = snapPoint(candidate, context);
    if (pointSnap.snapped && pointSnap.point.distanceTo(candidate) <= tolerance) {
      // Keep the axis constraint if the point snap would break it.
      if (kind == SnapKind.axis) {
        final aligned = (candidate.x == anchor.x)
            ? Vec2(anchor.x, pointSnap.point.y)
            : Vec2(pointSnap.point.x, anchor.y);
        return SnapResult(
          point: aligned,
          kind: pointSnap.kind,
          guideStart: anchor,
          guideEnd: aligned,
        );
      }
      return pointSnap;
    }

    return SnapResult(
      point: candidate,
      kind: kind,
      guideStart: kind == SnapKind.axis ? anchor : null,
      guideEnd: kind == SnapKind.axis ? candidate : null,
    );
  }

  void _addPoint(
    List<_Candidate> out,
    Vec2 raw,
    Vec2 target,
    SnapKind kind,
    int priority, {
    Vec2? guideStart,
    Vec2? guideEnd,
  }) {
    final d = raw.distanceTo(target);
    if (d <= tolerance) {
      out.add(_Candidate(target, kind, priority, d, guideStart, guideEnd));
    }
  }

  void _addIntersections(List<_Candidate> out, Vec2 raw, List<SketchPrimitive> context) {
    final lines = context.whereType<LinePrimitive>().toList();
    for (var i = 0; i < lines.length; i++) {
      for (var j = i + 1; j < lines.length; j++) {
        final p = GeometryMath.lineIntersection(
          lines[i].start,
          lines[i].end,
          lines[j].start,
          lines[j].end,
        );
        if (p == null) continue;
        final onBoth =
            GeometryMath.distanceToSegment(p, lines[i].start, lines[i].end) < 1 &&
                GeometryMath.distanceToSegment(p, lines[j].start, lines[j].end) < 1;
        if (onBoth) _addPoint(out, raw, p, SnapKind.intersection, 1);
      }
    }
  }

  /// Offers the position that would make the new division evenly spaced with
  /// the divisions already present inside the same frame (§7).
  void _addEqualSpacing(List<_Candidate> out, Vec2 raw, List<SketchPrimitive> context) {
    final frame = _largestRectangle(context);
    if (frame == null) return;
    final box = frame.box;
    if (!box.inflate(tolerance * 2).contains(raw)) return;

    final verticalXs = context
        .whereType<LinePrimitive>()
        .where((l) => l.orientation == LineOrientation.vertical)
        .map((l) => (l.start.x + l.end.x) / 2)
        .where((x) => x > box.left + 1 && x < box.right - 1)
        .toList()
      ..sort();

    final divisions = verticalXs.length + 1;
    for (var n = 2; n <= divisions + 1; n++) {
      for (var k = 1; k < n; k++) {
        final x = box.left + box.width * k / n;
        _addPoint(
          out,
          raw,
          Vec2(x, raw.y.clamp(box.top, box.bottom).toDouble()),
          SnapKind.equalSpacing,
          3,
          guideStart: Vec2(x, box.top),
          guideEnd: Vec2(x, box.bottom),
        );
      }
    }

    final horizontalYs = context
        .whereType<LinePrimitive>()
        .where((l) => l.orientation == LineOrientation.horizontal)
        .map((l) => (l.start.y + l.end.y) / 2)
        .where((y) => y > box.top + 1 && y < box.bottom - 1)
        .toList();
    final rowDivisions = horizontalYs.length + 1;
    for (var n = 2; n <= rowDivisions + 1; n++) {
      for (var k = 1; k < n; k++) {
        final y = box.top + box.height * k / n;
        _addPoint(
          out,
          raw,
          Vec2(raw.x.clamp(box.left, box.right).toDouble(), y),
          SnapKind.equalSpacing,
          3,
          guideStart: Vec2(box.left, y),
          guideEnd: Vec2(box.right, y),
        );
      }
    }
  }

  RectanglePrimitive? _largestRectangle(List<SketchPrimitive> context) {
    RectanglePrimitive? best;
    for (final p in context.whereType<RectanglePrimitive>()) {
      if (best == null || p.box.area > best.box.area) best = p;
    }
    return best;
  }
}

class _Candidate {
  final Vec2 point;
  final SnapKind kind;
  final int priority;
  final double distance;
  final Vec2? guideStart;
  final Vec2? guideEnd;

  const _Candidate(
    this.point,
    this.kind,
    this.priority,
    this.distance,
    this.guideStart,
    this.guideEnd,
  );
}
