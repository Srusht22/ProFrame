import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/elements.dart' show DesignKind;
import '../sketch/stroke.dart';
import 'stroke_fit.dart';

/// Which axis a run was squared to, if any.
enum RunAxis {
  /// Squared level: both ends at one height.
  level,

  /// Squared upright: both ends at one distance across.
  upright,
}

/// One straight leg of one stroke, as the reading carries it from the fit to
/// the planar subdivision.
class DrawnRun {
  final Segment segment;

  /// The stroke it was read from — the thread back to the user's own hand.
  final String strokeId;

  /// The axis the run was squared to, or null where it keeps the angle it
  /// was drawn at. Set by [GeometryNormalizer] and carried by every later
  /// step, so a run squared once stays square whatever moves its ends.
  final RunAxis? squaredTo;

  const DrawnRun(this.segment, this.strokeId, {this.squaredTo});

  /// The same run, its ends at [to].
  DrawnRun moved(Segment to) => DrawnRun(to, strokeId, squaredTo: squaredTo);
}

/// What the normaliser is told about the drawing beyond its lines: what is
/// being drawn, and the ink every run was read from.
class NormalizationContext {
  /// The category the user began the design as — the user's own answer to
  /// what is being built, read rather than worked out from the shape.
  ///
  /// It decides one rule: a lean squared because the drawing round it is
  /// square ([isStandard]). Everything else the normaliser does is cleaning
  /// that is the same whatever is being drawn.
  final DesignKind kind;

  /// The strokes, by id: the ink, which says where an end was really drawn
  /// when straightening has moved the line it lies on.
  final Map<String, Stroke> ink;

  const NormalizationContext({required this.kind, this.ink = const {}});

  /// Whether the design is a standard one — a door, a window, a sliding set
  /// or a door & window set — whose lines the user means level, upright and
  /// square. An angled design is not: choosing it is the user saying,
  /// before a line is drawn, that the slopes they draw are meant.
  bool get isStandard => kind != DesignKind.angled;
}

/// What a correction did.
enum CorrectionKind {
  /// A run within a few degrees of level or upright was squared to it.
  squared,

  /// An end drawn onto another line was carried onto the straight line
  /// that other line became.
  carriedOnto,

  /// Ends drawn a little apart were joined into one point.
  joined,

  /// A squared run whose ends the joining moved was made square again, its
  /// ends staying joined.
  keptSquare,

  /// A run whose two ends were joined into one point: a slip of the pen,
  /// left in the sketch and not built.
  absorbed,

  /// Two runs drawn past the corner where they cross, each trimmed back to
  /// it.
  trimmed,

  /// A run leaning further than [squared] takes, in a standard design,
  /// squared because the side opposite it or the side it turns a corner
  /// from is square.
  leaning,
}

/// One change the normaliser made to one run, and the run before and after
/// it — so what was cleaned can always be said, and checked.
class GeometryCorrection {
  final CorrectionKind kind;
  final String strokeId;
  final Segment before;

  /// Null for a run that was [CorrectionKind.absorbed].
  final Segment? after;

  const GeometryCorrection(this.kind, this.strokeId, this.before, this.after);

  @override
  String toString() => '${kind.name} $strokeId: $before → $after';
}

/// The runs of a drawing as the design is built from them, and every change
/// that was made to get there.
class NormalizedGeometry {
  final List<DrawnRun> runs;
  final List<GeometryCorrection> corrections;

  const NormalizedGeometry(this.runs, this.corrections);

  /// Whether anything was changed at all.
  bool get changed => corrections.isNotEmpty;
}

