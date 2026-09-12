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

  /// Below this a region is not a section — it is a gap between strokes.
  /// 100 mm² is a 10 mm square, smaller than any real glazed area.
  static const double minimumSectionAreaMmSq = 100;

  /// The smallest section side the app will accept without objecting.
  static const double minimumSectionSideMm = 50;

  /// Whether [a] and [b] are the same length within [lengthMm].
  static bool sameLength(double a, double b) => (a - b).abs() <= lengthMm;

  const Tolerances._();
}
