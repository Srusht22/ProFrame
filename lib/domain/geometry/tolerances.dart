/// Documented geometric tolerances (spec section 12).
///
/// "Exact" in this application means matching the confirmed specification
/// within these numbers — not reproducing shaky strokes literally
/// (spec section 2). Every comparison in the geometry layer uses one of these
/// rather than an inline epsilon, so the tolerances can be reviewed in one
/// place and cited in test failures.
abstract final class Tolerances {
  /// Two model points closer than this are the same point. 0.5 mm is below
  /// what any fabrication process resolves and well under a profile wall
  /// thickness, so merging within it cannot change a cut length.
  static const double pointCoincidenceMm = 0.5;

  /// A length difference under this is not a difference. Matches
  /// [pointCoincidenceMm] so a segment and its endpoints agree.
  static const double lengthMm = 0.5;

  /// An edge within this of horizontal or vertical is treated as axis-aligned.
  ///
  /// Chosen from the drawing side, not the manufacturing side: hand strokes in
  /// the reference sketches wobble by two to three degrees, while a deliberate
  /// sloping top in a real door is at least eight. Five degrees separates them
  /// with margin on both sides, which is what keeps shaky lines straight
  /// without flattening an intended slope (spec section 4).
  static const double axisAlignmentDegrees = 5;

  /// Below this a region is not a panel — it is a gap between strokes.
  /// 100 mm² is a 10 mm square, smaller than any real glazed area.
  static const double minimumPanelAreaMmSq = 100;

  /// The smallest panel side the app will accept without objecting.
  static const double minimumPanelSideMm = 50;

  // -- stroke recognition ---------------------------------------------------
  //
  // These govern reading a finger drawing, which is a looser problem than
  // measuring a product. They are deliberately separate from
  // [axisAlignmentDegrees]: that one decides whether a *frame edge* is a
  // deliberate slope, where being wrong scraps a frame. These decide what a
  // rough gesture meant, where being wrong costs one undo.

  /// How far a sample may sit off the line between its neighbours before it
  /// counts as a corner. Large, because a finger wobbles by several
  /// millimetres and every wobble would otherwise read as a corner.
  static const double cornerToleranceMm = 12;

  /// A divider stroke is "mostly vertical" when its vertical extent is at
  /// least this many times its horizontal extent, and vice versa.
  ///
  /// 2.0 is about 26 degrees off axis. Well beyond any hand wobble, and well
  /// short of the 45 degrees at which the two axes become a coin toss — so a
  /// stroke that is genuinely diagonal is discarded rather than snapped to
  /// whichever axis it leans towards.
  static const double dividerAxisDominance = 2.0;

  /// How close a stroke's ends must be, relative to its own size, for the
  /// loop to count as closed.
  ///
  /// A frame drawn by hand rarely meets itself exactly; 0.25 of the diagonal
  /// accepts a visible gap while still rejecting an open L shape.
  static const double loopClosureFraction = 0.25;

  /// The smallest a drawn frame may be before it is treated as a stray mark.
  static const double minimumFrameSideMm = 200;

  /// How far the point of a chevron must stick out sideways past its ends,
  /// as a fraction of its own arm length.
  ///
  /// Expressed as a fraction so it holds at any drawing scale. A quarter is
  /// comfortably past the few millimetres a hand wobbles when drawing what was
  /// meant to be a straight line, so a kinked vertical stroke is not read as a
  /// `<`.
  static const double chevronReachFraction = 0.25;

  /// Whether [a] and [b] are the same length within [lengthMm].
  static bool sameLength(double a, double b) => (a - b).abs() <= lengthMm;

  const Tolerances._();
}