/// Where the accidental inaccuracy of a hand comes out of a drawing — and the
/// only place it does.
///
/// ```
/// strokes ─ StrokeFitter.fit ─► raw runs ─ GeometryNormalizer ─► runs
///   ─ PlanarSubdivision ─► frame, bars, sections ─► Design
///   ─► DesignTree / DesignGeometry ─► Draw, CAD, 3D
/// ```
///
/// It works on the runs of the **whole drawing at once**, because each of
/// its steps used to be a pass of its own inside the reading, and the later
/// ones undid the earlier: a run squared on its own had its ends averaged
/// with its neighbours' afterwards, so a rectangle drawn a degree out came
/// back with no square side, and two transoms drawn level either side of a
/// mullion came back as two sloped bars. In one place, in one order, a
/// correction stays made.
///
/// Its output is what the design is built from, so the correction is in the
/// canonical geometry — the frame's outline and the bars of `Design` — and
/// every view shows it because every view reads that. Nothing here draws,
/// and nothing here knows there are views.
///
/// **It cleans and never redesigns** — the table *Where the line falls* in
/// `CLAUDE.md`. It squares a run a hand drew a few degrees off level or
/// upright, carries an end back onto the line it was drawn onto, joins ends
/// drawn a little apart, trims two runs drawn past their corner back to it,
/// and keeps a squared run square when its ends are joined. In a standard
/// design — not an angled one — it also squares a run leaning up to
/// `Tol.leanDegrees` where the drawing round it is square. Any other run
/// keeps the angle it was drawn at, exactly; nothing is made equal,
/// symmetrical or regular; no run is added; an outline drawn open is not
/// closed; and every run comes out in the same order it went in, from the
/// same stroke, so the reading can pair it with what it made last time.
abstract final class GeometryNormalizer {
  /// The runs of a drawing whose lines were meant level, upright or meeting,
  /// as the design is to be built from them.
  ///
  /// The steps, in their order:
  ///
  /// 1. **Square** each run within `Tol.axisSnapDegrees` of an axis
  ///    (`StrokeFitter.straightened`), and remember which axis.
  /// 2. **Carry onto the ink** an end drawn onto another stroke, along its
  ///    own line.
  /// 3. **Join** ends drawn a little apart into one point.
  /// 4. **Trim** two runs drawn past the corner where they cross back to it
  ///    (`Tol.overshootFraction`).
  /// 5. **Square a lean**, in a standard design only: a run up to
  ///    `Tol.leanDegrees` off an axis, where the side opposite it or the
  ///    side it turns a corner from is square, and squaring it changes the
  ///    width of what it bounds by no more than `Tol.leanShare`.
  /// 6. **Keep square**: every run squared in step 1 or 5 is made square
  ///    with its ends still joined, by giving the joined points that a
  ///    level run runs between one height, and those an upright runs
  ///    between one distance across. A closed outline is closed after it,
  ///    because a point two runs share is moved as one point.
  static NormalizedGeometry normalizeStandardGeometry(
    List<DrawnRun> raw,
    NormalizationContext context,
  ) {
    final corrections = <GeometryCorrection>[];
    void note(CorrectionKind kind, DrawnRun was, DrawnRun? now) {
      if (now != null && _same(was.segment, now.segment)) return;
      corrections.add(
        GeometryCorrection(kind, was.strokeId, was.segment, now?.segment),
      );
    }

    final squared = [for (final run in raw) _squared(run)];
    for (var i = 0; i < raw.length; i++) {
      note(CorrectionKind.squared, raw[i], squared[i]);
    }

    final carried = _ontoWhatTheyWereDrawnOn(squared, context.ink);
    for (var i = 0; i < squared.length; i++) {
      note(CorrectionKind.carriedOnto, squared[i], carried[i]);
    }

    final joined = _joined(carried);
    final kept = <DrawnRun>[];
    for (var i = 0; i < carried.length; i++) {
      final run = joined[i];
      note(
        run == null ? CorrectionKind.absorbed : CorrectionKind.joined,
        carried[i],
        run,
      );
      if (run != null) kept.add(run);
    }

    final trimmed = _trimmedAtCorners(kept);
    for (var i = 0; i < kept.length; i++) {
      note(CorrectionKind.trimmed, kept[i], trimmed[i]);
    }

    final leaning = context.isStandard ? _leansSquared(trimmed) : trimmed;
    final square = _keptSquare(leaning);
    for (var i = 0; i < leaning.length; i++) {
      note(
        leaning[i].squaredTo == trimmed[i].squaredTo
            ? CorrectionKind.keptSquare
            : CorrectionKind.leaning,
        trimmed[i],
        square[i],
      );
    }
    return NormalizedGeometry(square, corrections);
  }

  /// [run] squared to the axis it is within a few degrees of, and marked so.
  static DrawnRun _squared(DrawnRun run) {
    final to = StrokeFitter.straightened(run.segment);
    final axis = to.a.y == to.b.y && to.a.x != to.b.x
        ? RunAxis.level
        : to.a.x == to.b.x && to.a.y != to.b.y
        ? RunAxis.upright
        : null;
    return DrawnRun(to, run.strokeId, squaredTo: axis);
  }

