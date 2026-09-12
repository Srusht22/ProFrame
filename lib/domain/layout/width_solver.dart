import '../geometry/point2.dart';
import '../geometry/polygon.dart';
import '../geometry/tolerances.dart';
import '../panel.dart';

/// The outcome of asking for a panel width.
sealed class WidthOutcome {
  const WidthOutcome();
}

/// The width was applied; [panels] is the whole row, still summing to the
/// frame width.
class WidthApplied extends WidthOutcome {
  final List<Panel> panels;

  /// Which panel absorbed the difference, so the UI can say so rather than
  /// leaving the user to spot that a neighbour moved.
  final String adjustedPanelId;

  /// How much the neighbour changed by, signed.
  final double adjustmentMm;

  const WidthApplied({
    required this.panels,
    required this.adjustedPanelId,
    required this.adjustmentMm,
  });
}

/// Why a width was refused.
///
/// The code is what makes a refusal translatable: [WidthRefused.reason] is
/// the English wording, for a log and a test, and the UI writes its own
/// sentence from the code and the numbers.
enum WidthRefusal {
  noPanelsToResize,
  panelNotInRow,
  onlyPanelInRow,
  narrowerThanMinimum,
  neighbourWouldBeTooNarrow,
}

/// The width could not be applied. Nothing was changed.
///
/// A refusal, not a silent clamp: quietly giving the user a different number
/// from the one they typed is the behaviour the spec forbids (section 2).
class WidthRefused extends WidthOutcome {
  /// Which refusal this is, so it can be written in any language.
  final WidthRefusal code;

  /// Plain language, no jargon. English: what a log and a test read.
  final String reason;

  /// The largest width that would have worked, when one exists. Offered as a
  /// suggestion the user may take, never applied automatically.
  final double? largestWorkableMm;

  /// The numbers the sentence names, unformatted.
  final Map<String, double> values;

  const WidthRefused(
    this.reason, {
    required this.code,
    this.largestWorkableMm,
    this.values = const {},
  });
}

/// Keeps panel widths summing to the frame width (spec Phase 2, item 4).
///
/// **Which neighbour absorbs the change:** the panel immediately to the right,
/// because the user reads and edits the row left to right and expects what
/// they have already set to stay put. For the rightmost panel there is no
/// right-hand neighbour, so the one to its left absorbs instead. The outcome
/// names the panel that moved.
abstract final class WidthSolver {
  /// Sets the width of [panelId] within [row], adjusting one neighbour.
  ///
  /// [row] must be the panels of a single horizontal band, in any order; they
  /// are sorted internally by their left edge.
  static WidthOutcome setWidth(
    List<Panel> row,
    String panelId,
    double newWidthMm,
  ) {
    if (row.isEmpty) {
      return const WidthRefused(
        'There are no panels to resize.',
        code: WidthRefusal.noPanelsToResize,
      );
    }

    final sorted = [...row]
      ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));
    final index = sorted.indexWhere((p) => p.id == panelId);
    if (index < 0) {
      return const WidthRefused(
        'That panel is not in this row.',
        code: WidthRefusal.panelNotInRow,
      );
    }

    if (sorted.length == 1) {
      return const WidthRefused(
        'This is the only panel, so its width is the frame width. Change the '
        'overall width instead.',
        code: WidthRefusal.onlyPanelInRow,
      );
    }

    if (newWidthMm < Tolerances.minimumPanelSideMm) {
      return const WidthRefused(
        'A panel cannot be narrower than '
        '${Tolerances.minimumPanelSideMm} mm.',
        code: WidthRefusal.narrowerThanMinimum,
        values: {'minimum': Tolerances.minimumPanelSideMm},
      );
    }

    final target = sorted[index];
    final delta = newWidthMm - target.boundary.width;
    if (delta.abs() < Tolerances.lengthMm) {
      return WidthApplied(
        panels: sorted,
        adjustedPanelId: target.id,
        adjustmentMm: 0,
      );
    }

    // The right-hand neighbour absorbs, except for the last panel in the row.
    final isLast = index == sorted.length - 1;
    final neighbourIndex = isLast ? index - 1 : index + 1;
    final neighbour = sorted[neighbourIndex];
    final neighbourWidth = neighbour.boundary.width - delta;

    if (neighbourWidth < Tolerances.minimumPanelSideMm) {
      final headroom = neighbour.boundary.width - Tolerances.minimumPanelSideMm;
      return WidthRefused(
        'There is not enough room. Widening this panel to '
        '${newWidthMm.round()} mm would leave the panel beside it at '
        '${neighbourWidth.round()} mm, under the '
        '${Tolerances.minimumPanelSideMm.round()} mm minimum.',
        code: WidthRefusal.neighbourWouldBeTooNarrow,
        largestWorkableMm: target.boundary.width + headroom,
        values: {
          'requested': newWidthMm,
          'neighbour': neighbourWidth,
          'minimum': Tolerances.minimumPanelSideMm,
        },
      );
    }

    return WidthApplied(
      panels: _rebuild(sorted, index, newWidthMm, neighbourIndex, neighbourWidth),
      adjustedPanelId: neighbour.id,
      adjustmentMm: -delta,
    );
  }

  /// Lays the row out again from the new widths, keeping every panel's id,
  /// behaviour, note and infill.
  ///
  /// Rebuilding from the left edge of the row is what guarantees the panels
  /// still tile it exactly: the widths are the input and the positions follow,
  /// so rounding cannot open a gap between two panels.
  static List<Panel> _rebuild(
    List<Panel> sorted,
    int targetIndex,
    double targetWidth,
    int neighbourIndex,
    double neighbourWidth,
  ) {
    final widths = [
      for (var i = 0; i < sorted.length; i++)
        if (i == targetIndex)
          targetWidth
        else if (i == neighbourIndex)
          neighbourWidth
        else
          sorted[i].boundary.width,
    ];

    var cursor = sorted.first.boundary.left;
    final result = <Panel>[];
    for (var i = 0; i < sorted.length; i++) {
      final panel = sorted[i];
      final box = panel.boundary;
      result.add(
        panel.copyWith(
          boundary: Polygon.rectangle(
            width: widths[i],
            height: box.height,
            topLeft: Point2(cursor, box.top),
          ),
        ),
      );
      cursor += widths[i];
    }
    return result;
  }

  /// Distributes [row] into equal widths across the space it already occupies.
  ///
  /// Only ever called because the user asked for it. Equal panels are never
  /// assumed (spec section 2).
  static List<Panel> distributeEqually(List<Panel> row) {
    if (row.length < 2) return [...row];

    final sorted = [...row]
      ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));
    final left = sorted.first.boundary.left;
    final right = sorted.last.boundary.right;
    final each = (right - left) / sorted.length;

    var cursor = left;
    final result = <Panel>[];
    for (final panel in sorted) {
      result.add(
        panel.copyWith(
          boundary: Polygon.rectangle(
            width: each,
            height: panel.boundary.height,
            topLeft: Point2(cursor, panel.boundary.top),
          ),
        ),
      );
      cursor += each;
    }
    return result;
  }

  /// Whether [row] still tiles the span it occupies, within tolerance.
  ///
  /// Used by tests and by validation; a design that fails this has a gap or an
  /// overlap the user needs to be told about.
  static bool tilesExactly(List<Panel> row) {
    if (row.length < 2) return true;
    final sorted = [...row]
      ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].boundary.left - sorted[i - 1].boundary.right;
      if (gap.abs() > Tolerances.lengthMm) return false;
    }
    return true;
  }
}
