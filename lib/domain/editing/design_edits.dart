import 'dart:math' as math;

import '../geometry/local_space.dart';
import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../hardware/opening_hardware.dart';
import '../model/design.dart';
import '../model/elements.dart';
import '../model/materials.dart';
import '../sections/section_builder.dart';

/// Changing the design by hand.
///
/// Every one of these does exactly what it says and nothing else. Moving a
/// bar moves that bar; the sections either side follow because they are what
/// the bars enclose, not because anything was rebalanced. Nothing here ever
/// tidies up the rest of the design on the user's behalf.
enum FrameEdge { left, right, top, bottom }

abstract final class DesignEdits {
  /// Moves a divider bodily.
  static Design moveDivider(Design design, String dividerId, Vec2 by) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    return _rebuild(design.withElement(
      divider.copyWith(a: divider.a + by, b: divider.b + by),
    ));
  }

  /// Moves one end of a divider, leaving the other where it is.
  static Design moveDividerEnd(
    Design design,
    String dividerId, {
    required bool startEnd,
    required Vec2 to,
  }) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    final moved =
        startEnd ? divider.copyWith(a: to) : divider.copyWith(b: to);
    if (moved.lengthMm < Tol.minLineMm) return design;
    return _rebuild(design.withElement(moved));
  }

  /// Adds a divider the user drew or asked for, between two points.
  static Design addDivider(
    Design design, {
    required String id,
    required Vec2 a,
    required Vec2 b,
    String? fromStrokeId,
  }) {
    if (a.distanceTo(b) < Tol.minLineMm) return design;
    return _rebuild(design.copyWith(dividers: [
      ...design.dividers,
      DividerElement(
        id: id,
        a: a,
        b: b,
        widthMm: (design.frame?.profileMm ?? 62.5) * 0.8,
        finish: design.frame?.finish ?? Finish.frameDefault,
        fromStrokeId: fromStrokeId,
      ),
    ]));
  }

  /// Adds a line the user drew inside a section, as that section's own.
  ///
  /// This is how an opening gets its internal geometry. The bar belongs to
  /// the section from the moment it is made, so it divides that section and
  /// not the design: an opening does not end because a line was drawn in it,
  /// and the line travels with the opening ever afterwards.
  ///
  /// The line is laid across the section the user drew it in, at the place
  /// they drew it. A line tool says *where* a line goes; how far it runs is
  /// settled by the section it is inside, because a bar that stops half way
  /// divides nothing. Nothing is placed where the line does not cross the
  /// section at all.
  static Design addDividerInside(
    Design design,
    String sectionId, {
    required String id,
    required Vec2 a,
    required Vec2 b,
  }) {
    final section = design.sectionById(sectionId);
    if (section == null) return design;
    final across = spanAcross(section.outline, Segment(a, b));
    if (across == null) return design;

    return _rebuild(design.copyWith(dividers: [
      ...design.dividers,
      DividerElement(
        id: id,
        a: across.a,
        b: across.b,
        widthMm: (design.frame?.profileMm ?? 62.5) * 0.55,
        finish: design.frame?.finish ?? Finish.frameDefault,
        parentId: sectionId,
      ),
    ]));
  }

  /// Adds a shape the user drew inside a section, as that section's own.
  ///
  /// A rectangle is four bars, a polyline is a chain of them, and a straight
  /// line at an angle is one — all the same operation, because in this model
  /// a shape is not a picture of a shape: it is the lines that enclose the
  /// panes it makes. Every bar is the section's from the moment it exists,
  /// so the whole shape divides that section and travels with it.
  ///
  /// Unlike [addDividerInside], a leg is **not** laid right across the
  /// section. A single bar that stopped half way would divide nothing, which
  /// is why one gets spanned; the legs of a shape close on each other
  /// instead, so spanning them would turn a rectangle into a cross. Each leg
  /// is trimmed to the section it was drawn in, which is the same cleaning
  /// as trimming a line drawn past its corner, and a leg left with nothing
  /// inside is dropped rather than placed somewhere near.
  static Design addShapeInside(
    Design design,
    String sectionId, {
    required String idPrefix,
    required List<Vec2> corners,
    bool closed = false,
  }) {
    final section = design.sectionById(sectionId);
    if (section == null || corners.length < 2) return design;

    // One line on its own is a line, not a shape: it is laid right across
    // the section like every other line tool, because a bar that stops half
    // way divides nothing. Only a shape's legs are trimmed, because they
    // close on each other rather than on the section.
    if (corners.length == 2 && !closed) {
      return addDividerInside(
        design,
        sectionId,
        id: '$idPrefix-0',
        a: corners.first,
        b: corners.last,
      );
    }

    final legs = <Segment>[];
    for (var i = 0; i + 1 < corners.length; i++) {
      legs.add(Segment(corners[i], corners[i + 1]));
    }
    if (closed && corners.length > 2) {
      legs.add(Segment(corners.last, corners.first));
    }

    final made = <DividerElement>[];
    for (final leg in legs) {
      final within = clippedInto(section.outline, leg);
      if (within == null) continue;
      made.add(DividerElement(
        id: '$idPrefix-${made.length}',
        a: within.a,
        b: within.b,
        widthMm: (design.frame?.profileMm ?? 62.5) * 0.55,
        finish: design.frame?.finish ?? Finish.frameDefault,
        parentId: sectionId,
      ));
    }
    if (made.isEmpty) return design;

    return _rebuild(design.copyWith(dividers: [...design.dividers, ...made]));
  }

  /// The part of [line] that lies within [outline], or null when none of it
  /// does or what is left is too short to be a line.
  ///
  /// The ends move and nothing else: the direction and the position are the
  /// user's, and only what strayed outside the shape is taken off.
  static Segment? clippedInto(Polygon outline, Segment line) {
    if (line.length < 1e-6) return null;

    // Where the line crosses the boundary, as fractions along it, with the
    // two ends thrown in so a line wholly inside needs no crossings at all.
    final cuts = <double>[0, 1];
    final direction = line.b - line.a;
    for (final edge in outline.edges) {
      final hit = _meetOnLine(line.a, direction, edge);
      if (hit == null || hit < 0 || hit > 1) continue;
      cuts.add(hit);
    }
    cuts.sort();

    // The longest run whose middle is inside. A shape can be any the user's
    // lines make, so a line can leave it and come back.
    double? bestFrom;
    double? bestTo;
    for (var i = 0; i + 1 < cuts.length; i++) {
      final from = cuts[i];
      final to = cuts[i + 1];
      if (to - from < 1e-9) continue;
      final middle = line.a + direction * ((from + to) / 2);
      if (!outline.contains(middle)) continue;
      if (bestFrom == null || to - from > bestTo! - bestFrom) {
        bestFrom = from;
        bestTo = to;
      }
    }
    if (bestFrom == null) return null;

    final kept = Segment(
      line.a + direction * bestFrom,
      line.a + direction * bestTo!,
    );
    return kept.length < Tol.minLineMm ? null : kept;
  }

  /// The same for a line the user placed with one of the line tools, which
  /// says its direction for them.
  ///
  /// A horizontal line is horizontal: the tool is the instruction, so there
  /// is no wobble to clean and no angle to preserve. Where it goes is the
  /// point they put it at.
  static Design addLineInside(
    Design design,
    String sectionId, {
    required String id,
    required Vec2 at,
    required bool horizontal,
  }) =>
      addDividerInside(
        design,
        sectionId,
        id: id,
        a: at,
        b: horizontal ? at + const Vec2(1, 0) : at + const Vec2(0, 1),
      );

  /// Makes a bar [lengthMm] long, about its own middle.
  ///
  /// The middle and the angle are the user's and neither moves: a bar made
  /// shorter loses the same from each end, and one made longer grows the
  /// same at each. Anything else would be the application deciding which end
  /// of their line was the important one.
  ///
  /// What it divides follows from where it now reaches, because the sections
  /// are the faces the lines make — a bar pulled back from a jamb stops
  /// dividing what it was dividing, which is the honest answer and is what
  /// the drawing will show.
  static Design setDividerLength(
    Design design,
    String dividerId,
    double lengthMm,
  ) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    if (lengthMm < Tol.minLineMm) return design;
    final was = divider.segment;
    if ((was.length - lengthMm).abs() < Tol.sameLengthMm) return design;
    if (was.length < 1e-6) return design;

    final middle = was.midpoint;
    final reach = was.unit * (lengthMm / 2);
    return _rebuild(design.withElement(
      divider.copyWith(a: middle - reach, b: middle + reach),
    ));
  }

  /// Turns a bar to [degrees] from horizontal, about its own middle.
  ///
  /// The length and the middle are kept, so only the direction changes —
  /// the same shape of edit as [setDividerLength] seen the other way round.
  /// A heading is measured the way `Segment.headingDegrees` reports one, so
  /// what is typed into the field is what comes back out of it.
  static Design setDividerAngle(
    Design design,
    String dividerId,
    double degrees,
  ) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    final was = divider.segment;
    if (was.length < 1e-6) return design;

    final wanted = (degrees % 180 + 180) % 180;
    if ((was.headingDegrees - wanted).abs() < 1e-6) return design;

    final radians = wanted * math.pi / 180;
    final middle = was.midpoint;
    final reach =
        Vec2(math.cos(radians), math.sin(radians)) * (was.length / 2);
    return _rebuild(design.withElement(
      divider.copyWith(a: middle - reach, b: middle + reach),
    ));
  }

  /// Moves a bar inside a section to a place measured from that section's
  /// own top left corner.
  ///
  /// An opening's contents are the opening's, so where they are is naturally
  /// said in the opening's terms: a bar 40 cm down the sash is 40 cm down the
  /// sash wherever the sash is. Only the bar moves; the opening does not.
  static Design moveDividerWithin(
    Design design,
    String dividerId,
    double alongMm,
  ) {
    final divider = _divider(design, dividerId);
    final box = boxAround(design, divider);
    if (divider == null || box == null) return design;

    // Square to the bar, at whatever angle it was drawn. A bar across the
    // opening moves down it, a bar up the opening moves across it, and a
    // diagonal moves square to itself — one rule, so no bar has a figure on
    // its panel that does nothing when it is typed over.
    return moveDivider(
      design,
      dividerId,
      LocalSpace.shiftFor(box, divider.segment, alongMm),
    );
  }

  /// How far [divider] sits into the section it is inside, in that section's
  /// own terms. Null when it is not inside one.
  static double? alongWithin(Design design, DividerElement? divider) {
    final box = boxAround(design, divider);
    if (divider == null || box == null) return null;
    return LocalSpace.alongIn(box, divider.segment);
  }

  /// How far that section reaches, square to the bar: the largest figure
  /// [alongWithin] can give.
  static double? reachWithin(Design design, DividerElement? divider) {
    final box = boxAround(design, divider);
    if (divider == null || box == null) return null;
    return LocalSpace.reachIn(box, divider.segment);
  }

  /// The outline of the section [divider] is inside, or null when it is not
  /// inside one — a bar that divides the design is measured from the design.
  static Polygon? boxAround(Design design, DividerElement? divider) {
    final parent = design.sectionHolding(divider?.parentId);
    if (parent == null) return null;
    return design.sectionById(parent)?.outline;
  }

  /// Where [point] is inside [sectionId], measured from that section's own
  /// top left corner. Null when there is no such section.
  static Vec2? within(Design design, String sectionId, Vec2 point) {
    final section = design.sectionById(sectionId);
    if (section == null) return null;
    return LocalSpace.of(section.outline, point);
  }

  /// The opening a part is inside, as the section that opens.
  ///
  /// Answers for the opening itself, for the section it is on, and for
  /// anything that lives in it — a bar drawn inside, a pane those bars make,
  /// a hinge, the handle. Null when the part is not part of an opening, so
  /// there is nothing to draw inside.
  static String? openingAround(Design design, String? elementId) {
    if (elementId == null) return null;
    final element = design.elementById(elementId);

    final candidate = switch (element) {
      OpeningElement() => element.sectionId,
      SectionElement() => design.openingOf(element.id) != null
          ? element.id
          : design.sectionHolding(element.parentId),
      DividerElement() => design.sectionHolding(element.parentId),
      HardwareElement() => design.sectionHolding(element.parentId),
      _ => null,
    };
    if (candidate == null) return null;
    if (design.openingOf(candidate) != null) return candidate;

    // A pane inside an opening answers with the opening, not with itself.
    final parent =
        design.sectionHolding(design.sectionById(candidate)?.parentId);
    if (parent != null && design.openingOf(parent) != null) return parent;
    return null;
  }

  /// How far [line] runs when laid right across [outline], or null when it
  /// does not cross it.
  ///
  /// Measured on the line the user drew, not on a line of this method's
  /// choosing: the direction and the position are theirs, and only the two
  /// ends are found — where the line meets the boundary of the shape it was
  /// drawn inside.
  static Segment? spanAcross(Polygon outline, Segment line) {
    if (line.length < 1e-6) return null;
    final direction = line.unit;
    final from = line.a;

    var least = double.infinity;
    var most = -double.infinity;
    for (final edge in outline.edges) {
      final hit = _meetOnLine(from, direction, edge);
      if (hit == null) continue;
      if (hit < least) least = hit;
      if (hit > most) most = hit;
    }
    if (!least.isFinite || !most.isFinite) return null;
    if (most - least < Tol.minLineMm) return null;

    return Segment(from + direction * least, from + direction * most);
  }

  /// How far along an infinite line through [from] in [direction] it meets
  /// [edge], or null when it does not meet it within the edge's own length.
  static double? _meetOnLine(Vec2 from, Vec2 direction, Segment edge) {
    final along = edge.direction;
    final denominator = direction.cross(along);
    if (denominator.abs() < 1e-12) return null;
    final onEdge = (edge.a - from).cross(direction) / denominator;
    if (onEdge < -1e-9 || onEdge > 1 + 1e-9) return null;
    return (edge.a - from).cross(along) / denominator;
  }

  /// Deletes an element outright, at the user's word.
  static Design delete(Design design, String elementId) =>
      _rebuild(design.withoutElement(elementId));

  /// Sets a section's width by moving the bar that forms one of its vertical
  /// edges — the one furthest from the frame, so the frame itself stays put.
  ///
  /// Returns the design unchanged, rather than approximating, when no bar
  /// forms that edge: a section whose width is set by the frame changes by
  /// resizing the frame, and doing that silently would move parts of the
  /// design the user did not ask to move.
  static Design setSectionWidth(
    Design design,
    String sectionId,
    double widthMm,
  ) {
    final section = design.sectionById(sectionId);
    if (section == null || widthMm < Tol.minLineMm) return design;

    final growth = widthMm - section.widthMm;
    if (growth.abs() < Tol.sameLengthMm) return design;

    final right =
        _dividerAlong(design, x: section.outline.right, within: section.parentId);
    if (right != null) {
      return moveDivider(design, right.id, Vec2(growth, 0));
    }
    final left =
        _dividerAlong(design, x: section.outline.left, within: section.parentId);
    if (left != null) {
      return moveDivider(design, left.id, Vec2(-growth, 0));
    }

    // No bar at this level either side. A pane inside an opening with no bar
    // beside it *is* the opening, so its width is the opening's width and the
    // question passes outward to whatever bounds that.
    final parent = design.sectionHolding(section.parentId);
    if (parent != null) return setSectionWidth(design, parent, widthMm);

    // Otherwise this pane runs from jamb to jamb, so its width is the frame's
    // width and the jamb is what has to move. Nothing else does — the other
    // jamb, every bar and every other pane stay where they are.
    final frame = design.frame;
    if (frame == null) return design;
    if ((section.outline.right - frame.innerOutline.right).abs() <=
        Tol.sameLengthMm) {
      return moveFrameEdge(
        design,
        FrameEdge.right,
        frame.outline.right + growth,
      );
    }
    return design;
  }

  /// The same for height, moving the transom below the section.
  static Design setSectionHeight(
    Design design,
    String sectionId,
    double heightMm,
  ) {
    final section = design.sectionById(sectionId);
    if (section == null || heightMm < Tol.minLineMm) return design;

    final growth = heightMm - section.heightMm;
    if (growth.abs() < Tol.sameLengthMm) return design;

    final below =
        _dividerAlong(design, y: section.outline.bottom, within: section.parentId);
    if (below != null) {
      return moveDivider(design, below.id, Vec2(0, growth));
    }
    final above =
        _dividerAlong(design, y: section.outline.top, within: section.parentId);
    if (above != null) {
      return moveDivider(design, above.id, Vec2(0, -growth));
    }

    // As above: a pane inside an opening with no bar above or below it is
    // the opening, and the question passes outward.
    final parent = design.sectionHolding(section.parentId);
    if (parent != null) return setSectionHeight(design, parent, heightMm);

    // Otherwise this pane runs from head to sill, so the sill is what has to
    // move, and only the sill.
    final frame = design.frame;
    if (frame == null) return design;
    if ((section.outline.bottom - frame.innerOutline.bottom).abs() <=
        Tol.sameLengthMm) {
      return moveFrameEdge(
        design,
        FrameEdge.bottom,
        frame.outline.bottom + growth,
      );
    }
    return design;
  }

  /// Resizes the whole opening, taking everything inside it along in
  /// proportion.
  ///
  /// The proportions are the design: a bar a third of the way across a
  /// window is a third of the way across the bigger window too. What is not
  /// stretched is the profile of the frame and the width of the bars, which
  /// are real sections of material and do not get wider because the window
  /// did.
  ///
  /// An opening's mark scales with everything else. A rescale is not a
  /// re-cut: every region maps proportionally onto its new self, so the mark
  /// in the middle of a light is in the middle of the bigger light too.
  /// Leaving it behind made it drift out of its own opening — near the head
  /// of a section it had been in the middle of — and then the next edit that
  /// moved a bar found it outside and either moved that opening somewhere
  /// the user had not marked or lost it altogether. The mark is the one
  /// thing that says which region opens, so it cannot be the one thing a
  /// resize forgets.
  static Design resizeFrame(
    Design design, {
    double? widthMm,
    double? heightMm,
  }) {
    final frame = design.frame;
    if (frame == null) return design;

    final sx = widthMm == null || frame.widthMm <= 0
        ? 1.0
        : widthMm / frame.widthMm;
    final sy = heightMm == null || frame.heightMm <= 0
        ? 1.0
        : heightMm / frame.heightMm;
    if (!sx.isFinite || !sy.isFinite || sx <= 0 || sy <= 0) return design;
    if ((sx - 1).abs() < 1e-9 && (sy - 1).abs() < 1e-9) return design;

    final origin = frame.outline.topLeft;
    Vec2 point(Vec2 p) => Vec2(
          origin.x + (p.x - origin.x) * sx,
          origin.y + (p.y - origin.y) * sy,
        );

    return _rebuild(design.copyWith(
      frame: frame.copyWith(
        outline: Polygon([for (final c in frame.outline.corners) point(c)]),
      ),
      dividers: [
        for (final d in design.dividers)
          d.copyWith(a: point(d.a), b: point(d.b)),
      ],
      hardware: [for (final h in design.hardware) h.copyWith(at: point(h.at))],
      openings: [
        for (final o in design.openings)
          if (o.markAt case final at?) o.copyWith(markAt: point(at)) else o,
      ],
    ));
  }

  /// Moves one side of the frame by [byMm] along its own normal.
  ///
  /// Works on any outline, not just a rectangle: a raking head on a
  /// five-sided frame moves square to itself, which is what taking hold of
  /// that edge and pulling it means. Only the two corners of that edge move;
  /// every other corner stays exactly where it was.
  static Design moveFrameMember(Design design, int index, double byMm) {
    final frame = design.frame;
    if (frame == null) return design;
    final corners = frame.outline.corners;
    if (index < 0 || index >= corners.length) return design;
    if (byMm.abs() < 1e-9) return design;

    final a = index;
    final b = (index + 1) % corners.length;
    final edge = Segment(corners[a], corners[b]);
    if (edge.length < 1e-9) return design;

    // Outward is away from the middle of the shape.
    var normal = edge.unit.perpendicular;
    if ((edge.midpoint + normal).distanceTo(frame.outline.centroid) <
        edge.midpoint.distanceTo(frame.outline.centroid)) {
      normal = -normal;
    }

    final moved = [
      for (var i = 0; i < corners.length; i++)
        if (i == a || i == b) corners[i] + normal * byMm else corners[i],
    ];
    final outline = Polygon(moved);
    // An edge pushed through the other side is not a frame.
    if (outline.area < frame.profileMm * frame.profileMm * 4) return design;

    return _rebuild(design.copyWith(frame: frame.copyWith(outline: outline)));
  }

  /// How far [index]'s edge would have to move for its midpoint to land on
  /// [to]. Only the part of the drag square to the edge counts.
  static double frameMemberOffset(Design design, int index, Vec2 to) {
    final frame = design.frame;
    if (frame == null) return 0;
    final corners = frame.outline.corners;
    if (index < 0 || index >= corners.length) return 0;

    final edge = Segment(corners[index], corners[(index + 1) % corners.length]);
    if (edge.length < 1e-9) return 0;
    var normal = edge.unit.perpendicular;
    if ((edge.midpoint + normal).distanceTo(frame.outline.centroid) <
        edge.midpoint.distanceTo(frame.outline.centroid)) {
      normal = -normal;
    }
    return (to - edge.midpoint).dot(normal);
  }

  /// Moves a bar square to itself, so that its centre line lands on [to].
  ///
  /// Dragging the boundary between two panes moves the bar that makes it,
  /// and only along the one direction that means anything for a bar: across
  /// itself. A drag along its length would change nothing and is ignored.
  static Design moveDividerAcross(
    Design design,
    String dividerId,
    Vec2 to,
  ) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    final normal = divider.segment.unit.perpendicular;
    final across = (to - divider.segment.midpoint).dot(normal);
    if (across.abs() < 1e-9) return design;
    return moveDivider(design, dividerId, normal * across);
  }

  /// Moves one end of a dimension, leaving the other where it is.
  static Design moveDimensionEnd(
    Design design,
    String dimensionId,
    Vec2 to, {
    required bool startEnd,
  }) {
    for (final dimension in design.dimensions) {
      if (dimension.id != dimensionId) continue;
      return design.withElement(
        startEnd ? dimension.copyWith(a: to) : dimension.copyWith(b: to),
      );
    }
    return design;
  }

  /// Slides a dimension line off the thing it measures, without changing
  /// what it measures.
  static Design setDimensionOffset(
    Design design,
    String dimensionId,
    Vec2 to,
  ) {
    for (final dimension in design.dimensions) {
      if (dimension.id != dimensionId) continue;
      final line = Segment(dimension.a, dimension.b);
      if (line.length < 1e-9) return design;
      final off = (to - line.midpoint).dot(line.unit.perpendicular);
      return design.withElement(dimension.copyWith(offsetMm: off));
    }
    return design;
  }

  /// Moves one side of the frame to where the user dragged it.
  ///
  /// Direct, not proportional: dragging the head of a frame in a drawing
  /// moves the head, and the bars stay where they are. That is the opposite
  /// of typing an overall width in the inspector, which scales everything in
  /// proportion — one is reaching into the drawing and moving a line, the
  /// other is saying how big the whole thing really is.
  static Design moveFrameEdge(
    Design design,
    FrameEdge edge,
    double toMm,
  ) {
    final frame = design.frame;
    if (frame == null) return design;

    final box = frame.outline;
    final least = frame.profileMm * 2 + Tol.minLineMm;
    final limited = switch (edge) {
      FrameEdge.left => math.min(toMm, box.right - least),
      FrameEdge.right => math.max(toMm, box.left + least),
      FrameEdge.top => math.min(toMm, box.bottom - least),
      FrameEdge.bottom => math.max(toMm, box.top + least),
    };

    // Only the corners on that side move, so a frame drawn at an angle keeps
    // the shape it was drawn with. This is the same movement the grip makes,
    // stated as a position rather than as a distance, so typing a figure and
    // dragging to it reach the same geometry.
    final was = switch (edge) {
      FrameEdge.left => box.left,
      FrameEdge.right => box.right,
      FrameEdge.top => box.top,
      FrameEdge.bottom => box.bottom,
    };
    final moved = [
      for (final corner in box.corners)
        switch (edge) {
          FrameEdge.left => (corner.x - was).abs() <= Tol.samePointMm
              ? Vec2(limited, corner.y)
              : corner,
          FrameEdge.right => (corner.x - was).abs() <= Tol.samePointMm
              ? Vec2(limited, corner.y)
              : corner,
          FrameEdge.top => (corner.y - was).abs() <= Tol.samePointMm
              ? Vec2(corner.x, limited)
              : corner,
          FrameEdge.bottom => (corner.y - was).abs() <= Tol.samePointMm
              ? Vec2(corner.x, limited)
              : corner,
        },
    ];

    return _rebuild(
      design.copyWith(frame: frame.copyWith(outline: Polygon(moved))),
    );
  }

  /// The positions a drag could land on, along one axis.
  ///
  /// Only places where there is already something: the frame's own edges,
  /// the faces and centre lines of the other bars, the edges of the
  /// sections. Deliberately not halves, thirds or equal spacings — those
  /// would quietly pull a design towards being symmetrical, which is the one
  /// thing this application must never do.
  static List<double> snapCandidates(
    Design design, {
    required bool horizontal,
    String? ignoreId,
  }) {
    final frame = design.frame;
    if (frame == null) return const [];
    final values = <double>[];

    void add(double value) {
      if (values.any((v) => (v - value).abs() <= Tol.samePointMm)) return;
      values.add(value);
    }

    for (final corner in frame.outline.corners) {
      add(horizontal ? corner.x : corner.y);
    }
    for (final corner in frame.innerOutline.corners) {
      add(horizontal ? corner.x : corner.y);
    }
    for (final divider in design.dividers) {
      if (divider.id == ignoreId) continue;
      if (horizontal && !divider.isVertical) continue;
      if (!horizontal && !divider.isHorizontal) continue;
      final centre = horizontal
          ? (divider.a.x + divider.b.x) / 2
          : (divider.a.y + divider.b.y) / 2;
      add(centre);
      add(centre - divider.widthMm / 2);
      add(centre + divider.widthMm / 2);
    }
    for (final section in design.sections) {
      add(horizontal ? section.outline.left : section.outline.top);
      add(horizontal ? section.outline.right : section.outline.bottom);
    }

    values.sort();
    return values;
  }

  /// The nearest thing worth snapping to, or null when nothing is near.
  static double? snapTo(
    List<double> candidates,
    double value, {
    required double withinMm,
  }) {
    double? best;
    var bestGap = withinMm;
    for (final candidate in candidates) {
      final gap = (candidate - value).abs();
      if (gap <= bestGap) {
        bestGap = gap;
        best = candidate;
      }
    }
    return best;
  }

  /// Moves a piece of hardware to where the user dragged it.
  static Design moveHardware(Design design, String hardwareId, Vec2 to) {
    for (final piece in design.hardware) {
      if (piece.id == hardwareId) {
        return design.withElement(piece.copyWith(at: to));
      }
    }
    return design;
  }

  /// Records what the user said a section does.
  ///
  /// Answering is the only way an opening is ever created: the reading asks,
  /// the user says, and what they said is marked as theirs.
  static Design setOpening(
    Design design,
    String sectionId, {
    required String openingId,
    required OpeningMechanism mechanism,
    OpeningDirection direction = OpeningDirection.inward,
    Vec2? markAt,
    String? markGlyph,
    String? fromStrokeId,
  }) {
    final without = [
      for (final o in design.openings) if (o.sectionId != sectionId) o,
    ];
    if (mechanism == OpeningMechanism.fixed) {
      return OpeningHardware.settle(design.copyWith(openings: without));
    }
    // **What the user has said about this opening outlasts a re-reading.**
    // The sheet says a section opens; it does not say whether the leaf is a
    // door or a window, or where they wanted its handle, so re-reading it
    // cannot answer those and must not throw the answers away. This is the
    // same rule the bars already keep — a reading re-reads the drawing, it
    // does not overturn what the user said about it — and without it the
    // question came back every time the sheet was read, asking them to say
    // again what they had already said.
    final said = _openingSaid(design, openingId, sectionId);
    return OpeningHardware.settle(design.copyWith(openings: [
      ...without,
      OpeningElement(
        id: openingId,
        sectionId: sectionId,
        mechanism: mechanism,
        direction: direction,
        confirmed: true,
        markAt: markAt,
        markGlyph: markGlyph,
        fromStrokeId: fromStrokeId,
        kind: said?.kind,
        hingeCount: said?.hingeCount,
        hingeFromStartMm: said?.hingeFromStartMm,
        hingeFromEndMm: said?.hingeFromEndMm,
        handleAlongMm: said?.handleAlongMm,
        // The form of the handle is the user's too, and the sheet never says
        // it: a knob chosen for a leaf is a knob after the next reading.
        handleKind: said?.handleKind,
      ),
    ]));
  }

  /// The opening this one is replacing, if it is replacing one.
  ///
  /// By id first, because an opening's id is its mark's and outlives every
  /// reading; by section otherwise, for an opening the user made with the
  /// **Opens** control, which has no mark to be named after.
  static OpeningElement? _openingSaid(
    Design design,
    String openingId,
    String sectionId,
  ) {
    for (final opening in design.openings) {
      if (opening.id == openingId) return opening;
    }
    for (final opening in design.openings) {
      if (opening.sectionId == sectionId) return opening;
    }
    return null;
  }

  /// Moves a bar between dividing the design and dividing one section of it.
  ///
  /// Every line the user draws divides the design; this is how they say one
  /// of them is a section's instead. Passing null puts it back among the main
  /// divisions.
  ///
  /// A bar can only be put inside a section it is actually in. Belonging is
  /// a fact about where the bar is, not a label that can be pinned on it: a
  /// bar in the fixed light beside an opening is not the opening's, and
  /// saying that it is would have the opening drag it across the design the
  /// next time it moved.
  ///
  /// **A bar that has joined a section is laid right across it**, which is
  /// the same thing [addLineInside] does and for the same reason: a bar that
  /// stops half way across divides nothing. A line drawn by hand ends a few
  /// millimetres short of a jamb or a little past it, and while it was
  /// dividing the design that did not matter — it was cutting the section it
  /// now belongs to, from the outside. Inside, those few millimetres are the
  /// difference between glass over panel and one undivided pane with a line
  /// lying on it. [spanAcross] finds where the line the user drew meets the
  /// boundary of the section, so the direction and the position are theirs
  /// and only the two ends move.
  static Design setDividerParent(
    Design design,
    String dividerId,
    String? sectionId,
  ) {
    final divider = _divider(design, dividerId);
    if (divider == null) return design;
    if (divider.parentId == sectionId) return design;
    if (sectionId != null && !liesInside(design, divider, sectionId)) {
      return design;
    }
    final moved = _rebuild(design.withElement(
      sectionId == null
          ? divider.copyWith(clearParent: true)
          : divider.copyWith(parentId: sectionId),
    ));
    if (sectionId == null) return moved;

    // Across the section as it is *now*. Until the bar joined it, the
    // section stopped at the bar; it is the section on the other side of
    // that edge, grown back to its full size, that the bar has to cross.
    final joined = moved.dividerById(dividerId);
    final within = moved.sectionById(
        moved.sectionHolding(joined?.parentId) ?? sectionId);
    if (joined == null || within == null) return moved;
    final across = spanAcross(within.outline, joined.segment);
    if (across == null) return moved;
    final welded = _weldedTo(across, joined.segment, within.outline);
    if (welded.a.distanceTo(joined.a) < Tol.samePointMm &&
        welded.b.distanceTo(joined.b) < Tol.samePointMm) {
      return moved;
    }
    return _rebuild(
        moved.withElement(joined.copyWith(a: welded.a, b: welded.b)));
  }

  /// [line] brought to the edges of the section it has joined — trimmed
  /// where it ran past them, welded where it stopped just short of them,
  /// and left exactly where the user drew it anywhere else.
  ///
  /// The two halves of that are the two rows of the table in this
  /// repository's own notes, and they are not symmetrical.
  ///
  /// *Trimming a line drawn past its corner* is cleaning, always. Outside
  /// the section the line is not the section's anyway, so the end comes
  /// back to the boundary whatever the distance.
  ///
  /// *Welding two ends drawn a few millimetres apart* is cleaning too, but
  /// only for a few millimetres. A line drawn by hand to run the width of a
  /// sash stops a little short of a stile, and inside a section that little
  /// is the difference between two panes and one pane with a line lying on
  /// it, because the face does not close.
  ///
  /// **A line drawn to reach only half way is neither.** Taking that end out
  /// to the far side invents a division nobody drew: an upright drawn from a
  /// rail down to the sill came back running head to sill, and the sash had
  /// four panes where the drawing showed three. The end stays where they put
  /// it, and what the line does or does not divide follows from where it
  /// actually reaches.
  ///
  /// The margin for welding is the section's own weld tolerance, which is
  /// relative: a hand three pixels out is a couple of millimetres on a small
  /// sash and twenty-odd on a three-metre one.
  static Segment _weldedTo(Segment across, Segment line, Polygon within) {
    final reach = Tol.weldFor(math.max(within.width, within.height));

    Vec2 endFor(Vec2 own, Vec2 full) {
      if (!within.contains(own)) return full;
      return own.distanceTo(full) <= reach ? full : own;
    }

    // `spanAcross` runs along the line's own direction, so its ends answer
    // to the line's ends in order.
    return Segment(endFor(line.a, across.a), endFor(line.b, across.b));
  }

  /// True when [divider] lies within the section [sectionId] names — inside
  /// it, or along its edge.
  ///
  /// The one test both the offered list and the accepted change go through,
  /// so what the user is shown and what the design will take are the same
  /// thing by construction.
  ///
  /// The edge counts, because a bar the user wants to put *into* a section is
  /// usually bounding it at the moment they ask: it is the line between that
  /// section and the next, and saying it belongs inside is what joins the two
  /// into one opening. What the test refuses is a bar somewhere else — one in
  /// the fixed light across the design, which is nothing to do with this
  /// section and must not be dragged about by it.
  ///
  /// Sampled along the bar rather than at its middle alone, so a bar crossing
  /// the section and running away out of it is refused however its midpoint
  /// happens to fall.
  static bool liesInside(
    Design design,
    DividerElement divider,
    String sectionId,
  ) {
    final section = design.sectionById(sectionId);
    if (section == null) return false;

    return section.outline.holds(
      divider.segment,
      reach: reachFor(divider),
    );
  }

  /// How far a bar may stray off a section's edge and still be that
  /// section's: its own thickness, because a bar drawn along a boundary sits
  /// half on either side of it.
  static double reachFor(DividerElement divider) =>
      math.max(divider.widthMm, Tol.minLineMm);

  /// The sections a bar could be put inside: the main divisions it actually
  /// lies within. The same test [setDividerParent] applies, so nothing is
  /// offered that would then be refused.
  static List<SectionElement> containersFor(
    Design design,
    String dividerId,
  ) {
    final divider = _divider(design, dividerId);
    if (divider == null) return const [];
    return [
      for (final section in design.topLevelSections)
        if (liesInside(design, divider, section.id)) section,
    ];
  }

  /// Changes what an opening does.
  ///
  /// The mark the user drew is kept as the record of how the section came to
  /// open in the first place. What the opening does now is this, and the
  /// drawing and the model both follow it.
  static Design setOpeningMechanism(
    Design design,
    String openingId,
    OpeningMechanism mechanism,
  ) {
    final opening = _opening(design, openingId);
    if (opening == null) return design;
    if (mechanism == OpeningMechanism.fixed) {
      return OpeningHardware.settle(design.copyWith(openings: [
        for (final o in design.openings) if (o.id != openingId) o,
      ]));
    }
    return OpeningHardware.settle(
      design.withElement(opening.copyWith(mechanism: mechanism)),
    );
  }

  static Design setOpeningSwing(
    Design design,
    String openingId,
    OpeningDirection direction,
  ) {
    final opening = _opening(design, openingId);
    if (opening == null) return design;
    return design.withElement(opening.copyWith(direction: direction));
  }

  /// Moves an opening to a different section.
  ///
  /// The section it leaves stops opening and the section it arrives at
  /// starts. Neither section changes shape: an opening is a property of a
  /// section, not a shape of its own.
  ///
  /// What the opening holds goes with it. A sash the user divided into glass
  /// over panel is that sash wherever it is put, so its bars and its panes
  /// travel, each landing at the same place in the new section as it had in
  /// the old — the same rule that carries them through a resize. Leaving
  /// them behind would put a division in a fixed light nobody drew one in,
  /// and hand the user back an undivided opening they would have to draw
  /// again.
  static Design moveOpeningToSection(
    Design design,
    String openingId,
    String sectionId,
  ) {
    final opening = _opening(design, openingId);
    if (opening == null) return design;
    if (opening.sectionId == sectionId) return design;
    final section = design.sectionById(sectionId);
    if (section == null) return design;
    // A leaf cannot be put inside itself. One of its own panes is part of it,
    // so moving it there would make it its own parent.
    if (_within(design, sectionId, opening.sectionId)) return design;

    final left = design.sectionById(opening.sectionId);
    final carried =
        left == null ? design : _carryInsideTo(design, from: left, to: section);

    return _rebuild(carried.copyWith(openings: [
      for (final o in carried.openings)
        if (o.id != openingId && o.sectionId != sectionId) o,
      OpeningElement(
        id: opening.id,
        sectionId: sectionId,
        mechanism: opening.mechanism,
        direction: opening.direction,
        confirmed: true,
        // The mark goes with the opening, because the mark is what says this
        // section opens. Left where it was drawn it would be a mark in a
        // section that no longer opens, and the next rebuild would read it
        // as one.
        markGlyph: opening.markGlyph,
        markAt: section.outline.centroid,
        fromStrokeId: opening.fromStrokeId,
      ),
    ]));
  }

  /// The sections an opening can be moved to.
  ///
  /// Every section but the ones inside the opening itself, which are part of
  /// it. The same test [moveOpeningToSection] applies, so the user is never
  /// offered a move the design would refuse. The section it is already on
  /// stays in the list, because that is where it is.
  static List<SectionElement> placesFor(Design design, String openingId) {
    final opening = _opening(design, openingId);
    if (opening == null) return const [];
    return [
      for (final section in design.sections)
        if (section.id == opening.sectionId ||
            !_within(design, section.id, opening.sectionId))
          section,
    ];
  }

  /// True when [sectionId] is [ancestorId] or lies inside it.
  static bool _within(Design design, String sectionId, String ancestorId) {
    var id = sectionId;
    for (var depth = 0; depth < 8; depth++) {
      if (id == ancestorId) return true;
      final parent = design.sectionHolding(design.sectionById(id)?.parentId);
      if (parent == null) return false;
      id = parent;
    }
    return false;
  }

  /// Everything inside [from], moved into [to].
  ///
  /// Bars at any depth are moved and the ones [from] held directly become
  /// [to]'s; the panes they make come with them, keeping their ids and so
  /// keeping the glass, the panel, the colour and the name the user gave
  /// them. Where a thing lands is [Polygon.sameIn] — the same place in the
  /// new section as it had in the old.
  static Design _carryInsideTo(
    Design design, {
    required SectionElement from,
    required SectionElement to,
  }) {
    final bars = <String>{};
    final panes = <String>{};
    void collect(String id) {
      for (final divider in design.dividers) {
        if (design.sectionHolding(divider.parentId) == id) bars.add(divider.id);
      }
      for (final section in design.sections) {
        if (design.sectionHolding(section.parentId) != id) continue;
        panes.add(section.id);
        collect(section.id);
      }
    }

    collect(from.id);
    if (bars.isEmpty && panes.isEmpty) return design;

    Vec2 moved(Vec2 point) => from.outline.sameIn(to.outline, point);

    return design.copyWith(
      dividers: [
        for (final divider in design.dividers)
          if (!bars.contains(divider.id))
            divider
          else if (design.sectionHolding(divider.parentId) == from.id)
            divider.copyWith(
              a: moved(divider.a),
              b: moved(divider.b),
              parentId: to.id,
            )
          else
            divider.copyWith(a: moved(divider.a), b: moved(divider.b)),
      ],
      sections: [
        for (final section in design.sections)
          if (!panes.contains(section.id))
            section
          else if (design.sectionHolding(section.parentId) == from.id)
            section.copyWith(
              outline: from.outline.sameShapeIn(to.outline, section.outline),
              parentId: to.id,
            )
          else
            section.copyWith(
              outline: from.outline.sameShapeIn(to.outline, section.outline),
            ),
      ],
    );
  }

  /// Changes an opening's ironmongery.
  ///
  /// Only what is named changes. Passing nothing for a figure leaves it as it
  /// was, and the hinges and handle are worked out again from the opening so
  /// they land where the new figures put them.
  static Design setOpeningHardware(
    Design design,
    String openingId, {
    int? hingeCount,
    double? hingeFromStartMm,
    double? hingeFromEndMm,
    double? handleAlongMm,
  }) {
    final opening = _opening(design, openingId);
    if (opening == null) return design;
    return OpeningHardware.settle(design.withElement(opening.copyWith(
      hingeCount: hingeCount,
      hingeFromStartMm: hingeFromStartMm,
      hingeFromEndMm: hingeFromEndMm,
      handleAlongMm: handleAlongMm,
    )));
  }

  /// The opening a piece of hardware belongs to, or null when the user put
  /// the piece there themselves.
  static OpeningElement? openingOwning(Design design, String hardwareId) {
    for (final piece in design.hardware) {
      if (piece.id != hardwareId) continue;
      return design.openingHolding(piece.parentId);
    }
    return null;
  }

  /// Which hinge a piece is, counting down or along the hinged edge from the
  /// start. Null when the piece is not one of an opening's hinges.
  static int? hingeIndexOf(Design design, String hardwareId) {
    final opening = openingOwning(design, hardwareId);
    if (opening == null) return null;
    final prefix = '${opening.id}-hinge-';
    if (!hardwareId.startsWith(prefix)) return null;
    return int.tryParse(hardwareId.substring(prefix.length));
  }

  static OpeningElement? _opening(Design design, String id) {
    for (final opening in design.openings) {
      if (opening.id == id) return opening;
    }
    return null;
  }

  /// Which element, if any, is at [point] — for tapping on the canvas.
  ///
  /// Ordered so that the small things on top of a section are reachable: a
  /// handle beats the bar it sits on, and a bar beats the section behind it.
  static DesignElement? hitTest(
    Design design,
    Vec2 point, {
    required double slopMm,
  }) {
    for (final opening in design.openings) {
      final at = opening.markAt;
      if (at != null && at.distanceTo(point) <= slopMm * 1.6) return opening;
    }
    for (final piece in design.hardware) {
      if (piece.at.distanceTo(point) <= slopMm * 2) return piece;
    }
    for (final text in design.texts) {
      if (text.at.distanceTo(point) <= math.max(slopMm, text.sizeMm)) {
        return text;
      }
    }
    for (final dimension in design.dimensions) {
      if (dimension.anchor.distanceTo(point) <= slopMm * 2) return dimension;
    }
    for (final arrow in design.arrows) {
      if (arrow.segment.distanceTo(point) <= slopMm) return arrow;
    }
    for (final divider in design.dividers) {
      final reach = math.max(slopMm, divider.widthMm / 2);
      if (divider.segment.distanceTo(point) <= reach) return divider;
    }
    final section = SectionBuilder.sectionAt(design, point);
    if (section != null) return section;
    // Tapping the frame picks the side you tapped — the head, the sill, a
    // jamb — because that is the part you are pointing at. The frame as a
    // whole is reached from the component tree.
    final frame = design.frame;
    if (frame != null) {
      FrameMemberElement? nearest;
      var best = double.infinity;
      for (final member in design.frameMembers) {
        final away = member.run.distanceTo(point);
        if (away <= math.max(slopMm, frame.profileMm) && away < best) {
          best = away;
          nearest = member;
        }
      }
      if (nearest != null) return nearest;
    }
    return null;
  }

  /// Where a drag on [element] should put it, given a drag of [by].
  static Design dragElement(Design design, String elementId, Vec2 by) {
    final element = design.elementById(elementId);
    return switch (element) {
      DividerElement() => moveDivider(design, elementId, by),
      HardwareElement() => moveHardware(design, elementId, element.at + by),
      TextElement() => design.withElement(element.copyWith(at: element.at + by)),
      ArrowElement() => design.withElement(
          element.copyWith(from: element.from + by, to: element.to + by)),
      DimensionElement() => design.withElement(
          element.copyWith(a: element.a + by, b: element.b + by)),
      FrameMemberElement() => design,
      FrameElement() => _rebuild(design.copyWith(
          frame: element.copyWith(outline: element.outline.translated(by)),
          dividers: [
            for (final d in design.dividers) d.translated(by),
          ],
          hardware: [
            for (final h in design.hardware) h.copyWith(at: h.at + by),
          ],
        )),
      // A section is not moved directly — it is the space between the bars
      // around it, so the bars are what move.
      SectionElement() || OpeningElement() || null => design,
    };
  }

  static DividerElement? _divider(Design design, String id) {
    for (final d in design.dividers) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// The divider running along a given x or y, if there is one.
  /// The bar lying along a given line, at the level [within] belongs to.
  ///
  /// A section's edge can only be made by a bar at its own level: the panes
  /// of an opening are made by the bars drawn inside that opening, and a
  /// transom on the design outside it cannot be what one of them ends at,
  /// even where the two happen to lie along the same line.
  static DividerElement? _dividerAlong(
    Design design, {
    double? x,
    double? y,
    String? within,
  }) {
    // The level is a section; a bar inside an opening names the opening. Both
    // are resolved to the section, so the two sides are asked the same thing.
    final level = design.sectionHolding(within);
    for (final divider in design.dividers) {
      if (design.sectionHolding(divider.parentId) != level) continue;
      if (x != null && divider.isVertical) {
        final at = (divider.a.x + divider.b.x) / 2;
        final reach = math.max(divider.widthMm, Tol.minLineMm);
        if ((at - x).abs() <= reach) return divider;
      }
      if (y != null && divider.isHorizontal) {
        final at = (divider.a.y + divider.b.y) / 2;
        final reach = math.max(divider.widthMm, Tol.minLineMm);
        if ((at - y).abs() <= reach) return divider;
      }
    }
    return null;
  }

  static Design _rebuild(Design design) => SectionBuilder.rebuild(design);
}
