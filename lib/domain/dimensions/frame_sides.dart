import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../sections/section_builder.dart';
import '../sketch/stroke.dart';
import '../text/names.dart';
import '../text/words.dart';
import 'measurements.dart' show MeasureAxis;

/// One side of a frame that is not a rectangle, with a size of its own.
///
/// A window under a stair has a short jamb and a tall one; a frame with a
/// sloped head has a left side of 200 cm and a right side of 150. The
/// overall height is the tallest of them and says nothing about the
/// others, so each upright side shorter than the whole, and each level
/// side narrower than it, is a figure of its own — measured on the side
/// that is there, never made equal to another.
///
/// A side has an end that stays — its **anchor**, on the floor where it
/// stands on the sill, or at the side of the frame where a level edge
/// meets the jamb — and an end that moves when its size is given, its
/// **free** end. A slope is not a side: it is what joins the sides, and it
/// follows them.
class FrameSide {
  /// Which edge of the frame's outline it is.
  final int edge;

  /// Down for an upright side, across for a level one.
  final MeasureAxis axis;

  /// The corner of the outline that stays, and the corner that moves.
  final int anchor;
  final int free;

  /// What it is called: *Right jamb height*, *Head width*.
  final String label;

  /// The frame member it is (`FrameMemberElement.placement`), and its
  /// number where two sides share a name — what [labelIn] is said from.
  final String placement;
  final int? number;

  const FrameSide({
    required this.edge,
    required this.axis,
    required this.anchor,
    required this.free,
    required this.label,
    this.placement = '',
    this.number,
  });

  /// [label], in [w].
  String labelIn(Words w) {
    final side = placementIn(w, placement);
    final said = axis == MeasureAxis.down
        ? w.sideHeight(side)
        : w.sideWidth(side);
    return number == null ? said : '$said $number';
  }

  /// The key its size is kept under in [Design.measured].
  String get key => FrameSides.keyOf(edge);

  /// How long it is on [outline], along its axis.
  double lengthOn(Polygon outline) {
    final a = outline.corners[anchor];
    final b = outline.corners[free];
    return axis == MeasureAxis.down ? (b.y - a.y).abs() : (b.x - a.x).abs();
  }
}

/// The sides of a frame that is not a rectangle, and the one way a side, or
/// the whole, is given a size on such a frame.
abstract final class FrameSides {
  static const _prefix = 'side:';

  /// How far a corner may be from an extreme, or an edge from square, and
  /// still be on it: a reading leaves both exact, so this is rounding.
  static const double _on = Tol.samePointMm;

  static String keyOf(int edge) => '$_prefix$edge';

  /// The edge [key] names, or null when it names no side.
  static int? edgeOf(String key) => key.startsWith(_prefix)
      ? int.tryParse(key.substring(_prefix.length))
      : null;

  /// Whether [outline] is a rectangle square to the axes — the one shape
  /// whose overall width and height say everything about its sides.
  static bool isRectangle(Polygon outline) {
    if (outline.corners.length != 4) return false;
    for (final e in outline.edges) {
      if ((e.a.x - e.b.x).abs() > _on && (e.a.y - e.b.y).abs() > _on) {
        return false;
      }
    }
    return true;
  }

  /// The sides of [design]'s frame that have a size of their own: every
  /// upright side shorter than the frame is high and every level side
  /// narrower than it is wide. None on a rectangle, and none on a side the
  /// user left open.
  static List<FrameSide> of(Design design) {
    final frame = design.frame;
    if (frame == null) return const [];
    final outline = frame.outline;
    if (outline.corners.length < 3 || isRectangle(outline)) return const [];
    final corners = outline.corners;
    final n = corners.length;
    final members = {for (final m in design.frameMembers) m.index: m};

    final sides = <FrameSide>[];
    for (var i = 0; i < n; i++) {
      final member = members[i];
      if (member == null) continue;
      final j = (i + 1) % n;
      final a = corners[i], b = corners[j];
      final upright = (a.x - b.x).abs() <= _on && (a.y - b.y).abs() > _on;
      final level = (a.y - b.y).abs() <= _on && (a.x - b.x).abs() > _on;
      if (!upright && !level) continue;

      bool atLow(Vec2 p) => upright
          ? (p.y - outline.top).abs() <= _on
          : (p.x - outline.left).abs() <= _on;
      bool atHigh(Vec2 p) => upright
          ? (p.y - outline.bottom).abs() <= _on
          : (p.x - outline.right).abs() <= _on;
      // A side running the whole height or width is the overall figure.
      if ((atLow(a) && atHigh(b)) || (atHigh(a) && atLow(b))) continue;

      // It stays where the frame stands — the sill for an upright side, the
      // right-hand side for a level one, the sides the overall figures keep
      // still — or at the other extreme, or failing both at its lower or
      // right-hand end.
      final int anchor;
      if (atHigh(a) || atHigh(b)) {
        anchor = atHigh(a) ? i : j;
      } else if (atLow(a) || atLow(b)) {
        anchor = atLow(a) ? i : j;
      } else {
        anchor = (upright ? a.y > b.y : a.x > b.x) ? i : j;
      }
      sides.add(
        FrameSide(
          edge: i,
          axis: upright ? MeasureAxis.down : MeasureAxis.across,
          anchor: anchor,
          free: anchor == i ? j : i,
          label: '${member.placement} ${upright ? 'height' : 'width'}',
          placement: member.placement,
        ),
      );
    }

    // Two sides of one name — a stepped head — are told apart by number.
    final counts = <String, int>{};
    for (final s in sides) {
      counts[s.label] = (counts[s.label] ?? 0) + 1;
    }
    final seen = <String, int>{};
    return [
      for (final s in sides)
        if (counts[s.label]! < 2)
          s
        else
          FrameSide(
            edge: s.edge,
            axis: s.axis,
            anchor: s.anchor,
            free: s.free,
            label: '${s.label} ${seen[s.label] = (seen[s.label] ?? 0) + 1}',
            placement: s.placement,
            number: seen[s.label],
          ),
    ];
  }

