import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../sketch/stroke.dart';

/// What a stroke turned out to be.
enum FitKind {
  /// One straight run.
  line,

  /// A chain of straight runs that does not close.
  polyline,

  /// A chain of straight runs that closes — a box, or any closed shape.
  loop,

  /// Too short or too scribbled to be a line at all.
  mark,
}

/// A stroke read as straight runs.
///
/// The corners are the user's own: a wobble along a line is smoothed away,
/// but a deliberate change of direction is kept, at the angle it was drawn.
class StrokeFit {
  final Stroke stroke;
  final FitKind kind;

  /// The corner points, in order. Two points for a line.
  final List<Vec2> vertices;

  /// How far the stroke wandered from the fit, in millimetres. Small means
  /// the fit is a faithful reading of what was drawn.
  final double errorMm;

  const StrokeFit({
    required this.stroke,
    required this.kind,
    required this.vertices,
    required this.errorMm,
  });

  bool get isClosed => kind == FitKind.loop;

  List<Segment> get segments => [
        for (var i = 0; i + 1 < vertices.length; i++)
          Segment(vertices[i], vertices[i + 1]),
        if (isClosed && vertices.length > 2)
          Segment(vertices.last, vertices.first),
      ];

  /// True when this is a single straight run, whatever its angle.
  bool get isSingleLine => kind == FitKind.line;

  /// How confident the fit is, 0 to 1. Used to decide whether to ask.
  double get confidence {
    final span = math.max(stroke.diagonal, Tol.minLineMm);
    return (1 - errorMm / (span * Tol.cornerFraction * 2)).clamp(0.0, 1.0);
  }
}

/// Reads strokes as straight runs.
///
/// This is the whole of what the application is allowed to do to a drawing
/// without asking: take out the shake of a hand, and nothing else. It never
/// straightens a line the user meant to slope, never squares a shape the
/// user drew at an angle, and never adds or removes a corner.
abstract final class StrokeFitter {
  static StrokeFit fit(Stroke stroke) {
    final points = stroke.points;
    if (stroke.isEmpty || stroke.pathLength < Tol.minLineMm) {
      return StrokeFit(
        stroke: stroke,
        kind: FitKind.mark,
        vertices: points.isEmpty ? const [] : [points.first],
        errorMm: 0,
      );
    }

    // The corner tolerance scales with the stroke, never with the sheet:
    // a small mark is allowed small corners, a long sweep is not broken up
    // by the tremor of drawing it.
    final tolerance =
        math.max(stroke.diagonal * Tol.cornerFraction, Tol.cornerFloorMm);

    var vertices = _simplify(points, tolerance);
    final closed = stroke.isClosed && vertices.length >= 4;

    if (closed) {
      // The two ends are the same corner: merge them so the loop has one
      // vertex there rather than two nearly on top of each other.
      vertices = _mergeEnds(vertices, tolerance);
    }

    vertices = _dropSpurs(vertices, tolerance, closed: closed);

    final kind = closed
        ? FitKind.loop
        : vertices.length <= 2
            ? FitKind.line
            : FitKind.polyline;

    if (kind == FitKind.line) {
      vertices = [stroke.start, stroke.end];
    }

    return StrokeFit(
      stroke: stroke,
      kind: kind,
      vertices: vertices,
      errorMm: _errorOf(points, vertices, closed: closed),
    );
  }

  /// Ramer–Douglas–Peucker: keeps the points that carry the shape and drops
  /// the ones that only carry the shake.
  static List<Vec2> _simplify(List<Vec2> points, double tolerance) {
    if (points.length < 3) return List.of(points);

    var worst = 0.0;
    var worstAt = 0;
    final line = Segment(points.first, points.last);
    final degenerate = line.length < 1e-9;
    for (var i = 1; i < points.length - 1; i++) {
      final distance = degenerate
          ? points.first.distanceTo(points[i])
          : line.distanceTo(points[i]);
      if (distance > worst) {
        worst = distance;
        worstAt = i;
      }
    }

    if (worst <= tolerance) return [points.first, points.last];

    final left = _simplify(points.sublist(0, worstAt + 1), tolerance);
    final right = _simplify(points.sublist(worstAt), tolerance);
    return [...left.sublist(0, left.length - 1), ...right];
  }

  static List<Vec2> _mergeEnds(List<Vec2> vertices, double tolerance) {
    final merged = List.of(vertices);
    if (merged.length > 3 &&
        merged.first.distanceTo(merged.last) <= tolerance * 2) {
      merged.removeLast();
    }
    return merged;
  }

