import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/geometry/point2.dart';
import 'canvas_projection.dart';

/// A note's label, positioned in pixels.
@immutable
class NoteLabel {
  final String panelId;
  final String noteId;
  final String text;

  /// Where the label is drawn.
  final Offset centre;

  /// The panel the note belongs to, in pixels. A note is moved within its own
  /// panel and no further, so the drag needs the panel's box as well as the
  /// label's position.
  final Rect panelRect;

  const NoteLabel({
    required this.panelId,
    required this.noteId,
    required this.text,
    required this.centre,
    required this.panelRect,
  });

  /// Where a finger has to land to mean this label.
  ///
  /// A full touch target however short the note is, so a one-word note can
  /// still be grabbed with a work glove on (spec section 7).
  Rect get hitRect => Rect.fromCenter(
        center: centre,
        width: AppSizing.minTouchTarget,
        height: AppSizing.minTouchTarget,
      );

  /// [pixels] expressed as a fraction of the panel, which is how a note's
  /// position is stored so that it survives the panel being resized.
  Point2 fractionOf(Offset pixels) {
    if (panelRect.width <= 0 || panelRect.height <= 0) {
      return const Point2(0.5, 0.5);
    }
    return Point2(
      ((pixels.dx - panelRect.left) / panelRect.width).clamp(0.0, 1.0),
      ((pixels.dy - panelRect.top) / panelRect.height).clamp(0.0, 1.0),
    );
  }
}

/// Works out where every note label goes.
///
/// One place, used by both the painter and the canvas's hit testing, so what
/// is drawn and what can be dragged cannot drift apart.
abstract final class NoteLabels {
  /// The visible notes of [design], in pixels, under [projection].
  ///
  /// Hidden notes are left out: a hidden label is not drawn, so it must not be
  /// grabbable either.
  static List<NoteLabel> of(
    DesignDocument design,
    CanvasProjection projection,
  ) {
    final labels = <NoteLabel>[];
    for (final panel in design.panels) {
      final box = panel.boundary;
      final rect = projection.toPixelRect(
        box.left,
        box.top,
        box.right,
        box.bottom,
      );
      for (final note in panel.visibleNotes) {
        final at = note.clampedPosition;
        labels.add(
          NoteLabel(
            panelId: panel.id,
            noteId: note.id,
            text: note.text,
            centre: Offset(
              rect.left + rect.width * at.x,
              rect.top + rect.height * at.y,
            ),
            panelRect: rect,
          ),
        );
      }
    }
    return labels;
  }

  /// The label under [pixels], or null. The nearest one wins, so overlapping
  /// labels pick the one the user aimed at rather than the first drawn.
  static NoteLabel? at(List<NoteLabel> labels, Offset pixels) {
    NoteLabel? best;
    var bestDistance = double.infinity;
    for (final label in labels) {
      if (!label.hitRect.contains(pixels)) continue;
      final distance = (label.centre - pixels).distanceSquared;
      if (distance < bestDistance) {
        best = label;
        bestDistance = distance;
      }
    }
    return best;
  }
}
