import '../dimensions/scale.dart';
import '../geometry/polygon.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';

/// What is wrong with a design's geometry.
enum GeometryProblemKind {
  /// A coordinate that is not a number — infinite, or not a number at all.
  coordinate,

  /// An outline that encloses nothing: fewer than three corners, or no area.
  boundary,

  /// An outline that crosses or touches itself — a bow tie, or a shape
  /// pinched to a point.
  selfIntersection,

  /// Geometry that is not joined to the design: a bar of the design touching
  /// neither the frame nor another bar, or a section outside the frame.
  disconnected,

  /// A dimension that measures nothing, or a figure the geometry no longer
  /// agrees with.
  dimension,

  /// An opening whose region has gone, or whose mark is not in it.
  opening,

  /// A child outside what it is the child of: a line or a pane outside its
  /// section, or a piece of ironmongery off its leaf.
  child,
}

/// One thing wrong with a design's geometry, and the element it is wrong
/// with.
class GeometryProblem {
  final GeometryProblemKind kind;
  final String elementId;
  final String detail;

  const GeometryProblem(this.kind, this.elementId, this.detail);

  @override
  String toString() => '${kind.name} $elementId: $detail';
}

/// Whether a design's geometry is geometry something can be built from.
///
/// **It says; it does not mend.** An angled design keeps every slope its user
/// drew, so nothing here squares, moves or removes anything: it reports
/// what cannot be built — a coordinate that is not a number, an outline that
/// crosses itself, a bar hanging from nothing, a figure the drawing no
/// longer agrees with, an opening that has lost its region, a child outside
/// its parent — and leaves the drawing as the user drew it. What a standard
/// design is squared to is the normaliser's business; what any design must
/// be, square or not, is this.
abstract final class GeometryValidation {
  /// Everything wrong with [design]'s geometry, or nothing.
  static List<GeometryProblem> of(Design design) {
    final problems = <GeometryProblem>[];
    void problem(GeometryProblemKind kind, String id, String detail) =>
        problems.add(GeometryProblem(kind, id, detail));

    // Valid coordinates, everywhere a point is kept.
    bool finite(Vec2 p) => p.x.isFinite && p.y.isFinite;
    void points(String id, Iterable<Vec2> at) {
      if (!at.every(finite)) {
        problem(GeometryProblemKind.coordinate, id, 'a point is not a number');
      }
    }

    final frame = design.frame;
    if (frame != null) points(frame.id, frame.outline.corners);
    for (final bar in design.dividers) {
      points(bar.id, [bar.a, bar.b]);
    }
    for (final section in design.sections) {
      points(section.id, section.outline.corners);
    }
    for (final piece in design.hardware) {
      points(piece.id, [piece.at]);
    }
    for (final opening in design.openings) {
      if (opening.markAt case final at?) points(opening.id, [at]);
    }
    for (final dimension in design.dimensions) {
      points(dimension.id, [dimension.a, dimension.b]);
    }
    if (problems.isNotEmpty || frame == null) return problems;

    final outline = frame.outline;
    final weld = Tol.weldFor(Vec2(outline.width, outline.height).length);
    bool within(Polygon shape, Vec2 p, double slack) =>
        shape.contains(p) || shape.awayFrom(p) <= slack;

    // Valid boundaries, and no self-intersections.
    void shapeOf(String id, Polygon shape, String what) {
      if (shape.corners.length < 3 || shape.area <= Tol.samePointMm) {
        problem(GeometryProblemKind.boundary, id, '$what encloses nothing');
      } else if (!shape.isSimple) {
        problem(
          GeometryProblemKind.selfIntersection,
          id,
          '$what crosses itself',
        );
      }
    }

    shapeOf(frame.id, outline, 'the outline');
    for (final section in design.sections) {
      shapeOf(section.id, section.outline, 'a section');
    }

    // Connected geometry: the design's own sections inside the frame, and
    // every bar of the design joined to the frame or to another bar.
    for (final section in design.topLevelSections) {
      if (!section.outline.corners.every((c) => within(outline, c, weld))) {
        problem(
          GeometryProblemKind.disconnected,
          section.id,
          'a section lies outside the frame',
        );
      }
    }
    final daylight = frame.innerOutline;
    for (final bar in design.topLevelDividers) {
      bool joined(Vec2 end) =>
          outline.awayFrom(end) <= weld ||
          daylight.awayFrom(end) <= weld + bar.widthMm ||
          design.topLevelDividers.any(
            (other) =>
                other.id != bar.id &&
                other.segment.distanceTo(end) <= weld + other.widthMm,
          );
      if (!joined(bar.a) && !joined(bar.b)) {
        problem(
          GeometryProblemKind.disconnected,
          bar.id,
          'a bar touches neither the frame nor another bar',
        );
      }
    }

    // Valid child geometry: every line and pane inside the section it
    // belongs to.
    for (final bar in design.dividers) {
      if (bar.parentId == null) continue;
      final parent = design.sectionById(
        design.sectionHolding(bar.parentId) ?? '',
      );
      if (parent == null || !parent.outline.holds(bar.segment, reach: weld)) {
        problem(
          GeometryProblemKind.child,
          bar.id,
          'a line lies outside the part it belongs to',
        );
      }
    }
    for (final section in design.sections) {
      if (section.parentId == null) continue;
      final parent = design.sectionById(
        design.sectionHolding(section.parentId) ?? '',
      );
      if (parent == null ||
          !section.outline.corners.every(
            (c) => within(parent.outline, c, weld),
          )) {
        problem(
          GeometryProblemKind.child,
          section.id,
          'a pane lies outside the part it belongs to',
        );
      }
    }

    // Valid openings: a region of their own, holding their own mark, and
    // their ironmongery on their leaf.
    for (final opening in design.openings) {
      final region = design.sectionById(opening.sectionId);
      if (region == null) {
        problem(
          GeometryProblemKind.opening,
          opening.id,
          'the opening has no region',
        );
        continue;
      }
      if (opening.markAt case final mark?
          when !within(region.outline, mark, weld)) {
        problem(
          GeometryProblemKind.opening,
          opening.id,
          'the opening\'s mark is not in its region',
        );
      }
      for (final piece in design.hardware) {
        if (design.openingHolding(piece.parentId)?.id != opening.id) continue;
        if (piece.kind.staysOnFrame) continue;
        if (!within(region.outline, piece.at, weld)) {
          problem(
            GeometryProblemKind.child,
            piece.id,
            'a ${piece.kind.name} is off its leaf',
          );
        }
      }
    }

    // Valid dimensions: each measures something, and every figure the user
    // stated is still true of the geometry.
    for (final dimension in design.dimensions) {
      if (dimension.measuredMm <= Tol.samePointMm) {
        problem(
          GeometryProblemKind.dimension,
          dimension.id,
          'a dimension measures nothing',
        );
      } else if (dimension.statedMm case final stated? when stated <= 0) {
        problem(
          GeometryProblemKind.dimension,
          dimension.id,
          'a stated figure is not a size',
        );
      }
    }
    for (final conflict in DesignScale.conflicts(design)) {
      problem(
        GeometryProblemKind.dimension,
        conflict.dimension.id,
        'the geometry no longer agrees with ${conflict.statedMm} mm',
      );
    }
    return problems;
  }
}