  /// Two runs drawn past the corner where they cross, trimmed back to it.
  ///
  /// A hand drawing a frame side by side runs the head on past the jamb, or
  /// closes the loop past where it began. The two lines cross a little way
  /// from an end of each: that crossing is the corner the user drew, and
  /// what lies beyond it is the pen not stopping. Left alone, the stub is a
  /// bar lying along the frame that nobody drew.
  ///
  /// Only an end that meets no other end, only where the lines genuinely
  /// cross, and only where each end is within `Tol.overshootFraction` of its
  /// own run from the crossing. An end that stops *short* of the other line
  /// further than the join reaches is not touched: that is an outline left
  /// open, and the user is asked about it rather than having it closed for
  /// them.
  static List<DrawnRun> _trimmedAtCorners(List<DrawnRun> runs) {
    final meeting = <Vec2, int>{};
    for (final run in runs) {
      for (final p in [run.segment.a, run.segment.b]) {
        meeting[p] = (meeting[p] ?? 0) + 1;
      }
    }
    final weld = Tol.weldFor(spanOf(runs));
    final ends = [
      for (final run in runs) [run.segment.a, run.segment.b],
    ];
    final done = <(int, int)>{};
    bool loose(int run, int end) =>
        !done.contains((run, end)) && meeting[ends[run][end]] == 1;

    for (var i = 0; i < runs.length; i++) {
      for (var j = i + 1; j < runs.length; j++) {
        final cross = runs[i].segment.crossing(
          runs[j].segment,
          tolerance: weld,
        );
        if (cross == null) continue;
        final at = cross.at;
        for (var e = 0; e < 2; e++) {
          for (var f = 0; f < 2; f++) {
            if (!loose(i, e) || !loose(j, f)) continue;
            final past = ends[i][e].distanceTo(at);
            final over = ends[j][f].distanceTo(at);
            if (past <= Tol.samePointMm && over <= Tol.samePointMm) continue;
            if (past > Tol.overshootFraction * runs[i].segment.length ||
                over > Tol.overshootFraction * runs[j].segment.length) {
              continue;
            }
            ends[i][e] = at;
            ends[j][f] = at;
            done
              ..add((i, e))
              ..add((j, f));
          }
        }
      }
    }
    return [
      for (var i = 0; i < runs.length; i++)
        runs[i].moved(Segment(ends[i][0], ends[i][1])),
    ];
  }

  /// [runs], with every lean of the hand in a standard design marked to be
  /// squared by [_keptSquare].
  ///
  /// A run further off an axis than `Tol.axisSnapDegrees` is ordinarily a
  /// slope, and kept. But in a door or a window the drawing round it can
  /// say otherwise, and a rectangle drawn with one leaning side is still a
  /// rectangle: the brief's own example. So a run up to `Tol.leanDegrees`
  /// off an axis is squared when either
  ///
  /// - **the side opposite it is square** — a run squared to the same axis,
  ///   alongside it for at least half its length: a jamb leaning beside an
  ///   upright jamb, a head tilted over a level sill; or
  /// - **it turns a corner from a square side** — it shares an end with a
  ///   run squared to the other axis: the jamb meeting a level head;
  ///
  /// and squaring it moves its far end by no more than `Tol.leanShare` of
  /// the width of what it bounds — the gap to the side opposite, or the
  /// length of the side it turns from. More than that and the lean is the
  /// shape of the thing, not a wobble in drawing it.
  ///
  /// Only runs squared in the first step count as square here, so a lean
  /// is never squared on the strength of another lean: two jambs leaning
  /// the same way under a head that leans too have nothing square to go by,
  /// and are kept as drawn.
  static List<DrawnRun> _leansSquared(List<DrawnRun> runs) {
    RunAxis? leanOf(DrawnRun run) {
      if (run.squaredTo != null) return null;
      final s = run.segment;
      if (s.offAxisDegrees > Tol.leanDegrees) return null;
      return (s.a.x - s.b.x).abs() < (s.a.y - s.b.y).abs()
          ? RunAxis.upright
          : RunAxis.level;
    }

    bool squarable(DrawnRun run, RunAxis axis) {
      final s = run.segment;
      final upright = axis == RunAxis.upright;
      // How far squaring moves it: one end against the other, across.
      final across = upright ? (s.a.x - s.b.x).abs() : (s.a.y - s.b.y).abs();
      double along(Vec2 p) => upright ? p.y : p.x;
      double side(Vec2 p) => upright ? p.x : p.y;

      for (final other in runs) {
        if (identical(other, run) || other.squaredTo == null) continue;
        final o = other.segment;
        final double room;
        if (other.squaredTo == axis) {
          final from = math.max(
            math.min(along(s.a), along(s.b)),
            math.min(along(o.a), along(o.b)),
          );
          final to = math.min(
            math.max(along(s.a), along(s.b)),
            math.max(along(o.a), along(o.b)),
          );
          final extent = (along(s.a) - along(s.b)).abs();
          if (to - from < extent / 2) continue;
          room = (side(o.a) - side(s.midpoint)).abs();
        } else {
          final corner = {s.a, s.b}.intersection({o.a, o.b}).isNotEmpty;
          if (!corner) continue;
          room = o.length;
        }
        if (across <= Tol.leanShare * room) return true;
      }
      return false;
    }

    return [
      for (final run in runs)
        switch (leanOf(run)) {
          final RunAxis axis when squarable(run, axis) => DrawnRun(
            run.segment,
            run.strokeId,
            squaredTo: axis,
          ),
          _ => run,
        },
    ];
  }

