import 'dart:math' as math;

import '../geometry/polygon.dart';
import 'design.dart';
import 'elements.dart';

/// The leaf of an opening: the part that swings.
///
/// An opening is a region of the design, and the leaf is the sash filling
/// that region — its own frame of material, with glass or a panel inside it.
/// It has a boundary of its own, and that boundary is the section's, never
/// the window's: a leaf that took the whole outline would be a door the size
/// of the wall it is in.
///
/// Both the drawing and the solid are built from what is here, so the leaf
/// the user sees in the elevation and the leaf that swings in the model are
/// the same leaf, described once.
abstract final class OpeningLeaf {
  /// How thick the leaf's own frame is, as a fraction of the outer frame's.
  ///
  /// A sash is lighter than the frame it hangs in — it carries only glass,
  /// not the building — but it is not flimsy, so there is a floor under it.
  static const double ofFrameProfile = 0.7;
  static const double leastProfileMm = 18;

  /// The profile of the leaf hanging in [frame].
  static double profileFor(FrameElement frame) =>
      math.max(leastProfileMm, frame.profileMm * ofFrameProfile);

  /// The outside of the leaf: the boundary of the section that opens, and
  /// nothing wider.
  static Polygon outerOf(SectionElement section) => section.outline;

  /// The daylight inside the leaf — what the glass or the panel fills — or
  /// null when the leaf is too small to have any.
  static Polygon? innerOf(SectionElement section, FrameElement frame) {
    final outer = outerOf(section);
    final inner = outer.inset(profileFor(frame));
    if (inner.isEmpty) return null;
    if (inner.corners.length != outer.corners.length) return null;
    if (inner.area <= 0 || inner.area >= outer.area) return null;
    return inner;
  }

  /// The leaf of [opening] on [design], or null when there is nothing to
  /// hang — no section, or no frame to hang it in.
  static ({Polygon outer, Polygon? inner})? of(
    Design design,
    OpeningElement opening,
  ) {
    final section = design.sectionById(opening.sectionId);
    final frame = design.frame;
    if (section == null || frame == null) return null;
    return (outer: outerOf(section), inner: innerOf(section, frame));
  }
}