  /// Removes a vertex where the line doubles straight back on itself — the
  /// flick at the end of a fast stroke, not a corner anybody drew.
  static List<Vec2> _dropSpurs(
    List<Vec2> vertices,
    double tolerance, {
    required bool closed,
  }) {
    if (vertices.length < 3) return vertices;
    final kept = <Vec2>[];
    for (var i = 0; i < vertices.length; i++) {
      final isEnd = !closed && (i == 0 || i == vertices.length - 1);
      if (isEnd) {
        kept.add(vertices[i]);
        continue;
      }
      final before = vertices[(i - 1 + vertices.length) % vertices.length];
      final after = vertices[(i + 1) % vertices.length];
      final run = before.distanceTo(vertices[i]) + vertices[i].distanceTo(after);
      final direct = before.distanceTo(after);
      if (run - direct < tolerance * 0.25 && direct > tolerance) continue;
      kept.add(vertices[i]);
    }
    return kept.length >= (closed ? 3 : 2) ? kept : vertices;
  }

  static double _errorOf(
    List<Vec2> points,
    List<Vec2> vertices, {
    required bool closed,
  }) {
    if (vertices.length < 2) return 0;
    final edges = <Segment>[
      for (var i = 0; i + 1 < vertices.length; i++)
        Segment(vertices[i], vertices[i + 1]),
      if (closed) Segment(vertices.last, vertices.first),
    ];
    var worst = 0.0;
    for (final point in points) {
      var nearest = double.infinity;
      for (final edge in edges) {
        nearest = math.min(nearest, edge.distanceTo(point));
      }
      worst = math.max(worst, nearest);
    }
    return worst;
  }

  /// Squares a run to the axis it is nearly on, and leaves it alone when it
  /// is not.
  ///
  /// This is the line between cleaning and redesigning. Within a few degrees
  /// the user was drawing a straight bar and their hand moved; beyond that
  /// they were drawing a slope, and the slope is theirs to keep.
  /// The stroke drawn again as the straight runs it is read as — the corner
  /// points, in order, closed back to the first where it closes — or null
  /// when it is too short or too scribbled to be a line at all.
  ///
  /// **This is the reading, drawn back onto the sheet, and nothing more.**
  /// It is what the user asks for by pausing with the pen down: make this
  /// line straight. So it is not a second opinion about the stroke; it is
  /// [fit], the same corners the design is built from, which means what
  /// snaps on the screen is exactly what gets built and nothing the reading
  /// would not have made is invented for the look of it. A wobble along a
  /// line comes out, a corner the user drew stays at the angle they drew
  /// it, and both ends stay where the pen put them.
  ///
  /// A single line near an axis is squared as the reading squares it, by
  /// [straightened] — two degrees off vertical is a hand, not a design.
  static List<Vec2>? straightRuns(Stroke stroke) {
    if (stroke.isEmpty) return null;
    final fit = StrokeFitter.fit(stroke);
    switch (fit.kind) {
      case FitKind.mark:
        return null;
      case FitKind.line:
        final run = straightened(Segment(fit.vertices.first, fit.vertices.last));
        return [run.a, run.b];
      case FitKind.polyline:
        return List.of(fit.vertices);
      case FitKind.loop:
        return [...fit.vertices, fit.vertices.first];
    }
  }

  /// Samples laid along [corners] no further apart than [spacingMm].
  ///
  /// A straightened stroke is still a stroke — the eraser finds one by its
  /// samples, and the reading fits one from them — so it is laid down as
  /// ink along its runs rather than as its corners alone, every corner kept
  /// exactly.
  static List<StrokeSample> samplesAlong(
    List<Vec2> corners, {
    required double spacingMm,
    double pressure = 1,
  }) {
    if (corners.isEmpty) return const [];
    final step = math.max(spacingMm, Tol.samePointMm);
    final samples = [StrokeSample(corners.first, pressure: pressure)];
    for (var i = 1; i < corners.length; i++) {
      final from = corners[i - 1];
      final to = corners[i];
      final pieces = math.max(1, (from.distanceTo(to) / step).ceil());
      for (var k = 1; k <= pieces; k++) {
        samples.add(StrokeSample(from.lerp(to, k / pieces), pressure: pressure));
      }
    }
    return samples;
  }

  static Segment straightened(Segment run) {
    if (run.offAxisDegrees > Tol.axisSnapDegrees) return run;
    if (run.isHorizontalish) {
      final y = (run.a.y + run.b.y) / 2;
      return Segment(Vec2(run.a.x, y), Vec2(run.b.x, y));
    }
    if (run.isVerticalish) {
      final x = (run.a.x + run.b.x) / 2;
      return Segment(Vec2(x, run.a.y), Vec2(x, run.b.y));
    }
    return run;
  }
}
