import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';

/// What a dragged point came to rest on.
enum SnapKind {
  /// A point the geometry already has: a corner of the frame or of a light,
  /// the end of a bar, or where two of its lines cross.
  point,

  /// Somewhere along one of the geometry's own lines — a sloped side as much
  /// as a level one — square to it from where the pointer is.
  line,

  /// Level with, or upright from, a point the geometry already has.
  alignment,
}

/// Where a drag lands once it has snapped, and what it snapped to.
class Snapped {
  final Vec2 at;
  final SnapKind kind;

  /// The line it lies on, for [SnapKind.line].
  final Segment? line;

  const Snapped(this.at, this.kind, {this.line});

  @override
  String toString() => 'Snapped(${kind.name} $at)';
}

/// Snapping on the technical drawing that reads the geometry as it is,
/// sloped lines and all — for an Angled / Asymmetrical design.
///
/// **The design's own geometry is the only thing snapped to.** The frame's
/// outline and daylight, each bar's centre line, each light's corners —
/// read from the canonical design each time, so a snap lands on what the
/// user drew and never on something worked out for it. Nothing here holds
/// geometry of its own, and nothing here changes the design: it says where
/// a dragged point should land, and the edit the drag makes does the rest.
///
/// **A slope is a line like any other.** A point is measured to a line
/// square to that line, whatever its angle, and lands on it there: an end
/// dragged near a raking side lands on the side, at the side's own angle.
/// No angle is preferred — not 45°, not level, not upright — because the
/// slope is the user's, and snapping is help with editing, never permission
/// to redesign. A level or an upright line is snapped to in exactly the same
/// way, so the standard snaps are the case of this at 0° and 90°.
///
/// **Nearest of the most specific kind wins**: a point the geometry has,
/// then a line it has, then a point level with or upright from one it has.
/// Within each, the nearest; and nothing further than [withinMm] — so a
/// drag well clear of everything is left exactly where the pointer is.
///
/// **A child snaps within its parent.** A line inside an opening is the
/// opening's, so its ends snap to that opening's region and what is drawn
/// in it, never to the design's lines outside — snapping does not move a
/// line from one owner to another.
///
/// The standard categories keep the snapping they had
/// (`DesignEdits.snapCandidates`): [byGeometry] is the category's
/// `GeometryPolicy` and nothing else about it.
abstract final class CadSnap {
  /// Whether [design] snaps by its geometry: an angled design, whose slopes
  /// are meant.
  static bool byGeometry(Design design) =>
      design.kind.geometryPolicy == GeometryPolicy.preserve;

  /// Where a point dragged to [raw] lands — the end of a bar, a figure or an
  /// arrow — or null where nothing is within [withinMm].
  ///
  /// [ignoreId] is the element being dragged, which is never snapped to
  /// itself; [insideOf] the section a child line belongs to, which keeps
  /// its snaps inside that section.
  static Snapped? point(
    Design design,
    Vec2 raw, {
    required double withinMm,
    String? ignoreId,
    String? insideOf,
  }) {
    final targets = _Targets.of(design, ignoreId: ignoreId, insideOf: insideOf);

    // A point the geometry has: its corners and bar ends, and where two of
    // its lines near the pointer cross.
    final near = [
      for (final line in targets.lines)
        if (line.distanceTo(raw) <= withinMm) line,
    ];
    final points = [
      ...targets.points,
      for (var i = 0; i < near.length; i++)
        for (var j = i + 1; j < near.length; j++)
          ?near[i].crossing(near[j])?.at,
    ];
    final corner = _nearest(points, raw, withinMm);
    if (corner != null) return Snapped(corner, SnapKind.point);

    // Along a line, square to it.
    Segment? on;
    var best = withinMm;
    for (final line in near) {
      final away = line.distanceTo(raw);
      if (away <= best) {
        best = away;
        on = line;
      }
    }
    if (on != null) {
      return Snapped(on.nearestTo(raw), SnapKind.line, line: on);
    }

    // Level with or upright from a point the geometry has.
    final x = _nearestValue(
      [for (final p in targets.points) p.x],
      raw.x,
      withinMm,
    );
    final y = _nearestValue(
      [for (final p in targets.points) p.y],
      raw.y,
      withinMm,
    );
    if (x == null && y == null) return null;
    return Snapped(Vec2(x ?? raw.x, y ?? raw.y), SnapKind.alignment);
  }

