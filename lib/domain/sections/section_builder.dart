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

    final bounds = frame.innerOutline;
    final lines = <Segment>[
      ...bounds.edges,
      for (final divider in design.dividers)
        ..._clipToBounds(divider.segment, bounds),
    ];

    // The ends are already where the user put them, so this only has to
    // cover arithmetic and the width of a drawn line, not a shaky hand.
    final weld = Tol.weldFor(
      math.sqrt(bounds.width * bounds.width + bounds.height * bounds.height),
      fraction: Tol.weldFractionClean,
    );
    final faces = PlanarSubdivision.facesOf(lines, weldTolerance: weld);
    var counter = 0;
    String nextId() => newId?.call() ?? 'section-${design.id}-${counter++}';

    // Sections read the way a drawing reads: top to bottom, then left to
    // right, so the component tree matches what the eye follows — and so
    // that two rebuilds of the same design put them in the same order.
    faces.sort(_readingOrder);

    final sections = _carryIdentityForward(design.sections, faces, nextId);

    final liveIds = {for (final s in sections) s.id};
    return design.copyWith(
      sections: sections,
      openings: [
        for (final opening in design.openings)
          if (liveIds.contains(opening.sectionId)) opening,
      ],
    );
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
}
