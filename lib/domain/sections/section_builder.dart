import 'dart:math' as math;

import '../geometry/polygon.dart';
import '../geometry/segment.dart';
import '../geometry/tolerances.dart';
import '../geometry/vec2.dart';
import '../model/design.dart';
import '../model/elements.dart';
import 'planar_graph.dart';

/// Works out the sections of a design from its frame and its dividers.
///
/// Run after anything that changes a line. The sections are whatever the
/// user's own lines enclose — this never decides how many there should be,
/// how big they should be, or whether they ought to match.
abstract final class SectionBuilder {
  /// The design with its sections brought up to date.
  ///
  /// A section that still covers the same ground keeps its id, and so keeps
  /// the colour, material, name and opening the user gave it. Only a section
  /// that genuinely was not there before is new.
  static Design rebuild(Design design, {String Function()? newId}) {
    final frame = design.frame;
    if (frame == null) {
      return design.copyWith(sections: const [], openings: const []);
    }

    // Ids already in play, so a new section can never be handed one that a
    // section carried forward is already using. Two sections sharing an id
    // makes one of them its own parent, and the tree stops being a tree.
    final used = {for (final section in design.sections) section.id};
    var counter = 0;
    String nextId() {
      final made = newId?.call();
      if (made != null) {
        used.add(made);
        return made;
      }
      while (used.contains('section-${design.id}-$counter')) {
        counter++;
      }
      final id = 'section-${design.id}-${counter++}';
      used.add(id);
      return id;
    }

    // The main divisions of the design: what the frame encloses, cut by the
    // bars that divide the design as a whole. Bars drawn inside a section
    // are not among them — they divide that section, not this.
    final top = _subdivide(
      bounds: frame.innerOutline,
      dividers: design.topLevelDividers,
    );
    top.sort(_readingOrder);

    final parents = _carryIdentityForward(
      design.topLevelSections,
      top,
      nextId,
    );

    // Anything drawn inside a section travels with it. Where a section has
    // moved or changed size, its contents are carried by the same movement,
    // so an opening and everything in it stay one thing.
    var dividers = design.dividers;
    for (var i = 0; i < parents.length; i++) {
      final was = _previousOutlineOf(design, parents[i].id);
      if (was == null) continue;
      dividers = _carryContents(
        design: design,
        dividers: dividers,
        sectionId: parents[i].id,
        from: was,
        to: parents[i].outline,
      );
    }

    // Then each section that has bars inside it is divided by them, and only
    // by them. This is what stops a line drawn inside an opening from
    // splitting the whole design into another top-level section.
    final sections = <SectionElement>[];
    for (final parent in parents) {
      sections.add(parent);
      sections.addAll(
        _childrenOf(
          design: design,
          dividers: dividers,
          parent: parent,
          nextId: nextId,
        ),
      );
    }

    final liveIds = {for (final s in sections) s.id};
    return design.copyWith(
      dividers: [
        for (final divider in dividers)
          if (divider.parentId == null || liveIds.contains(divider.parentId))
            divider,
      ],
      sections: sections,
      openings: [
        for (final opening in design.openings)
          if (liveIds.contains(opening.sectionId)) opening,
      ],
    );
  }

  /// The sections inside [parent], made by the bars drawn in it.
  ///
  /// Recursive, because a bar drawn inside one of those sections divides
  /// that one in turn. The drawing decides how deep this goes; nothing here
  /// imposes a limit beyond a guard against a cycle.
  static List<SectionElement> _childrenOf({
    required Design design,
    required List<DividerElement> dividers,
    required SectionElement parent,
    required String Function() nextId,
    int depth = 0,
  }) {
    if (depth > 6) return const [];
    final inside = [
      for (final d in dividers) if (d.parentId == parent.id) d,
    ];
    if (inside.isEmpty) return const [];

    final faces = _subdivide(bounds: parent.outline, dividers: inside)
      ..sort(_readingOrder);
    if (faces.length < 2) return const [];

    final previous = [
      for (final s in design.sections) if (s.parentId == parent.id) s,
    ];
    final children = [
      for (final child in _carryIdentityForward(previous, faces, nextId))
        child.copyWith(parentId: parent.id),
    ];

    final out = <SectionElement>[];
    for (final child in children) {
      out.add(child);
      out.addAll(_childrenOf(
        design: design,
        dividers: dividers,
        parent: child,
        nextId: nextId,
        depth: depth + 1,
      ));
    }
    return out;
  }

