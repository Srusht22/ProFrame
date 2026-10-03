import 'dart:math' as math;

import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart' show Design;
import '../model/elements.dart' show DesignKind, DimensionElement;
import '../sketch/stroke.dart';
import 'geometry_validation.dart';

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

  /// What the user has fixed about each end by stating a dimension that
  /// measures it: [pinA] for [Segment.a], [pinB] for [Segment.b]. Carried by
  /// every step, so the end keeps the figure whatever moves it.
  final SizePin pinA;
  final SizePin pinB;

  const DrawnRun(
    this.segment,
    this.strokeId, {
    this.squaredTo,
    this.pinA = SizePin.none,
    this.pinB = SizePin.none,
  });

  /// The same run, its ends at [to].
  DrawnRun moved(Segment to) => withAxis(to, squaredTo);

  /// The same run, its ends at [to] and squared to [axis].
  DrawnRun withAxis(Segment to, RunAxis? axis) =>
      DrawnRun(to, strokeId, squaredTo: axis, pinA: pinA, pinB: pinB);

  /// Whether the user's own figures put this run's two ends at different
  /// heights — for [RunAxis.level] — or different distances across: two
  /// stated sizes that say the line is not square, so it is not squared.
  bool pinnedApart(RunAxis axis) {
    final (a, b) = axis == RunAxis.level ? (pinA.y, pinB.y) : (pinA.x, pinB.x);
    return a != null && b != null && (a - b).abs() > Tol.samePointMm;
  }

  /// The coordinate the user's figures fix for this run on [axis], if any.
  double? pinnedOn(RunAxis axis) =>
      axis == RunAxis.level ? (pinA.y ?? pinB.y) : (pinA.x ?? pinB.x);
}

/// A coordinate of one end of a run that a dimension the user stated
/// measures: the end of a figure they typed, which the correction keeps
/// rather than choosing one of its own.
class SizePin {
  /// The distance across that a dimension measuring across fixes.
  final double? x;

  /// The height that a dimension measuring down fixes.
  final double? y;

  const SizePin({this.x, this.y});

  /// Nothing fixed.
  static const none = SizePin();
}

/// How far a run is out from the axis it is nearest — what the normaliser
/// decides by, rather than its angle alone.
///
/// One angle means very different things at different sizes: five degrees
/// is a few millimetres on a short rail and a hand's width on a tall jamb.
/// So a run is measured three ways, all in the drawing's own millimetres:
///
/// - [degrees], how far it turns off the axis;
/// - [errorMm], how far out it actually is — one end against the other,
///   across the axis — which is what squaring it would move;
/// - against the drawing's own size, [spanMm], because the hand's error
///   scales with what it is drawing: a design is drawn to fill the screen,
///   whatever size it will be built, so the same drawing at any scale reads
///   the same.
///
/// From those, [kind]: whether this is a wobble to clean, a lean that the
/// drawing round it must settle, or a slope that is the drawing.
class Deviation {
  /// The axis the run is nearest.
  final RunAxis axis;

  /// How far it turns off that axis.
  final double degrees;

  /// How far out it is, end against end, across the axis.
  final double errorMm;

  /// The size of the whole drawing it is part of.
  final double spanMm;

  /// Whether the design is a standard one, whose lines are meant level,
  /// upright and square — or an angled one, where they need not be.
  final bool standard;

  const Deviation._(
    this.axis,
    this.degrees,
    this.errorMm,
    this.spanMm,
    this.standard,
  );

  /// [segment], measured in a drawing [spanMm] across, in a standard
  /// design or — [standard] false — an angled one.
  factory Deviation.of(Segment segment, double spanMm, {bool standard = true}) {
    final dx = (segment.a.x - segment.b.x).abs();
    final dy = (segment.a.y - segment.b.y).abs();
    final upright = dx < dy;
    return Deviation._(
      upright ? RunAxis.upright : RunAxis.level,
      segment.offAxisDegrees,
      upright ? dx : dy,
      spanMm,
      standard,
    );
  }

  /// The finest the hand places a line in this drawing: the weld, a
  /// hundredth of its size. A run out by less than this is out by less than
  /// the hand can mean.
  double get precisionMm => Tol.weldFor(spanMm);

