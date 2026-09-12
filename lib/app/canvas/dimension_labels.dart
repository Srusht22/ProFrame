import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import 'canvas_projection.dart';

/// Which dimension a label stands for.
enum DimensionTarget {
  overallWidth,
  overallHeight,

  /// One panel's width, written under that panel.
  panelWidth,
}

/// A dimension line and its label, positioned in pixels.
@immutable
class DimensionLabel {
  final DimensionTarget target;

  /// The panel this belongs to, for [DimensionTarget.panelWidth].
  final String? panelId;

  final double valueMm;

  /// False while the size is only scaled from the drawing. Unconfirmed values
  /// are written in brackets, not merely in a different colour, so the
  /// distinction survives a monochrome print and a colour-blind reader
  /// (spec sections 2 and 7).
  final bool confirmed;

  final Offset from;
  final Offset to;
  final bool horizontal;

  const DimensionLabel({
    required this.target,
    required this.valueMm,
    required this.confirmed,
    required this.from,
    required this.to,
    required this.horizontal,
    this.panelId,
  });

  Offset get centre => Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);

  /// Where a finger has to land to mean this label.
  ///
  /// Always at least the minimum touch target, however short the dimension
  /// line is — a narrow panel's label must still be tappable with a work
  /// glove on (spec section 7).
  Rect get hitRect => Rect.fromCenter(
        center: centre,
        width: AppSizing.minTouchTarget,
        height: AppSizing.minTouchTarget,
      );
}

/// Works out where every dimension line and label goes.
///
/// One place, used by both the painter and the canvas's hit testing, so what
/// is drawn and what can be tapped cannot drift apart.
abstract final class DimensionLabels {
  /// The labels for [design], in pixels, under [projection].
  ///
  /// Laid out like the paper sketches: each panel's width under its own panel,
  /// the total width below that, the total height at the side
  /// (spec Phase 2, item 4).
  static List<DimensionLabel> of(
    DesignDocument design,
    CanvasProjection projection,
  ) {
    final outline = design.outline;
    if (outline == null) return const [];

    final frame = projection.toPixelRect(
      outline.left,
      outline.top,
      outline.right,
      outline.bottom,
    );
    final widthConfirmed = design.overallWidth?.isConfirmed ?? false;
    final heightConfirmed = design.overallHeight?.isConfirmed ?? false;

    // Panels along the bottom of the frame get their width written under them.
    final bottomRow = design.panels
        .where((panel) => (panel.boundary.bottom - outline.bottom).abs() < 1)
        .toList()
      ..sort((a, b) => a.boundary.left.compareTo(b.boundary.left));

    return [
      // Only worth labelling per panel when there is more than one; otherwise
      // it just repeats the total.
      if (bottomRow.length > 1)
        for (final panel in bottomRow)
          DimensionLabel(
            target: DimensionTarget.panelWidth,
            panelId: panel.id,
            valueMm: panel.widthMm,
            confirmed: widthConfirmed,
            from: Offset(
              projection.toPixels(panel.boundary.vertices.first).dx,
              frame.bottom + AppCanvasMetrics.dimensionOffset * 0.7,
            ),
            to: Offset(
              projection
                  .toPixels(panel.boundary.vertices[1])
                  .dx,
              frame.bottom + AppCanvasMetrics.dimensionOffset * 0.7,
            ),
            horizontal: true,
          ),
      DimensionLabel(
        target: DimensionTarget.overallWidth,
        valueMm: outline.width,
        confirmed: widthConfirmed,
        from: Offset(
          frame.left,
          frame.bottom + AppCanvasMetrics.dimensionOffset * 1.8,
        ),
        to: Offset(
          frame.right,
          frame.bottom + AppCanvasMetrics.dimensionOffset * 1.8,
        ),
        horizontal: true,
      ),
      DimensionLabel(
        target: DimensionTarget.overallHeight,
        valueMm: outline.height,
        confirmed: heightConfirmed,
        from: Offset(frame.left - AppCanvasMetrics.dimensionOffset, frame.top),
        to: Offset(frame.left - AppCanvasMetrics.dimensionOffset, frame.bottom),
        horizontal: false,
      ),
    ];
  }

  /// The label under [pixels], or null.
  ///
  /// Panel labels are tested before the totals: they are smaller and sit
  /// closer together, so a tap that could mean either should mean the more
  /// specific one.
  static DimensionLabel? at(List<DimensionLabel> labels, Offset pixels) {
    for (final label in labels) {
      if (label.target == DimensionTarget.panelWidth &&
          label.hitRect.contains(pixels)) {
        return label;
      }
    }
    for (final label in labels) {
      if (label.hitRect.contains(pixels)) return label;
    }
    return null;
  }
}
