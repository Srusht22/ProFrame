import 'polygon.dart';
import 'segment.dart';
import 'vec2.dart';

/// A section's own coordinates: where the things inside it are, said in its
/// terms rather than the sheet's.
///
/// A bar 40 cm down a sash is 40 cm down that sash wherever on the sheet the
/// sash happens to be, and whatever the design around it is doing. That is
/// what it means for something to be *inside* a section rather than merely
/// drawn on top of it, and it is the figure the user typed, so it is the one
/// the application has to keep.
///
/// Everything that reads or writes a child's place goes through here — the
/// inspector's figures, the field the user types into, and the tests — so
/// there is one answer rather than the same arithmetic written out in four
/// places and quietly disagreeing in the corners.
///
/// **Nothing is stored twice.** A child keeps the one set of coordinates it
/// has, and its place in its parent's terms is worked out from them. Storing
/// both would be two descriptions of one fact, and the first edit that
/// touched one and not the other would make the design mean two things at
/// once. What matters is not where the numbers live but that the figure the
/// user typed comes back unchanged, and it does: a bar put 40 cm down an
/// opening reads 40 cm down that opening after the opening has been moved
/// across the window and after it has been made wider.
abstract final class LocalSpace {
  /// Where [point] is inside [box], from that box's own top left corner.
  static Vec2 of(Polygon box, Vec2 point) => point - box.topLeft;

  /// The point that [local] names inside [box], back on the sheet.
  static Vec2 onSheet(Polygon box, Vec2 local) => box.topLeft + local;

  /// [line] said in [box]'s terms, end for end.
  static Segment segmentOf(Polygon box, Segment line) =>
      Segment(of(box, line.a), of(box, line.b));

  /// How far [line] sits into [box], measured from the box's own top left
  /// corner square to the line.
  ///
  /// For a bar across the box that is how far down it is; for a bar up the
  /// box, how far across. A bar at any other angle has the same answer by
  /// the same measurement — the perpendicular from the corner to the line —
  /// which is what lets a diagonal glazing bar be placed in the opening's
  /// own terms like every other. Measuring the two square cases separately
  /// and leaving the third out meant the figure on a diagonal's panel did
  /// nothing at all when it was typed over.
  static double alongIn(Polygon box, Segment line) =>
      (line.a - box.topLeft).dot(_outFrom(box, line));

  /// How far [box] reaches from its top left corner, square to [line]: the
  /// largest figure [alongIn] can return for a line at that angle.
  static double reachIn(Polygon box, Segment line) {
    final out = _outFrom(box, line);
    var most = 0.0;
    for (final corner in box.corners) {
      final away = (corner - box.topLeft).dot(out);
      if (away > most) most = away;
    }
    return most;
  }

  /// How far [line] has to move, square to itself, to sit [alongMm] into
  /// [box] — clamped, so a figure typed past the far side puts the bar on
  /// the far side rather than outside the section it belongs to.
  static Vec2 shiftFor(Polygon box, Segment line, double alongMm) {
    final out = _outFrom(box, line);
    final to = alongMm.clamp(0.0, reachIn(box, line));
    return out * (to - alongIn(box, line));
  }

  /// The way out of [box]'s top left corner, square to [line].
  ///
  /// Turned to point into the box rather than out of it, so the figure does
  /// not change sign because the user happened to draw the bar right to left
  /// instead of left to right.
  static Vec2 _outFrom(Polygon box, Segment line) {
    final normal = line.unit.perpendicular;
    return (line.a - box.topLeft).dot(normal) < 0 ? -normal : normal;
  }
}
