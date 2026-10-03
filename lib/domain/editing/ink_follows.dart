import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../sketch/stroke.dart';

/// The ink, moved exactly as an edit moved what was read from it.
///
/// **The sheet is what a reading reads.** The frame and every bar of the
/// design are read from the user's strokes, and `SketchInterpreter` reads
/// them again on every **Read** — which is right: the drawing is the source
/// of truth, and a reading is a faithful copy of it. So an edit made on the
/// technical drawing — the head dragged down, a transom dragged, a bar's end
/// moved, a length typed — changed the design and not the ink, and the next
/// reading rebuilt the design from the ink as it was: the edit was simply
/// gone. A size typed in the form never had this fault, because
/// `Measurements.stretch` moves the ink a line was read from as the line
/// moves; this is the same rule for every other edit.
///
/// [edit] takes the design before an edit and after it, and gives the
/// after with:
///
/// - **the ink each bar, figure or arrow was read from** carried as that
///   element moved, end to end — each sample by the displacement of the
///   point of the element it lies against;
/// - **the frame's ink** carried as the frame's edges moved, a sample with
///   the edge it lies near, and only within the hand's reach of it, so a
///   stroke that is nothing to do with the frame is not dragged along;
/// - **a dimension resting on what moved** carried with it, and a figure
///   the user stated reading the new length, so the next reading's pins
///   hold the edit rather than pulling the geometry back to the old figure.
///
/// Nothing else changes: not the geometry the edit produced, not a mark,
/// not a stroke that nothing moved. Nothing is written into the ink that
/// was not already there — every sample is the user's own, moved — and a
/// reading of the moved ink builds the design the edit made.
abstract final class InkFollows {
  static Design edit(Design before, Design after) {
    if (identical(before, after)) return after;

    // What moved, line by line: (where it was, where it is).
    final byStroke = <String, List<(Segment, Segment)>>{};
    final lines = <(Segment, Segment)>[];
    void moved(String? strokeId, Segment from, Segment to) {
      final pair = (from, to);
      lines.add(pair);
      if (strokeId != null) (byStroke[strokeId] ??= []).add(pair);
    }

    for (final bar in before.dividers) {
      final now = after.dividerById(bar.id);
      if (now != null) moved(bar.fromStrokeId, bar.segment, now.segment);
    }
    for (final arrow in before.arrows) {
      for (final now in after.arrows) {
        if (now.id != arrow.id) continue;
        moved(
          arrow.fromStrokeId,
          Segment(arrow.from, arrow.to),
          Segment(now.from, now.to),
        );
      }
    }
    final frameEdges = <(Segment, Segment)>[];
    final was = before.frame?.outline, now = after.frame?.outline;
    if (was != null &&
        now != null &&
        was.corners.length == now.corners.length) {
      final n = was.corners.length;
      for (var i = 0; i < n; i++) {
        final pair = (
          Segment(was.corners[i], was.corners[(i + 1) % n]),
          Segment(now.corners[i], now.corners[(i + 1) % n]),
        );
        frameEdges.add(pair);
        lines.add(pair);
      }
    }
    bool still((Segment, Segment) pair) {
      final (from, to) = pair;
      return from.a.distanceTo(to.a) < 1e-9 && from.b.distanceTo(to.b) < 1e-9;
    }

    // A dimension resting on a line that moved goes with it; one the edit
    // itself moved is taken as it is.
    final span = _spanOf([for (final (from, _) in lines) from]);
    final weld = Tol.weldFor(span);
    final dimensions = <DimensionElement>[];
    for (final d in after.dimensions) {
      final earlier = before.dimensions.where((x) => x.id == d.id).firstOrNull;
      if (earlier == null || earlier.a != d.a || earlier.b != d.b) {
        if (earlier != null) {
          moved(
            d.fromStrokeId,
            Segment(earlier.a, earlier.b),
            Segment(d.a, d.b),
          );
        }
        dimensions.add(d);
        continue;
      }
      Vec2 rested(Vec2 p) {
        (Segment, Segment)? on;
        var nearest = weld;
        for (final pair in lines) {
          if (still(pair)) continue;
          final away = pair.$1.distanceTo(p);
          if (away <= nearest) {
            nearest = away;
            on = pair;
          }
        }
        return on == null ? p : _carried(p, on);
      }

      final a = rested(d.a), b = rested(d.b);
      if (a == d.a && b == d.b) {
        dimensions.add(d);
        continue;
      }
      final shifted = d.copyWith(a: a, b: b);
      moved(d.fromStrokeId, Segment(d.a, d.b), Segment(a, b));
      dimensions.add(
        d.isStated ? shifted.copyWith(statedMm: a.distanceTo(b)) : shifted,
      );
    }

    if (lines.every(still)) {
      return after.copyWith(dimensions: dimensions);
    }

    // The frame's ink is every stroke nothing else was read from: the
    // outline, however many strokes it was drawn in.
    final claimed = <String>{
      ...byStroke.keys,
      for (final t in after.texts) ?t.fromStrokeId,
      for (final o in after.openings)
        if (o.id.startsWith('opening-')) o.id.substring('opening-'.length),
    };
    final reach = span * Tol.wobbleShare;

    Stroke inked(Stroke stroke) {
      final own = byStroke[stroke.id] ?? const [];
      final frameInk =
          !claimed.contains(stroke.id) ||
          stroke.id == after.frame?.fromStrokeId;
      if (own.isEmpty && !frameInk) return stroke;
      if (own.every(still) && (!frameInk || frameEdges.every(still))) {
        return stroke;
      }
      return stroke.copyWith(
        samples: [
          for (final s in stroke.samples)
            s.movedTo(() {
              // Its own element first: a bar's end lying on the jamb it
              // meets is the bar's, not the jamb's.
              (Segment, Segment)? by;
              var nearest = double.infinity;
              for (final pair in own) {
                final away = pair.$1.distanceTo(s.at);
                if (away < nearest) {
                  nearest = away;
                  by = pair;
                }
              }
              if (frameInk) {
                for (final pair in frameEdges) {
                  final away = pair.$1.distanceTo(s.at);
                  if (away > reach) continue;
                  if (away < nearest - Tol.samePointMm) {
                    nearest = away;
                    by = pair;
                  }
                }
              }
              return by == null ? s.at : _carried(s.at, by);
            }()),
        ],
      );
    }

    return after.copyWith(
      dimensions: dimensions,
      sketch: Sketch(strokes: [for (final s in after.sketch.strokes) inked(s)]),
    );
  }

  /// The diagonal of everything [lines] reach: what the reading's own
  /// tolerances are a share of (`GeometryNormalizer.spanOf`).
  static double _spanOf(List<Segment> lines) {
    if (lines.isEmpty) return 0;
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (final line in lines) {
      for (final p in [line.a, line.b]) {
        left = math.min(left, p.x);
        right = math.max(right, p.x);
        top = math.min(top, p.y);
        bottom = math.max(bottom, p.y);
      }
    }
    final w = right - left, h = bottom - top;
    return math.sqrt(w * w + h * h);
  }

  /// [p], carried as the line it lies against moved from `pair.$1` to
  /// `pair.$2`: each end's displacement, shared out along the line.
  static Vec2 _carried(Vec2 p, (Segment, Segment) pair) {
    final (from, to) = pair;
    final t = from.parameterOf(p).clamp(0.0, 1.0);
    return p + (to.a - from.a) * (1 - t) + (to.b - from.b) * t;
  }
}