  /// The sides of [design] whose size is asked for, as against worked out
  /// from the others.
  ///
  /// A side is asked only where giving it moves no side already asked: on
  /// a stepped frame the step and the jamb beyond it add up to the height,
  /// so only one of them is free, and the other follows — the same rule
  /// as a row of lights, whose last width is what is left.
  static Set<int> askedOf(Design design) {
    final frame = design.frame;
    if (frame == null) return const {};
    final sides = of(design);
    final asked = <int>{};
    final corners = frame.outline.corners;
    for (final side in sides) {
      final moved = Polygon(
        _carried(corners, {side.free}, side.axis, _probe(side, corners)),
      );
      final undoes = sides.any(
        (other) =>
            asked.contains(other.edge) &&
            (other.lengthOn(moved) - other.lengthOn(frame.outline)).abs() >
                1e-6,
      );
      if (!undoes) asked.add(side.edge);
    }
    return asked;
  }

  static double _probe(FrameSide side, List<Vec2> corners) {
    final a = corners[side.anchor], b = corners[side.free];
    final away = side.axis == MeasureAxis.down ? b.y - a.y : b.x - a.x;
    return away.sign * 10;
  }

  /// [design] with [side] made [valueMm] long: its free corner moved along
  /// it, and nothing else of the frame — the slope that joins it to the
  /// next side follows, and stays a straight slope. Null when that is not
  /// a frame any more or the parts inside it no longer fit.
  static Design? sized(Design design, FrameSide side, double valueMm) {
    final frame = design.frame;
    if (frame == null || valueMm <= 0) return null;
    final corners = frame.outline.corners;
    final a = corners[side.anchor], b = corners[side.free];
    final away = side.axis == MeasureAxis.down ? b.y - a.y : b.x - a.x;
    final by = away.sign * (valueMm - side.lengthOn(frame.outline));
    if (by.abs() < 1e-9) return design;
    return reshaped(design, _carried(corners, {side.free}, side.axis, by));
  }

  /// [design] with its overall size along [axis] made [valueMm], on a frame
  /// that is not a rectangle.
  ///
  /// The far side — the sill, the right-hand jamb — moves, and every side
  /// that stands on it moves with it, so each keeps the size it has: a
  /// right side of 150 cm is still 150 cm when the window is made taller,
  /// and it is the slope between the sides that takes the difference. On a
  /// rectangle the whole sheet is stretched instead (`Measurements.stretch`).
  static Design? overall(Design design, MeasureAxis axis, double valueMm) {
    final frame = design.frame;
    if (frame == null) return null;
    final outline = frame.outline;
    final down = axis == MeasureAxis.down;
    final by = valueMm - (down ? outline.height : outline.width);
    if (by.abs() < 1e-9) return design;
    final corners = outline.corners;
    final far = down ? outline.bottom : outline.right;
    final start = <int>{
      for (var i = 0; i < corners.length; i++)
        if (((down ? corners[i].y : corners[i].x) - far).abs() <= _on) i,
    };
    final asked = askedOf(design);
    for (final side in of(design)) {
      if (side.axis == axis &&
          asked.contains(side.edge) &&
          start.contains(side.anchor)) {
        start.add(side.free);
      }
    }
    return reshaped(design, _carried(corners, start, axis, by));
  }