  /// Every run that was squared, square again — with every end that was
  /// joined to another still joined to it.
  ///
  /// Joining averages the ends that meet, and an average of a level run's
  /// end and an upright run's end is on neither: left there, the rectangle
  /// a hand drew a degree out came back with no square side at all. So the
  /// joined points are grouped — the two ends of a level run in one group
  /// for height, the two ends of an upright run in one group for distance
  /// across, and groups that share a point are one group — and each group
  /// is given the average of its points. A point in no group keeps where it
  /// is, so a run drawn at a slope moves only where its end is a corner it
  /// shares with a squared run, and then only as far as that corner did.
  static List<DrawnRun> _keptSquare(List<DrawnRun> runs) {
    if (runs.isEmpty) return runs;
    final points = <Vec2>[];
    int indexOf(Vec2 p) {
      final at = points.indexOf(p);
      if (at >= 0) return at;
      points.add(p);
      return points.length - 1;
    }

    final ends = [
      for (final run in runs) (indexOf(run.segment.a), indexOf(run.segment.b)),
    ];
    final ys = _Groups(points.length);
    final xs = _Groups(points.length);
    for (var i = 0; i < runs.length; i++) {
      final (a, b) = ends[i];
      switch (runs[i].squaredTo) {
        case RunAxis.level:
          ys.join(a, b);
        case RunAxis.upright:
          xs.join(a, b);
        case null:
          break;
      }
    }
    final y = ys.averages([for (final p in points) p.y]);
    final x = xs.averages([for (final p in points) p.x]);
    Vec2 at(int i) => Vec2(x[i], y[i]);
    return [
      for (var i = 0; i < runs.length; i++)
        runs[i].moved(Segment(at(ends[i].$1), at(ends[i].$2))),
    ];
  }

  static bool _same(Segment a, Segment b) =>
      a.a.distanceTo(b.a) < 1e-9 && a.b.distanceTo(b.b) < 1e-9;

  /// Each end of a run that the user drew **onto** another line, carried
  /// onto the straight line that other line became.
  ///
  /// **An end that touches a line on the sheet touches it in the design.**
  /// That is a fact of the drawing, and straightening is not allowed to
  /// break it. A hand's outline is straightened leg by leg — a kink of a few
  /// centimetres in a metre-long jamb is wobble, and taking it out is the
  /// cleaning this file exists to do — but the straight leg can then lie a
  /// hand's width from where the user actually drew it, and a transom drawn
  /// to their jamb now stops short of the straightened one. It divides
  /// nothing on that side: the light above it and the light below run
  /// together, and a `<` the user drew in a small upper light opened the
  /// whole column from head to sill.
  ///
  /// So the question is asked of the **ink**, not of the fit. An end within
  /// a weld of another stroke's own samples was drawn onto it, and is moved
  /// along its own line to where that line meets the leg the stroke became.
  /// Along its own line, so the angle the user drew it at is kept; never
  /// further than that stroke's straightening was allowed to move it, so
  /// this can only undo the fitter's own displacement and never reach
  /// across the design; and only when the fit really did move the line
  /// away, so an end already on its line is left exactly where it was.
  static List<DrawnRun> _ontoWhatTheyWereDrawnOn(
    List<DrawnRun> runs,
    Map<String, Stroke> drawn,
  ) {
    final weld = Tol.weldFor(spanOf(runs));
    final legs = <String, List<Segment>>{};
    for (final run in runs) {
      legs.putIfAbsent(run.strokeId, () => []).add(run.segment);
    }

    double offTheInk(Vec2 point, Stroke stroke) {
      final ink = stroke.points;
      var nearest = double.infinity;
      for (var i = 1; i < ink.length; i++) {
        nearest = math.min(
          nearest,
          Segment(ink[i - 1], ink[i]).distanceTo(point),
        );
      }
      return nearest;
    }

    Vec2 follow(Vec2 end, Vec2 from, String own) {
      final along = end - from;
      if (along.length <= Tol.samePointMm) return end;

      Vec2? best;
      var nearest = double.infinity;
      for (final entry in legs.entries) {
        if (entry.key == own) continue;
        final stroke = drawn[entry.key];
        if (stroke == null || offTheInk(end, stroke) > weld) continue;

        var already = double.infinity;
        for (final leg in entry.value) {
          already = math.min(already, leg.distanceTo(end));
        }
        if (already <= weld) continue;

        // How far that stroke's own straightening could have moved it —
        // the fitter's tolerance for it, not a figure chosen here.
        final allowance = math.max(
          stroke.diagonal * Tol.cornerFraction,
          Tol.cornerFloorMm,
        );
        for (final leg in entry.value) {
          final hit = _whereLinesMeet(from, end, leg);
          if (hit == null || leg.distanceTo(hit) > weld) continue;
          if ((hit - from).dot(along) <= 0) continue;
          final move = hit.distanceTo(end);
          if (move > allowance + weld || move >= nearest) continue;
          best = hit;
          nearest = move;
        }
      }
      return best ?? end;
    }

    return [
      for (final run in runs)
        run.moved(
          Segment(
            follow(run.segment.a, run.segment.b, run.strokeId),
            follow(run.segment.b, run.segment.a, run.strokeId),
          ),
        ),
    ];
  }

