import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
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

    final right = _dividerAlong(design, x: section.outline.right);
    if (right != null) {
      return moveDivider(design, right.id, Vec2(growth, 0));
    }
    final left = _dividerAlong(design, x: section.outline.left);
    if (left != null) {
      return moveDivider(design, left.id, Vec2(-growth, 0));
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

    final below = _dividerAlong(design, y: section.outline.bottom);
    if (below != null) {
      return moveDivider(design, below.id, Vec2(0, growth));
    }
    final above = _dividerAlong(design, y: section.outline.top);
    if (above != null) {
      return moveDivider(design, above.id, Vec2(0, -growth));
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
    ));
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
    // the shape it was drawn with.
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
      return design.copyWith(openings: without);
    }
    return design.copyWith(openings: [
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
      ),
    ]);
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
    final frame = design.frame;
    if (frame != null) {
      for (final edge in frame.outline.edges) {
        if (edge.distanceTo(point) <= math.max(slopMm, frame.profileMm)) {
          return frame;
        }
      }
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
  static DividerElement? _dividerAlong(Design design, {double? x, double? y}) {
    for (final divider in design.dividers) {
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