  /// [corners] with [start] moved [by] along [axis], and every corner
  /// joined to a moved one by a side square across that axis moved with
  /// it — so a level head stays level when the corner it starts from is
  /// raised, rather than being tipped into a slope nobody drew.
  static List<Vec2> _carried(
    List<Vec2> corners,
    Set<int> start,
    MeasureAxis axis,
    double by,
  ) {
    final n = corners.length;
    final down = axis == MeasureAxis.down;
    final moving = {...start};
    final queue = [...start];
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      for (final j in [(i + 1) % n, (i - 1 + n) % n]) {
        if (moving.contains(j)) continue;
        final a = corners[i], b = corners[j];
        final across = down
            ? (a.y - b.y).abs() <= _on
            : (a.x - b.x).abs() <= _on;
        if (!across) continue;
        moving.add(j);
        queue.add(j);
      }
    }
    return [
      for (var i = 0; i < n; i++)
        if (moving.contains(i))
          corners[i] + (down ? Vec2(0, by) : Vec2(by, 0))
        else
          corners[i],
    ];
  }

  /// [design] with its frame's outline made [corners] — the same corners
  /// in the same order, some of them moved — and everything that met the
  /// frame still meeting it.
  ///
  /// **Each relationship is kept, and nothing is moved that did not have
  /// to be.** A bar that ended on a side that moved now ends on it where
  /// its own line meets it: a mullion dropped from a slope still reaches
  /// the slope, at the angle it was drawn and in the place it was drawn,
  /// so the lights either side keep their widths. A bar that ended on a
  /// side that did not move is where it was. A line inside an opening is
  /// the opening's, and goes with it as any resize carries it — from the
  /// sides that bound it square, its ends kept on the slope it met
  /// (`Polygon.sameIn`, `Polygon.lineIn`). The ink is moved with
  /// what was read from it — the frame's along each side that moved, a
  /// bar's along the bar — so reading the sheet again builds this design.
  /// A figure the user drew on a side that moved goes with it, and one
  /// they stated reads what the side now is, since a stated figure is
  /// held when the sheet is read again and the newer word is this one.
  ///
  /// Null when the new outline is not a frame — crossing itself, or too
  /// small for its border — or when a light or an opening it held is lost.
  static Design? reshaped(Design design, List<Vec2> corners) {
    final frame = design.frame;
    if (frame == null) return null;
    final was = frame.outline;
    if (corners.length != was.corners.length) return null;
    final now = Polygon(corners);
    if (!now.isSimple ||
        now.area < frame.profileMm * frame.profileMm * 4 ||
        now.signedArea.sign != was.signedArea.sign) {
      return null;
    }
    final newFrame = frame.copyWith(outline: now);
    final wasInner = frame.innerOutline;
    final nowInner = newFrame.innerOutline;
    if (wasInner.corners.length != was.corners.length ||
        nowInner.corners.length != was.corners.length) {
      return null;
    }

    final n = corners.length;
    final shift = [for (var i = 0; i < n; i++) corners[i] - was.corners[i]];
    final changed = <int>{
      for (var k = 0; k < n; k++)
        if (shift[k].length > 1e-9 || shift[(k + 1) % n].length > 1e-9) k,
    };
    final span = math.max(was.width, was.height);
    final reach = Tol.weldFor(span, fraction: Tol.weldFractionClean);

    // Where a point on a side that moved now is: the same share along it.
    Vec2? onSide(Vec2 p, double within) {
      int? best;
      var nearest = within;
      for (final k in changed) {
        final edge = Segment(was.corners[k], was.corners[(k + 1) % n]);
        final away = edge.distanceTo(p);
        if (away <= nearest) {
          best = k;
          nearest = away;
        }
      }
      if (best == null) return null;
      final edge = Segment(was.corners[best], was.corners[(best + 1) % n]);
      final t = edge.parameterOf(p).clamp(0.0, 1.0);
      return p + shift[best] * (1 - t) + shift[(best + 1) % n] * t;
    }

    // Where a bar's end now is: on its own line, where that meets the
    // side it ended on.
    Vec2 endOf(Segment bar, Vec2 end) {
      // An end on a side that did not move stays on it, where it is.
      var still = double.infinity;
      for (var k = 0; k < n; k++) {
        if (changed.contains(k)) continue;
        for (final from in [was, wasInner]) {
          final edge = Segment(from.corners[k], from.corners[(k + 1) % n]);
          still = math.min(still, edge.distanceTo(end));
        }
      }
      // An end on a side that moved goes to where its own line now meets
      // the frame — the same face of it, outside or daylight — nearest to
      // where it was: on that side, usually, and on the slope beyond it
      // when the side has drawn back past the bar's line.
      Vec2? best;
      var nearest = double.infinity;
      for (final (from, to) in [(was, now), (wasInner, nowInner)]) {
        final onIt = changed.any((k) {
          final old = Segment(from.corners[k], from.corners[(k + 1) % n]);
          final away = old.distanceTo(end);
          return away <= reach && away <= still;
        });
        if (!onIt) continue;
        for (final side in to.edges) {
          final at = _meeting(bar, side);
          if (at == null) continue;
          final d = at.distanceTo(end);
          if (d < nearest) {
            best = at;
            nearest = d;
          }
        }
      }
      return best ?? end;
    }

    final bars = <String, DividerElement>{};
    for (final bar in design.dividers) {
      // A line inside a section is that section's, and the rebuild carries
      // it with the section (`Polygon.sameIn`, `Polygon.lineIn`).
      if (bar.parentId != null) {
        bars[bar.id] = bar;
        continue;
      }
      final line = bar.segment;
      final a = endOf(line, bar.a), b = endOf(line, bar.b);
      bars[bar.id] = (a == bar.a && b == bar.b)
          ? bar
          : bar.copyWith(a: a, b: b);
    }

    final dimensions = <String, DimensionElement>{};
    for (final d in design.dimensions) {
      final a = onSide(d.a, reach) ?? d.a;
      final b = onSide(d.b, reach) ?? d.b;
      if (a == d.a && b == d.b) {
        dimensions[d.id] = d;
        continue;
      }
      final moved = d.copyWith(a: a, b: b);
      dimensions[d.id] = d.isStated
          ? moved.copyWith(statedMm: a.distanceTo(b))
          : moved;
    }

    // The ink: each stroke a bar or a figure was read from moves as that
    // did, end to end; every other stroke near a side that moved — the
    // frame's — moves with the side.
    final read = <String, (Segment, Segment)>{};
    for (final bar in design.dividers) {
      final id = bar.fromStrokeId;
      if (id != null) read[id] = (bar.segment, bars[bar.id]!.segment);
    }
    for (final d in design.dimensions) {
      final id = d.fromStrokeId;
      final to = dimensions[d.id]!;
      if (id != null) read[id] = (Segment(d.a, d.b), Segment(to.a, to.b));
    }
    final claimed = <String>{
      ...read.keys,
      for (final a in design.arrows) ?a.fromStrokeId,
      for (final t in design.texts) ?t.fromStrokeId,
      for (final o in design.openings)
        if (o.id.startsWith('opening-')) o.id.substring('opening-'.length),
    };
    final hand = span * Tol.wobbleShare;
    Stroke inked(Stroke stroke) {
      final pair = read[stroke.id];
      if (pair != null) {
        final (from, to) = pair;
        if (from.a == to.a && from.b == to.b) return stroke;
        final da = to.a - from.a, db = to.b - from.b;
        return stroke.copyWith(
          samples: [
            for (final s in stroke.samples)
              s.movedTo(() {
                final t = from.parameterOf(s.at).clamp(0.0, 1.0);
                return s.at + da * (1 - t) + db * t;
              }()),
          ],
        );
      }
      if (claimed.contains(stroke.id)) return stroke;
      return stroke.copyWith(
        samples: [
          for (final s in stroke.samples) s.movedTo(onSide(s.at, hand) ?? s.at),
        ],
      );
    }

    final placed = design.copyWith(
      frame: newFrame,
      dividers: [for (final d in design.dividers) bars[d.id]!],
      dimensions: [for (final d in design.dimensions) dimensions[d.id]!],
      sketch: Sketch(
        strokes: [for (final s in design.sketch.strokes) inked(s)],
      ),
    );
    // What is inside a section that changed shape goes with it, carried
    // from the sides that bound it square: a raked light's sill moved down
    // takes its rail down with it, so the panel below keeps its height, and
    // its slope moved takes nothing of the rail, which met no slope.
    final rebuilt = SectionBuilder.rebuild(placed);

    if (rebuilt.topLevelSections.length != design.topLevelSections.length ||
        rebuilt.sections.length != design.sections.length ||
        rebuilt.openings.length != design.openings.length) {
      return null;
    }
    return rebuilt;
  }

  /// Where the line through [bar] meets the side [side] — on the side, give
  /// or take a little at its ends — or null when they run alongside.
  static Vec2? _meeting(Segment bar, Segment side) {
    final r = bar.direction, s = side.direction;
    final denominator = r.cross(s);
    if (denominator.abs() < 1e-9 * r.length * s.length) return null;
    if ((denominator / (r.length * s.length)).abs() < Tol.alongSine) {
      return null;
    }
    final u = (side.a - bar.a).cross(r) / denominator;
    final slack = 1 / math.max(s.length, 1e-9);
    if (u < -slack || u > 1 + slack) return null;
    return side.pointAt(u.clamp(0.0, 1.0));
  }
}