  /// Where the line through [from] and [to] meets the line [leg] lies on.
  static Vec2? _whereLinesMeet(Vec2 from, Vec2 to, Segment leg) {
    final r = to - from;
    final s = leg.direction;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-9) return null;
    final t = (leg.a - from).cross(s) / denominator;
    return from + r * t;
  }

  /// Ends that met joined into one point.
  ///
  /// Ends within the join tolerance of one another share one anchor, the
  /// average of the ends that met there, so no one stroke wins over the
  /// others. A run's list place is kept: one with nothing left of it once
  /// its ends have met is null.
  static List<DrawnRun?> _joined(List<DrawnRun> runs) {
    final span = spanOf(runs);
    final tolerance = math.max(span * Tol.joinFraction * 0.25, Tol.minLineMm);

    final anchors = <Vec2>[];
    Vec2 anchorFor(Vec2 point) {
      for (var i = 0; i < anchors.length; i++) {
        if (anchors[i].distanceTo(point) <= tolerance) {
          // The anchor drifts to the average of the ends that met there, so
          // no one stroke wins over the others.
          anchors[i] = anchors[i].lerp(point, 0.5);
          return anchors[i];
        }
      }
      anchors.add(point);
      return point;
    }

    final welded = [
      for (final run in runs)
        run.moved(Segment(anchorFor(run.segment.a), anchorFor(run.segment.b))),
    ];

    // Anchors moved while welding, so read them back to their final places.
    Vec2 settled(Vec2 point) {
      for (final anchor in anchors) {
        if (anchor.distanceTo(point) <= tolerance) return anchor;
      }
      return point;
    }

    // A run whose two ends met in one anchor has nothing left of it; it
    // stays in the list as null, so every run still lines up with the one
    // it was, and the caller says what became of it.
    return [
      for (final run in welded)
        if (settled(run.segment.a).distanceTo(settled(run.segment.b)) >=
            Tol.minLineMm)
          run.moved(Segment(settled(run.segment.a), settled(run.segment.b)))
        else
          null,
    ];
  }

  /// The diagonal of everything [runs] reach: the size every tolerance in
  /// the reading is a share of.
  static double spanOf(List<DrawnRun> runs) {
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (final run in runs) {
      for (final p in [run.segment.a, run.segment.b]) {
        left = math.min(left, p.x);
        right = math.max(right, p.x);
        top = math.min(top, p.y);
        bottom = math.max(bottom, p.y);
      }
    }
    final w = right - left, h = bottom - top;
    return math.sqrt(w * w + h * h);
  }
}

/// Points joined into groups, each group given the average of what its
/// points held.
class _Groups {
  final List<int> _parent;

  _Groups(int n) : _parent = [for (var i = 0; i < n; i++) i];

  int _root(int i) {
    while (_parent[i] != i) {
      _parent[i] = _parent[_parent[i]];
      i = _parent[i];
    }
    return i;
  }

  void join(int a, int b) => _parent[_root(a)] = _root(b);

  /// [values], with every point in a group of more than one given the
  /// average of its group.
  List<double> averages(List<double> values) {
    final sum = <int, double>{};
    final count = <int, int>{};
    for (var i = 0; i < values.length; i++) {
      final root = _root(i);
      sum[root] = (sum[root] ?? 0) + values[i];
      count[root] = (count[root] ?? 0) + 1;
    }
    return [
      for (var i = 0; i < values.length; i++) sum[_root(i)]! / count[_root(i)]!,
    ];
  }
}
