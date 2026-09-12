import '../geometry/point2.dart';
import '../geometry/polygon.dart';
import '../geometry/tolerances.dart';
import '../panel.dart';

/// Splits a panel where a divider was drawn.
///
/// The split is **proportional to where the stroke landed** (spec Phase 2,
/// item 3): a divider drawn a third of the way across makes a panel a third
/// as wide, not half. Equal panels happen only when the user asks for them.
abstract final class PanelSplitter {
  /// Splits [panel] with a vertical divider at [atX].
  ///
  /// Returns the two new panels, left first. Both are CH, because an unmarked
  /// panel is fixed until the user says otherwise (spec Phase 2, item 2).
  ///
  /// The original panel's id does not survive. Splitting creates two new
  /// things, and pretending one of them is the old panel would make the user's
  /// earlier CH/Z choice silently apply to half a design
  /// (spec section 10). Notes and infill are inherited by both halves, because
  /// those describe the glass and the glass is still there.
  static (Panel left, Panel right) splitVertical(
    Panel panel,
    double atX, {
    required String leftId,
    required String rightId,
  }) {
    final box = panel.boundary;
    _requireRoom(atX, box.left, box.right, 'vertical');

    return (
      _derive(
        panel,
        leftId,
        Polygon.rectangle(
          width: atX - box.left,
          height: box.height,
          topLeft: Point2(box.left, box.top),
        ),
      ),
      _derive(
        panel,
        rightId,
        Polygon.rectangle(
          width: box.right - atX,
          height: box.height,
          topLeft: Point2(atX, box.top),
        ),
      ),
    );
  }

  /// Splits [panel] with a horizontal divider at [atY]. Top panel first.
  static (Panel top, Panel bottom) splitHorizontal(
    Panel panel,
    double atY, {
    required String topId,
    required String bottomId,
  }) {
    final box = panel.boundary;
    _requireRoom(atY, box.top, box.bottom, 'horizontal');

    return (
      _derive(
        panel,
        topId,
        Polygon.rectangle(
          width: box.width,
          height: atY - box.top,
          topLeft: Point2(box.left, box.top),
        ),
      ),
      _derive(
        panel,
        bottomId,
        Polygon.rectangle(
          width: box.width,
          height: box.bottom - atY,
          topLeft: Point2(box.left, atY),
        ),
      ),
    );
  }

  /// A new panel carrying across what still applies after a split.
  ///
  /// Always CH: the halves are new panels and nobody has said how they open.
  /// Mesh and the empty flag follow, because they describe the infill rather
  /// than the opening.
  ///
  /// Notes are deliberately *not* copied here. Duplicating a remark onto both
  /// halves would put it somewhere the user never wrote it; where each note
  /// belongs is decided geometrically by [NoteResolver.afterSplit], which the
  /// caller applies to the pair this returns.
  static Panel _derive(Panel source, String id, Polygon boundary) => Panel.fixed(
        id: id,
        boundary: boundary,
        infill: source.infill,
        hasMesh: source.hasMesh,
        isEmpty: source.isEmpty,
      );

  static void _requireRoom(double at, double low, double high, String axis) {
    if (at - low < Tolerances.minimumPanelSideMm ||
        high - at < Tolerances.minimumPanelSideMm) {
      throw ArgumentError.value(
        at,
        'at',
        'A $axis divider here would leave a panel under '
            '${Tolerances.minimumPanelSideMm.round()} mm.',
      );
    }
  }
}