  /// What the deviation is.
  ///
  /// Out by less than the hand can place a line, it is a wobble in any
  /// design. Between that and `Tol.wobbleShare` of the drawing, within the
  /// snap angle, it could be the hand or it could be meant, and the drawing
  /// alone cannot say: **the category says.** A standard design's lines are
  /// meant square, so it is a wobble; an angled design is one whose user
  /// said before drawing that non-standard geometry is meant, so it is
  /// kept — a side ten centimetres out over two metres is a side drawn ten
  /// centimetres out. The pause to straighten squares any line the user
  /// asks it to, in either.
  DeviationKind get kind {
    if (errorMm == 0) return DeviationKind.none;
    if (degrees <= Tol.leanDegrees && errorMm <= precisionMm) {
      return DeviationKind.wobble;
    }
    if (standard &&
        degrees <= Tol.axisSnapDegrees &&
        errorMm <= Tol.wobbleShare * spanMm) {
      return DeviationKind.wobble;
    }
    if (degrees <= Tol.leanDegrees) return DeviationKind.lean;
    return DeviationKind.slope;
  }

  @override
  String toString() =>
      '${kind.name}: ${degrees.toStringAsFixed(1)}° off ${axis.name}, '
      '${errorMm.toStringAsFixed(1)} mm out in ${spanMm.toStringAsFixed(0)}';
}

/// What a run's [Deviation] is.
enum DeviationKind {
  /// Exactly level or upright: nothing to do.
  none,

  /// Out by less than a hand can mean — under its precision at any angle a
  /// lean may have, or within the snap angle and a small share of the
  /// drawing. Squared in every design.
  wobble,

  /// Out further than a wobble but not past `Tol.leanDegrees`: squared in a
  /// standard design where the drawing round it is square, and kept
  /// otherwise.
  lean,

  /// Further off than any lean: the drawing, kept exactly.
  slope,
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

  /// The dimensions the user has stated a figure for: the sizes they have
  /// said, which a correction keeps rather than choosing a size of its own.
  /// An end of one of these, square to an axis, fixes the coordinate it
  /// measures at the corner it was drawn to.
  final List<DimensionElement> stated;

  const NormalizationContext({
    required this.kind,
    this.ink = const {},
    this.stated = const [],
  });

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

  /// How big the drawing was: what the hand's precision is measured
  /// against.
  final double spanMm;

  const NormalizedGeometry(this.runs, this.corrections, {this.spanMm = 0});

  /// Whether anything was changed at all.
  bool get changed => corrections.isNotEmpty;

  /// The strokes a correction moved by more than the hand can place a line
  /// in this drawing ([Deviation.precisionMm], the weld): what a person
  /// would see had been put right, as against the shake taken out of every
  /// line drawn by hand.
  ///
  /// A slip of the pen that was not built ([CorrectionKind.absorbed]) is
  /// not among them: nothing of it was corrected, it was left in the
  /// sketch.
  Set<String> get noticeableStrokes {
    final precision = Tol.weldFor(spanMm);
    return {
      for (final c in corrections)
        if (c.after case final after?)
          if (math.max(c.before.a.distanceTo(after.a),
                  c.before.b.distanceTo(after.b)) >
              precision)
            c.strokeId,
    };
  }
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
  /// 1. **Square** each run whose [Deviation] is a wobble — out by less than
  ///    the hand can mean at this drawing's size — about its middle, and
  ///    remember which axis. Not by angle alone: the same five degrees is a
  ///    wobble on a rail and a visible lean on a jamb the drawing's height.
  /// 2. **Carry onto the ink** an end drawn onto another stroke, along its
  ///    own line.
  /// 3. **Join** ends drawn a little apart into one point.
  /// 4. **Trim** two runs drawn past the corner where they cross back to it
  ///    (`Tol.overshootFraction`).
  /// 5. **Square a lean**, in a standard design only: a run whose
  ///    [Deviation] is a lean, where the side opposite it or the
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

    final span = spanOf(raw);
    final pinned = _pinned(raw, context.stated, span);
    final squared = [
      for (final run in pinned)
        _squared(run, span, standard: context.isStandard),
    ];
    for (var i = 0; i < raw.length; i++) {
      note(CorrectionKind.squared, raw[i], squared[i]);
    }

    final carried = _ontoWhatTheyWereDrawnOn(squared, context.ink);
    for (var i = 0; i < squared.length; i++) {
      note(CorrectionKind.carriedOnto, squared[i], carried[i]);
    }

