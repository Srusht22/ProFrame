import 'dart:math' as math;

import '../model/design.dart';

// ---------------------------------------------------------------------------
// One space for the whole solid
// ---------------------------------------------------------------------------
//
// Every part of the model — frame, sash, bars, glass, panels, beads,
// ironmongery — is placed in one coordinate system, and this is it:
//
//   X  across the design, to the right, in millimetres — the drawing's own x.
//   Y  down the elevation, in millimetres — the drawing's own y. Up is -Y.
//   Z  out of the face the drawing is of, towards whoever is looking at it.
//      The frame's drawn face is Z = 0 and the design runs back from it to
//      Z = -depth ([Design.depthMm]).
//
// X and Y are the drawing's, unchanged, because the front-facing design is
// the source of truth: every figure the user drew or typed is carried into
// the solid exactly, and nothing in the third dimension can move one. Depth
// is only Z, and only [DepthLayout] says where along it anything stands. Y
// runs down, as the drawing's does, rather than being turned up for the
// solid: a second convention for the same design is how two views come to
// disagree. The camera's eye space is the same turn of hand — x across the
// screen, y down it, z out of it — so a face seen square on in the model is
// seen square on on the screen.

/// A span of depth: from [front], the side nearer the face the drawing is
/// of, back to [back]. Both are Z values, so [front] > [back].
class DepthBand {
  final double front;
  final double back;

  const DepthBand(this.front, this.back);

  /// How deep it is.
  double get depth => front - back;

  /// Half way through it.
  double get middle => (front + back) / 2;

  /// A band [thickness] deep, centred in this one.
  DepthBand centred(double thickness) =>
      DepthBand(middle + thickness / 2, middle - thickness / 2);

  /// This band with [share] of its depth taken off each face.
  DepthBand inset(double share) =>
      DepthBand(front - depth * share, back + depth * share);

  /// Whether [z] is within it, give or take [slack].
  bool holds(double z, {double slack = 1e-6}) =>
      z <= front + slack && z >= back - slack;

  @override
  bool operator ==(Object other) =>
      other is DepthBand && other.front == front && other.back == back;

  @override
  int get hashCode => Object.hash(front, back);

  @override
  String toString() =>
      'DepthBand(${front.toStringAsFixed(2)} … ${back.toStringAsFixed(2)})';
}

/// Where along Z every part of a design stands: the one description of the
/// solid's depth.
///
/// **Every figure is a share of what holds the part**, so depth is
/// consistent at every level of the tree. A leaf stands in whatever holds it
/// — the frame, or another leaf — the same way; the bars and the panes drawn
/// inside a leaf stand in the leaf the way the design's own bars and lights
/// stand in the frame; glass and panels are centred in what holds them. A
/// part inside a sash was once placed against the frame's depth instead of
/// the sash's, so a glazing bar stood proud of the sash it was in and the
/// panes of a divided sash sat off its middle — which is what this is for.
///
/// **Only Z.** Nothing here reads or changes a width, a height or a
/// position on the face: those are the drawing's.
class DepthLayout {
  /// How deep the frame is: [Design.depthMm].
  final double depth;

  /// Whether the room — where a glazing bead is fixed from — is on the face
  /// the drawing is of: a design seen from inside.
  final bool roomInFront;

  const DepthLayout(this.depth, {this.roomInFront = false});

  factory DepthLayout.of(Design design) =>
      DepthLayout(design.depthMm, roomInFront: design.seenFrom == Face.inside);

  /// The frame: from its drawn face at Z = 0 back through its whole depth.
  DepthBand get frame => DepthBand(0, -depth);

  /// How far back from the face of what holds it a leaf's face stands, as a
  /// share of that depth: set a little in, as a sash is.
  static const leafSetBack = 0.08;

  /// How much of the depth of what holds it a leaf takes.
  static const leafShare = 0.66;

  /// A leaf hanging in [holder]: a little back from its face, two thirds of
  /// its depth deep.
  DepthBand leafIn(DepthBand holder) {
    final front = holder.front - holder.depth * leafSetBack;
    return DepthBand(front, front - holder.depth * leafShare);
  }

  /// The leaf hanging in the frame.
  DepthBand get leaf => leafIn(frame);

  /// How much of the depth of what holds them a bar gives up at each face:
  /// set back from both, as a mullion is from the frame's faces.
  static const barSetBack = 0.1;

  /// The bars in [holder] — the design's own in the frame, a glazing bar in
  /// its leaf.
  DepthBand barsIn(DepthBand holder) => holder.inset(barSetBack);

  /// A glazing unit in [holder]: as deep as a sealed unit is made, never
  /// more than two fifths of what holds it, and centred in it.
  DepthBand glazingIn(DepthBand holder) =>
      holder.centred(math.min(28.0, holder.depth * 0.4));

  /// A panel in [holder]: more than half its depth, never more than a
  /// panel is made, and centred in it.
  DepthBand panelIn(DepthBand holder) =>
      holder.centred(math.min(40.0, holder.depth * 0.55));

  /// How thick each pane of glass in a sealed unit is.
  static const lite = 4.0;

  /// The narrowest cavity a unit is made with: thinner than this, it is a
  /// single sheet of glass.
  static const narrowestCavity = 6.0;

  /// The two panes of a sealed unit filling [unit], front one first — or the
  /// one sheet, where the unit is too thin to be two with a cavity.
  List<DepthBand> litesOf(DepthBand unit) {
    final pane = math.min(lite, unit.depth * 0.25);
    if (unit.depth - 2 * pane < narrowestCavity) return [unit];
    return [
      DepthBand(unit.front, unit.front - pane),
      DepthBand(unit.back + pane, unit.back),
    ];
  }

  /// How far a glazing bead stops short of the face of what holds it, as a
  /// share of that depth: behind the frame's or the sash's own face, where
  /// its sightline has already fallen away.
  static const beadSetBack = 0.12;

  /// The glazing bead holding [unit] in [holder], on the room side: from the
  /// unit's face on that side out to a little short of the holder's face.
  /// Null where there is no room for one.
  DepthBand? beadIn(DepthBand holder, DepthBand unit) {
    final band = roomInFront
        ? DepthBand(holder.front - holder.depth * beadSetBack, unit.front)
        : DepthBand(unit.back, holder.back + holder.depth * beadSetBack);
    return band.depth > 1 ? band : null;
  }
}
