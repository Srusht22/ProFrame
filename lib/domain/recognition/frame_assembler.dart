import 'dart:math' as math;

import '../geometry/point2.dart';
import '../geometry/tolerances.dart';
import '../sketch.dart';

/// Joins strokes that were drawn as one outline.
///
/// Almost nobody draws a box in a single stroke: they draw the top, then a
/// side, then the bottom, then the other side, lifting the finger between
/// them. Read one at a time each of those is a line, and a line before there
/// is a frame means nothing — so the drawing produced nothing at all and the
/// app asked the user to draw the frame they had just drawn.
///
/// This chains them back together. It decides nothing about what the outline
/// *is*: it hands the joined path to the same classifier a single stroke goes
/// through, so a frame drawn in four strokes is held to exactly the same
/// rules — size, corner count, closure, and a sloping top kept as drawn — as
/// a frame drawn in one.
abstract final class FrameAssembler {
  /// The strokes in [sketch], joined into one closed path, or null when they
  /// do not make one.
  ///
  /// The most recent strokes are tried first: a scribble drawn before the
  /// frame should not stop the frame from being read, so the oldest stroke is
  /// dropped and the rest tried again, down to the last two.
  static List<Point2>? join(Sketch sketch) {
    final strokes = sketch.strokes;
    if (strokes.length < 2) return null;

    for (var from = 0; from <= strokes.length - 2; from++) {
      final joined = _chain(strokes.sublist(from));
      if (joined != null) return joined;
    }
    return null;
  }

  /// Chains every stroke in [strokes] end to end, or null when one of them
  /// does not reach the others, or the chain does not come back to where it
  /// started.
  ///
  /// Every stroke has to be used. A stroke left over is a line the user drew
  /// for some other reason, and building a frame out of its neighbours while
  /// ignoring it would be a guess.
  static List<Point2>? _chain(List<Stroke> strokes) {
    final paths = [
      for (final stroke in strokes)
        if (stroke.points.length >= 2) stroke.points,
    ];
    if (paths.length < 2) return null;

    final reach = _reachOf(paths);
    final remaining = paths.sublist(1);
    final chain = [...paths.first];

    while (remaining.isNotEmpty) {
      final end = chain.last;

      var bestIndex = -1;
      var bestDistance = double.infinity;
      var bestReversed = false;
      for (var i = 0; i < remaining.length; i++) {
        final toStart = end.distanceTo(remaining[i].first);
        final toEnd = end.distanceTo(remaining[i].last);
        final nearest = math.min(toStart, toEnd);
        if (nearest < bestDistance) {
          bestDistance = nearest;
          bestIndex = i;
          bestReversed = toEnd < toStart;
        }
      }

      if (bestDistance > reach) return null;
      final next = remaining.removeAt(bestIndex);
      final path = bestReversed ? next.reversed.toList() : next;

      // The two ends become one point, halfway between them. Left as they
      // were, the little jump from one stroke to the next reads as two more
      // corners, and a four-sided box would be rejected for having eight.
      // This is the same tidying a single wobbly stroke already gets — and
      // what comes out still has to pass every frame rule.
      chain[chain.length - 1] = Point2(
        (end.x + path.first.x) / 2,
        (end.y + path.first.y) / 2,
      );
      chain.addAll(path.skip(1));
    }

    // Back where it started, or it is not an outline.
    if (chain.last.distanceTo(chain.first) > reach) return null;
    return chain;
  }

  /// How far apart two ends may be and still be the same corner.
  ///
  /// Relative to the size of the thing being drawn, so it holds whether the
  /// user is sketching a window or a patio door, with the hand-drawing corner
  /// tolerance as a floor for a very small one.
  static double _reachOf(List<List<Point2>> paths) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final path in paths) {
      for (final point in path) {
        left = math.min(left, point.x);
        top = math.min(top, point.y);
        right = math.max(right, point.x);
        bottom = math.max(bottom, point.y);
      }
    }

    final width = right - left;
    final height = bottom - top;
    final diagonal = math.sqrt(width * width + height * height);
    return math.max(
      Tolerances.cornerToleranceMm,
      diagonal * Tolerances.strokeJoinFraction,
    );
  }
}