  /// The faces [dividers] cut [bounds] into.
  static List<Polygon> _subdivide({
    required Polygon bounds,
    required List<DividerElement> dividers,
  }) {
    if (bounds.isEmpty) return const [];

    // Every bar is cut in as its two faces and its two ends, not as its
    // centre line. A bar is a real piece of material with a width: the glass
    // stops at its face, not at the middle of it. Subdividing on the centre
    // line made every daylight opening half a bar too wide, which nobody
    // notices on a coloured picture and everybody notices on a drawing with
    // dimensions on it.
    final bodies = <Polygon>[];
    final lines = <Segment>[...bounds.edges];
    for (final divider in dividers) {
      final run = _clipToBounds(divider.segment, bounds);
      if (run.isEmpty) continue;
      final body = _bodyOf(run.single, divider.widthMm);
      bodies.add(body);
      for (final edge in body.edges) {
        lines.addAll(_clipToBounds(edge, bounds));
      }
    }

    // The ends are already where the user put them, so this only has to
    // cover arithmetic and the width of a drawn line, not a shaky hand.
    final weld = Tol.weldFor(
      math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height),
      fraction: Tol.weldFractionClean,
    );
    final all = PlanarSubdivision.facesOf(lines, weldTolerance: weld);

    // What is left once the bars themselves are taken out is the daylight.
    return [
      for (final face in all)
        if (!bodies.any((body) => body.contains(face.centroid))) face,
    ];
  }

  static Polygon? _previousOutlineOf(Design design, String sectionId) {
    for (final section in design.sections) {
      if (section.id == sectionId) return section.outline;
    }
    return null;
  }

  /// Moves everything inside a section by the same change the section made.
  ///
  /// A section is the space between the bars around it, so it moves when
  /// they do. What is drawn inside it has to move with it, or a bar drawn
  /// within an opening would be left behind on the frame when the opening
  /// was dragged — which is the one thing an opening's contents must never
  /// do.
  static List<DividerElement> _carryContents({
    required Design design,
    required List<DividerElement> dividers,
    required String sectionId,
    required Polygon from,
    required Polygon to,
  }) {
    if (from.width <= 0 || from.height <= 0) return dividers;
    final sameSize = (from.width - to.width).abs() < 1e-6 &&
        (from.height - to.height).abs() < 1e-6;
    final samePlace = (from.left - to.left).abs() < 1e-6 &&
        (from.top - to.top).abs() < 1e-6;
    if (sameSize && samePlace) return dividers;

    final sx = to.width / from.width;
    final sy = to.height / from.height;
    Vec2 moved(Vec2 p) => Vec2(
          to.left + (p.x - from.left) * sx,
          to.top + (p.y - from.top) * sy,
        );

    // The ids of everything inside this section, at any depth: a bar two
    // levels down still belongs to the thing being moved.
    final inside = <String>{};
    void collect(String id) {
      for (final divider in dividers) {
        if (divider.parentId == id) inside.add(divider.id);
      }
      for (final section in design.sections) {
        if (section.parentId == id) collect(section.id);
      }
    }

    collect(sectionId);
    if (inside.isEmpty) return dividers;

    return [
      for (final divider in dividers)
        if (inside.contains(divider.id))
          divider.copyWith(a: moved(divider.a), b: moved(divider.b))
        else
          divider,
    ];
  }

  static int _readingOrder(Polygon a, Polygon b) {
    final rowA = (a.top / 10).round();
    final rowB = (b.top / 10).round();
    if (rowA != rowB) return rowA.compareTo(rowB);
    return a.left.compareTo(b.left);
  }

  /// Gives each new face the id of the section it is a continuation of, so
  /// the colour, material, name and opening the user set stay with the part
  /// they set them on.
  ///
  /// When the design still has the same number of sections, nothing was added
  /// or removed — a bar was moved, or the frame was resized — and the nth
  /// section in reading order is still the nth section. That is what the user
  /// sees, and it is right even when a bar moves so far that the new left
  /// section overlaps the old right one more than the old left one.
  ///
  /// When the count changed, a line was drawn or deleted, and the match is
  /// made on how much ground each new face shares with each old section.
  static List<SectionElement> _carryIdentityForward(
    List<SectionElement> previous,
    List<Polygon> faces,
    String Function() nextId,
  ) {
    if (previous.length == faces.length) {
      return [
        for (var i = 0; i < faces.length; i++)
          previous[i].copyWith(outline: faces[i]),
      ];
    }

    final claimed = <String>{};
    final matched = List<SectionElement?>.filled(faces.length, null);

    // Every pairing, best first, so a strong match is never lost to a weaker
    // one that happened to be considered earlier.
    final pairs = <(double, int, SectionElement)>[];
    for (var i = 0; i < faces.length; i++) {
      for (final candidate in previous) {
        final share = _overlapFraction(faces[i], candidate.outline);
        if (share >= 0.5) pairs.add((share, i, candidate));
      }
    }
    pairs.sort((a, b) => b.$1.compareTo(a.$1));

    for (final (_, index, candidate) in pairs) {
      if (matched[index] != null) continue;
      if (claimed.contains(candidate.id)) continue;
      matched[index] = candidate;
      claimed.add(candidate.id);
    }

    return [
      for (var i = 0; i < faces.length; i++)
        matched[i]?.copyWith(outline: faces[i]) ??
            SectionElement(id: nextId(), outline: faces[i]),
    ];
  }

  /// Roughly how much of [face] lies inside [other], 0 to 1.
  ///
  /// Measured by sampling rather than by clipping, because a face can be any
  /// shape the user's lines make, including a non-convex one. The grid is
  /// coarse on purpose: this decides which section is which, not how big it
  /// is.
  static double _overlapFraction(Polygon face, Polygon other) {
    const steps = 11;
    var inside = 0;
    var tested = 0;
    for (var ix = 0; ix < steps; ix++) {
      for (var iy = 0; iy < steps; iy++) {
        final point = Vec2(
          face.left + face.width * (ix + 0.5) / steps,
          face.top + face.height * (iy + 0.5) / steps,
        );
        if (!face.contains(point)) continue;
        tested++;
        if (other.contains(point)) inside++;
      }
    }
    if (tested == 0) return other.contains(face.centroid) ? 1 : 0;
    return inside / tested;
  }

  /// The rectangle a bar actually occupies.
  static Polygon _bodyOf(Segment run, double widthMm) {
    final side = run.unit.perpendicular * (widthMm / 2);
    return Polygon([
      run.a + side,
      run.b + side,
      run.b - side,
      run.a - side,
    ]);
  }

  /// Trims a divider to the part of it that is actually inside the frame.
  ///
  /// A user drawing quickly runs the line past the frame, or stops a little
  /// short. Neither changes what they meant: the bar runs across the opening.
  /// The line itself is not modified — only the copy the subdivision sees.
  static List<Segment> _clipToBounds(Segment line, Polygon bounds) {
    final aInside = bounds.contains(line.a);
    final bInside = bounds.contains(line.b);
    if (aInside && bInside) return [line];

    final hits = <double>[];
    for (final edge in bounds.edges) {
      final crossing = line.crossing(edge, tolerance: Tol.samePointMm);
      if (crossing != null) hits.add(crossing.onA);
    }
    if (hits.isEmpty) return aInside || bInside ? [line] : const [];

    hits.sort();
    final from = aInside ? 0.0 : hits.first;
    final to = bInside ? 1.0 : hits.last;
    if (to - from < 1e-6) return const [];

    final clipped = Segment(line.pointAt(from), line.pointAt(to));
    return clipped.length < Tol.minLineMm ? const [] : [clipped];
  }

  /// Which section a point falls in, for tapping on the canvas.
  ///
  /// The smallest one that contains it, so tapping inside an opening that
  /// has been divided picks the pane you are pointing at rather than the
  /// opening around it. The opening itself is reached from its mark, from
  /// the component tree, or from that pane's own panel.
  static SectionElement? sectionAt(Design design, Vec2 point) {
    SectionElement? smallest;
    for (final section in design.sections) {
      if (!section.outline.contains(point)) continue;
      if (smallest == null || section.areaMmSq < smallest.areaMmSq) {
        smallest = section;
      }
    }
    return smallest;
  }

  /// The outermost section containing [point] — the one that owns that part
  /// of the design rather than the smallest piece of it.
  static SectionElement? topSectionAt(Design design, Vec2 point) {
    SectionElement? largest;
    for (final section in design.topLevelSections) {
      if (!section.outline.contains(point)) continue;
      if (largest == null || section.areaMmSq > largest.areaMmSq) {
        largest = section;
      }
    }
    return largest;
  }
}