  /// Where a member dragged square to itself lands: [moving] is where it
  /// now is, and [raw] where the pointer has it go.
  ///
  /// A bar or a side of the frame moves along its own normal only, so what
  /// it can land on is an offset along that normal: through a point the
  /// geometry has, or onto a line parallel to it — for an upright bar, the
  /// x of a corner or of another upright's face, exactly as before; for a
  /// raking side, a line at the side's own angle through a corner. The
  /// geometry within [bandMm] of [moving] moves with it and is left out.
  /// Returns the point to drag to, or null where nothing is near.
  static Snapped? across(
    Design design,
    Segment moving,
    Vec2 raw, {
    required double withinMm,
    required double bandMm,
    String? ignoreId,
    String? insideOf,
  }) {
    if (moving.length < Tol.samePointMm) return null;
    final normal = moving.unit.perpendicular;
    final middle = moving.midpoint;
    double offsetOf(Vec2 p) => (p - middle).dot(normal);
    bool movesWith(Vec2 p) =>
        moving.distanceTo(p) <= bandMm &&
        moving.parameterOf(p) >= 0 &&
        moving.parameterOf(p) <= 1;

    final targets = _Targets.of(
      design,
      ignoreId: ignoreId,
      insideOf: insideOf,
      withFaces: true,
    );
    final offsets = [
      for (final p in targets.points)
        if (!movesWith(p)) offsetOf(p),
      for (final line in targets.lines)
        if (_parallel(line, moving) && !movesWith(line.midpoint))
          offsetOf(line.midpoint),
    ];
    final wanted = offsetOf(raw);
    final landed = _nearestValue(offsets, wanted, withinMm);
    if (landed == null) return null;
    return Snapped(raw + normal * (landed - wanted), SnapKind.line);
  }

  /// Level with or upright from a point the geometry has — for a whole
  /// element dragged by its middle, which lands where it is put.
  static Snapped? aligned(
    Design design,
    Vec2 raw, {
    required double withinMm,
    String? ignoreId,
  }) {
    final points = _Targets.of(design, ignoreId: ignoreId).points;
    final x = _nearestValue([for (final p in points) p.x], raw.x, withinMm);
    final y = _nearestValue([for (final p in points) p.y], raw.y, withinMm);
    if (x == null && y == null) return null;
    return Snapped(Vec2(x ?? raw.x, y ?? raw.y), SnapKind.alignment);
  }

  /// Two lines running the same way, whatever way that is.
  static bool _parallel(Segment a, Segment b) {
    if (a.length < Tol.samePointMm || b.length < Tol.samePointMm) return false;
    return a.unit.cross(b.unit).abs() <= Tol.alongSine;
  }

  static Vec2? _nearest(List<Vec2> points, Vec2 to, double within) {
    Vec2? best;
    var gap = within;
    for (final p in points) {
      final away = p.distanceTo(to);
      if (away <= gap) {
        gap = away;
        best = p;
      }
    }
    return best;
  }

  static double? _nearestValue(List<double> values, double to, double within) {
    double? best;
    var gap = within;
    for (final v in values) {
      final away = (v - to).abs();
      if (away <= gap) {
        gap = away;
        best = v;
      }
    }
    return best;
  }
}

/// What a drag can snap to: the design's own points and lines, at the
/// level of the tree the dragged element belongs to.
class _Targets {
  final List<Vec2> points;
  final List<Segment> lines;

  const _Targets(this.points, this.lines);

  static _Targets of(
    Design design, {
    String? ignoreId,
    String? insideOf,
    bool withFaces = false,
  }) {
    final points = <Vec2>[];
    final lines = <Segment>[];
    void add(Vec2 p) {
      if (!p.x.isFinite || !p.y.isFinite) return;
      if (points.any((q) => q.distanceTo(p) <= Tol.samePointMm)) return;
      points.add(p);
    }

    void edgesOf(Polygon shape) {
      for (final c in shape.corners) {
        add(c);
      }
      lines.addAll(shape.edges);
    }

    void bar(DividerElement bar) {
      if (bar.id == ignoreId) return;
      add(bar.a);
      add(bar.b);
      lines.add(bar.segment);
      if (withFaces && bar.segment.length > Tol.samePointMm) {
        final side = bar.segment.unit.perpendicular * (bar.widthMm / 2);
        lines
          ..add(Segment(bar.a + side, bar.b + side))
          ..add(Segment(bar.a - side, bar.b - side));
      }
    }

    final region = insideOf == null ? null : design.sectionById(insideOf);
    if (region != null) {
      // A child's snaps are its parent's: the region, and what is drawn in
      // it.
      edgesOf(region.outline);
      design.childDividersOf(region.id).forEach(bar);
      for (final pane in design.childSectionsOf(region.id)) {
        edgesOf(pane.outline);
      }
      return _Targets(points, lines);
    }

    final frame = design.frame;
    if (frame != null) {
      edgesOf(frame.outline);
      edgesOf(frame.innerOutline);
    }
    design.topLevelDividers.forEach(bar);
    for (final section in design.topLevelSections) {
      edgesOf(section.outline);
    }
    return _Targets(points, lines);
  }
}
