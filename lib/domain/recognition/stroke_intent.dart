import '../geometry/point2.dart';
import '../geometry/polygon.dart';
import '../product/opening.dart';

/// What the classifier decided a stroke means.
///
/// A closed set: the drawing grammar this release supports is exactly these
/// four intents plus "discarded". Anything the user draws that is not one of
/// them is thrown away rather than guessed at (spec Phase 2, item 2).
sealed class StrokeIntent {
  /// The stroke this came from, so the UI can point at what it read.
  final String strokeId;

  const StrokeIntent(this.strokeId);
}

/// A closed-ish loop with about four corners: the outer frame.
///
/// [rectangle] is the perfect rectangle fitted to the loop's extent. The rough
/// loop the user actually drew is kept in the sketch, so nothing is lost.
class FrameIntent extends StrokeIntent {
  final Polygon rectangle;

  const FrameIntent(super.strokeId, this.rectangle);

  @override
  String toString() => 'FrameIntent(${rectangle.width.round()} x '
      '${rectangle.height.round()} mm)';
}

/// A mostly-vertical stroke inside the frame: a mullion, snapped to vertical.
class VerticalDividerIntent extends StrokeIntent {
  /// Where it sits across the frame, in model millimetres.
  final double atX;

  /// The panel it was drawn across, which is the one that gets split.
  final String panelId;

  const VerticalDividerIntent(super.strokeId, this.atX, this.panelId);

  @override
  String toString() => 'VerticalDividerIntent(x=${atX.round()}, $panelId)';
}

/// A mostly-horizontal stroke inside the frame: a transom, snapped to
/// horizontal.
class HorizontalDividerIntent extends StrokeIntent {
  final double atY;
  final String panelId;

  const HorizontalDividerIntent(super.strokeId, this.atY, this.panelId);

  @override
  String toString() => 'HorizontalDividerIntent(y=${atY.round()}, $panelId)';
}

/// A chevron drawn inside a panel: that panel opens, hinged on the side the
/// chevron points to.
///
/// The convention is the factory's: the point of the `<` or `>` is the hinge
/// edge. It is read in the elevation as drawn, and the project's viewing side
/// says whether that elevation is the outside or the inside — the app states
/// which, and never infers it (spec section 3C).
class ChevronIntent extends StrokeIntent {
  final String panelId;
  final HingeSide hingeSide;

  /// Where the point of the chevron landed, for the UI to acknowledge the mark.
  final Point2 apex;

  const ChevronIntent(
    super.strokeId, {
    required this.panelId,
    required this.hingeSide,
    required this.apex,
  });

  @override
  String toString() => 'ChevronIntent($panelId, ${hingeSide.name})';
}

/// The stroke meant nothing the app understands, and was dropped.
///
/// [reason] is not shown to the user — the spec says discard *silently*
/// (Phase 2, item 2) — but it makes the classifier's decisions inspectable in
/// tests and in a debug overlay, which is the difference between a rule engine
/// and a black box.
class DiscardedIntent extends StrokeIntent {
  final String reason;

  const DiscardedIntent(super.strokeId, this.reason);

  @override
  String toString() => 'DiscardedIntent($reason)';
}