    final joined = _joined(carried, drawn: raw);
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
    return NormalizedGeometry(square, corrections, spanMm: span);
  }

  /// [run] squared, about its middle, where its [Deviation] in a drawing
  /// [spanMm] across is a wobble — and marked with its axis where it is
  /// square, already or now.
  static DrawnRun _squared(
    DrawnRun run,
    double spanMm, {
    required bool standard,
  }) {
    final s = run.segment;
    final deviation = Deviation.of(s, spanMm, standard: standard);
    switch (deviation.kind) {
      case DeviationKind.none:
        return run.withAxis(s, deviation.axis);
      case DeviationKind.wobble when !run.pinnedApart(deviation.axis):
        // To the figure the user stated where an end has one; about its
        // middle where neither does.
        final middle = s.midpoint;
        final fixed = run.pinnedOn(deviation.axis);
        final to = deviation.axis == RunAxis.upright
            ? Segment(
                Vec2(fixed ?? middle.x, s.a.y),
                Vec2(fixed ?? middle.x, s.b.y),
              )
            : Segment(
                Vec2(s.a.x, fixed ?? middle.y),
                Vec2(s.b.x, fixed ?? middle.y),
              );
        return run.withAxis(to, deviation.axis);
      case DeviationKind.wobble || DeviationKind.lean || DeviationKind.slope:
        return run.withAxis(s, null);
    }
  }

  /// [runs], each end carrying what the user's [stated] dimensions fix
  /// there.
  ///
  /// A stated dimension square to an axis measures one coordinate — a
  /// height for one running down, a distance across for one running across
  /// — between its two ends, and those ends were put on the corners it
  /// measures. So a run end within the join tolerance of one is pinned to
  /// that coordinate: whatever the correction then does, that corner keeps
  /// the figure the user typed, and the design, its dimensions and both
  /// views agree. A dimension at a slope fixes no axis, and pins nothing.
  static List<DrawnRun> _pinned(
    List<DrawnRun> runs,
    List<DimensionElement> stated,
    double spanMm,
  ) {
    if (stated.isEmpty) return runs;
    final reach = _joinToleranceFor(spanMm);
    SizePin pinAt(Vec2 p) {
      double? x, y;
      for (final d in stated) {
        if (d.measuredMm <= 0) continue;
        if (Segment(d.a, d.b).offAxisDegrees > Tol.axisSnapDegrees) continue;
        final down = (d.a.y - d.b.y).abs() > (d.a.x - d.b.x).abs();
        for (final end in [d.a, d.b]) {
          if (end.distanceTo(p) > reach) continue;
          if (down) {
            y ??= end.y;
          } else {
            x ??= end.x;
          }
        }
      }
      return x == null && y == null ? SizePin.none : SizePin(x: x, y: y);
    }

    return [
      for (final run in runs)
        DrawnRun(
          run.segment,
          run.strokeId,
          squaredTo: run.squaredTo,
          pinA: pinAt(run.segment.a),
          pinB: pinAt(run.segment.b),
        ),
    ];
  }

  /// How near two ends must be to be joined, in a drawing [spanMm] across.
  static double _joinToleranceFor(double spanMm) =>
      math.max(spanMm * Tol.joinFraction * 0.25, Tol.minLineMm);

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
    final span = spanOf(runs);
    RunAxis? leanOf(DrawnRun run) {
      if (run.squaredTo != null) return null;
      final deviation = Deviation.of(run.segment, span);
      if (run.pinnedApart(deviation.axis)) return null;
      return switch (deviation.kind) {
        DeviationKind.lean || DeviationKind.wobble => deviation.axis,
        DeviationKind.none || DeviationKind.slope => null,
      };
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
          final RunAxis axis when squarable(run, axis) => run.withAxis(
            run.segment,
            axis,
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
    // What the user's stated sizes fix at each point, from every run end
    // that lies there.
    final pinX = List<double?>.filled(points.length, null);
    final pinY = List<double?>.filled(points.length, null);
    for (var i = 0; i < runs.length; i++) {
      final (a, b) = ends[i];
      for (final (point, pin) in [(a, runs[i].pinA), (b, runs[i].pinB)]) {
        pinX[point] ??= pin.x;
        pinY[point] ??= pin.y;
      }
    }
    final y = ys.settled([for (final p in points) p.y], pinY);
    final x = xs.settled([for (final p in points) p.x], pinX);
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
  static List<DrawnRun?> _joined(
    List<DrawnRun> runs, {
    required List<DrawnRun> drawn,
  }) {
    final tolerance = _joinToleranceFor(spanOf(runs));

    // **Two lines drawn past each other at a corner are not joined end to
    // end.** Each runs on past the point where the two cross, so their ends
    // lie out beyond the corner, a little way apart. Averaging them put the
    // corner on neither line, the trim then had no loose ends to take back,
    // and keeping the frame square carried both lines off where they were
    // drawn: a head and a jamb each drawn 4 cm past their corner came back a
    // centimetre outside it. Left apart here, they are trimmed back to the
    // crossing, which is on both lines (`_trimmedAtCorners`).
    //
    // Only where it is plainly that, **in the ink** ([drawn], the runs
    // before anything was squared — the same runs, in the same order): both
    // ends past the crossing by more than the hand can place a line (the
    // weld), and no other end at that corner. A line that wobbles a few
    // millimetres through a corner other lines also meet is joined as it
    // always was; and two legs that squaring each about its middle has
    // pushed past a corner the user drew closed are joined too, because
    // the user did not draw them past it.
    final hand = Tol.weldFor(spanOf(drawn));
    final allEnds = [
      for (final run in drawn) ...[run.segment.a, run.segment.b],
    ];
    int endsNear(Vec2 p) =>
        allEnds.where((q) => q.distanceTo(p) <= tolerance).length;
    final drawnPast = <(int, int)>{};
    for (var i = 0; i < drawn.length; i++) {
      for (var j = i + 1; j < drawn.length; j++) {
        final cross = drawn[i].segment.crossing(drawn[j].segment);
        if (cross == null) continue;
        final at = cross.at;
        final ei = [drawn[i].segment.a, drawn[i].segment.b];
        final ej = [drawn[j].segment.a, drawn[j].segment.b];
        for (var e = 0; e < 2; e++) {
          for (var f = 0; f < 2; f++) {
            if (ei[e].distanceTo(ej[f]) > tolerance) continue;
            final past = ei[e].distanceTo(at), over = ej[f].distanceTo(at);
            // Ends on the crossing, or within a hand of it, meet there.
            if (past <= hand || over <= hand) continue;
            if (endsNear(ei[e]) != 2 || endsNear(ej[f]) != 2) continue;
            if (past > Tol.overshootFraction * drawn[i].segment.length ||
                over > Tol.overshootFraction * drawn[j].segment.length) {
              continue;
            }
            drawnPast
              ..add((i, e))
              ..add((j, f));
          }
        }
      }
    }

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
      for (final (i, run) in runs.indexed)
        run.moved(
          Segment(
            drawnPast.contains((i, 0))
                ? run.segment.a
                : anchorFor(run.segment.a),
            drawnPast.contains((i, 1))
                ? run.segment.b
                : anchorFor(run.segment.b),
          ),
        ),
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
      for (final (i, run) in welded.indexed)
        if (_endOf(run.segment.a, drawnPast.contains((i, 0)), settled)
                .distanceTo(
                  _endOf(run.segment.b, drawnPast.contains((i, 1)), settled),
                ) >=
            Tol.minLineMm)
          run.moved(
            Segment(
              _endOf(run.segment.a, drawnPast.contains((i, 0)), settled),
              _endOf(run.segment.b, drawnPast.contains((i, 1)), settled),
            ),
          )
        else
          null,
    ];
  }

  /// [point], read back to the anchor it was joined into — unless it is an
  /// end drawn past a corner, which was left where it was ([_joined]).
  static Vec2 _endOf(
    Vec2 point,
    bool drawnPast,
    Vec2 Function(Vec2) settled,
  ) => drawnPast ? point : settled(point);

  /// Everything wrong with an angled [design]'s geometry — or any design's
  /// — and nothing changed.
  ///
  /// An angled design is not squared: its slopes, its unequal heights and
  /// its sides that are not parallel are the drawing. It is still held to
  /// what anything built must be: coordinates that are numbers, an outline
  /// that closes without crossing itself, bars joined to the design, every
  /// child inside its parent, openings holding their own marks and their
  /// ironmongery on their leaves, and dimensions that measure what they say.
  /// See [GeometryValidation].
  static List<GeometryProblem> validateAngledGeometry(Design design) =>
      GeometryValidation.of(design);

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

  /// [values], with every point in a group of more than one given one
  /// value: the figure the user stated where any point of the group is
  /// [pinned] to one, and otherwise the average of the group — the line
  /// that best fits the ends as drawn, neither the larger nor the smaller.
  ///
  /// A group whose points the user's figures pin to *different* values
  /// cannot be one line without overruling one of them, and which figure is
  /// right is theirs to say: every point keeps its own value.
  List<double> settled(List<double> values, List<double?> pinned) {
    final sum = <int, double>{};
    final count = <int, int>{};
    final pins = <int, List<double>>{};
    for (var i = 0; i < values.length; i++) {
      final root = _root(i);
      sum[root] = (sum[root] ?? 0) + values[i];
      count[root] = (count[root] ?? 0) + 1;
      if (pinned[i] case final pin?) (pins[root] ??= []).add(pin);
    }
    double valueOf(int i) {
      final root = _root(i);
      if (count[root]! < 2) return values[i];
      final said = pins[root];
      if (said == null) return sum[root]! / count[root]!;
      final low = said.reduce(math.min), high = said.reduce(math.max);
      if (high - low > Tol.samePointMm) return values[i];
      return (low + high) / 2;
    }

    return [for (var i = 0; i < values.length; i++) valueOf(i)];
  }
}
