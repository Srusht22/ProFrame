import 'dart:math' as math;

/// Every tolerance the geometry uses, in one place, each with the reason it
/// is the size it is.
///
/// They are all about reading a *drawing*, not about manufacturing. Being
/// wrong here costs the user one undo; being wrong about what they meant
/// costs them a window.
abstract final class Tol {
  /// Two points closer than this are the same point. Half a millimetre is
  /// below anything a workshop cuts to.
  static const double samePointMm = 0.5;

  /// Lengths within this of each other are the same length.
  static const double sameLengthMm = 0.5;

  /// How far off horizontal or vertical a line may be and still be treated as
  /// straight along that axis.
  ///
  /// Cleaning, not redesigning: a hand wobbles two or three degrees, a line
  /// somebody meant to slope is drawn at eight or more. Five separates them
  /// with margin either side, and a line further off than this keeps the
  /// angle it was drawn at, exactly.
  static const double axisSnapDegrees = 5;

  /// How far a line may lean off level or upright and still be read as a
  /// lean of the hand **in a standard design** — a door, a window, a
  /// sliding set, or both — rather than a slope.
  ///
  /// Beyond [axisSnapDegrees] a line is squared only when the drawing round
  /// it says it was meant square: the side opposite it is square, or it
  /// turns a corner from a square side (`GeometryNormalizer`). A finger
  /// drawing a jamb the height of a phone leans it six or eight degrees as
  /// often as not, and in a design the user began as a door or a window
  /// that is the jamb of a rectangle drawn by hand. Ten, because past it the
  /// lean is plain to the eye and so is likely meant; and never in an
  /// angled design, where the user said before drawing that slopes are
  /// meant.
  static const double leanDegrees = 10;

  /// How far a line may be out — one end against the other, across the
  /// axis it is near — and still be a wobble of the hand whatever is round
  /// it, as a share of the size of the whole drawing.
  ///
  /// An angle alone cannot say this. Five degrees on a short rail is a few
  /// millimetres; on a jamb running the height of the drawing it is the
  /// best part of a tenth of the drawing, which the eye sees plainly and
  /// which may well be meant. The hand's own error scales with what it is
  /// drawing — people draw a design to fill the screen, whatever size it
  /// will be built — so the measure is the distance out against the
  /// drawing's own size: a twentieth, which is a line half the drawing
  /// long drawn [axisSnapDegrees] off. Further out than this, a line within
  /// [axisSnapDegrees] is squared only where the drawing round it is square
  /// (the lean rule), and in an angled design not at all.
  static const double wobbleShare = 0.05;

  /// How far squaring a lean may move the far end of the line, as a share
  /// of the width of what it bounds — the gap to the square side opposite
  /// it, or the length of the square side it turns a corner from.
  ///
  /// A lean that changes the width of what it bounds by more than this is a
  /// shape, not a wobble: a narrow light drawn tapering is a tapering light,
  /// whatever its angle. A tall door drawn on a phone leans its jamb a
  /// quarter of its own width, so the share is set just above that.
  static const double leanShare = 0.3;

  /// How far a line may run past a corner and still be read as drawn past
  /// it, as a fraction of its own length.
  ///
  /// Two lines that cross a little way from both their ends are a corner
  /// the hand overshot — trimming them back is cleaning, *Trimming a line
  /// drawn past its corner* — and left alone the stub is a bar lying along
  /// the frame that nobody drew. A tenth, because a hand overshoots by a
  /// finger's width on a line a hand long, and a stub a tenth of the line is
  /// already far longer than the join tolerance catches.
  static const double overshootFraction = 0.1;

  /// How far a sample may sit off the line between its neighbours before it
  /// counts as a corner, as a fraction of the stroke's own size.
  ///
  /// Relative, because the sheet is metres across on a screen a few hundred
  /// pixels wide: a fixed millimetre figure is either blind to real corners
  /// on a small drawing or sees a corner in every wobble on a large one.
  static const double cornerFraction = 0.05;

  /// The floor for the above, for a very small mark.
  static const double cornerFloorMm = 10;

  /// How near two ends must be, as a fraction of the size of the thing being
  /// drawn, to be treated as meeting. A box drawn side by side rarely has its
  /// corners meet exactly.
  static const double joinFraction = 0.12;

  /// How close a stroke's two ends must be, relative to its own size, for it
  /// to count as closed.
  static const double closeFraction = 0.25;

  /// How near two ends must be to count as the same point, on a drawing
  /// whose overall size is [spanMm].
  ///
  /// Relative, for the same reason as [cornerFraction]: a hand that lands
  /// three pixels away from where it meant to lands twenty-three millimetres
  /// away on a three-metre sheet. A fixed half-millimetre leaves every
  /// hand-drawn junction hanging open.
  static double weldFor(double spanMm, {double fraction = weldFraction}) =>
      math.max(spanMm * fraction, samePointMm);

  /// The fraction above, for a raw drawing.
  static const double weldFraction = 0.01;

  /// The fraction for geometry that has already been cleaned up, where the
  /// ends are where the user put them and only arithmetic is in the way.
  static const double weldFractionClean = 0.004;

  /// A section smaller than this is a sliver where two lines nearly met, not
  /// something anybody meant to build.
  static const double minSectionAreaMmSq = 400;

  /// The shortest line that is a line rather than a slip of the finger.
  static const double minLineMm = 30;

  /// How much bigger, as a fraction of itself, the shape one line across two
  /// loose ends would close must be than the shape that is already closed,
  /// for the drawing to be an outline with a side missing.
  ///
  /// A door drawn as head and jambs with a transom near the top closes — as
  /// the strip above the transom, with the rest of the jambs hanging below
  /// it. The shape the user drew is the whole door, many times that strip.
  /// A jamb drawn a hand's width past the sill closes a sliver a few
  /// percent of the door, and that is an overshoot to trim, not a side
  /// left open. A fifth separates the two with room either side.
  static const double openSideFraction = 0.2;
}
